`include "dp_defs.vh"

// Single-operand 32-bit lane decoder and Stage 1 register bank (two M16/E10/S4 atoms per lane).
// Classification, subnormal exponent adjustment, hidden-bit restoration, Q re-biasing, and HiF4 e1
// scaling happen once during combinational atom decoding before S1 register capture.
// Magnitude format: T/FP16=I1F10, BF16=I1F7, Q=I1F3, MX/NV=I3F1, HiF4=I2F2, INT8=I8F0.
module dp_lane_operand_unpack #(
  parameter integer QE_ONLY          = 0, // 1 removes T/H/INT8 decode paths statically
  parameter integer PRECISION_GATING = 0  // 1 enables per-format split-field S1 clock gating
) (
  // Control and format configuration
  input  wire                          clock,
  input  wire                          rst_n,
  input  wire                          in_valid,
  input  wire [        `DP_TYPE_W-1:0] in_datatype,
  input  wire [        `DP_TYPE_W-1:0] in_registered_datatype,

  // Raw lane input and HiF4 shared exponents
  input  wire [        `DP_LANE_W-1:0] in_data,
  input  wire [                   1:0] in_e1,
  input  wire                          in_e2,

  // Stage 1 compact unpacked atom outputs
  output wire [ `DP_UNPACK_MANT_W-1:0] out_mantissas,
  output wire [  `DP_UNPACK_EXP_W-1:0] out_exponents,
  output wire [ `DP_UNPACK_SIGN_W-1:0] out_signs,
  output wire [`DP_UNPACK_CLASS_W-1:0] out_classes,
  output wire [ `DP_UNPACK_SIGN_W-1:0] out_signaling
);

  // Stage 1 per-atom registered fields (probed by testbench cutpoints)
  wire [              `DP_HALF_W-1:0] r1_mantissas [0:`DP_LANES-1];
  wire [   `DP_UNPACK_ATOM_EXP_W-1:0] r1_exponents [0:`DP_LANES-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] r1_signs     [0:`DP_LANES-1];
  wire [ `DP_UNPACK_ATOM_CLASS_W-1:0] r1_classes   [0:`DP_LANES-1];
  wire [  `DP_UNPACK_ATOM_SIGN_W-1:0] r1_signaling [0:`DP_LANES-1];

  genvar atom_index;
  genvar class_index;
  generate
    for (atom_index = 0; atom_index < `DP_LANES; atom_index = atom_index + 1) begin : g_atom
      // 1. Combinational atom decoding (fixed M16/E10/S4/Class8 layout)
      wire [             `DP_HALF_W-1:0] mantissa_d;
      wire [  `DP_UNPACK_ATOM_EXP_W-1:0] exponent_d;
      wire [ `DP_UNPACK_ATOM_SIGN_W-1:0] signs_d;
      wire [`DP_UNPACK_ATOM_CLASS_W-1:0] classes_d;
      wire [ `DP_UNPACK_ATOM_SIGN_W-1:0] signaling_d;
      wire                               select_e;

      assign select_e = (in_datatype == `DP_DT_MXFP4) |
                        (in_datatype == `DP_DT_NVFP4) |
                        (in_datatype == `DP_DT_HIF4);

      dp_unpack_atom #(
        .ATOM_INDEX (atom_index),
        .QE_ONLY    (QE_ONLY)
      ) u_atom_decode (
        .in_data       (in_data),
        .in_datatype   (in_datatype),
        .in_e1         (in_e1),
        .in_e2         (in_e2),
        .out_mantissas (mantissa_d),
        .out_exponents (exponent_d),
        .out_signs     (signs_d),
        .out_classes   (classes_d),
        .out_signaling (signaling_d)
      );

      // 2. Stage 1 register boundary (with optional precision-based field gating)
      dp_lib_DFFE #(.WIDTH(`DP_HALF_W))
      ff_s0_s1_mantissas (.clock(clock), .in_en(rst_n & in_valid), .in_d(mantissa_d), .out_q(r1_mantissas[atom_index]));

      if (PRECISION_GATING != 0) begin : g_precision_exponents
        // HiF4 only uses exponent bit 0 (e2); MXFP4/NVFP4 exponents are zero
        wire                               exponent_low_en;
        wire                               exponent_upper_en;
        wire                               r1_is_e;
        wire                               r1_is_hif4;
        wire                               r1_exponent_low;
        wire [`DP_UNPACK_ATOM_EXP_W-2:0]   r1_exponent_upper;

        assign exponent_low_en   = rst_n & in_valid & (~select_e | (in_datatype == `DP_DT_HIF4));
        assign exponent_upper_en = rst_n & in_valid & ~select_e;
        assign r1_is_e           = (in_registered_datatype == `DP_DT_MXFP4) |
                                   (in_registered_datatype == `DP_DT_NVFP4) |
                                   (in_registered_datatype == `DP_DT_HIF4);
        assign r1_is_hif4        = (in_registered_datatype == `DP_DT_HIF4);

        dp_lib_DFFE #(.WIDTH(1))
        ff_s0_s1_exponent_low (.clock(clock), .in_en(exponent_low_en), .in_d(exponent_d[0]), .out_q(r1_exponent_low));
        dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_EXP_W-1))
        ff_s0_s1_exponent_upper (.clock(clock), .in_en(exponent_upper_en), .in_d(exponent_d[`DP_UNPACK_ATOM_EXP_W-1:1]), .out_q(r1_exponent_upper));

        assign r1_exponents[atom_index] = r1_is_e ?
          {{(`DP_UNPACK_ATOM_EXP_W - 1){1'b0}}, (r1_is_hif4 & r1_exponent_low)} :
          {r1_exponent_upper, r1_exponent_low};
      end else begin : g_full_exponents
        dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_EXP_W))
        ff_s0_s1_exponents (.clock(clock), .in_en(rst_n & in_valid), .in_d(exponent_d), .out_q(r1_exponents[atom_index]));
      end

      dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_SIGN_W))
      ff_s0_s1_signs (.clock(clock), .in_en(rst_n & in_valid), .in_d(signs_d), .out_q(r1_signs[atom_index]));

      if (PRECISION_GATING != 0) begin : g_precision_classes
        // E formats only distinguish ZERO vs. FINITE (class bit 0); class bit 1 and sNaN gate off
        wire                              special_fields_en;
        wire                              r1_is_e;
        wire [`DP_UNPACK_ATOM_SIGN_W-1:0] r1_signaling_raw;

        assign special_fields_en = rst_n & in_valid & ~select_e;
        assign r1_is_e           = (in_registered_datatype == `DP_DT_MXFP4) |
                                   (in_registered_datatype == `DP_DT_NVFP4) |
                                   (in_registered_datatype == `DP_DT_HIF4);

        for (class_index = 0; class_index < `DP_UNPACK_ATOM_SIGN_W; class_index = class_index + 1) begin : g_class
          wire r1_class_low;
          wire r1_class_high;

          dp_lib_DFFE #(.WIDTH(1))
          ff_s0_s1_class_low (.clock(clock), .in_en(rst_n & in_valid), .in_d(classes_d[class_index*`DP_NUM_CLASS_W]), .out_q(r1_class_low));
          dp_lib_DFFE #(.WIDTH(1))
          ff_s0_s1_class_high (.clock(clock), .in_en(special_fields_en), .in_d(classes_d[class_index*`DP_NUM_CLASS_W+1]), .out_q(r1_class_high));

          assign r1_classes[atom_index][class_index*`DP_NUM_CLASS_W+:`DP_NUM_CLASS_W] = {
            (~r1_is_e & r1_class_high),
            r1_class_low
          };
        end

        dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_SIGN_W))
        ff_s0_s1_signaling (.clock(clock), .in_en(special_fields_en), .in_d(signaling_d), .out_q(r1_signaling_raw));

        assign r1_signaling[atom_index] = r1_is_e ? {`DP_UNPACK_ATOM_SIGN_W{1'b0}} : r1_signaling_raw;
      end else begin : g_full_classes
        dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_CLASS_W))
        ff_s0_s1_classes (.clock(clock), .in_en(rst_n & in_valid), .in_d(classes_d), .out_q(r1_classes[atom_index]));
        dp_lib_DFFE #(.WIDTH(`DP_UNPACK_ATOM_SIGN_W))
        ff_s0_s1_signaling (.clock(clock), .in_en(rst_n & in_valid), .in_d(signaling_d), .out_q(r1_signaling[atom_index]));
      end

      // 3. Pack per-atom S1 registers into flat output buses
      assign out_mantissas[atom_index*`DP_HALF_W+:`DP_HALF_W]                           = r1_mantissas[atom_index];
      assign out_exponents[atom_index*`DP_UNPACK_ATOM_EXP_W+:`DP_UNPACK_ATOM_EXP_W]     = r1_exponents[atom_index];
      assign out_signs[atom_index*`DP_UNPACK_ATOM_SIGN_W+:`DP_UNPACK_ATOM_SIGN_W]       = r1_signs[atom_index];
      assign out_classes[atom_index*`DP_UNPACK_ATOM_CLASS_W+:`DP_UNPACK_ATOM_CLASS_W]   = r1_classes[atom_index];
      assign out_signaling[atom_index*`DP_UNPACK_ATOM_SIGN_W+:`DP_UNPACK_ATOM_SIGN_W]   = r1_signaling[atom_index];
    end
  endgenerate

endmodule
