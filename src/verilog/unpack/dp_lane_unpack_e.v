`include "dp_defs.vh"

// Combinational 8-element E-operand decoder (32-bit lane container, instantiated for A and B).
// MXFP4/NVFP4 map via the E2M1 F1 table; HiF4 folds the 4-element shared e1 into F2 magnitude.
// Precision    | Magnitude S | I | F | Separate sign bits per element
// ------------ | ----------- | - | - | ------------------------------
// MXFP4/NVFP4  | 0           | 3 | 1 | 1
// HiF4 (e1 in) | 0           | 2 | 2 | 1
module dp_lane_unpack_e (
  input  wire [              `DP_LANE_W-1:0] in_data,
  input  wire [              `DP_TYPE_W-1:0] in_datatype,
  input  wire [                         1:0] in_e1,
  output wire [`DP_E_LANES*`DP_MUL_LO-1:0]   out_magnitude,
  output wire [            `DP_E_LANES-1:0]  out_negative
);

  genvar element_index;
  generate
    for (element_index = 0; element_index < `DP_E_LANES; element_index = element_index + 1) begin : g_element
      wire [`DP_EIGHTH_W-1:0] raw_encoding;
      wire [`DP_EIGHTH_W-1:0] fp4_magnitude;

      assign raw_encoding  = in_data[element_index*`DP_EIGHTH_W+:`DP_EIGHTH_W];
      // E2M1 encoding magnitude table in F1: {0, 1, 2, 3, 4, 6, 8, 12}
      assign fp4_magnitude = (raw_encoding[`DP_E_PAYLOAD_W-1:0] < 3'd5)  ? {1'b0, raw_encoding[`DP_E_PAYLOAD_W-1:0]} :
                             (raw_encoding[`DP_E_PAYLOAD_W-1:0] == 3'd5) ? 4'd6 :
                             (raw_encoding[`DP_E_PAYLOAD_W-1:0] == 3'd6) ? 4'd8 :
                                                                           4'd12;

      assign out_magnitude[element_index*`DP_MUL_LO+:`DP_MUL_LO] = (in_datatype == `DP_DT_HIF4) ?
        ({1'b0, raw_encoding[`DP_E_PAYLOAD_W-1:0]} << in_e1[element_index/`DP_E1_GRAIN]) :
        fp4_magnitude;
      assign out_negative[element_index] = in_data[element_index*`DP_EIGHTH_W+`DP_E_SIGN_BIT];
    end
  endgenerate

endmodule
