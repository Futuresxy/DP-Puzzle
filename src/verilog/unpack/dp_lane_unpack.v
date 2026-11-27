`include "dp_defs.vh"

// Dual-operand A/B lane unpacker: registers compact M32/E20/S8 atoms at S1 and performs
// elementwise A/B special-value pairing (0*Inf, sNaN, signed Inf) in the S2 combinational region.
module dp_lane_unpack #(
  parameter integer QE_ONLY          = 0, // 1 removes T/H/INT8 decode paths statically
  parameter integer PRECISION_GATING = 0  // 1 enables per-format split-field S1 clock gating
) (
  // Control and format configuration
  input  wire                         clock,
  input  wire                         rst_n,
  input  wire                         in_valid,
  input  wire [       `DP_TYPE_W-1:0] in_datatype,
  input  wire [       `DP_TYPE_W-1:0] in_registered_datatype,

  // Raw A/B lane operands and HiF4 shared exponents
  input  wire [       `DP_LANE_W-1:0] in_a,
  input  wire [       `DP_LANE_W-1:0] in_b,
  input  wire [                  1:0] in_e1_a,
  input  wire [                  1:0] in_e1_b,
  input  wire                         in_e2_a,
  input  wire                         in_e2_b,

  // Stage 1 compact A/B unpacked atom outputs
  output wire [`DP_UNPACK_MANT_W-1:0] out_a_mantissas,
  output wire [`DP_UNPACK_MANT_W-1:0] out_b_mantissas,
  output wire [ `DP_UNPACK_EXP_W-1:0] out_a_exponents,
  output wire [ `DP_UNPACK_EXP_W-1:0] out_b_exponents,
  output wire [`DP_UNPACK_SIGN_W-1:0] out_a_signs,
  output wire [`DP_UNPACK_SIGN_W-1:0] out_b_signs,

  // Stage 2 combinational paired product sign, activity, and special summary
  output wire [      `DP_E_LANES-1:0] out_product_negative,
  output wire [      `DP_E_LANES-1:0] out_product_active,
  output wire [    `DP_SPECIAL_W-1:0] out_special,
  output wire                         out_all_negative
);

  `include "dp_functions.vh"

  // 1. Stage 1 A/B operand unpacking
  wire [`DP_UNPACK_CLASS_W-1:0] r1_a_classes;
  wire [`DP_UNPACK_CLASS_W-1:0] r1_b_classes;
  wire [ `DP_UNPACK_SIGN_W-1:0] r1_a_signaling;
  wire [ `DP_UNPACK_SIGN_W-1:0] r1_b_signaling;

  dp_lane_operand_unpack #(
    .QE_ONLY          (QE_ONLY),
    .PRECISION_GATING (PRECISION_GATING)
  ) u_operand_a (
    .clock                  (clock),
    .rst_n                  (rst_n),
    .in_valid               (in_valid),
    .in_datatype            (in_datatype),
    .in_registered_datatype (in_registered_datatype),
    .in_data                (in_a),
    .in_e1                  (in_e1_a),
    .in_e2                  (in_e2_a),
    .out_mantissas          (out_a_mantissas),
    .out_exponents          (out_a_exponents),
    .out_signs              (out_a_signs),
    .out_classes            (r1_a_classes),
    .out_signaling          (r1_a_signaling)
  );

  dp_lane_operand_unpack #(
    .QE_ONLY          (QE_ONLY),
    .PRECISION_GATING (PRECISION_GATING)
  ) u_operand_b (
    .clock                  (clock),
    .rst_n                  (rst_n),
    .in_valid               (in_valid),
    .in_datatype            (in_datatype),
    .in_registered_datatype (in_registered_datatype),
    .in_data                (in_b),
    .in_e1                  (in_e1_b),
    .in_e2                  (in_e2_b),
    .out_mantissas          (out_b_mantissas),
    .out_exponents          (out_b_exponents),
    .out_signs              (out_b_signs),
    .out_classes            (r1_b_classes),
    .out_signaling          (r1_b_signaling)
  );

  // 2. Stage 2 per-element pairing and special-value reduction
  // Elements must pair at identical indices before OR reduction so Inf on one lane and Zero on
  // another lane never falsely trigger 0*Inf invalid.
  wire select_h;
  wire select_e;

  assign select_h = (QE_ONLY == 0) &
                    ((in_registered_datatype == `DP_DT_TF32) |
                     (in_registered_datatype == `DP_DT_FP16) |
                     (in_registered_datatype == `DP_DT_BF16));
  assign select_e = (in_registered_datatype == `DP_DT_MXFP4) |
                    (in_registered_datatype == `DP_DT_NVFP4) |
                    (in_registered_datatype == `DP_DT_HIF4);

  wire [`DP_E_LANES-1:0] nan_sources;
  wire [`DP_E_LANES-1:0] invalid_sources;
  wire [`DP_E_LANES-1:0] positive_inf_sources;
  wire [`DP_E_LANES-1:0] negative_inf_sources;
  wire [`DP_E_LANES-1:0] included_negative;

  genvar element_index;
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_pair_class
      // Static atom slot mapping for H (1/atom), Q/INT8 (2/atom), and E (4/atom)
      localparam integer H_SLOT = (element_index % `DP_LANES) * `DP_UNPACK_ATOM_SIGN_W;
      localparam integer Q_SLOT = ((element_index / `DP_UNPACK_ATOM_Q_LANES) % `DP_LANES) *
                                  `DP_UNPACK_ATOM_SIGN_W + (element_index % `DP_UNPACK_ATOM_Q_LANES);
      localparam integer E_SLOT = element_index;

      wire                       element_used;
      wire [`DP_NUM_CLASS_W-1:0] a_class;
      wire [`DP_NUM_CLASS_W-1:0] b_class;
      wire                       a_sign;
      wire                       b_sign;
      wire                       a_signaling;
      wire                       b_signaling;

      assign element_used = element_index < ((QE_ONLY != 0) ?
                            (select_e ? `DP_E_LANES : `DP_Q_LANES) :
                            elements(in_registered_datatype));
      assign a_class      = select_h ? r1_a_classes[H_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] :
                            select_e ? r1_a_classes[E_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] :
                                       r1_a_classes[Q_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W];
      assign a_sign       = select_h ? out_a_signs[H_SLOT] :
                            select_e ? out_a_signs[E_SLOT] :
                                       out_a_signs[Q_SLOT];
      assign a_signaling  = select_h ? r1_a_signaling[H_SLOT] :
                            select_e ? r1_a_signaling[E_SLOT] :
                                       r1_a_signaling[Q_SLOT];
      assign b_class      = select_h ? r1_b_classes[H_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] :
                            select_e ? r1_b_classes[E_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] :
                                       r1_b_classes[Q_SLOT*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W];
      assign b_sign       = select_h ? out_b_signs[H_SLOT] :
                            select_e ? out_b_signs[E_SLOT] :
                                       out_b_signs[Q_SLOT];
      assign b_signaling  = select_h ? r1_b_signaling[H_SLOT] :
                            select_e ? r1_b_signaling[E_SLOT] :
                                       r1_b_signaling[Q_SLOT];

      wire pair_nan;
      wire pair_inf;
      wire pair_zero;
      wire pair_infinity;

      assign pair_nan                            = (a_class == `DP_CLASS_NAN)  | (b_class == `DP_CLASS_NAN);
      assign pair_inf                            = (a_class == `DP_CLASS_INF)  | (b_class == `DP_CLASS_INF);
      assign pair_zero                           = (a_class == `DP_CLASS_ZERO) | (b_class == `DP_CLASS_ZERO);
      assign pair_infinity                       = element_used & pair_inf & ~pair_zero & ~pair_nan;
      assign out_product_negative[element_index] = element_used & (a_sign ^ b_sign);
      assign out_product_active[element_index]   = element_used &
                                                   (a_class == `DP_CLASS_FINITE) &
                                                   (b_class == `DP_CLASS_FINITE);
      assign nan_sources[element_index]          = element_used & pair_nan;
      assign invalid_sources[element_index]      = element_used & (a_signaling | b_signaling | (pair_inf & pair_zero));
      assign positive_inf_sources[element_index] = pair_infinity & ~out_product_negative[element_index];
      assign negative_inf_sources[element_index] = pair_infinity & out_product_negative[element_index];
      assign included_negative[element_index]    = ~element_used | out_product_negative[element_index];
    end
  endgenerate

  assign out_special[`DP_SP_NAN]     = |nan_sources;
  assign out_special[`DP_SP_POS_INF] = |positive_inf_sources;
  assign out_special[`DP_SP_NEG_INF] = |negative_inf_sources;
  assign out_special[`DP_SP_INVALID] = (|invalid_sources) | ((|positive_inf_sources) & (|negative_inf_sources));
  assign out_all_negative            = &included_negative;

endmodule
