`include "dp_defs.vh"

// Combinational M16/E10/S4/Class8 atom decoder for one 16-bit half-lane (ATOM_INDEX = 0 or 1).
// All field widths and slice offsets are elaboration constants per format_index.
// Magnitude layout: T/FP16 = I1F10, BF16 = I1F7, Q = 2x I1F3, MX/NV = 4x I3F1, HiF4 = 4x I2F2.
module dp_unpack_atom #(
  parameter integer ATOM_INDEX = 0, // Half-lane atom index (0 or 1; TF32 uses atom 0 only)
  parameter integer QE_ONLY    = 0  // 1 removes T/H/INT8 decode paths statically
) (
  input  wire [               `DP_LANE_W-1:0] in_data,
  input  wire [               `DP_TYPE_W-1:0] in_datatype,
  input  wire [                          1:0] in_e1,
  input  wire                                 in_e2,
  output wire [               `DP_HALF_W-1:0] out_mantissas,
  output wire [    `DP_UNPACK_ATOM_EXP_W-1:0] out_exponents,
  output wire [   `DP_UNPACK_ATOM_SIGN_W-1:0] out_signs,
  output wire [  `DP_UNPACK_ATOM_CLASS_W-1:0] out_classes,
  output wire [   `DP_UNPACK_ATOM_SIGN_W-1:0] out_signaling
);

  localparam integer FORMAT_COUNT = {28'd0, `DP_DT_INT8} + 1;

  // Per-format candidate atom fields and one-hot gated outputs
  wire [              `DP_HALF_W-1:0] format_mantissas   [0:FORMAT_COUNT-1];
  wire [   `DP_UNPACK_ATOM_EXP_W-1:0] format_exponents   [0:FORMAT_COUNT-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] format_signs       [0:FORMAT_COUNT-1];
  wire [ `DP_UNPACK_ATOM_CLASS_W-1:0] format_classes     [0:FORMAT_COUNT-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] format_signaling   [0:FORMAT_COUNT-1];

  wire [              `DP_HALF_W-1:0] selected_mantissas [0:FORMAT_COUNT-1];
  wire [   `DP_UNPACK_ATOM_EXP_W-1:0] selected_exponents [0:FORMAT_COUNT-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] selected_signs     [0:FORMAT_COUNT-1];
  wire [ `DP_UNPACK_ATOM_CLASS_W-1:0] selected_classes   [0:FORMAT_COUNT-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] selected_signaling [0:FORMAT_COUNT-1];

  genvar format_index;
  genvar slot_index;
  generate
    for (format_index = 0; format_index < FORMAT_COUNT; format_index = format_index + 1) begin : g_format
      wire format_selected;
      assign format_selected = (in_datatype == format_index);

      // 1. Unused or statically disabled format branch
      if (((QE_ONLY != 0) & ((format_index <= `DP_DT_BF16) | (format_index == `DP_DT_INT8))) |
          ((ATOM_INDEX != 0) & (format_index == `DP_DT_TF32))) begin : g_unused
        assign format_mantissas[format_index] = {`DP_HALF_W{1'b0}};
        assign format_exponents[format_index] = {`DP_UNPACK_ATOM_EXP_W{1'b0}};
        assign format_signs[format_index]     = {`DP_UNPACK_ATOM_SIGN_W{1'b0}};
        assign format_classes[format_index]   = {`DP_UNPACK_ATOM_CLASS_W{1'b0}};
        assign format_signaling[format_index] = {`DP_UNPACK_ATOM_SIGN_W{1'b0}};

      // 2. Floating-point formats (TF32, FP16, BF16, MXFP8, MXFP6)
      end else if (format_index <= `DP_DT_MX6_E2M3) begin : g_float
        localparam                  IS_Q        = (format_index >= `DP_DT_MX8_E4M3);
        localparam integer          SLOT_COUNT  = IS_Q ? `DP_UNPACK_ATOM_Q_LANES : 1;
        localparam integer          EXP_FIELD_W = ((format_index == `DP_DT_TF32) | (format_index == `DP_DT_BF16))   ? `DP_FP32_E :
                                                  ((format_index == `DP_DT_FP16) | (format_index == `DP_DT_MX8_E5M2)) ? `DP_FP16_E :
                                                  (format_index == `DP_DT_MX8_E4M3)                                 ? `DP_MX8_E4_E :
                                                  (format_index == `DP_DT_MX6_E3M2)                                 ? `DP_MX6_E3_E :
                                                                                                                      `DP_MX6_E2_E;
        localparam integer          FRACTION_W  = ((format_index == `DP_DT_TF32) | (format_index == `DP_DT_FP16))     ? `DP_FP16_F :
                                                  (format_index == `DP_DT_BF16)                                       ? `DP_BF16_F :
                                                  ((format_index == `DP_DT_MX8_E4M3) | (format_index == `DP_DT_MX6_E2M3)) ? `DP_MX8_E4_F :
                                                                                                                        `DP_MX8_E5_F;
        localparam integer          MANTISSA_W  = IS_Q ? `DP_MUL_LO : (FRACTION_W + 1);
        localparam integer          EXP_PACK_W  = IS_Q ? `DP_Q_EXP_W : `DP_EXP_W;
        localparam [EXP_PACK_W-1:0] EXP_OFFSET  = (format_index == `DP_DT_MX8_E4M3) ? (`DP_Q_BIAS - `DP_MX8_E4_BIAS) :
                                                  (format_index == `DP_DT_MX6_E3M2) ? (`DP_Q_BIAS - `DP_MX6_E3_BIAS) :
                                                  (format_index == `DP_DT_MX6_E2M3) ? (`DP_Q_BIAS - `DP_MX6_E2_BIAS) :
                                                                                      {EXP_PACK_W{1'b0}};
        localparam                  HAS_INF     = (format_index <= `DP_DT_BF16) | (format_index == `DP_DT_MX8_E5M2);

        for (slot_index = 0; slot_index < SLOT_COUNT; slot_index = slot_index + 1) begin : g_slot
          localparam integer RAW_LSB = (format_index == `DP_DT_TF32) ? `DP_TF32_PAD :
                                       IS_Q ? ((ATOM_INDEX * `DP_UNPACK_ATOM_Q_LANES + slot_index) * `DP_QUARTER_W +
                                               ((format_index >= `DP_DT_MX6_E3M2) ? `DP_MX6_PAD : 0)) :
                                              (ATOM_INDEX * `DP_HALF_W);

          wire [EXP_FIELD_W-1:0] exponent_field;
          wire [ FRACTION_W-1:0] fraction_field;
          wire                   exponent_nonzero;
          wire                   exponent_all_ones;
          wire                   fraction_nonzero;
          wire                   number_nan;
          wire                   number_inf;
          wire                   number_zero;
          wire [ EXP_PACK_W-1:0] effective_exponent;

          assign exponent_field     = in_data[RAW_LSB+FRACTION_W+:EXP_FIELD_W];
          assign fraction_field     = in_data[RAW_LSB+:FRACTION_W];
          assign exponent_nonzero   = |exponent_field;
          assign exponent_all_ones  = &exponent_field;
          assign fraction_nonzero   = |fraction_field;
          assign number_nan         = exponent_all_ones &
                                      ((HAS_INF & fraction_nonzero) |
                                       ((format_index == `DP_DT_MX8_E4M3) & (&fraction_field)));
          assign number_inf         = HAS_INF & exponent_all_ones & ~fraction_nonzero;
          assign number_zero        = ~exponent_nonzero & ~fraction_nonzero;
          assign effective_exponent = (exponent_nonzero ?
                                       {{(EXP_PACK_W - EXP_FIELD_W){1'b0}}, exponent_field} :
                                       {{(EXP_PACK_W - 1){1'b0}}, 1'b1}) + EXP_OFFSET;

          assign format_mantissas[format_index][slot_index*MANTISSA_W+:MANTISSA_W] =
            (number_nan | number_inf) ?
            {MANTISSA_W{1'b0}} :
            {exponent_nonzero, fraction_field, {(MANTISSA_W - FRACTION_W - 1){1'b0}}};
          assign format_exponents[format_index][slot_index*EXP_PACK_W+:EXP_PACK_W] =
            (number_nan | number_inf) ?
            {{(EXP_PACK_W - 1){1'b0}}, 1'b1} :
            effective_exponent;
          assign format_signs[format_index][slot_index] = in_data[RAW_LSB+FRACTION_W+EXP_FIELD_W];
          assign format_classes[format_index][slot_index*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] =
            number_nan  ? `DP_CLASS_NAN :
            number_inf  ? `DP_CLASS_INF :
            number_zero ? `DP_CLASS_ZERO :
                          `DP_CLASS_FINITE;
          assign format_signaling[format_index][slot_index] = number_nan & HAS_INF & ~fraction_field[FRACTION_W-1];
        end

        assign format_mantissas[format_index][`DP_HALF_W-1:SLOT_COUNT*MANTISSA_W] = 0;
        if (SLOT_COUNT * EXP_PACK_W < `DP_UNPACK_ATOM_EXP_W) begin : g_exp_pad
          assign format_exponents[format_index][`DP_UNPACK_ATOM_EXP_W-1:SLOT_COUNT*EXP_PACK_W] = 0;
        end
        assign format_signs[format_index][`DP_UNPACK_ATOM_SIGN_W-1:SLOT_COUNT]                      = 0;
        assign format_classes[format_index][`DP_UNPACK_ATOM_CLASS_W-1:SLOT_COUNT*`DP_NUM_CLASS_W]   = 0;
        assign format_signaling[format_index][`DP_UNPACK_ATOM_SIGN_W-1:SLOT_COUNT]                  = 0;

      // 3. E-family formats (MXFP4, NVFP4, HiF4)
      end else if (format_index <= `DP_DT_HIF4) begin : g_e
        for (slot_index = 0; slot_index < `DP_UNPACK_ATOM_SIGN_W; slot_index = slot_index + 1) begin : g_slot
          localparam integer RAW_LSB = (ATOM_INDEX * `DP_UNPACK_ATOM_SIGN_W + slot_index) * `DP_EIGHTH_W;

          wire [`DP_E_PAYLOAD_W-1:0] payload;
          wire [     `DP_MUL_LO-1:0] magnitude;

          assign payload = in_data[RAW_LSB+:`DP_E_PAYLOAD_W];

          if (format_index == `DP_DT_HIF4) begin : g_hif
            assign magnitude = in_e1[ATOM_INDEX] ? {payload, 1'b0} : {1'b0, payload};
          end else begin : g_mx_nv
            assign magnitude = (payload < 3'd5)  ? {1'b0, payload} :
                               (payload == 3'd5) ? 4'd6 :
                               (payload == 3'd6) ? 4'd8 :
                                                   4'd12;
          end

          assign format_mantissas[format_index][slot_index*`DP_MUL_LO+:`DP_MUL_LO]          = magnitude;
          assign format_signs[format_index][slot_index]                                     = in_data[RAW_LSB+`DP_E_PAYLOAD_W];
          assign format_classes[format_index][slot_index*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W]  = (|payload) ? `DP_CLASS_FINITE : `DP_CLASS_ZERO;
        end

        assign format_exponents[format_index] = (format_index == `DP_DT_HIF4) ?
                                                {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, in_e2} :
                                                {`DP_UNPACK_ATOM_EXP_W{1'b0}};
        assign format_signaling[format_index] = {`DP_UNPACK_ATOM_SIGN_W{1'b0}};

      // 4. Signed INT8 format (two 8-bit two's-complement slots per atom, preserving abs(-128) = 128)
      end else begin : g_int
        for (slot_index = 0; slot_index < `DP_UNPACK_ATOM_Q_LANES; slot_index = slot_index + 1) begin : g_slot
          localparam integer RAW_LSB = (ATOM_INDEX * `DP_UNPACK_ATOM_Q_LANES + slot_index) * `DP_QUARTER_W;

          wire [`DP_QUARTER_W-1:0] raw_integer;
          assign raw_integer = in_data[RAW_LSB+:`DP_QUARTER_W];

          assign format_mantissas[format_index][slot_index*`DP_QUARTER_W+:`DP_QUARTER_W] =
            raw_integer[`DP_QUARTER_W-1] ? (~raw_integer + {{(`DP_QUARTER_W - 1){1'b0}}, 1'b1}) : raw_integer;
          assign format_signs[format_index][slot_index]                                    = raw_integer[`DP_QUARTER_W-1];
          assign format_classes[format_index][slot_index*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] = (|raw_integer) ? `DP_CLASS_FINITE : `DP_CLASS_ZERO;
        end

        assign format_exponents[format_index]                                                     = 0;
        assign format_signs[format_index][`DP_UNPACK_ATOM_SIGN_W-1:`DP_UNPACK_ATOM_Q_LANES]       = 0;
        assign format_classes[format_index][`DP_UNPACK_ATOM_CLASS_W-1:`DP_UNPACK_ATOM_Q_LANES*`DP_NUM_CLASS_W] = 0;
        assign format_signaling[format_index]                                                     = 0;
      end

      // 5. One-hot format AND masking
      assign selected_mantissas[format_index] = {`DP_HALF_W{format_selected}}              & format_mantissas[format_index];
      assign selected_exponents[format_index] = {`DP_UNPACK_ATOM_EXP_W{format_selected}}   & format_exponents[format_index];
      assign selected_signs[format_index]     = {`DP_UNPACK_ATOM_SIGN_W{format_selected}}  & format_signs[format_index];
      assign selected_classes[format_index]   = {`DP_UNPACK_ATOM_CLASS_W{format_selected}} & format_classes[format_index];
      assign selected_signaling[format_index] = {`DP_UNPACK_ATOM_SIGN_W{format_selected}}  & format_signaling[format_index];
    end
  endgenerate

  // OR-reduce one-hot selected format candidates
  assign out_mantissas =
    selected_mantissas[`DP_DT_TF32]     |
    selected_mantissas[`DP_DT_FP16]     |
    selected_mantissas[`DP_DT_BF16]     |
    selected_mantissas[`DP_DT_MX8_E4M3] |
    selected_mantissas[`DP_DT_MX8_E5M2] |
    selected_mantissas[`DP_DT_MX6_E3M2] |
    selected_mantissas[`DP_DT_MX6_E2M3] |
    selected_mantissas[`DP_DT_MXFP4]    |
    selected_mantissas[`DP_DT_NVFP4]    |
    selected_mantissas[`DP_DT_HIF4]     |
    selected_mantissas[`DP_DT_INT8];

  assign out_exponents =
    selected_exponents[`DP_DT_TF32]     |
    selected_exponents[`DP_DT_FP16]     |
    selected_exponents[`DP_DT_BF16]     |
    selected_exponents[`DP_DT_MX8_E4M3] |
    selected_exponents[`DP_DT_MX8_E5M2] |
    selected_exponents[`DP_DT_MX6_E3M2] |
    selected_exponents[`DP_DT_MX6_E2M3] |
    selected_exponents[`DP_DT_MXFP4]    |
    selected_exponents[`DP_DT_NVFP4]    |
    selected_exponents[`DP_DT_HIF4]     |
    selected_exponents[`DP_DT_INT8];

  assign out_signs =
    selected_signs[`DP_DT_TF32]     |
    selected_signs[`DP_DT_FP16]     |
    selected_signs[`DP_DT_BF16]     |
    selected_signs[`DP_DT_MX8_E4M3] |
    selected_signs[`DP_DT_MX8_E5M2] |
    selected_signs[`DP_DT_MX6_E3M2] |
    selected_signs[`DP_DT_MX6_E2M3] |
    selected_signs[`DP_DT_MXFP4]    |
    selected_signs[`DP_DT_NVFP4]    |
    selected_signs[`DP_DT_HIF4]     |
    selected_signs[`DP_DT_INT8];

  assign out_classes =
    selected_classes[`DP_DT_TF32]     |
    selected_classes[`DP_DT_FP16]     |
    selected_classes[`DP_DT_BF16]     |
    selected_classes[`DP_DT_MX8_E4M3] |
    selected_classes[`DP_DT_MX8_E5M2] |
    selected_classes[`DP_DT_MX6_E3M2] |
    selected_classes[`DP_DT_MX6_E2M3] |
    selected_classes[`DP_DT_MXFP4]    |
    selected_classes[`DP_DT_NVFP4]    |
    selected_classes[`DP_DT_HIF4]     |
    selected_classes[`DP_DT_INT8];

  assign out_signaling =
    selected_signaling[`DP_DT_TF32]     |
    selected_signaling[`DP_DT_FP16]     |
    selected_signaling[`DP_DT_BF16]     |
    selected_signaling[`DP_DT_MX8_E4M3] |
    selected_signaling[`DP_DT_MX8_E5M2] |
    selected_signaling[`DP_DT_MX6_E3M2] |
    selected_signaling[`DP_DT_MX6_E2M3] |
    selected_signaling[`DP_DT_MXFP4]    |
    selected_signaling[`DP_DT_NVFP4]    |
    selected_signaling[`DP_DT_HIF4]     |
    selected_signaling[`DP_DT_INT8];

endmodule
