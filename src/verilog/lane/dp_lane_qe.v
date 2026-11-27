`include "dp_defs.vh"

// QE mixed lane (Q4/E8): S1 unpack, S2 4x4 products & Q exponent MAX candidate,
// S3 local alignment (with v1.9 E fixed-coordinate bypass), and S4 4-leaf sum tree.
// Synchronous active-low reset clears valid bits only; disabled payload registers hold.
//
// S3 shift magnitude -> TC tree leaf (P = LOCAL_W - 2, default 26):
// Precision       | Shift S | Leaf S | I  | F
// --------------- | ------- | ------ | -- | ----
// MXFP8 / MXFP6   | 0       | 1      | 2  | P
// MXFP4 / NVFP4   | 0 / N/A | 1      | 7/9| P-5 / P-7
// HiF4            | 0 / N/A | 1      | 5/7| P-3 / P-5
//
// S4 lane SOP (TC):
// Precision / signal | S | I  | F
// ------------------ | - | -- | ----
// MXFP8 / MXFP6      | 1 | 4  | P
// MXFP4 / NVFP4      | 1 | 9  | P-5
// HiF4 legacy / v1.9 | 1 | 7/9| P-3 / P-5
module dp_lane_qe #(
  parameter integer ARCHITECTURE_V19 = 0,                            // 1 enables v1.9 E fixed-coordinate bypass
  parameter integer COMPACT_UNPACK   = 0,                            // 1 selects pre-paired dp_lane_unpack_qe
  parameter integer LOCAL_W          = `DP_DEFAULT_LOCAL_W,          // S3 unsigned alignment window width
  parameter integer LEAF_W           = LOCAL_W + 1,                  // S3 two's-complement leaf width
  parameter integer LANE_SOP_W       = LEAF_W + $clog2(`DP_Q_LANES)  // S4 4-input tree sum width
) (
  // Control and format configuration
  input  wire                          clock,
  input  wire                          rst_n,
  input  wire                          in_valid,
  input  wire [        `DP_TYPE_W-1:0] in_datatype,

  // Raw A/B lane operands and HiF4 shared exponents
  input  wire [        `DP_LANE_W-1:0] in_a,
  input  wire [        `DP_LANE_W-1:0] in_b,
  input  wire [                   1:0] in_e1_a,
  input  wire [                   1:0] in_e1_b,
  input  wire                          in_e2_a,
  input  wire                          in_e2_b,

  // Stage 2 combinational group exponent MAX interface
  output wire [     (`DP_Q_EXP_W+1)-1:0] out_candidate,
  output wire                            out_candidate_active,
  input  wire [     (`DP_Q_EXP_W+1)-1:0] in_group_max,

  // Stage 4 lane SOP and sideband outputs
  output wire                            out_valid,
  output wire signed [   LANE_SOP_W-1:0] out_sop,
  output wire [     (`DP_Q_EXP_W+1)-1:0] out_anchor,
  output wire [       `DP_SPECIAL_W-1:0] out_special,
  output wire                            out_all_negative
);

  `include "dp_functions.vh"

  localparam integer E_LEAF_W   = `DP_E_PAIR_W + `DP_E_GUARD;
  localparam integer E_LEAF_PAD = LEAF_W - E_LEAF_W;

  // Stage valid and datatype pipeline tracking (r1..r4)
  wire                  r1_valid;
  wire                  r2_valid;
  wire                  r3_valid;
  wire                  r4_valid;
  wire [`DP_TYPE_W-1:0] r1_datatype;
  wire [`DP_TYPE_W-1:0] r2_datatype;
  wire [`DP_TYPE_W-1:0] r3_datatype;

  wire r1_is_e;
  wire r2_is_e;
  wire r3_is_e;
  wire r1_is_hif4;
  wire r2_is_hif4;

  assign r1_is_e    = (r1_datatype == `DP_DT_MXFP4) | (r1_datatype == `DP_DT_NVFP4) | (r1_datatype == `DP_DT_HIF4);
  assign r2_is_e    = (r2_datatype == `DP_DT_MXFP4) | (r2_datatype == `DP_DT_NVFP4) | (r2_datatype == `DP_DT_HIF4);
  assign r3_is_e    = (r3_datatype == `DP_DT_MXFP4) | (r3_datatype == `DP_DT_NVFP4) | (r3_datatype == `DP_DT_HIF4);
  assign r1_is_hif4 = (r1_datatype == `DP_DT_HIF4);
  assign r2_is_hif4 = (r2_datatype == `DP_DT_HIF4);

  // ==== Stage 1: Compact QE Unpack and Special-Value Pairing ====
  wire [`DP_UNPACK_MANT_W-1:0] unpack_mantissa_mul_a_mantissas;
  wire [`DP_UNPACK_MANT_W-1:0] unpack_mantissa_mul_b_mantissas;
  wire [ `DP_UNPACK_EXP_W-1:0] unpack_exponent_add_a_exponents;
  wire [ `DP_UNPACK_EXP_W-1:0] unpack_exponent_add_b_exponents;
  wire [`DP_UNPACK_SIGN_W-1:0] unpack_lane_a_signs;
  wire [`DP_UNPACK_SIGN_W-1:0] unpack_lane_b_signs;
  wire [      `DP_E_LANES-1:0] product_negative_d;
  wire [      `DP_E_LANES-1:0] product_active_d;
  wire [    `DP_SPECIAL_W-1:0] lane_special_flags_d;
  wire                         all_products_negative_d;

  generate
    if (COMPACT_UNPACK != 0) begin : g_compact_unpack
      dp_lane_unpack_qe u_lane_unpack (
        .clock                  (clock),
        .rst_n                  (rst_n),
        .in_valid               (in_valid),
        .in_datatype            (in_datatype),
        .in_registered_datatype (r1_datatype),
        .in_a                   (in_a),
        .in_b                   (in_b),
        .in_e1_a                (in_e1_a),
        .in_e1_b                (in_e1_b),
        .in_e2_a                (in_e2_a),
        .in_e2_b                (in_e2_b),
        .out_a_mantissas        (unpack_mantissa_mul_a_mantissas),
        .out_b_mantissas        (unpack_mantissa_mul_b_mantissas),
        .out_a_exponents        (unpack_exponent_add_a_exponents),
        .out_b_exponents        (unpack_exponent_add_b_exponents),
        .out_product_negative   (product_negative_d),
        .out_product_active     (product_active_d),
        .out_special            (lane_special_flags_d),
        .out_all_negative       (all_products_negative_d)
      );
      assign unpack_lane_a_signs = {`DP_UNPACK_SIGN_W{1'b0}};
      assign unpack_lane_b_signs = {`DP_UNPACK_SIGN_W{1'b0}};
    end else begin : g_reference_unpack
      dp_lane_unpack #(
        .QE_ONLY          (1),
        .PRECISION_GATING (1)
      ) u_lane_unpack (
        .clock                  (clock),
        .rst_n                  (rst_n),
        .in_valid               (in_valid),
        .in_datatype            (in_datatype),
        .in_registered_datatype (r1_datatype),
        .in_a                   (in_a),
        .in_b                   (in_b),
        .in_e1_a                (in_e1_a),
        .in_e1_b                (in_e1_b),
        .in_e2_a                (in_e2_a),
        .in_e2_b                (in_e2_b),
        .out_a_mantissas        (unpack_mantissa_mul_a_mantissas),
        .out_b_mantissas        (unpack_mantissa_mul_b_mantissas),
        .out_a_exponents        (unpack_exponent_add_a_exponents),
        .out_b_exponents        (unpack_exponent_add_b_exponents),
        .out_a_signs            (unpack_lane_a_signs),
        .out_b_signs            (unpack_lane_b_signs),
        .out_product_negative   (product_negative_d),
        .out_product_active     (product_active_d),
        .out_special            (lane_special_flags_d),
        .out_all_negative       (all_products_negative_d)
      );
    end
  endgenerate

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(r1_valid));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s0_s1_type_s1 (.clock(clock), .in_en(rst_n & in_valid), .in_d(in_datatype), .out_q(r1_datatype));

  // ==== Stage 2: 4x4 Product Bank, Exponent Addition, and Group MAX ====
  wire [`DP_E_LANES*(2*`DP_EIGHTH_W)-1:0]      product_magnitudes_d;
  wire [`DP_E_LANES*(`DP_Q_EXP_W+1)-1:0]       product_exponents_d;
  wire [`DP_E_LANES*((`DP_Q_EXP_W+1)+1)-1:0]   product_exponent_candidates;
  wire [                      `DP_E_LANES-1:0] exponent_candidates_active;
  wire signed [              (`DP_Q_EXP_W+1):0] lane_max_exponent;

  dp_qe_product_bank u_product_bank (
    .in_datatype    (r1_datatype),
    .in_enable      (r1_valid),
    .in_a_mantissas (unpack_mantissa_mul_a_mantissas),
    .in_b_mantissas (unpack_mantissa_mul_b_mantissas),
    .in_a_exponents (unpack_exponent_add_a_exponents),
    .in_b_exponents (unpack_exponent_add_b_exponents),
    .out_products   (product_magnitudes_d),
    .out_exponents  (product_exponents_d)
  );

  genvar element_index;
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_candidate
      assign product_exponent_candidates[element_index*((`DP_Q_EXP_W+1)+1)+:(`DP_Q_EXP_W+1)+1] = {
        1'b0,
        product_exponents_d[element_index*(`DP_Q_EXP_W+1)+:(`DP_Q_EXP_W+1)]
      };
    end
  endgenerate

  // v1.9 excludes E formats from cross-lane MAX; HiF4 e2 sum travels in a narrow 2b sideband
  assign exponent_candidates_active = ((ARCHITECTURE_V19 != 0) & (r1_datatype >= `DP_DT_MXFP4)) ?
                                      {`DP_E_LANES{1'b0}} :
                                      product_active_d;

  dp_max_tree #(
    .N (`DP_E_LANES),
    .W ((`DP_Q_EXP_W + 1) + 1)
  ) u_lane_exponent_max (
    .in_values  (product_exponent_candidates),
    .in_active  (exponent_candidates_active),
    .out_max    (lane_max_exponent),
    .out_active (out_candidate_active)
  );

  assign out_candidate = lane_max_exponent[(`DP_Q_EXP_W+1)-1:0];

  // Stage 2 registered signals (Q gates off unused slots 4..7; E gates off Q exponents)
  wire [`DP_E_LANES*(2*`DP_EIGHTH_W)-1:0] r2_product_magnitudes;
  wire [`DP_E_LANES*(`DP_Q_EXP_W+1)-1:0]  r2_q_exponents;
  wire [                 `DP_E_GUARD-1:0] r2_hif4_exponent;
  wire [`DP_E_LANES*(`DP_Q_EXP_W+1)-1:0]  r2_product_exponents;
  wire [                 `DP_E_LANES-1:0] r2_product_negative;
  wire [                 `DP_E_LANES-1:0] r2_product_active;
  wire [            (`DP_Q_EXP_W+1)-1:0]  r2_group_anchor;
  wire [               `DP_SPECIAL_W-1:0] r2_special_flags;
  wire                                    r2_all_products_negative;

  genvar product_index;
  generate
    for (product_index = 0; product_index < `DP_E_LANES; product_index = product_index + 1) begin : g_product_register
      wire [2*`DP_EIGHTH_W-1:0] r2_product;

      dp_lib_DFFE #(.WIDTH(2*`DP_EIGHTH_W))
      ff_s1_s2_product (.clock(clock), .in_en(rst_n & r1_valid & (r1_is_e | (product_index < `DP_Q_LANES))), .in_d(product_magnitudes_d[product_index*(2*`DP_EIGHTH_W)+:(2*`DP_EIGHTH_W)]), .out_q(r2_product));

      assign r2_product_magnitudes[product_index*(2*`DP_EIGHTH_W)+:(2*`DP_EIGHTH_W)] =
        (r2_is_e | (product_index < `DP_Q_LANES)) ? r2_product : {(2 * `DP_EIGHTH_W){1'b0}};
    end
  endgenerate

  dp_lib_DFFE #(.WIDTH(`DP_E_LANES * (`DP_Q_EXP_W + 1)))
  ff_s1_s2_q_exponents (.clock(clock), .in_en(rst_n & r1_valid & ~r1_is_e), .in_d(product_exponents_d), .out_q(r2_q_exponents));
  dp_lib_DFFE #(.WIDTH(`DP_E_GUARD))
  ff_s1_s2_hif4_exponent (.clock(clock), .in_en(rst_n & r1_valid & r1_is_hif4), .in_d(product_exponents_d[0+:`DP_E_GUARD]), .out_q(r2_hif4_exponent));

  assign r2_product_exponents = r2_is_e ?
    {`DP_E_LANES{{(`DP_Q_EXP_W + 1 - `DP_E_GUARD){1'b0}}, (r2_is_hif4 ? r2_hif4_exponent : {`DP_E_GUARD{1'b0}})}} :
    r2_q_exponents;

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(r1_valid), .out_q(r2_valid));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s1_s2_negative (.clock(clock), .in_en(rst_n & r1_valid), .in_d(product_negative_d), .out_q(r2_product_negative));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s1_s2_active (.clock(clock), .in_en(rst_n & r1_valid), .in_d(product_active_d), .out_q(r2_product_active));
  dp_lib_DFFE #(.WIDTH(`DP_Q_EXP_W + 1))
  ff_s1_s2_anchor_s2 (.clock(clock), .in_en(rst_n & r1_valid), .in_d(in_group_max), .out_q(r2_group_anchor));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s1_s2_type_s2 (.clock(clock), .in_en(rst_n & r1_valid), .in_d(r1_datatype), .out_q(r2_datatype));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s1_s2_special_s2 (.clock(clock), .in_en(rst_n & r1_valid), .in_d(lane_special_flags_d), .out_q(r2_special_flags));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s1_s2_all_negative_s2 (.clock(clock), .in_en(rst_n & r1_valid), .in_d(all_products_negative_d), .out_q(r2_all_products_negative));

  // ==== Stage 3: Local Alignment and Signed Leaf Generation ====
  wire [`DP_Q_LANES*LEAF_W-1:0] aligned_leaves_d;
  wire [`DP_Q_LANES*LEAF_W-1:0] r3_aligned_leaves;
  wire [       `DP_E_GUARD-1:0] r3_hif4_exponent;
  wire [  (`DP_Q_EXP_W+1)-1:0]  r3_group_anchor;
  wire [     `DP_SPECIAL_W-1:0] r3_special_flags;
  wire                          r3_all_products_negative;

  dp_lane_align #(
    .LOCAL_W       (LOCAL_W),
    .LEAF_W        (LEAF_W),
    .QE_ONLY       (1),
    .E_FIXED_COORD (ARCHITECTURE_V19),
    .PRODUCT_W     (2 * `DP_EIGHTH_W),
    .EXPONENT_W    (`DP_Q_EXP_W + 1)
  ) u_local_alignment (
    .in_valid     (r2_valid),
    .in_datatype  (r2_datatype),
    .in_products  (r2_product_magnitudes),
    .in_negative  (r2_product_negative),
    .in_active    (r2_product_active),
    .in_anchor    (r2_group_anchor),
    .in_exponents (r2_product_exponents),
    .out_leaves   (aligned_leaves_d)
  );

  // Stage 3 register boundary (E formats gate off structural low padding bits E_LEAF_PAD)
  dp_lib_DFFE #(.WIDTH(`DP_E_GUARD))
  ff_s2_s3_hif4_exponent (.clock(clock), .in_en(rst_n & r2_valid & r2_is_hif4 & (ARCHITECTURE_V19 != 0)), .in_d(r2_hif4_exponent), .out_q(r3_hif4_exponent));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(r2_valid), .out_q(r3_valid));

  genvar leaf_index;
  generate
    for (leaf_index = 0; leaf_index < `DP_Q_LANES; leaf_index = leaf_index + 1) begin : g_leaf_register
      wire [  E_LEAF_W-1:0] r3_leaf_upper;
      wire [E_LEAF_PAD-1:0] r3_leaf_lower;

      dp_lib_DFFE #(.WIDTH(E_LEAF_W))
      ff_s2_s3_leaf_upper (.clock(clock), .in_en(rst_n & r2_valid), .in_d(aligned_leaves_d[leaf_index*LEAF_W+E_LEAF_PAD+:E_LEAF_W]), .out_q(r3_leaf_upper));
      dp_lib_DFFE #(.WIDTH(E_LEAF_PAD))
      ff_s2_s3_leaf_lower (.clock(clock), .in_en(rst_n & r2_valid & ~r2_is_e), .in_d(aligned_leaves_d[leaf_index*LEAF_W+:E_LEAF_PAD]), .out_q(r3_leaf_lower));

      assign r3_aligned_leaves[leaf_index*LEAF_W+:LEAF_W] = {
        r3_leaf_upper,
        (r3_is_e ? {E_LEAF_PAD{1'b0}} : r3_leaf_lower)
      };
    end
  endgenerate

  dp_lib_DFFE #(.WIDTH(`DP_Q_EXP_W + 1))
  ff_s2_s3_anchor_s3 (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_group_anchor), .out_q(r3_group_anchor));
  dp_lib_DFFE #(.WIDTH(`DP_TYPE_W))
  ff_s2_s3_type_s3 (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_datatype), .out_q(r3_datatype));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s2_s3_special_s3 (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_special_flags), .out_q(r3_special_flags));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_all_negative_s3 (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_all_products_negative), .out_q(r3_all_products_negative));

  // ==== Stage 4: Balanced 4-Leaf Sum Tree and v1.9 E Coordinate Shift ====
  wire signed [   LANE_SOP_W-1:0] lane_sum_d;
  wire [       `DP_E_GUARD-1:0]   lane_e_shift;
  wire [          LANE_SOP_W-1:0] lane_sop_d;
  wire [     `DP_SPECIAL_W-1:0]   r4_special_flags;

  dp_sum_tree #(
    .N (`DP_Q_LANES),
    .W (LEAF_W)
  ) u_lane_sop_tree (
    .in_values (r3_aligned_leaves),
    .out_sum   (lane_sum_d)
  );

  assign lane_e_shift = (r3_datatype == `DP_DT_HIF4) ? r3_hif4_exponent : `DP_E_GUARD;
  assign lane_sop_d   = ((ARCHITECTURE_V19 != 0) & r3_is_e) ? (lane_sum_d << lane_e_shift) : lane_sum_d;

  // Stage 4 register boundary
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(r3_valid), .out_q(r4_valid));
  dp_lib_DFFE #(.WIDTH(LANE_SOP_W))
  ff_s3_s4_out_sop (.clock(clock), .in_en(rst_n & r3_valid), .in_d(lane_sop_d), .out_q(out_sop));
  dp_lib_DFFE #(.WIDTH(`DP_Q_EXP_W + 1))
  ff_s3_s4_out_anchor (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_group_anchor), .out_q(out_anchor));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s3_s4_special_s4 (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_special_flags), .out_q(r4_special_flags));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s3_s4_out_all_negative (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_all_products_negative), .out_q(out_all_negative));

  assign out_valid   = r4_valid;
  assign out_special = r4_special_flags;

endmodule
