`include "dp_defs.vh"

// Multi-precision group (T2/H4/Q8/E16): two synchronized dp_lane units, S2 common exponent MAX,
// S1-S4 block-scale sideband pipeline, and S5 two-lane reduction, scale multiply, and LZD.
//
// S5 group output format (SM, P = LOCAL_W - 2, default 26):
// Precision / signal | S | I  | F
// ------------------ | - | -- | ----
// TF32               | 1 | 3  | P+2
// FP16 / BF16        | 1 | 4  | P+1
// MXFP8 / MXFP6      | 1 | 5  | P
// MXFP4              | 1 | 10 | P-5
// NVFP4              | 1 | 12 | P-7
// HiF4 legacy / v1.8 | 1 | 10/12 | P-5 / P-7
// INT8               | 1 | 18 | P-13
module dp_group #(
  parameter integer LOCAL_W      = `DP_DEFAULT_LOCAL_W,
  parameter integer BASELINE_V18 = 0, // 1 enables v1.8 S3 A_raw and S5 registered compare_exp
  parameter integer LANE_SOP_W   = LOCAL_W + 1 + $clog2(`DP_Q_LANES),
  parameter integer GROUP_W      = LANE_SOP_W + $clog2(`DP_LANES),
  parameter integer MAG_W        = GROUP_W - 1,
  parameter integer ANCHOR_W     = anchor_width(MAG_W)
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

  localparam integer COEFF_W         = 2 * `DP_SCALE_M;
  localparam integer SCALE_MAG_W     = `DP_SCALE_SOP_W - 1;
  localparam integer STRUCTURAL_DROP = GROUP_W - `DP_SCALE_SOP_W;
  localparam integer SCALE_PRODUCT_W = SCALE_MAG_W + COEFF_W;
  localparam integer SCALE_LOW_PAD   = MAG_W - SCALE_PRODUCT_W;

  // ==== Lanes & Stage 2 Common Group Exponent MAX ====
  wire [              `DP_LANES*LANE_SOP_W-1:0] lane_group_sum;
  wire [`DP_LANES*(`DP_PRODUCT_EXP_W+1)-1:0]    lane_exponent_max_candidates;
  wire [                         `DP_LANES-1:0] lane_exponent_max_active;
  wire [                         `DP_LANES-1:0] lane_group_all_negative;
  wire [                         `DP_LANES-1:0] lane_group_valid;
  wire [           `DP_LANES*`DP_SPECIAL_W-1:0] lane_group_special;
  wire [                 `DP_PRODUCT_EXP_W-1:0] lane_group_anchor [0:`DP_LANES-1];
  wire signed [              `DP_PRODUCT_EXP_W:0] exponent_max_lane_anchor;
  wire                                          max_active;

  genvar lane_index;
  generate
    for (lane_index = 0; lane_index < `DP_LANES; lane_index = lane_index + 1) begin : g_lane
      wire [`DP_PRODUCT_EXP_W-1:0] candidate;
      wire [    `DP_SPECIAL_W-1:0] special_value;

      dp_lane #(
        .LOCAL_W      (LOCAL_W),
        .BASELINE_V18 (BASELINE_V18)
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
        .in_group_max         (exponent_max_lane_anchor[`DP_PRODUCT_EXP_W-1:0]),
        .out_valid            (lane_group_valid[lane_index]),
        .out_sop              (lane_group_sum[lane_index*LANE_SOP_W+:LANE_SOP_W]),
        .out_anchor           (lane_group_anchor[lane_index]),
        .out_special          (special_value),
        .out_all_negative     (lane_group_all_negative[lane_index])
      );

      assign lane_exponent_max_candidates[lane_index*(`DP_PRODUCT_EXP_W+1)+:`DP_PRODUCT_EXP_W+1] = {1'b0, candidate};
      assign lane_group_special[lane_index*`DP_SPECIAL_W+:`DP_SPECIAL_W]                         = special_value;
    end
  endgenerate

  dp_max_tree #(
    .N (`DP_LANES),
    .W (`DP_PRODUCT_EXP_W + 1)
  ) u_group_exponent_max (
    .in_values  (lane_exponent_max_candidates),
    .in_active  (lane_exponent_max_active),
    .out_max    (exponent_max_lane_anchor),
    .out_active (max_active)
  );

  // ==== Stages 1-4: Block-Scale Unpack, Pair Multiply, and Raw Anchor Pipeline ====
  wire [                  3:0] valid_q;
  wire [       `DP_TYPE_W-1:0] type_q              [0:3];
  wire [      `DP_SCALE_M-1:0] scale_a_magnitude_d;
  wire [      `DP_SCALE_M-1:0] scale_b_magnitude_d;
  wire [        `DP_EXP_W-1:0] scale_a_exponent_d;
  wire [        `DP_EXP_W-1:0] scale_b_exponent_d;
  wire                         scale_a_nan_d;
  wire                         scale_b_nan_d;
  wire [      `DP_SCALE_M-1:0] scale_a_magnitude_q;
  wire [      `DP_SCALE_M-1:0] scale_b_magnitude_q;
  wire [        `DP_EXP_W-1:0] scale_a_exponent_q;
  wire [        `DP_EXP_W-1:0] scale_b_exponent_q;
  wire                         nan_s1_q;
  wire [          COEFF_W-1:0] coeff_d;
  wire [          COEFF_W-1:0] coeff_q             [1:3];
  wire [`DP_PRODUCT_EXP_W-1:0] scale_exponent_sum_d;
  wire [`DP_PRODUCT_EXP_W-1:0] scale_exp_q         [1:3];
  wire                         scale_nan_q         [1:3];
  wire [`DP_PRODUCT_EXP_W-1:0] r2_group_max;
  wire signed [          31:0] raw_anchor_work;
  wire signed [  ANCHOR_W-1:0] r3_raw_anchor;
  wire signed [  ANCHOR_W-1:0] r4_raw_anchor;

  dp_scale_unpack #(
    .UNBIASED_EXPONENT (BASELINE_V18)
  ) u_scale_unpack_a (
    .in_data       (in_scale_a),
    .in_datatype   (in_scale_datatype),
    .out_magnitude (scale_a_magnitude_d),
    .out_exponent  (scale_a_exponent_d),
    .out_nan       (scale_a_nan_d)
  );

  dp_scale_unpack #(
    .UNBIASED_EXPONENT (BASELINE_V18)
  ) u_scale_unpack_b (
    .in_data       (in_scale_b),
    .in_datatype   (in_scale_datatype),
    .out_magnitude (scale_b_magnitude_d),
    .out_exponent  (scale_b_exponent_d),
    .out_nan       (scale_b_nan_d)
  );

  // Stage 1 scale registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(valid_q[0]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s0_s1_type_q_0 (.clock(clock), .in_en(rst_n & in_valid), .in_d(in_datatype), .out_q(type_q[0]));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_sa (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_magnitude_d), .out_q(scale_a_magnitude_q));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_sb (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_magnitude_d), .out_q(scale_b_magnitude_q));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_ea (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_exponent_d), .out_q(scale_a_exponent_q));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_eb (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_exponent_d), .out_q(scale_b_exponent_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s0_s1_nan_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_nan_d | scale_b_nan_d), .out_q(nan_s1_q));

  // Stage 2 scale coefficient product and exponent sum
  dp_mul_unsigned #(
    .A_W (`DP_SCALE_M),
    .B_W (`DP_SCALE_M)
  ) u_scale_pair_mul (
    .in_a        (scale_a_magnitude_q),
    .in_b        (scale_b_magnitude_q),
    .out_product (coeff_d)
  );

  assign scale_exponent_sum_d = (BASELINE_V18 != 0) ?
    ({scale_a_exponent_q[`DP_EXP_W-1], scale_a_exponent_q} + {scale_b_exponent_q[`DP_EXP_W-1], scale_b_exponent_q}) :
    ({1'b0, scale_a_exponent_q} + {1'b0, scale_b_exponent_q});

  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s1_s2_group_max (.clock(clock), .in_en(rst_n & valid_q[0] & (BASELINE_V18 != 0)), .in_d(exponent_max_lane_anchor[`DP_PRODUCT_EXP_W-1:0]), .out_q(r2_group_max));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[0]), .out_q(valid_q[1]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s1_s2_type_q_1 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(type_q[0]), .out_q(type_q[1]));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s1_s2_coeff_q_1 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(coeff_d), .out_q(coeff_q[1]));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s1_s2_scale_exp_q_1 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(scale_exponent_sum_d), .out_q(scale_exp_q[1]));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s1_s2_scale_nan_q_1 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(nan_s1_q), .out_q(scale_nan_q[1]));

  // Stage 3 raw anchor precomputation (A_raw = group_max + scale_exp + M - 1 - F - 2*bias)
  assign raw_anchor_work = $signed({{(32 - `DP_PRODUCT_EXP_W){1'b0}}, r2_group_max}) +
    ((scale_type(type_q[1]) != `DP_SC_NONE) ?
     $signed({{(32 - `DP_PRODUCT_EXP_W){scale_exp_q[1][`DP_PRODUCT_EXP_W-1]}}, scale_exp_q[1]}) :
     32'sd0) +
    MAG_W - 1 -
    group_fraction((type_q[1] == `DP_DT_HIF4) ? `DP_DT_NVFP4 : type_q[1], LOCAL_W) -
    2 * element_bias(type_q[1]);

  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s2_s3_raw_anchor (.clock(clock), .in_en(rst_n & valid_q[1] & (BASELINE_V18 != 0)), .in_d(raw_anchor_work[ANCHOR_W-1:0]), .out_q(r3_raw_anchor));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[1]), .out_q(valid_q[2]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s2_s3_type_q_2 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(type_q[1]), .out_q(type_q[2]));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s2_s3_coeff_q_2 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(coeff_q[1]), .out_q(coeff_q[2]));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s2_s3_scale_exp_q_2 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(scale_exp_q[1]), .out_q(scale_exp_q[2]));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_scale_nan_q_2 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(scale_nan_q[1]), .out_q(scale_nan_q[2]));

  // Stage 4 sideband pipeline registers
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s3_s4_raw_anchor (.clock(clock), .in_en(rst_n & valid_q[2] & (BASELINE_V18 != 0)), .in_d(r3_raw_anchor), .out_q(r4_raw_anchor));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[2]), .out_q(valid_q[3]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s3_s4_type_q_3 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(type_q[2]), .out_q(type_q[3]));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s3_s4_coeff_q_3 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(coeff_q[2]), .out_q(coeff_q[3]));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s3_s4_scale_exp_q_3 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(scale_exp_q[2]), .out_q(scale_exp_q[3]));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s3_s4_scale_nan_q_3 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(scale_nan_q[2]), .out_q(scale_nan_q[3]));

  // ==== Stage 5: Two-Lane Reduction, Scale Multiply, LZD, and Group Token ====
  wire signed [        GROUP_W-1:0] group_sum;
  wire                              inject_scale;
  wire                              group_negative;
  wire [               GROUP_W-1:0] absolute_sop;
  wire [           SCALE_MAG_W-1:0] compact_mag;
  wire [               COEFF_W-1:0] compact_coeff;
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

  assign inject_scale   = ((type_q[3] == `DP_DT_NVFP4) | (type_q[3] == `DP_DT_HIF4)) & valid_q[3];
  assign group_negative = group_sum[GROUP_W-1];
  assign absolute_sop   = group_negative ? -group_sum : group_sum;
  assign compact_mag    = inject_scale ? absolute_sop[STRUCTURAL_DROP+:SCALE_MAG_W] : {SCALE_MAG_W{1'b0}};
  assign compact_coeff  = inject_scale ? coeff_q[3] : {COEFF_W{1'b0}};

  dp_scale_multiply u_group_scale_mul (
    .in_magnitude   (compact_mag),
    .in_coefficient (compact_coeff),
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
  wire [     `DP_SPECIAL_W-1:0] special_q;
  wire signed [         31:0]   anchor_work;
  wire signed [   ANCHOR_W-1:0] anchor_d;
  wire signed [   ANCHOR_W-1:0] compare_exp_d;
  wire [          ANCHOR_W-1:0] observed_z;

  assign lane0_special               = lane_group_special[0+:`DP_SPECIAL_W];
  assign lane1_special               = lane_group_special[`DP_SPECIAL_W+:`DP_SPECIAL_W];
  assign merged_special              = merge_special(lane0_special, lane1_special);
  assign zero_scale_infinity         = (coeff_q[3] == 0) &
                                       (merged_special[`DP_SP_POS_INF] | merged_special[`DP_SP_NEG_INF]);
  assign special_d[`DP_SP_NAN]       = merged_special[`DP_SP_NAN]     | scale_nan_q[3];
  assign special_d[`DP_SP_INVALID]   = merged_special[`DP_SP_INVALID] | zero_scale_infinity;
  assign special_d[`DP_SP_POS_INF]   = merged_special[`DP_SP_POS_INF] & ~zero_scale_infinity;
  assign special_d[`DP_SP_NEG_INF]   = merged_special[`DP_SP_NEG_INF] & ~zero_scale_infinity;
  assign out_special                 = special_q;

  // Legacy S5 anchor fallback when BASELINE_V18 == 0
  assign anchor_work = {{(32 - `DP_PRODUCT_EXP_W){1'b0}}, lane_group_anchor[0]} -
                       2 * element_bias(type_q[3]) -
                       group_fraction(type_q[3], LOCAL_W) +
                       MAG_W - 1 +
                       ((scale_type(type_q[3]) != `DP_SC_NONE) ?
                        ({{(32 - `DP_PRODUCT_EXP_W){1'b0}}, scale_exp_q[3]} - 2 * `DP_SCALE_BIAS) :
                        32'd0);
  assign anchor_d    = (~magnitude_active | (special_d != 0) | (type_q[3] == `DP_DT_INT8)) ?
                       {ANCHOR_W{1'b0}} :
                       ((BASELINE_V18 != 0) ? r4_raw_anchor : anchor_work[ANCHOR_W-1:0]);

  // Stage 5 output token registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_out_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[3]), .out_q(out_valid));
  dp_lib_DFFE #(.WIDTH(MAG_W))
  ff_s4_s5_out_magnitude (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(magnitude_d), .out_q(out_magnitude));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s4_s5_out_negative (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(negative_d), .out_q(out_negative));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s4_s5_out_anchor (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(anchor_d), .out_q(out_anchor));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s4_s5_special (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(special_d), .out_q(special_q));

  assign compare_exp_d = (magnitude_active & (special_d == 0) & (type_q[3] != `DP_DT_INT8)) ?
                         (anchor_d - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, z_d})) :
                         {ANCHOR_W{1'b0}};
  assign observed_z    = out_anchor - out_compare_exp;

  generate
    if (BASELINE_V18 != 0) begin : g_compare_register
      dp_lib_DFFE #(.WIDTH(ANCHOR_W))
      ff_s4_s5_compare_exp (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(compare_exp_d), .out_q(out_compare_exp));
      assign out_z = observed_z[$clog2(MAG_W+1)-1:0];
    end else begin : g_legacy_z_register
      dp_lib_DFFE #(.WIDTH($clog2(MAG_W + 1)))
      ff_s4_s5_out_z (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(((special_d == 0) & (type_q[3] != `DP_DT_INT8)) ? z_d : {$clog2(MAG_W+1){1'b0}}), .out_q(out_z));
      assign out_compare_exp = out_anchor - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, out_z});
    end
  endgenerate

endmodule
