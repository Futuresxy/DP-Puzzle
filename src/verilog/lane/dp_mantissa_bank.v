`include "dp_defs.vh"

// Stage 2 combinational lane multiplier bank: two shared HH/HL/LH/LL unsigned multiplier sets.
// Consumes two compact M16 atoms directly and isolates unused multiplier operands to zero.
//
// Unsigned mantissa operands A/B -> product Y (sign travels separately):
// Precision     | A/B S | A/B I | A/B F | Y S | Y I | Y F
// ------------- | ----- | ----- | ----- | --- | --- | ---
// TF32 / FP16   | 0     | 1     | 10    | 0   | 2   | 20
// BF16          | 0     | 1     | 7     | 0   | 2   | 14
// MXFP8 / MXFP6 | 0     | 1     | 3     | 0   | 2   | 6
// MXFP4 / NVFP4 | 0     | 3     | 1     | 0   | 6   | 2
// HiF4          | 0     | 2     | 2     | 0   | 4   | 4
// INT8          | 0     | 8     | 0     | 0   | 16  | 0
module dp_mantissa_bank (
  input  wire [                 `DP_TYPE_W-1:0] in_datatype,
  input  wire                                   in_enable,
  input  wire [          `DP_UNPACK_MANT_W-1:0] in_a_mantissas,
  input  wire [          `DP_UNPACK_MANT_W-1:0] in_b_mantissas,
  output wire [`DP_E_LANES*`DP_PRODUCT_W-1:0]   out_products
);

  `include "dp_functions.vh"

  // Per-bank reconstructed logical products (up to 4 products per bank in E mode)
  wire [`DP_PRODUCT_W-1:0] bank_products [0:`DP_MUL_BANKS-1][0:3];

  genvar bank_index;
  genvar element_index;

  // 1. Per-bank HH/HL/LH/LL operand slicing, isolation, multiplication, and recombination
  generate
    for (bank_index = 0; bank_index < `DP_MUL_BANKS; bank_index = bank_index + 1) begin : g_bank
      // Slice T/H (11b) and Q/INT8 even/odd (8b) operand fields from the bank's M16 atom
      wire [   `DP_MANT_W-1:0] h_magnitude_a;
      wire [   `DP_MANT_W-1:0] h_magnitude_b;
      wire [`DP_QUARTER_W-1:0] q_even_magnitude_a;
      wire [`DP_QUARTER_W-1:0] q_even_magnitude_b;
      wire [`DP_QUARTER_W-1:0] q_odd_magnitude_a;
      wire [`DP_QUARTER_W-1:0] q_odd_magnitude_b;

      assign h_magnitude_a      = in_a_mantissas[bank_index*`DP_HALF_W+:`DP_MANT_W];
      assign h_magnitude_b      = in_b_mantissas[bank_index*`DP_HALF_W+:`DP_MANT_W];
      assign q_even_magnitude_a = (in_datatype == `DP_DT_INT8) ?
                                  in_a_mantissas[bank_index*`DP_HALF_W+0+:`DP_QUARTER_W] :
                                  {{(`DP_QUARTER_W - `DP_MUL_LO){1'b0}}, in_a_mantissas[bank_index*`DP_HALF_W+0+:`DP_MUL_LO]};
      assign q_even_magnitude_b = (in_datatype == `DP_DT_INT8) ?
                                  in_b_mantissas[bank_index*`DP_HALF_W+0+:`DP_QUARTER_W] :
                                  {{(`DP_QUARTER_W - `DP_MUL_LO){1'b0}}, in_b_mantissas[bank_index*`DP_HALF_W+0+:`DP_MUL_LO]};
      assign q_odd_magnitude_a  = (in_datatype == `DP_DT_INT8) ?
                                  in_a_mantissas[bank_index*`DP_HALF_W+`DP_QUARTER_W+:`DP_QUARTER_W] :
                                  {{(`DP_QUARTER_W - `DP_MUL_LO){1'b0}}, in_a_mantissas[bank_index*`DP_HALF_W+`DP_MUL_LO+:`DP_MUL_LO]};
      assign q_odd_magnitude_b  = (in_datatype == `DP_DT_INT8) ?
                                  in_b_mantissas[bank_index*`DP_HALF_W+`DP_QUARTER_W+:`DP_QUARTER_W] :
                                  {{(`DP_QUARTER_W - `DP_MUL_LO){1'b0}}, in_b_mantissas[bank_index*`DP_HALF_W+`DP_MUL_LO+:`DP_MUL_LO]};

      // Mutually exclusive format family enables for operand isolation
      wire select_th;
      wire select_bf16;
      wire select_int8;
      wire select_e;
      wire select_q;

      assign select_th   = in_enable & ((in_datatype == `DP_DT_FP16) | ((in_datatype == `DP_DT_TF32) & (bank_index == 0)));
      assign select_bf16 = in_enable & (in_datatype == `DP_DT_BF16);
      assign select_int8 = in_enable & (in_datatype == `DP_DT_INT8);
      assign select_e    = in_enable & ((in_datatype == `DP_DT_MXFP4) | (in_datatype == `DP_DT_NVFP4) | (in_datatype == `DP_DT_HIF4));
      assign select_q    = in_enable &
                           ~((in_datatype == `DP_DT_TF32) |
                             (in_datatype == `DP_DT_FP16) |
                             (in_datatype == `DP_DT_BF16) |
                             (in_datatype == `DP_DT_INT8) |
                             (elements(in_datatype) == `DP_E_LANES));

      // Sub-multiplier input operands (8x8 HH, 8x4 HL, 4x8 LH, 4x4 LL)
      wire [`DP_MUL_HI-1:0] hh_a;
      wire [`DP_MUL_HI-1:0] hh_b;
      wire [`DP_MUL_HI-1:0] hl_a;
      wire [`DP_MUL_LO-1:0] hl_b;
      wire [`DP_MUL_LO-1:0] lh_a;
      wire [`DP_MUL_HI-1:0] lh_b;
      wire [`DP_MUL_LO-1:0] ll_a;
      wire [`DP_MUL_LO-1:0] ll_b;

      assign hh_a = select_th   ? {{(`DP_MUL_HI - (`DP_MANT_W - `DP_MUL_LO)){1'b0}}, h_magnitude_a[`DP_MANT_W-1:`DP_MUL_LO]} :
                    select_bf16 ? h_magnitude_a[`DP_MUL_HI-1:0] :
                    select_int8 ? q_even_magnitude_a[`DP_MUL_HI-1:0] :
                    select_e    ? {{(`DP_MUL_HI - `DP_MUL_LO){1'b0}}, in_a_mantissas[bank_index*`DP_HALF_W+0*`DP_MUL_LO+:`DP_MUL_LO]} :
                                  {`DP_MUL_HI{1'b0}};
      assign hh_b = select_th   ? {{(`DP_MUL_HI - (`DP_MANT_W - `DP_MUL_LO)){1'b0}}, h_magnitude_b[`DP_MANT_W-1:`DP_MUL_LO]} :
                    select_bf16 ? h_magnitude_b[`DP_MUL_HI-1:0] :
                    select_int8 ? q_even_magnitude_b[`DP_MUL_HI-1:0] :
                    select_e    ? {{(`DP_MUL_HI - `DP_MUL_LO){1'b0}}, in_b_mantissas[bank_index*`DP_HALF_W+0*`DP_MUL_LO+:`DP_MUL_LO]} :
                                  {`DP_MUL_HI{1'b0}};
      assign hl_a = select_th   ? hh_a :
                    select_int8 ? q_odd_magnitude_a[`DP_MUL_HI-1:0] :
                    select_e    ? {{(`DP_MUL_HI - `DP_MUL_LO){1'b0}}, in_a_mantissas[bank_index*`DP_HALF_W+1*`DP_MUL_LO+:`DP_MUL_LO]} :
                                  {`DP_MUL_HI{1'b0}};
      assign hl_b = select_th   ? h_magnitude_b[`DP_MUL_LO-1:0] :
                    select_int8 ? q_odd_magnitude_b[`DP_MUL_LO-1:0] :
                    select_e    ? in_b_mantissas[bank_index*`DP_HALF_W+1*`DP_MUL_LO+:`DP_MUL_LO] :
                                  {`DP_MUL_LO{1'b0}};
      assign lh_a = select_th   ? h_magnitude_a[`DP_MUL_LO-1:0] :
                    select_int8 ? q_odd_magnitude_b[`DP_MUL_LO+:`DP_MUL_LO] :
                    select_e    ? in_a_mantissas[bank_index*`DP_HALF_W+2*`DP_MUL_LO+:`DP_MUL_LO] :
                    select_q    ? q_odd_magnitude_a[`DP_MUL_LO-1:0] :
                                  {`DP_MUL_LO{1'b0}};
      assign lh_b = select_th   ? hh_b :
                    select_int8 ? q_odd_magnitude_a[`DP_MUL_HI-1:0] :
                    select_e    ? {{(`DP_MUL_HI - `DP_MUL_LO){1'b0}}, in_b_mantissas[bank_index*`DP_HALF_W+2*`DP_MUL_LO+:`DP_MUL_LO]} :
                    select_q    ? q_odd_magnitude_b[`DP_MUL_HI-1:0] :
                                  {`DP_MUL_HI{1'b0}};
      assign ll_a = select_th   ? h_magnitude_a[`DP_MUL_LO-1:0] :
                    select_e    ? in_a_mantissas[bank_index*`DP_HALF_W+3*`DP_MUL_LO+:`DP_MUL_LO] :
                    select_q    ? q_even_magnitude_a[`DP_MUL_LO-1:0] :
                                  {`DP_MUL_LO{1'b0}};
      assign ll_b = select_th   ? h_magnitude_b[`DP_MUL_LO-1:0] :
                    select_e    ? in_b_mantissas[bank_index*`DP_HALF_W+3*`DP_MUL_LO+:`DP_MUL_LO] :
                    select_q    ? q_even_magnitude_b[`DP_MUL_LO-1:0] :
                                  {`DP_MUL_LO{1'b0}};

      // Physical unsigned multiplier leaves
      wire [             2*`DP_MUL_HI-1:0] hh;
      wire [`DP_MUL_HI+`DP_MUL_LO-1:0]     hl;
      wire [`DP_MUL_HI+`DP_MUL_LO-1:0]     lh;
      wire [             2*`DP_MUL_LO-1:0] ll;

      dp_mul_unsigned #(
        .A_W (`DP_MUL_HI),
        .B_W (`DP_MUL_HI)
      ) u_hh_mul (
        .in_a        (hh_a),
        .in_b        (hh_b),
        .out_product (hh)
      );

      dp_mul_unsigned #(
        .A_W (`DP_MUL_HI),
        .B_W (`DP_MUL_LO)
      ) u_hl_mul (
        .in_a        (hl_a),
        .in_b        (hl_b),
        .out_product (hl)
      );

      dp_mul_unsigned #(
        .A_W (`DP_MUL_LO),
        .B_W (`DP_MUL_HI)
      ) u_lh_mul (
        .in_a        (lh_a),
        .in_b        (lh_b),
        .out_product (lh)
      );

      dp_mul_unsigned #(
        .A_W (`DP_MUL_LO),
        .B_W (`DP_MUL_LO)
      ) u_ll_mul (
        .in_a        (ll_a),
        .in_b        (ll_b),
        .out_product (ll)
      );

      // Zero-extend leaf products to DP_PRODUCT_W and recombine partial products for T/FP16 and odd INT8
      wire [`DP_PRODUCT_W-1:0] hh_extended;
      wire [`DP_PRODUCT_W-1:0] hl_extended;
      wire [`DP_PRODUCT_W-1:0] lh_extended;
      wire [`DP_PRODUCT_W-1:0] ll_extended;
      wire [`DP_PRODUCT_W-1:0] product_first;
      wire [`DP_PRODUCT_W-1:0] product_second;
      wire [`DP_PRODUCT_W-1:0] product_third;
      wire [`DP_PRODUCT_W-1:0] product_fourth;

      assign hh_extended = {{(`DP_PRODUCT_W - (2 * `DP_MUL_HI)){1'b0}}, hh};
      assign hl_extended = {{(`DP_PRODUCT_W - (`DP_MUL_HI + `DP_MUL_LO)){1'b0}}, hl};
      assign lh_extended = {{(`DP_PRODUCT_W - (`DP_MUL_HI + `DP_MUL_LO)){1'b0}}, lh};
      assign ll_extended = {{(`DP_PRODUCT_W - (2 * `DP_MUL_LO)){1'b0}}, ll};

      assign product_first =
        ((in_datatype == `DP_DT_TF32) | (in_datatype == `DP_DT_FP16)) ?
        ((hh_extended << (2 * `DP_MUL_LO)) + ((hl_extended + lh_extended) << `DP_MUL_LO) + ll_extended) :
        ((in_datatype == `DP_DT_BF16) | (in_datatype == `DP_DT_INT8) | (elements(in_datatype) == `DP_E_LANES)) ?
        hh_extended :
        ll_extended;
      assign product_second =
        (in_datatype == `DP_DT_INT8)           ? (hl_extended + (lh_extended << `DP_MUL_LO)) :
        (elements(in_datatype) == `DP_E_LANES) ? hl_extended :
        (elements(in_datatype) == `DP_Q_LANES) ? lh_extended :
                                                 {`DP_PRODUCT_W{1'b0}};
      assign product_third  = (elements(in_datatype) == `DP_E_LANES) ? lh_extended : {`DP_PRODUCT_W{1'b0}};
      assign product_fourth = (elements(in_datatype) == `DP_E_LANES) ? ll_extended : {`DP_PRODUCT_W{1'b0}};

      assign bank_products[bank_index][0] = product_first;
      assign bank_products[bank_index][1] = product_second;
      assign bank_products[bank_index][2] = product_third;
      assign bank_products[bank_index][3] = product_fourth;
    end
  endgenerate

  // 2. Route bank products to logical element slots (0..7)
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_route
      if (element_index < 2) begin : g_h
        assign out_products[element_index*`DP_PRODUCT_W+:`DP_PRODUCT_W] =
          (elements(in_datatype) < `DP_Q_LANES)  ? bank_products[element_index][0] :
          (elements(in_datatype) == `DP_Q_LANES) ? bank_products[element_index/2][element_index%2] :
                                                   bank_products[element_index/4][element_index%4];
      end else if (element_index < `DP_Q_LANES) begin : g_q
        assign out_products[element_index*`DP_PRODUCT_W+:`DP_PRODUCT_W] =
          (elements(in_datatype) < `DP_Q_LANES)  ? {`DP_PRODUCT_W{1'b0}} :
          (elements(in_datatype) == `DP_Q_LANES) ? bank_products[element_index/2][element_index%2] :
                                                   bank_products[element_index/4][element_index%4];
      end else begin : g_e
        assign out_products[element_index*`DP_PRODUCT_W+:`DP_PRODUCT_W] =
          (elements(in_datatype) == `DP_E_LANES) ? bank_products[element_index/4][element_index%4] :
                                                   {`DP_PRODUCT_W{1'b0}};
      end
    end
  endgenerate

endmodule
