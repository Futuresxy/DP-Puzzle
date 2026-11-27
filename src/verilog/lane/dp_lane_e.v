`include "dp_defs.vh"

// Dedicated E8 lane (MXFP4/NVFP4/HiF4): S1 decode, S2 4x4 multiply & pair sum, S3 4-pair sum tree.
// ARCHITECTURE_V19=1 fuses HiF4 e2 in S3 prior to the lane register; 0 retains legacy E64 S4 shift.
// Precision    | Input S | I | F | Product S | I | F | Pair S | I | F | Lane S | I | F
// ------------ | ------- | - | - | --------- | - | - | ------ | - | - | ------ | - | -
// MXFP4/NVFP4  | 0       | 3 | 1 | 0         | 6 | 2 | 1      | 7 | 2 | 1      | 9 | 2
// HiF4 (e1 in) | 0       | 2 | 2 | 0         | 4 | 4 | 1      | 5 | 4 | 1      | 7 | 4
// Output after e2 / fixed coordinate shift: TC S1I9F4 (14 bits).
module dp_lane_e #(
  parameter integer ARCHITECTURE_V19 = 0 // 0: legacy E64 S4 shift; 1: v1.9 S3 e2 fusion
) (
  input  wire                     clock,
  input  wire                     rst_n,
  input  wire                     in_valid,
  input  wire [   `DP_TYPE_W-1:0] in_datatype,
  input  wire [   `DP_LANE_W-1:0] in_a,
  input  wire [   `DP_LANE_W-1:0] in_b,
  input  wire [              1:0] in_e1_a,
  input  wire [              1:0] in_e1_b,
  input  wire                     in_e2_a,
  input  wire                     in_e2_b,
  output wire                     out_valid,
  output wire                     out_all_negative,
  output wire signed [      13:0] out_sop
);

  localparam integer PRODUCT_W = 2 * `DP_MUL_LO;
  localparam integer PAIRS     = `DP_E_LANES / 2;
  localparam integer PAIR_W    = PRODUCT_W + 2;
  localparam integer LANE_W    = PAIR_W + $clog2(PAIRS);
  localparam integer FUSED_W   = LANE_W + `DP_E_GUARD;

  // Stage valid pipeline tracking (S1..S3)
  wire [2:0] valid_q;

  // ==== Stage 1: E8 Operand Unpacking and Register Capture ====
  wire [`DP_E_LANES*`DP_MUL_LO-1:0] a_mantissa_d;
  wire [`DP_E_LANES*`DP_MUL_LO-1:0] b_mantissa_d;
  wire [           `DP_E_LANES-1:0] a_sign_d;
  wire [           `DP_E_LANES-1:0] b_sign_d;

  wire [`DP_E_LANES*`DP_MUL_LO-1:0] a_mantissa_s1_q;
  wire [`DP_E_LANES*`DP_MUL_LO-1:0] b_mantissa_s1_q;
  wire [           `DP_E_LANES-1:0] a_sign_s1_q;
  wire [           `DP_E_LANES-1:0] b_sign_s1_q;
  wire [                       1:0] shift_s1_q;

  dp_lane_unpack_e u_operand_unpack_a (
    .in_data       (in_a),
    .in_datatype   (in_datatype),
    .in_e1         (in_e1_a),
    .out_magnitude (a_mantissa_d),
    .out_negative  (a_sign_d)
  );

  dp_lane_unpack_e u_operand_unpack_b (
    .in_data       (in_b),
    .in_datatype   (in_datatype),
    .in_e1         (in_e1_b),
    .out_magnitude (b_mantissa_d),
    .out_negative  (b_sign_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(valid_q[0]));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s0_s1_a_sign_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(a_sign_d), .out_q(a_sign_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s0_s1_b_sign_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(b_sign_d), .out_q(b_sign_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES * `DP_MUL_LO))
  ff_s0_s1_a_mantissa_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(a_mantissa_d), .out_q(a_mantissa_s1_q));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES * `DP_MUL_LO))
  ff_s0_s1_b_mantissa_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(b_mantissa_d), .out_q(b_mantissa_s1_q));
  dp_lib_DFFE #(.WIDTH(2))
  ff_s0_s1_shift_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d((in_datatype == `DP_DT_HIF4) ? ({1'b0, in_e2_a} + {1'b0, in_e2_b}) : 2'd2), .out_q(shift_s1_q));

  // ==== Stage 2: 4x4 Unsigned Multiplication and Signed Pair Reduction ====
  wire [             `DP_E_LANES-1:0] product_negative;
  wire [`DP_E_LANES*(PRODUCT_W+1)-1:0] signed_products;
  wire [            PAIRS*PAIR_W-1:0] pairs_d;

  wire [            PAIRS*PAIR_W-1:0] pairs_s2_q;
  wire                                all_negative_s2_q;
  wire [                         1:0] shift_s2_q;

  genvar element_index;
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_product
      wire [        PRODUCT_W-1:0] magnitude;
      wire signed [  PRODUCT_W:0]  positive_product;

      assign positive_product = {1'b0, magnitude};

      dp_mul_unsigned #(
        .A_W (`DP_MUL_LO),
        .B_W (`DP_MUL_LO)
      ) u_element_mul (
        .in_a        (a_mantissa_s1_q[element_index*`DP_MUL_LO+:`DP_MUL_LO]),
        .in_b        (b_mantissa_s1_q[element_index*`DP_MUL_LO+:`DP_MUL_LO]),
        .out_product (magnitude)
      );

      assign product_negative[element_index] = a_sign_s1_q[element_index] ^ b_sign_s1_q[element_index];
      assign signed_products[element_index*(PRODUCT_W+1)+:PRODUCT_W+1] =
        product_negative[element_index] ? -positive_product : positive_product;
    end

    for (element_index = 0; element_index < PAIRS; element_index = element_index + 1) begin : g_pair
      wire signed [PRODUCT_W:0] pair_left;
      wire signed [PRODUCT_W:0] pair_right;

      assign pair_left  = signed_products[2*element_index*(PRODUCT_W+1)+:PRODUCT_W+1];
      assign pair_right = signed_products[(2*element_index+1)*(PRODUCT_W+1)+:PRODUCT_W+1];

      dp_sum_tree #(
        .N (2),
        .W (PRODUCT_W + 1)
      ) u_pair_sum (
        .in_values ({pair_right, pair_left}),
        .out_sum   (pairs_d[element_index*PAIR_W+:PAIR_W])
      );
    end
  endgenerate

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[0]), .out_q(valid_q[1]));
  dp_lib_DFFE #(.WIDTH(PAIRS * PAIR_W))
  ff_s1_s2_pairs_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(pairs_d), .out_q(pairs_s2_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s1_s2_all_negative_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(&product_negative), .out_q(all_negative_s2_q));
  dp_lib_DFFE #(.WIDTH(2))
  ff_s1_s2_shift_s2 (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(shift_s1_q), .out_q(shift_s2_q));

  // ==== Stage 3: 4-Pair Lane Sum Tree and e2 Coordinate Shift ====
  wire signed [LANE_W-1:0] lane_sum_d;
  wire signed [LANE_W-1:0] sop_s3_q;
  wire [              1:0] shift_s3_q;
  wire                     all_negative_s3_q;

  dp_sum_tree #(
    .N (PAIRS),
    .W (PAIR_W)
  ) u_lane_sop_tree (
    .in_values (pairs_s2_q),
    .out_sum   (lane_sum_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[1]), .out_q(valid_q[2]));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_all_negative_s3 (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(all_negative_s2_q), .out_q(all_negative_s3_q));

  generate
    if (ARCHITECTURE_V19 != 0) begin : g_v19
      // v1.9 fuses e2 shift into S14 before the S3 register boundary
      wire signed [FUSED_W-1:0] lane_fused_d;
      wire signed [FUSED_W-1:0] r3_fused_sum;

      dp_lane_e_shift #(
        .IN_W  (LANE_W),
        .OUT_W (FUSED_W)
      ) u_lane_coordinate_shift (
        .in_sum   (lane_sum_d),
        .in_shift (shift_s2_q),
        .out_sum  (lane_fused_d)
      );

      dp_lib_DFFE #(.WIDTH(FUSED_W))
      ff_s2_s3_fused_sum (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(lane_fused_d), .out_q(r3_fused_sum));

      assign out_sop    = r3_fused_sum;
      assign sop_s3_q   = {LANE_W{1'b0}};
      assign shift_s3_q = {`DP_E_GUARD{1'b0}};
    end else begin : g_legacy
      // Legacy E64 registers S12 sum and 2b shift at S3, then shifts combinationally in S4
      dp_lib_DFFE #(.WIDTH(LANE_W))
      ff_s2_s3_sop (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(lane_sum_d), .out_q(sop_s3_q));
      dp_lib_DFFE #(.WIDTH(`DP_E_GUARD))
      ff_s2_s3_shift (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(shift_s2_q), .out_q(shift_s3_q));

      dp_lane_e_shift #(
        .IN_W  (LANE_W),
        .OUT_W (FUSED_W)
      ) u_lane_coordinate_shift (
        .in_sum   (sop_s3_q),
        .in_shift (shift_s3_q),
        .out_sum  (out_sop)
      );
    end
  endgenerate

  assign out_valid        = valid_q[2];
  assign out_all_negative = all_negative_s3_q;

endmodule
