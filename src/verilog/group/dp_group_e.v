`include "dp_defs.vh"

// Dedicated E16 group: two E8 lanes, S4 two-lane sum & abs, S5 unsigned scale multiply, LZD, & token.
// Precision    | S4 S | I  | F | Scale A S | I  | F | Scale B S | I | F | Product S | I  | F
// ------------ | ---- | -- | - | --------- | -- | - | --------- | - | - | --------- | -- | --
// NVFP4/HiF4   | 1    | 10 | 4 | 0         | 10 | 4 | 0         | 2 | 6 | 0         | 12 | 10
// MXFP4        | 1    | 10 | 4 | bypass    | 10 | 4 | unused    | - | - | bypass    | 10 | 4
// S5 output (SM, M = LOCAL_W + 3): MXFP4 = S1 I10 F(M-10); NVFP4/HiF4 = S1 I12 F(M-12).
module dp_group_e #(
  parameter integer ARCHITECTURE_V19 = 0, // 1 enables v1.9 narrow U22 LZD and registered compare_exp
  parameter integer LOCAL_W          = `DP_DEFAULT_LOCAL_W,
  parameter integer MAG_W            = LOCAL_W + 3,
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

  localparam integer PAIR_W    = 2 * `DP_MUL_LO + 2;
  localparam integer LANE_W    = PAIR_W + $clog2(`DP_E_LANES / 2);
  localparam integer FUSED_W   = LANE_W + `DP_E_GUARD;
  localparam integer GROUP_W   = FUSED_W + $clog2(`DP_LANES);
  localparam integer COMPACT_W = GROUP_W - 1;
  localparam integer COEFF_W   = 2 * `DP_SCALE_M;
  localparam integer PRODUCT_W = COMPACT_W + COEFF_W;

  // ==== Lanes (Stages 1-3) ====
  wire [`DP_LANES*FUSED_W-1:0] lane_group_sum;
  wire [        `DP_LANES-1:0] lane_group_all_negative;
  wire [        `DP_LANES-1:0] lane_group_valid;

  genvar lane_index;
  generate
    for (lane_index = 0; lane_index < `DP_LANES; lane_index = lane_index + 1) begin : g_lane
      dp_lane_e #(
        .ARCHITECTURE_V19 (ARCHITECTURE_V19)
      ) u_lane (
        .clock            (clock),
        .rst_n            (rst_n),
        .in_valid         (in_valid),
        .in_datatype      (in_datatype),
        .in_a             (in_a[lane_index*`DP_LANE_W+:`DP_LANE_W]),
        .in_b             (in_b[lane_index*`DP_LANE_W+:`DP_LANE_W]),
        .in_e1_a          (in_e1_a[lane_index*2+:2]),
        .in_e1_b          (in_e1_b[lane_index*2+:2]),
        .in_e2_a          (in_e2_a[lane_index]),
        .in_e2_b          (in_e2_b[lane_index]),
        .out_valid        (lane_group_valid[lane_index]),
        .out_all_negative (lane_group_all_negative[lane_index]),
        .out_sop          (lane_group_sum[lane_index*FUSED_W+:FUSED_W])
      );
    end
  endgenerate

  // ==== Stages 1-3: Block-Scale Unpack, Pair Multiply, and Anchor Precomputation ====
  wire [                  3:0] valid_q;
  wire [       `DP_TYPE_W-1:0] type_s1_q;
  wire [       `DP_TYPE_W-1:0] type_s2_q;
  wire [       `DP_TYPE_W-1:0] type_s3_q;
  wire [       `DP_TYPE_W-1:0] type_s4_q;
  wire [      `DP_SCALE_M-1:0] scale_a_magnitude_d;
  wire [      `DP_SCALE_M-1:0] scale_b_magnitude_d;
  wire [        `DP_EXP_W-1:0] scale_a_exponent_d;
  wire [        `DP_EXP_W-1:0] scale_b_exponent_d;
  wire                         scale_a_nan_d;
  wire                         scale_b_nan_d;
  wire [      `DP_SCALE_M-1:0] scale_a_magnitude_s1_q;
  wire [      `DP_SCALE_M-1:0] scale_b_magnitude_s1_q;
  wire [        `DP_EXP_W-1:0] scale_a_exponent_s1_q;
  wire [        `DP_EXP_W-1:0] scale_b_exponent_s1_q;
  wire                         nan_s1_q;
  wire                         nan_s2_q;
  wire                         nan_s3_q;
  wire                         nan_s4_q;
  wire [          COEFF_W-1:0] coefficient_d;
  wire [          COEFF_W-1:0] coeff_s2_q;
  wire [          COEFF_W-1:0] coeff_s3_q;
  wire [          COEFF_W-1:0] coeff_s4_q;
  wire [`DP_PRODUCT_EXP_W-1:0] scale_exponent_sum_d;
  wire [`DP_PRODUCT_EXP_W-1:0] scale_exp_s2_q;
  wire signed [          31:0] anchor_work;
  wire signed [  ANCHOR_W-1:0] anchor_s3_q;
  wire signed [  ANCHOR_W-1:0] anchor_s4_q;

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
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(valid_q[0]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s0_s1_type_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(in_datatype), .out_q(type_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_sa_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_magnitude_d), .out_q(scale_a_magnitude_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_SCALE_M))
  ff_s0_s1_sb_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_magnitude_d), .out_q(scale_b_magnitude_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_ea_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_exponent_d), .out_q(scale_a_exponent_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_EXP_W))
  ff_s0_s1_eb_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_b_exponent_d), .out_q(scale_b_exponent_s1_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s0_s1_nan_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(scale_a_nan_d | scale_b_nan_d), .out_q(nan_s1_q));

  // Stage 2 scale coefficient product and exponent sum
  dp_mul_unsigned #(
    .A_W (`DP_SCALE_M),
    .B_W (`DP_SCALE_M)
  ) u_scale_pair_mul (
    .in_a        (scale_a_magnitude_s1_q),
    .in_b        (scale_b_magnitude_s1_q),
    .out_product (coefficient_d)
  );

  assign scale_exponent_sum_d = (ARCHITECTURE_V19 != 0) ?
    ({scale_a_exponent_s1_q[`DP_EXP_W-1], scale_a_exponent_s1_q} +
     {scale_b_exponent_s1_q[`DP_EXP_W-1], scale_b_exponent_s1_q}) :
    ({1'b0, scale_a_exponent_s1_q} + {1'b0, scale_b_exponent_s1_q});

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[0]), .out_q(valid_q[1]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s1_s2_type_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(type_s1_q), .out_q(type_s2_q));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s1_s2_coeff_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(coefficient_d), .out_q(coeff_s2_q));
  dp_lib_DFFE #(.WIDTH(`DP_PRODUCT_EXP_W))
  ff_s1_s2_scale_exp_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(scale_exponent_sum_d), .out_q(scale_exp_s2_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s1_s2_nan_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(nan_s1_q), .out_q(nan_s2_q));

  // Stage 3 anchor precomputation: alpha - F + M - 1, where M - 1 - F = 9 (MXFP4) or 11 (NVFP4/HiF4)
  assign anchor_work = ((ARCHITECTURE_V19 != 0) ?
                        $signed({{(32 - `DP_PRODUCT_EXP_W){scale_exp_s2_q[`DP_PRODUCT_EXP_W-1]}}, scale_exp_s2_q}) :
                        ($signed({{(32 - `DP_PRODUCT_EXP_W){1'b0}}, scale_exp_s2_q}) - 2 * `DP_SCALE_BIAS)) +
                       ((type_s2_q == `DP_DT_MXFP4) ? 32'sd9 : 32'sd11);

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[1]), .out_q(valid_q[2]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s2_s3_type_s3 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(type_s2_q), .out_q(type_s3_q));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s2_s3_coeff_s3 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(coeff_s2_q), .out_q(coeff_s3_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_nan_s3 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(nan_s2_q), .out_q(nan_s3_q));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s2_s3_anchor_s3 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(anchor_work[ANCHOR_W-1:0]), .out_q(anchor_s3_q));

  // ==== Stage 4: Two-Lane Sum and Absolute Value Capture ====
  wire signed [GROUP_W-1:0] group_sum;
  wire [       GROUP_W-1:0] absolute_sop;
  wire [     COMPACT_W-1:0] magnitude_s4_q;
  wire                      negative_s4_q;

  dp_sum_tree #(
    .N (`DP_LANES),
    .W (FUSED_W)
  ) u_group_sop_add (
    .in_values (lane_group_sum),
    .out_sum   (group_sum)
  );

  assign absolute_sop = group_sum[GROUP_W-1] ? -group_sum : group_sum;

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[2]), .out_q(valid_q[3]));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s3_s4_type_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(type_s3_q), .out_q(type_s4_q));
  dp_lib_DFFE #(.WIDTH(COEFF_W))
  ff_s3_s4_coeff_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(coeff_s3_q), .out_q(coeff_s4_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s3_s4_nan_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(nan_s3_q), .out_q(nan_s4_q));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s3_s4_anchor_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(anchor_s3_q), .out_q(anchor_s4_q));
  dp_lib_DFFE #(.WIDTH(COMPACT_W))
  ff_s3_s4_magnitude_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(absolute_sop[COMPACT_W-1:0]), .out_q(magnitude_s4_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s3_s4_negative_s4 (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(group_sum[GROUP_W-1] | ((group_sum == 0) & (&lane_group_all_negative))), .out_q(negative_s4_q));

  // ==== Stage 5: Scale Multiply, LZD, and Group Token Output ====
  wire                          inject_scale;
  wire [         COMPACT_W-1:0] scale_magnitude;
  wire [           COEFF_W-1:0] scale_coefficient;
  wire [         PRODUCT_W-1:0] scale_product;
  wire [             MAG_W-1:0] magnitude_d;
  wire [  $clog2(MAG_W+1)-1:0]  leading_d;
  wire                          magnitude_active;

  assign inject_scale      = valid_q[3] & (type_s4_q != `DP_DT_MXFP4);
  assign scale_magnitude   = inject_scale ? magnitude_s4_q : {COMPACT_W{1'b0}};
  assign scale_coefficient = inject_scale ? coeff_s4_q     : {COEFF_W{1'b0}};

  dp_scale_multiply u_group_scale_mul (
    .in_magnitude   (scale_magnitude),
    .in_coefficient (scale_coefficient),
    .out_product    (scale_product)
  );

  assign magnitude_d = inject_scale ?
                       {scale_product, {(MAG_W - PRODUCT_W){1'b0}}} :
                       {magnitude_s4_q, {(MAG_W - COMPACT_W){1'b0}}};

  generate
    if (ARCHITECTURE_V19 != 0) begin : g_narrow_lzd
      // NVFP4/HiF4 U22 product and MXFP4 U14<<8 share identical MSB position; narrow U22 LZD suffices
      wire [              PRODUCT_W-1:0] lzd_magnitude;
      wire [$clog2(PRODUCT_W+1)-1:0]     leading_zero_count;

      assign lzd_magnitude = inject_scale ? scale_product : {magnitude_s4_q, {COEFF_W{1'b0}}};

      dp_lzd #(
        .W (PRODUCT_W)
      ) u_group_leading_detect (
        .in_magnitude (lzd_magnitude),
        .out_count    (leading_zero_count),
        .out_active   (magnitude_active)
      );

      assign leading_d = {{($clog2(MAG_W + 1) - $clog2(PRODUCT_W + 1)){1'b0}}, leading_zero_count};
    end else begin : g_legacy_lzd
      dp_lzd #(
        .W (MAG_W)
      ) u_group_leading_detect (
        .in_magnitude (magnitude_d),
        .out_count    (leading_d),
        .out_active   (magnitude_active)
      );
    end
  endgenerate

  // Stage 5 output token registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_out_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[3]), .out_q(out_valid));
  dp_lib_DFFE #(.WIDTH(MAG_W))
  ff_s4_s5_out_magnitude (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(magnitude_d), .out_q(out_magnitude));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s4_s5_out_negative (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(negative_s4_q), .out_q(out_negative));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s4_s5_out_special (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d({nan_s4_q, 3'b000}), .out_q(out_special));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s4_s5_out_anchor (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d((magnitude_active & ~nan_s4_q) ? anchor_s4_q : {ANCHOR_W{1'b0}}), .out_q(out_anchor));

  wire signed [ANCHOR_W-1:0] compare_exp_d;
  wire [       ANCHOR_W-1:0] observed_zero_count;

  assign compare_exp_d       = (magnitude_active & ~nan_s4_q) ?
                               (anchor_s4_q - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, leading_d})) :
                               {ANCHOR_W{1'b0}};
  assign observed_zero_count = out_anchor - out_compare_exp;

  generate
    if (ARCHITECTURE_V19 != 0) begin : g_compare_register
      dp_lib_DFFE #(.WIDTH(ANCHOR_W))
      ff_s4_s5_compare_exp (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(compare_exp_d), .out_q(out_compare_exp));
      assign out_z = observed_zero_count[$clog2(MAG_W+1)-1:0];
    end else begin : g_legacy_z_register
      dp_lib_DFFE #(.WIDTH($clog2(MAG_W + 1)))
      ff_s4_s5_out_z (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(nan_s4_q ? {$clog2(MAG_W+1){1'b0}} : leading_d), .out_q(out_z));
      assign out_compare_exp = out_anchor - $signed({{(ANCHOR_W - $clog2(MAG_W + 1)){1'b0}}, out_z});
    end
  endgenerate

endmodule
