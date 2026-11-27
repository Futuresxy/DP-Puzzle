`include "dp_defs.vh"

// QE Stage 1 compact unpacker: stores A/B M32/E20 atoms and pre-reduces paired classification
// before the S1 register boundary (registering product sign, activity, and 4-bit special summary).
// Magnitude S/I/F: Q = S0I1F3, MX/NV = S0I3F1, HiF4 = S0I2F2.
module dp_lane_unpack_qe (
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

  // Stage 1 compact unpacked outputs and paired special summary
  output wire [`DP_UNPACK_MANT_W-1:0] out_a_mantissas,
  output wire [`DP_UNPACK_MANT_W-1:0] out_b_mantissas,
  output wire [ `DP_UNPACK_EXP_W-1:0] out_a_exponents,
  output wire [ `DP_UNPACK_EXP_W-1:0] out_b_exponents,
  output wire [      `DP_E_LANES-1:0] out_product_negative,
  output wire [      `DP_E_LANES-1:0] out_product_active,
  output wire [    `DP_SPECIAL_W-1:0] out_special,
  output wire                         out_all_negative
);

  // 1. Format decode and combinational element unpacking
  wire select_e;
  wire select_hif4;
  wire r1_select_e;
  wire r1_select_hif4;

  assign select_e       = (in_datatype == `DP_DT_MXFP4) |
                          (in_datatype == `DP_DT_NVFP4) |
                          (in_datatype == `DP_DT_HIF4);
  assign select_hif4    = (in_datatype == `DP_DT_HIF4);
  assign r1_select_e    = (in_registered_datatype == `DP_DT_MXFP4) |
                          (in_registered_datatype == `DP_DT_NVFP4) |
                          (in_registered_datatype == `DP_DT_HIF4);
  assign r1_select_hif4 = (in_registered_datatype == `DP_DT_HIF4);

  // Per-element combinational unpack outputs for A and B
  wire [   `DP_EIGHTH_W-1:0] a_magnitudes [0:`DP_E_LANES-1];
  wire [    `DP_Q_EXP_W-1:0] a_exponents  [0:`DP_E_LANES-1];
  wire [`DP_NUM_CLASS_W-1:0] a_classes    [0:`DP_E_LANES-1];
  wire [    `DP_E_LANES-1:0] a_negative;
  wire [    `DP_E_LANES-1:0] a_signaling;

  wire [   `DP_EIGHTH_W-1:0] b_magnitudes [0:`DP_E_LANES-1];
  wire [    `DP_Q_EXP_W-1:0] b_exponents  [0:`DP_E_LANES-1];
  wire [`DP_NUM_CLASS_W-1:0] b_classes    [0:`DP_E_LANES-1];
  wire [    `DP_E_LANES-1:0] b_negative;
  wire [    `DP_E_LANES-1:0] b_signaling;

  // Combinational paired status prior to S1 capture
  wire [`DP_E_LANES-1:0] product_negative_d;
  wire [`DP_E_LANES-1:0] product_active_d;
  wire [`DP_E_LANES-1:0] nan_sources;
  wire [`DP_E_LANES-1:0] invalid_sources;
  wire [`DP_E_LANES-1:0] positive_inf_sources;
  wire [`DP_E_LANES-1:0] negative_inf_sources;
  wire [`DP_E_LANES-1:0] included_negative;

  genvar element_index;
  genvar atom_index;
  genvar slot_index;
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_decode_pair
      dp_operand_unpack_qe #(
        .INDEX (element_index)
      ) u_operand_a (
        .in_data       (in_a),
        .in_datatype   (in_datatype),
        .in_e1         (in_e1_a),
        .in_e2         (in_e2_a),
        .out_magnitude (a_magnitudes[element_index]),
        .out_exponent  (a_exponents[element_index]),
        .out_negative  (a_negative[element_index]),
        .out_class     (a_classes[element_index]),
        .out_signaling (a_signaling[element_index])
      );

      dp_operand_unpack_qe #(
        .INDEX (element_index)
      ) u_operand_b (
        .in_data       (in_b),
        .in_datatype   (in_datatype),
        .in_e1         (in_e1_b),
        .in_e2         (in_e2_b),
        .out_magnitude (b_magnitudes[element_index]),
        .out_exponent  (b_exponents[element_index]),
        .out_negative  (b_negative[element_index]),
        .out_class     (b_classes[element_index]),
        .out_signaling (b_signaling[element_index])
      );

      // Pair A and B at identical element index before reducing special flags
      wire element_used;
      wire pair_nan;
      wire pair_inf;
      wire pair_zero;
      wire pair_infinity;

      assign element_used                         = select_e | (element_index < `DP_Q_LANES);
      assign pair_nan                             = (a_classes[element_index] == `DP_CLASS_NAN)  |
                                                    (b_classes[element_index] == `DP_CLASS_NAN);
      assign pair_inf                             = (a_classes[element_index] == `DP_CLASS_INF)  |
                                                    (b_classes[element_index] == `DP_CLASS_INF);
      assign pair_zero                            = (a_classes[element_index] == `DP_CLASS_ZERO) |
                                                    (b_classes[element_index] == `DP_CLASS_ZERO);
      assign pair_infinity                        = element_used & pair_inf & ~pair_zero & ~pair_nan;
      assign product_negative_d[element_index]    = element_used & (a_negative[element_index] ^ b_negative[element_index]);
      assign product_active_d[element_index]      = element_used &
                                                    (a_classes[element_index] == `DP_CLASS_FINITE) &
                                                    (b_classes[element_index] == `DP_CLASS_FINITE);
      assign nan_sources[element_index]           = element_used & pair_nan;
      assign invalid_sources[element_index]       = element_used &
                                                    (a_signaling[element_index] | b_signaling[element_index] | (pair_inf & pair_zero));
      assign positive_inf_sources[element_index]  = pair_infinity & ~product_negative_d[element_index];
      assign negative_inf_sources[element_index]  = pair_infinity & product_negative_d[element_index];
      assign included_negative[element_index]     = ~element_used | product_negative_d[element_index];
    end

    // 2. Stage 1 atom packing and precision-gated register capture
    for (atom_index = 0; atom_index < `DP_LANES; atom_index = atom_index + 1) begin : g_atom
      wire [            `DP_HALF_W-1:0] a_e_mantissas;
      wire [            `DP_HALF_W-1:0] a_q_mantissas;
      wire [            `DP_HALF_W-1:0] a_mantissas_d;
      wire [ `DP_UNPACK_ATOM_EXP_W-1:0] a_exponents_d;

      wire [            `DP_HALF_W-1:0] b_e_mantissas;
      wire [            `DP_HALF_W-1:0] b_q_mantissas;
      wire [            `DP_HALF_W-1:0] b_mantissas_d;
      wire [ `DP_UNPACK_ATOM_EXP_W-1:0] b_exponents_d;

      assign a_q_mantissas = {
        {(`DP_HALF_W - `DP_UNPACK_ATOM_Q_LANES * `DP_EIGHTH_W){1'b0}},
        a_magnitudes[atom_index*`DP_UNPACK_ATOM_Q_LANES+1],
        a_magnitudes[atom_index*`DP_UNPACK_ATOM_Q_LANES]
      };
      assign a_mantissas_d = select_e ? a_e_mantissas : a_q_mantissas;
      assign a_exponents_d = select_e ?
                             {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, a_exponents[0][0]} :
                             {a_exponents[atom_index*`DP_UNPACK_ATOM_Q_LANES+1], a_exponents[atom_index*`DP_UNPACK_ATOM_Q_LANES]};

      assign b_q_mantissas = {
        {(`DP_HALF_W - `DP_UNPACK_ATOM_Q_LANES * `DP_EIGHTH_W){1'b0}},
        b_magnitudes[atom_index*`DP_UNPACK_ATOM_Q_LANES+1],
        b_magnitudes[atom_index*`DP_UNPACK_ATOM_Q_LANES]
      };
      assign b_mantissas_d = select_e ? b_e_mantissas : b_q_mantissas;
      assign b_exponents_d = select_e ?
                             {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, b_exponents[0][0]} :
                             {b_exponents[atom_index*`DP_UNPACK_ATOM_Q_LANES+1], b_exponents[atom_index*`DP_UNPACK_ATOM_Q_LANES]};

      for (slot_index = 0; slot_index < `DP_UNPACK_ATOM_SIGN_W; slot_index = slot_index + 1) begin : g_mantissa_slot
        assign a_e_mantissas[slot_index*`DP_EIGHTH_W+:`DP_EIGHTH_W] = a_magnitudes[atom_index*`DP_UNPACK_ATOM_SIGN_W+slot_index];
        assign b_e_mantissas[slot_index*`DP_EIGHTH_W+:`DP_EIGHTH_W] = b_magnitudes[atom_index*`DP_UNPACK_ATOM_SIGN_W+slot_index];
      end

      // Split S1 exponent storage: bit 0 is shared by Q and HiF4 e2; upper bits update only in Q mode
      wire                             r1_a_exponent_low;
      wire [`DP_UNPACK_ATOM_EXP_W-2:0] r1_a_exponent_high;
      wire                             r1_b_exponent_low;
      wire [`DP_UNPACK_ATOM_EXP_W-2:0] r1_b_exponent_high;

      dp_lib_DFFE #(.WIDTH(`DP_HALF_W))
      ff_s0_s1_a_mantissas (.clock(clock), .in_en(rst_n & in_valid), .in_d(a_mantissas_d), .out_q(out_a_mantissas[atom_index*`DP_HALF_W+:`DP_HALF_W]));
      dp_lib_DFFE #(.WIDTH(1))
      ff_s0_s1_a_exponent_low (.clock(clock), .in_en(rst_n & in_valid & (~select_e | select_hif4)), .in_d(a_exponents_d[0]), .out_q(r1_a_exponent_low));
      dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_EXP_W-1))
      ff_s0_s1_a_exponent_high (.clock(clock), .in_en(rst_n & in_valid & ~select_e), .in_d(a_exponents_d[`DP_UNPACK_ATOM_EXP_W-1:1]), .out_q(r1_a_exponent_high));

      assign out_a_exponents[atom_index*`DP_UNPACK_ATOM_EXP_W+:`DP_UNPACK_ATOM_EXP_W] = r1_select_e ?
        {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, (r1_select_hif4 ? r1_a_exponent_low : 1'b0)} :
        {r1_a_exponent_high, r1_a_exponent_low};

      dp_lib_DFFE #(.WIDTH(`DP_HALF_W))
      ff_s0_s1_b_mantissas (.clock(clock), .in_en(rst_n & in_valid), .in_d(b_mantissas_d), .out_q(out_b_mantissas[atom_index*`DP_HALF_W+:`DP_HALF_W]));
      dp_lib_DFFE #(.WIDTH(1))
      ff_s0_s1_b_exponent_low (.clock(clock), .in_en(rst_n & in_valid & (~select_e | select_hif4)), .in_d(b_exponents_d[0]), .out_q(r1_b_exponent_low));
      dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_EXP_W-1))
      ff_s0_s1_b_exponent_high (.clock(clock), .in_en(rst_n & in_valid & ~select_e), .in_d(b_exponents_d[`DP_UNPACK_ATOM_EXP_W-1:1]), .out_q(r1_b_exponent_high));

      assign out_b_exponents[atom_index*`DP_UNPACK_ATOM_EXP_W+:`DP_UNPACK_ATOM_EXP_W] = r1_select_e ?
        {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, (r1_select_hif4 ? r1_b_exponent_low : 1'b0)} :
        {r1_b_exponent_high, r1_b_exponent_low};
    end
  endgenerate

  // 3. Stage 1 paired sign, activity, and special-flag registers
  wire [`DP_SPECIAL_W-1:0] special_flags_d;
  wire                     all_negative_d;

  assign special_flags_d[`DP_SP_NAN]     = |nan_sources;
  assign special_flags_d[`DP_SP_INVALID] = (|invalid_sources) | ((|positive_inf_sources) & (|negative_inf_sources));
  assign special_flags_d[`DP_SP_POS_INF] = |positive_inf_sources;
  assign special_flags_d[`DP_SP_NEG_INF] = |negative_inf_sources;
  assign all_negative_d                  = &included_negative;

  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s0_s1_product_negative (.clock(clock), .in_en(rst_n & in_valid), .in_d(product_negative_d), .out_q(out_product_negative));
  dp_lib_DFFE #(.WIDTH(`DP_E_LANES))
  ff_s0_s1_product_active (.clock(clock), .in_en(rst_n & in_valid), .in_d(product_active_d), .out_q(out_product_active));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s0_s1_special_flags (.clock(clock), .in_en(rst_n & in_valid), .in_d(special_flags_d), .out_q(out_special));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s0_s1_all_negative (.clock(clock), .in_en(rst_n & in_valid), .in_d(all_negative_d), .out_q(out_all_negative));

endmodule
