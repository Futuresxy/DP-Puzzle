`include "dp_defs.vh"

// Combinational block-scale unpacker -> unsigned I1F3 magnitude and 8-bit exponent.
// UNBIASED_EXPONENT=1 outputs signed 8-bit unbiased exponent; 0 outputs common bias=127.
// Precision / signal | S | I | F
// ------------------ | - | - | -
// E8M0 / E4M3 / E6M2 | 0 | 1 | 3
// Unit scale         | 0 | 1 | 3
module dp_scale_unpack #(
  parameter integer UNBIASED_EXPONENT = 0 // 1: signed 8b unbiased exponent; 0: common bias=127
) (
  input  wire [     `DP_SCALE_W-1:0] in_data,
  input  wire [`DP_SCALE_TYPE_W-1:0] in_datatype,
  output wire [     `DP_SCALE_M-1:0] out_magnitude,
  output wire [       `DP_EXP_W-1:0] out_exponent,
  output wire                        out_nan
);

  wire                   is_e8m0;
  wire                   is_e6m2;
  wire                   is_e4m3;
  wire [           31:0] exponent_work;
  wire [           31:0] unbiased_exponent_work;
  wire [`DP_SCALE_M-1:0] decoded_magnitude;

  assign is_e8m0 = (in_datatype == `DP_SC_E8M0);
  assign is_e6m2 = (in_datatype == `DP_SC_E6M2);
  assign is_e4m3 = (in_datatype == `DP_SC_E4M3);

  assign exponent_work = is_e8m0 ?
    {{(32 - `DP_SCALE_W){1'b0}}, in_data} :
    is_e6m2 ?
    ({{(32 - `DP_HIF_SCALE_E){1'b0}}, in_data[`DP_HIF_SCALE_F+:`DP_HIF_SCALE_E]} + `DP_SCALE_BIAS - `DP_HIF_SCALE_BIAS) :
    is_e4m3 ?
    (((in_data[`DP_NV_SCALE_F+:`DP_NV_SCALE_E] == 0) ?
      32'd1 :
      {{(32 - `DP_NV_SCALE_E){1'b0}}, in_data[`DP_NV_SCALE_F+:`DP_NV_SCALE_E]}) + `DP_SCALE_BIAS - `DP_NV_SCALE_BIAS) :
    `DP_SCALE_BIAS;

  assign out_nan = ((is_e8m0 | is_e6m2) & (&in_data)) |
                   (is_e4m3 & (&in_data[`DP_NV_SCALE_E+`DP_NV_SCALE_F-1:0]));

  assign decoded_magnitude = is_e6m2 ? {1'b1, in_data[`DP_HIF_SCALE_F-1:0], 1'b0} :
                             is_e4m3 ? {(|in_data[`DP_NV_SCALE_F+:`DP_NV_SCALE_E]), in_data[`DP_NV_SCALE_F-1:0]} :
                                       {1'b1, {`DP_SCALE_F{1'b0}}};

  assign out_magnitude          = out_nan ? {`DP_SCALE_M{1'b0}} : decoded_magnitude;
  assign unbiased_exponent_work = out_nan ? 32'd0 : (exponent_work - `DP_SCALE_BIAS);
  assign out_exponent           = (UNBIASED_EXPONENT != 0) ?
                                  unbiased_exponent_work[`DP_EXP_W-1:0] :
                                  exponent_work[`DP_EXP_W-1:0];

endmodule
