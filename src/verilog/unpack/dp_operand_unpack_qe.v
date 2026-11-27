`include "dp_defs.vh"

// Combinational single-element QE operand unpacker (fixed slices and narrow MUXes, no T/H/INT8).
// Precision        | S | I | F
// ---------------- | - | - | -
// MXFP8 / MXFP6    | 0 | 1 | 3
// MXFP4 / NVFP4    | 0 | 3 | 1
// HiF4 (e1 fused)  | 0 | 2 | 2
module dp_operand_unpack_qe #(
  parameter integer INDEX = 0 // Logical element slot (0..3 for Q or E; 4..7 for E only)
) (
  input  wire [       `DP_LANE_W-1:0] in_data,
  input  wire [       `DP_TYPE_W-1:0] in_datatype,
  input  wire [                  1:0] in_e1,
  input  wire                         in_e2,
  output wire [     `DP_EIGHTH_W-1:0] out_magnitude,
  output wire [      `DP_Q_EXP_W-1:0] out_exponent,
  output wire                         out_negative,
  output wire [  `DP_NUM_CLASS_W-1:0] out_class,
  output wire                         out_signaling
);

  localparam integer               Q_OFFSET      = (INDEX % `DP_Q_LANES) * `DP_QUARTER_W;
  localparam [`DP_Q_EXP_W-1:0]     E4_BIAS_DELTA = `DP_Q_BIAS - `DP_MX8_E4_BIAS;
  localparam [`DP_Q_EXP_W-1:0]     E3_BIAS_DELTA = `DP_Q_BIAS - `DP_MX6_E3_BIAS;
  localparam [`DP_Q_EXP_W-1:0]     E2_BIAS_DELTA = `DP_Q_BIAS - `DP_MX6_E2_BIAS;

  // 1. Format selection and raw field slicing
  wire                       select_e4;
  wire                       select_e5;
  wire                       select_e3;
  wire                       select_e2;
  wire                       select_fp4;
  wire                       select_hif4;
  wire                       select_q;
  wire                       select_e;
  wire [  `DP_QUARTER_W-1:0] q_encoding;
  wire [   `DP_MX8_E4_E-1:0] e4_exponent_field;
  wire [   `DP_MX8_E5_E-1:0] e5_exponent_field;
  wire [   `DP_MX6_E3_E-1:0] e3_exponent_field;
  wire [   `DP_MX6_E2_E-1:0] e2_exponent_field;
  wire [`DP_E_PAYLOAD_W-1:0] e_payload;

  assign select_e4         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX8_E4M3);
  assign select_e5         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX8_E5M2);
  assign select_e3         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX6_E3M2);
  assign select_e2         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX6_E2M3);
  assign select_fp4        = (in_datatype == `DP_DT_MXFP4) | (in_datatype == `DP_DT_NVFP4);
  assign select_hif4       = (in_datatype == `DP_DT_HIF4);
  assign select_q          = select_e4 | select_e5 | select_e3 | select_e2;
  assign select_e          = select_fp4 | select_hif4;

  assign q_encoding        = in_data[Q_OFFSET+:`DP_QUARTER_W];
  assign e4_exponent_field = q_encoding[`DP_MX8_E4_F+:`DP_MX8_E4_E];
  assign e5_exponent_field = q_encoding[`DP_MX8_E5_F+:`DP_MX8_E5_E];
  assign e3_exponent_field = q_encoding[(`DP_MX6_PAD+`DP_MX6_E3_F)+:`DP_MX6_E3_E];
  assign e2_exponent_field = q_encoding[(`DP_MX6_PAD+`DP_MX6_E2_F)+:`DP_MX6_E2_E];
  assign e_payload         = in_data[INDEX*`DP_EIGHTH_W+:`DP_E_PAYLOAD_W];

  // 2. Re-encode Q exponent to bias=15 (U5) or pass HiF4 e2
  wire [`DP_Q_EXP_W-1:0] e4_exponent;
  wire [`DP_Q_EXP_W-1:0] e5_exponent;
  wire [`DP_Q_EXP_W-1:0] e3_exponent;
  wire [`DP_Q_EXP_W-1:0] e2_exponent;
  wire [`DP_Q_EXP_W-1:0] finite_exponent;

  assign e4_exponent     = ((|e4_exponent_field) ?
                            {{(`DP_Q_EXP_W - `DP_MX8_E4_E){1'b0}}, e4_exponent_field} :
                            {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1}) + E4_BIAS_DELTA;
  assign e5_exponent     = (|e5_exponent_field) ?
                           e5_exponent_field :
                           {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1};
  assign e3_exponent     = ((|e3_exponent_field) ?
                            {{(`DP_Q_EXP_W - `DP_MX6_E3_E){1'b0}}, e3_exponent_field} :
                            {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1}) + E3_BIAS_DELTA;
  assign e2_exponent     = ((|e2_exponent_field) ?
                            {{(`DP_Q_EXP_W - `DP_MX6_E2_E){1'b0}}, e2_exponent_field} :
                            {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1}) + E2_BIAS_DELTA;
  assign finite_exponent = ({`DP_Q_EXP_W{select_e4}} & e4_exponent) |
                           ({`DP_Q_EXP_W{select_e5}} & e5_exponent) |
                           ({`DP_Q_EXP_W{select_e3}} & e3_exponent) |
                           ({`DP_Q_EXP_W{select_e2}} & e2_exponent) |
                           {{(`DP_Q_EXP_W - 1){1'b0}}, (select_hif4 & in_e2)};

  // 3. Construct Q/FP4/HiF4 4-bit magnitude coefficient
  wire [`DP_EIGHTH_W-1:0] q_magnitude;
  wire [`DP_EIGHTH_W-1:0] fp4_magnitude;
  wire [`DP_EIGHTH_W-1:0] hif4_magnitude;
  wire [`DP_EIGHTH_W-1:0] finite_magnitude;

  assign q_magnitude      = ({`DP_EIGHTH_W{select_e4}} & {(|e4_exponent_field), q_encoding[0+:`DP_MX8_E4_F]}) |
                            ({`DP_EIGHTH_W{select_e5}} & {(|e5_exponent_field), q_encoding[0+:`DP_MX8_E5_F], 1'b0}) |
                            ({`DP_EIGHTH_W{select_e3}} & {(|e3_exponent_field), q_encoding[`DP_MX6_PAD+:`DP_MX6_E3_F], 1'b0}) |
                            ({`DP_EIGHTH_W{select_e2}} & {(|e2_exponent_field), q_encoding[`DP_MX6_PAD+:`DP_MX6_E2_F]});
  // E2M1 table in F1: payload 0..4 -> identity; 5/6/7 -> 6/8/12
  assign fp4_magnitude    = (e_payload < 3'd5)  ? {1'b0, e_payload} :
                            (e_payload == 3'd5) ? 4'd6 :
                            (e_payload == 3'd6) ? 4'd8 :
                                                  4'd12;
  assign hif4_magnitude   = in_e1[INDEX/`DP_E1_GRAIN] ? {e_payload, 1'b0} : {1'b0, e_payload};
  assign finite_magnitude = q_magnitude |
                            ({`DP_EIGHTH_W{select_fp4}}  & fp4_magnitude) |
                            ({`DP_EIGHTH_W{select_hif4}} & hif4_magnitude);

  // 4. Special-value classification and output assignment
  wire is_nan;
  wire is_inf;
  wire is_special;

  assign is_nan        = (select_e4 & (&e4_exponent_field) & (&q_encoding[0+:`DP_MX8_E4_F])) |
                         (select_e5 & (&e5_exponent_field) & (|q_encoding[0+:`DP_MX8_E5_F]));
  assign is_inf        = select_e5 & (&e5_exponent_field) & ~(|q_encoding[0+:`DP_MX8_E5_F]);
  assign is_special    = is_nan | is_inf;

  assign out_signaling = select_e5 & is_nan & ~q_encoding[`DP_MX8_E5_F-1];
  assign out_magnitude = is_special ? {`DP_EIGHTH_W{1'b0}} : finite_magnitude;
  assign out_exponent  = is_special ? {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1} : finite_exponent;
  assign out_negative  = (select_q & q_encoding[`DP_QUARTER_W-1]) |
                         (select_e & in_data[INDEX*`DP_EIGHTH_W+`DP_EIGHTH_W-1]);
  assign out_class     = is_nan              ? `DP_CLASS_NAN :
                         is_inf              ? `DP_CLASS_INF :
                         (|finite_magnitude) ? `DP_CLASS_FINITE :
                                               `DP_CLASS_ZERO;

endmodule
