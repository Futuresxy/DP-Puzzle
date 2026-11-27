`include "dp_defs.vh"

// QE mixed group (Q8/E16): two synchronized dp_lane_qe units, S2 common Q exponent MAX,
// S1-S4 block-scale sideband pipeline, and S5 two-lane reduction, scale multiply, and LZD.
//
// S5 group output format (SM, P = LOCAL_W - 2, default 26):
// Precision / signal | S | I     | F
// ------------------ | - | ----- | ---------
// MXFP8 / MXFP6      | 1 | 5     | P
// MXFP4              | 1 | 10    | P-5
// NVFP4              | 1 | 12    | P-7
// HiF4 v1.9 / legacy | 1 | 12/10 | P-7 / P-5
module dp_group_qe #(
  parameter integer ARCHITECTURE_V19 = 0, // 1 enables v1.9 E fixed-coord, S3 A_raw, and S5 compare_exp
  parameter integer COMPACT_UNPACK   = 0, // 1 selects pre-paired dp_lane_unpack_qe in child lanes
  parameter integer LOCAL_W          = `DP_DEFAULT_LOCAL_W,
  parameter integer LANE_SOP_W       = LOCAL_W + 1 + $clog2(`DP_Q_LANES),
  parameter integer GROUP_W          = LANE_SOP_W + $clog2(`DP_LANES),
  parameter integer MAG_W            = GROUP_W - 1,
  parameter integer ANCHOR_W         = anchor_width(MAG_W)
) (
  // Control and format configuration
  input  wire                               clock,
  input  wire                               rst_n,
  input  wire                               in_valid,
  input  wire [             `DP_TYPE_W-1:0] in_datatype,

  // Packed 2-lane operands, block scales, and HiF4 shared exponents
  input  wire [  `DP_LANES*`DP_LANE_W-1:0]  in_a,
  input  wire [  `DP_LANES*`DP_LANE_W-1:0]  in_b,
  input  wire [            `DP_SCALE_W-1:0] in_scale_a,
  input  wire [            `DP_SCALE_W-1:0] in_scale_b,
  input  wire [       `DP_SCALE_TYPE_W-1:0] in_scale_datatype,
  input  wire [                        3:0] in_e1_a,
  input  wire [                        3:0] in_e1_b,
  input  wire [                        1:0] in_e2_a,
  input  wire [                        1:0] in_e2_b,

  // Stage 5 group token outputs
  output wire                               out_valid,
  output wire                               out_negative,
  output wire [                  MAG_W-1:0] out_magnitude,
  output wire signed [        ANCHOR_W-1:0] out_anchor,
  output wire signed [        ANCHOR_W-1:0] out_compare_exp,
  output wire [       $clog2(MAG_W+1)-1:0]  out_z,
  output wire [          `DP_SPECIAL_W-1:0] out_special
);

  `include "dp_functions.vh"

  localparam integer                   COEFF_W                = 2 * `DP_SCALE_M;
  localparam integer                   SCALE_MAG_W            = `DP_SCALE_SOP_W - 1;
  localparam integer                   STRUCTURAL_DROP        = GROUP_W - `DP_SCALE_SOP_W;
  localparam integer                   SCALE_PRODUCT_W        = SCALE_MAG_W + COEFF_W;
  localparam integer                   SCALE_LOW_PAD          = MAG_W - SCALE_PRODUCT_W;
  localparam integer                   Q_ANCHOR_OFFSET        = MAG_W - 1 - (LOCAL_W - 2) - 2 * `DP_Q_BIAS;
  localparam signed [ANCHOR_W-1:0]     MX_ANCHOR_OFFSET       = 9;
  localparam signed [ANCHOR_W-1:0]     SCALED_E_ANCHOR_OFFSET = 11;

  // ==== Lanes & Stage 2 Common Group Exponent MAX ====
  wire [            `DP_LANES*LANE_SOP_W-1:0] lane_group_sum;
  wire [`DP_LANES*((`DP_Q_EXP_W+1)+1)-1:0]    lane_exponent_max_candidates;
  wire [                       `DP_LANES-1:0] lane_exponent_max_active;
  wire [                       `DP_LANES-1:0] lane_group_all_negative;
  wire [                       `DP_LANES-1:0] lane_group_valid;
  wire [         `DP_LANES*`DP_SPECIAL_W-1:0] lane_group_special;
  wire [                  (`DP_Q_EXP_W+1)-1:0] lane_group_anchor [0:`DP_LANES-1];
  wire signed [              (`DP_Q_EXP_W+1):0] exponent_max_lane_anchor;
  wire                                        max_active;

  genvar lane_index;
  generate
    for (lane_index = 0; lane_index < `DP_LANES; lane_index = lane_index + 1) begin : g_lane
      wire [(`DP_Q_EXP_W+1)-1:0] candidate;
      wire [  `DP_SPECIAL_W-1:0] special_value;

      dp_lane_qe #(
        .ARCHITECTURE_V19 (ARCHITECTURE_V19),
        .COMPACT_UNPACK   (COMPACT_UNPACK),
        .LOCAL_W          (LOCAL_W)
      ) u_lane (
        .clock                (clock),
        .rst_n                (rst_n),
        .in_valid             (in_valid),
        .in_datatype          (in_datatype),
        .in_a                 (in_a[lane_index*`DP_LANE_W+:`DP_LANE_W]),
        .in_b                 (in_b[lane_index*`DP_LANE_W+:`DP_LANE_W]),
        .in_e1_a              (in_e1_a[lane_index*2+:2]),
        .in_e1_b              (in_e1_b[lane_index*2+:2]),
        .in_e2_a              (in_e2_a[lane_index]),
        .in_e2_b              (in_e2_b[lane_index]),
        .out_candidate        (candidate),
        .out_candidate_active (lane_exponent_max_active[lane_index]),
        .in_group_max         (exponent_max_lane_anchor[(`DP_Q_EXP_W+1)-1:0]),
        .out_valid            (lane_group_valid[lane_index]),
        .out_sop              (lane_group_sum[lane_index*LANE_SOP_W+:LANE_SOP_W]),
        .out_anchor           (lane_group_anchor[lane_index]),
        .out_special          (special_value),
        .out_all_negative     (lane_group_all_negative[lane_index])
      );

      assign lane_exponent_max_candidates[lane_index*((`DP_Q_EXP_W+1)+1)+:(`DP_Q_EXP_W+1)+1] = {1'b0, candidate};
      assign lane_group_special[lane_index*`DP_SPECIAL_W+:`DP_SPECIAL_W]                     = special_value;
    end
  endgenerate

  dp_max_tree #(
    .N (`DP_LANES),
    .W ((`DP_Q_EXP_W + 1) + 1)
  ) u_group_exponent_max (
    .in_values  (lane_exponent_max_candidates),
    .in_active  (lane_exponent_max_active),
    .out_max    (exponent_max_lane_anchor),
    .out_active (max_active)
  );

  // ==== Stages 1-4: Block-Scale Unpack, Pair Multiply, and Raw Anchor Pipeline ====
  wire                         r1_valid;
  wire                         r2_valid;
  wire                         r3_valid;
  wire                         r4_valid;
  wire [       `DP_TYPE_W-1:0] r1_datatype;
  wire [       `DP_TYPE_W-1:0] r2_datatype;
  wire [       `DP_TYPE_W-1:0] r3_datatype;
  wire [       `DP_TYPE_W-1:0] r4_datatype;

  wire [      `DP_SCALE_M-1:0] scale_a_magnitude_d;
  wire [      `DP_SCALE_M-1:0] scale_b_magnitude_d;
  wire [        `DP_EXP_W-1:0] scale_a_exponent_d;
  wire [        `DP_EXP_W-1:0] scale_b_exponent_d;
  wire                         scale_a_nan_d;
  wire                         scale_b_nan_d;
  wire [      `DP_SCALE_M-1:0] r1_scale_a_magnitude;
  wire [      `DP_SCALE_M-1:0] r1_scale_b_magnitude;
  wire [        `DP_EXP_W-1:0] r1_scale_a_exponent;
  wire [        `DP_EXP_W-1:0] r1_scale_b_exponent;
  wire                         r1_scale_nan;

  wire [          COEFF_W-1:0] scale_coefficient_d;
  wire [          COEFF_W-1:0] r2_scale_coefficient;
  wire [          COEFF_W-1:0] r3_scale_coefficient;
  wire [          COEFF_W-1:0] r4_scale_coefficient;
  wire [`DP_PRODUCT_EXP_W-1:0] scale_exponent_sum_d;
  wire [`DP_PRODUCT_EXP_W-1:0] r2_scale_exponent;
  wire [`DP_PRODUCT_EXP_W-1:0] r3_scale_exponent;
  wire [`DP_PRODUCT_EXP_W-1:0] r4_scale_exponent;
  wire                         r2_scale_nan;
  wire                         r3_scale_nan;
  wire                         r4_scale_nan;
  wire [        `DP_Q_EXP_W:0] r2_group_max;

  dp_scale_unpack #(
    .UNBIASED_EXPONENT (ARCHITECTURE_V19)
  ) u_scale_unpack_a (
    .in_data       (in_scale_a),
    .in_datatype   (in_scale_datatype),
    .out_magnitude (scale_a_magnitude_d),
    .out_exponent  (scale_a_exponent_d),
    .out_nan       (scale_a_nan_d)
  );

  dp_scale_unpack #(
    .UNBIASED_EXPONENT (ARCHITECTURE_V19)
  ) u_scale_unpack_b (
    .in_data       (in_scale_b),
    .in_datatype   (in_scale_datatype),
    .out_magnitude (scale_b_magnitude_d),
    .out_exponent  (scale_b_exponent_d),
    .out_nan       (scale_b_nan_d)
  );

  // Stage 1 scale registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(r1_valid));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s0_s1_datatype (.clock(clock), .in_en(rst_n & in_valid), .in_d(in_datatype), .out_q(r1_datatype));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_scale_a_magnitude (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_magnitude_d), .out_q(r1_scale_a_magnitude));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_scale_b_magnitude (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_magnitude_d), .out_q(r1_scale_b_magnitude));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_scale_a_exponent (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_exponent_d), .out_q(r1_scale_a_exponent));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_scale_b_exponent (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_exponent_d), .out_q(r1_scale_b_exponent));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s0_s1_scale_nan (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_nan_d | scale_b_nan_d), .out_q(r1_scale_nan));

  // Stage 2 scale coefficient product and exponent sum
  dp_mul_unsigned #(
    .A_W (`DP_SCALE_M),
    .B_W (`DP_SCALE_M)
  ) u_scale_pair_mul (
    .in_a        (r1_scale_a_magnitude),
    .in_b        (r1_scale_b_magnitude),
    .out_product (scale_coefficient_d)
  );

  assign scale_exponent_sum_d = (ARCHITECTURE_V19 != 0) ?
    ({r1_scale_a_exponent[`DP_EXP_W-1], r1_scale_a_exponent} +
     {r1_scale_b_exponent[`DP_EXP_W-1], r1_scale_b_exponent}) :
    ({1'b0, r1_scale_a_exponent} + {1'b0, r1_scale_b_exponent});

  dp_lib_DFFE #(.WIDTH(`DP_Q_EXP_W + 1))
  ff_s1_s2_group_max (.clock(clock), .in_en(rst_n & r1_valid & (ARCHITECTURE_V19 != 0)), .in_d(exponent_max_lane_anchor[`DP_Q_EXP_W:0]), .out_q(r2_group_max));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(r1_valid), .out_q(r2_valid));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s1_s2_datatype (.clock(clock), .in_en(rst_n & r1_valid), .in_d(r1_datatype), .out_q(r2_datatype));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s1_s2_scale_coefficient (.clock(clock), .in_en(rst_n & r1_valid), .in_d(scale_coefficient_d), .out_q(r2_scale_coefficient));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s1_s2_scale_exponent (.clock(clock), .in_en(rst_n & r1_valid), .in_d(scale_exponent_sum_d), .out_q(r2_scale_exponent));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s1_s2_scale_nan (.clock(clock), .in_en(rst_n & r1_valid), .in_d(r1_scale_nan), .out_q(r2_scale_nan));

  // Stage 3 raw anchor precomputation
  wire signed [ANCHOR_W-1:0] element_anchor_d;
  wire signed [ANCHOR_W-1:0] scale_anchor_d;
  wire signed [ANCHOR_W-1:0] coordinate_offset_d;
  wire signed [ANCHOR_W-1:0] raw_anchor_d;
  wire signed [ANCHOR_W-1:0] r3_raw_anchor;
  wire signed [ANCHOR_W-1:0] r4_raw_anchor;

  assign element_anchor_d    = $signed({{(ANCHOR_W - `DP_Q_EXP_W - 1){1'b0}}, r2_group_max});
  assign scale_anchor_d      = $signed({{(ANCHOR_W - `DP_PRODUCT_EXP_W){r2_scale_exponent[`DP_PRODUCT_EXP_W-1]}}, r2_scale_exponent});
  assign coordinate_offset_d = (r2_datatype < `DP_DT_MXFP4)  ? $signed(Q_ANCHOR_OFFSET[ANCHOR_W-1:0]) :
                               (r2_datatype == `DP_DT_MXFP4) ? MX_ANCHOR_OFFSET :
                                                               SCALED_E_ANCHOR_OFFSET;
  assign raw_anchor_d        = element_anchor_d + scale_anchor_d + coordinate_offset_d;

  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s2_s3_raw_anchor (.clock(clock), .in_en(rst_n & r2_valid & (ARCHITECTURE_V19 != 0)), .in_d(raw_anchor_d), .out_q(r3_raw_anchor));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(r2_valid), .out_q(r3_valid));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s2_s3_datatype (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_datatype), .out_q(r3_datatype));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s2_s3_scale_coefficient (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_scale_coefficient), .out_q(r3_scale_coefficient));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s2_s3_scale_exponent (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_scale_exponent), .out_q(r3_scale_exponent));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_scale_nan (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_scale_nan), .out_q(r3_scale_nan));

  // Stage 4 sideband pipeline registers
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s3_s4_raw_anchor (.clock(clock), .in_en(rst_n & r3_valid & (ARCHITECTURE_V19 != 0)), .in_d(r3_raw_anchor), .out_q(r4_raw_anchor));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(r3_valid), .out_q(r4_valid));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s3_s4_datatype (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_datatype), .out_q(r4_datatype));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s3_s4_scale_coefficient (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_scale_coefficient), .out_q(r4_scale_coefficient));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s3_s4_scale_exponent (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_scale_exponent), .out_q(r4_scale_exponent));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s3_s4_scale_nan (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_scale_nan), .out_q(r4_scale_nan));

  // ==== Stage 5: Two-Lane Reduction, Scale Multiply, LZD, and Group Token ====
  wire signed [        GROUP_W-1:0] group_sum;
  wire                              inject_scale;
  wire                              group_negative;
  wire [               GROUP_W-1:0] absolute_sop;
  wire [           SCALE_MAG_W-1:0] compact_magnitude;
  wire [               COEFF_W-1:0] compact_coefficient;
  wire [       SCALE_PRODUCT_W-1:0] scale_product;
  wire [                 MAG_W-1:0] magnitude_d;
  wire                              negative_d;
  wire [      $clog2(MAG_W+1)-1:0]  z_d;
  wire                              magnitude_active;

  dp_sum_tree #(
    .N (`DP_LANES),
    .W (LANE_SOP_W)
  ) u_group_sop_add (
    .in_values (lane_group_sum),
    .out_sum   (group_sum)
  );

  assign inject_scale        = ((r4_datatype == `DP_DT_NVFP4) | (r4_datatype == `DP_DT_HIF4)) & r4_valid;
  assign group_negative      = group_sum[GROUP_W-1];
  assign absolute_sop        = group_negative ? -group_sum : group_sum;
  assign compact_magnitude   = inject_scale ? absolute_sop[STRUCTURAL_DROP+:SCALE_MAG_W] : {SCALE_MAG_W{1'b0}};
  assign compact_coefficient = inject_scale ? r4_scale_coefficient : {COEFF_W{1'b0}};

  dp_scale_multiply u_group_scale_mul (
    .in_magnitude   (compact_magnitude),
    .in_coefficient (compact_coefficient),
    .out_product    (scale_product)
  );

  assign magnitude_d = inject_scale ? {scale_product, {SCALE_LOW_PAD{1'b0}}} : absolute_sop[MAG_W-1:0];
  assign negative_d  = group_negative | ((group_sum == 0) & (&lane_group_all_negative));

  dp_lzd #(
    .W (MAG_W)
  ) u_group_leading_detect (
    .in_magnitude (magnitude_d),
    .out_count    (z_d),
    .out_active   (magnitude_active)
  );

  // Merge lane special flags and check for 0_scale * Inf invalid
  wire [     `DP_SPECIAL_W-1:0] lane0_special;
  wire [     `DP_SPECIAL_W-1:0] lane1_special;
  wire [     `DP_SPECIAL_W-1:0] merged_special;
  wire                          zero_scale_infinity;
  wire [     `DP_SPECIAL_W-1:0] special_d;
  wire [     `DP_SPECIAL_W-1:0] r5_special;
  wire signed [         31:0]   anchor_work;
  wire signed [   ANCHOR_W-1:0] anchor_d;
  wire signed [   ANCHOR_W-1:0] compare_exp_d;
  wire [          ANCHOR_W-1:0] observed_zero_count;

  assign lane0_special               = lane_group_special[0+:`DP_SPECIAL_W];
  assign lane1_special               = lane_group_special[`DP_SPECIAL_W+:`DP_SPECIAL_W];
  assign merged_special              = merge_special(lane0_special, lane1_special);
  assign zero_scale_infinity         = (r4_scale_coefficient == 0) &
                                       (merged_special[`DP_SP_POS_INF] | merged_special[`DP_SP_NEG_INF]);
  assign special_d[`DP_SP_NAN]       = merged_special[`DP_SP_NAN]     | r4_scale_nan;
  assign special_d[`DP_SP_INVALID]   = merged_special[`DP_SP_INVALID] | zero_scale_infinity;
  assign special_d[`DP_SP_POS_INF]   = merged_special[`DP_SP_POS_INF] & ~zero_scale_infinity;
  assign special_d[`DP_SP_NEG_INF]   = merged_special[`DP_SP_NEG_INF] & ~zero_scale_infinity;
  assign out_special                 = r5_special;

  // Legacy S5 anchor fallback when ARCHITECTURE_V19 == 0
  assign anchor_work = {{(32 - (`DP_Q_EXP_W + 1)){1'b0}}, lane_group_anchor[0]} -
                       ((r4_datatype < `DP_DT_MXFP4) ? (2 * `DP_Q_BIAS) : 0) -
                       ((r4_datatype < `DP_DT_MXFP4)  ? (LOCAL_W - 2) :
                        (r4_datatype == `DP_DT_NVFP4) ? (LOCAL_W - 9) :
                                                        (LOCAL_W - 7)) +
                       MAG_W - 1 + {{(32 - `DP_PRODUCT_EXP_W){1'b0}}, r4_scale_exponent} - 2 * `DP_SCALE_BIAS;
  assign anchor_d    = (~magnitude_active | (special_d != 0)) ?
                       {ANCHOR_W{1'b0}} :
                       ((ARCHITECTURE_V19 != 0) ? r4_raw_anchor : anchor_work[ANCHOR_W-1:0]);

  // Stage 5 output token registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_out_valid (.clock(clock), .rst_n(rst_n), .in_d(r4_valid), .out_q(out_valid));
  dp_lib_DFFE #(.WIDTH(MAG_W))
  ff_s4_s5_out_magnitude (.clock(clock), .in_en(rst_n & r4_valid), .in_d(magnitude_d), .out_q(out_magnitude));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s4_s5_out_negative (.clock(clock), .in_en(rst_n & r4_valid), .in_d(negative_d), .out_q(out_negative));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s4_s5_out_anchor (.clock(clock), .in_en(rst_n & r4_valid), .in_d(anchor_d), .out_q(out_anchor));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s4_s5_special (.clock(clock), .in_en(rst_n & r4_valid), .in_d(special_d), .out_q(r5_special));

  assign compare_exp_d       = (magnitude_active & (special_d == 0)) ?
                               (anchor_d - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, z_d})) :
                               {ANCHOR_W{1'b0}};
  assign observed_zero_count = out_anchor - out_compare_exp;

  generate
    if (ARCHITECTURE_V19 != 0) begin : g_compare_register
      dp_lib_DFFE #(.WIDTH(ANCHOR_W))
      ff_s4_s5_compare_exp (.clock(clock), .in_en(rst_n & r4_valid), .in_d(compare_exp_d), .out_q(out_compare_exp));
      assign out_z = observed_zero_count[$clog2(MAG_W+1)-1:0];
    end else begin : g_legacy_z_register
      dp_lib_DFFE #(.WIDTH($clog2(MAG_W + 1)))
      ff_s4_s5_out_z (.clock(clock), .in_en(rst_n & r4_valid), .in_d((special_d == 0) ? z_d : {$clog2(MAG_W+1){1'b0}}), .out_q(out_z));
      assign out_compare_exp = out_anchor - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, out_z});
    end
  endgenerate

endmodule
