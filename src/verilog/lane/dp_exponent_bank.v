`include "dp_defs.vh"

// Stage 2 combinational lane exponent adder bank (two wide/narrow adder sets matching mantissa banks).
// Consumes two compact E10 atoms directly: T/H use the wide 8b adder, Q uses both wide and narrow
// 5b adders, and E shares a single e2 sum in bank 0.
module dp_exponent_bank (
  input  wire [                        `DP_TYPE_W-1:0] in_datatype,
  input  wire                                          in_enable,
  input  wire [                  `DP_UNPACK_EXP_W-1:0] in_a_exponents,
  input  wire [                  `DP_UNPACK_EXP_W-1:0] in_b_exponents,
  output wire [`DP_E_LANES*`DP_PRODUCT_EXP_W-1:0]      out_exponents
);

  // Per-bank wide (9b output) and narrow (6b output) exponent sums
  wire [`DP_PRODUCT_EXP_W-1:0] wide_sum   [0:`DP_MUL_BANKS-1];
  wire [        `DP_Q_EXP_W:0] narrow_sum [0:`DP_MUL_BANKS-1];

  genvar bank_index;
  genvar element_index;

  // 1. Per-bank wide/narrow operand muxing and unsigned exponent addition
  generate
    for (bank_index = 0; bank_index < `DP_MUL_BANKS; bank_index = bank_index + 1) begin : g_bank
      wire [  `DP_EXP_W-1:0] a_wide_exponent;
      wire [  `DP_EXP_W-1:0] b_wide_exponent;
      wire [`DP_Q_EXP_W-1:0] a_narrow_exponent;
      wire [`DP_Q_EXP_W-1:0] b_narrow_exponent;
      wire                   select_h;
      wire                   select_e;
      wire                   select_q;

      assign select_h = in_enable &
                        ((in_datatype == `DP_DT_FP16) |
                         (in_datatype == `DP_DT_BF16) |
                         ((in_datatype == `DP_DT_TF32) & (bank_index == 0)));
      assign select_e = in_enable & (bank_index == 0) &
                        ((in_datatype == `DP_DT_MXFP4) |
                         (in_datatype == `DP_DT_NVFP4) |
                         (in_datatype == `DP_DT_HIF4));
      assign select_q = in_enable &
                        ~((in_datatype == `DP_DT_TF32)  |
                          (in_datatype == `DP_DT_FP16)  |
                          (in_datatype == `DP_DT_BF16)  |
                          (in_datatype == `DP_DT_INT8)  |
                          (in_datatype == `DP_DT_MXFP4) |
                          (in_datatype == `DP_DT_NVFP4) |
                          (in_datatype == `DP_DT_HIF4));

      assign a_wide_exponent   = select_h ? in_a_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+:`DP_EXP_W] :
                                 select_e ? {{(`DP_EXP_W - 1){1'b0}}, in_a_exponents[0]} :
                                 select_q ? {{(`DP_EXP_W - `DP_Q_EXP_W){1'b0}}, in_a_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+:`DP_Q_EXP_W]} :
                                            {`DP_EXP_W{1'b0}};
      assign b_wide_exponent   = select_h ? in_b_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+:`DP_EXP_W] :
                                 select_e ? {{(`DP_EXP_W - 1){1'b0}}, in_b_exponents[0]} :
                                 select_q ? {{(`DP_EXP_W - `DP_Q_EXP_W){1'b0}}, in_b_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+:`DP_Q_EXP_W]} :
                                            {`DP_EXP_W{1'b0}};
      assign a_narrow_exponent = select_q ? in_a_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+`DP_Q_EXP_W+:`DP_Q_EXP_W] :
                                            {`DP_Q_EXP_W{1'b0}};
      assign b_narrow_exponent = select_q ? in_b_exponents[bank_index*`DP_UNPACK_ATOM_EXP_W+`DP_Q_EXP_W+:`DP_Q_EXP_W] :
                                            {`DP_Q_EXP_W{1'b0}};

      dp_exponent_add #(
        .W (`DP_EXP_W)
      ) u_wide_add (
        .in_a    (a_wide_exponent),
        .in_b    (b_wide_exponent),
        .out_sum (wide_sum[bank_index])
      );

      dp_exponent_add #(
        .W (`DP_Q_EXP_W)
      ) u_narrow_add (
        .in_a    (a_narrow_exponent),
        .in_b    (b_narrow_exponent),
        .out_sum (narrow_sum[bank_index])
      );
    end
  endgenerate

  // 2. Route per-bank sums to logical element slots (0..7)
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_route
      wire                         is_e;
      wire                         is_h;
      wire [`DP_PRODUCT_EXP_W-1:0] q_sum;

      assign is_e = (in_datatype == `DP_DT_MXFP4) |
                    (in_datatype == `DP_DT_NVFP4) |
                    (in_datatype == `DP_DT_HIF4);
      assign is_h = (in_datatype == `DP_DT_TF32) |
                    (in_datatype == `DP_DT_FP16) |
                    (in_datatype == `DP_DT_BF16);

      if ((element_index < `DP_Q_LANES) & ((element_index % 2) == 0)) begin : g_even
        assign q_sum = wide_sum[element_index/2];
      end else if (element_index < `DP_Q_LANES) begin : g_odd
        assign q_sum = {{(`DP_PRODUCT_EXP_W - `DP_Q_EXP_W - 1){1'b0}}, narrow_sum[element_index/2]};
      end else begin : g_unused
        assign q_sum = {`DP_PRODUCT_EXP_W{1'b0}};
      end

      if (element_index < `DP_MUL_BANKS) begin : g_h
        assign out_exponents[element_index*`DP_PRODUCT_EXP_W+:`DP_PRODUCT_EXP_W] =
          is_e ? wide_sum[0] :
          is_h ? wide_sum[element_index] :
                 q_sum;
      end else begin : g_other
        assign out_exponents[element_index*`DP_PRODUCT_EXP_W+:`DP_PRODUCT_EXP_W] =
          is_e ? wide_sum[0] :
          is_h ? {`DP_PRODUCT_EXP_W{1'b0}} :
                 q_sum;
      end
    end
  endgenerate

endmodule
