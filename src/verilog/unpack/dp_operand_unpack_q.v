`include "dp_defs.vh"

// Combinational single-element Q operand unpacker (MXFP8 E4M3/E5M2, MXFP6 E3M2/E2M3).
// Produces unsigned U4 magnitude (S0I1F3), U5 exponent unified to bias=15, sign, and class.
module dp_operand_unpack_q #(
  parameter integer INDEX = 0 // Q byte slot index (0..3)
) (
  input  wire [       `DP_LANE_W-1:0] in_data,
  input  wire [       `DP_TYPE_W-1:0] in_datatype,
  output wire [     `DP_EIGHTH_W-1:0] out_magnitude,
  output wire [      `DP_Q_EXP_W-1:0] out_exponent,
  output wire                         out_negative,
  output wire [  `DP_NUM_CLASS_W-1:0] out_class,
  output wire                         out_signaling
);

  localparam integer               Q_OFFSET      = INDEX * `DP_QUARTER_W;
  localparam [`DP_Q_EXP_W-1:0]     E4_BIAS_DELTA = `DP_Q_BIAS - `DP_MX8_E4_BIAS;
  localparam [`DP_Q_EXP_W-1:0]     E3_BIAS_DELTA = `DP_Q_BIAS - `DP_MX6_E3_BIAS;
  localparam [`DP_Q_EXP_W-1:0]     E2_BIAS_DELTA = `DP_Q_BIAS - `DP_MX6_E2_BIAS;

  // 1. Format selection and raw field slicing (FP6 occupies upper 6 bits of the byte container)
  wire                     select_e4;
  wire                     select_e5;
  wire                     select_e3;
  wire                     select_e2;
  wire                     select_q;
  wire [`DP_QUARTER_W-1:0] q_encoding;
  wire [ `DP_MX8_E4_E-1:0] e4_exponent_field;
  wire [ `DP_MX8_E5_E-1:0] e5_exponent_field;
  wire [ `DP_MX6_E3_E-1:0] e3_exponent_field;
  wire [ `DP_MX6_E2_E-1:0] e2_exponent_field;

  assign select_e4         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX8_E4M3);
  assign select_e5         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX8_E5M2);
  assign select_e3         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX6_E3M2);
  assign select_e2         = (INDEX < `DP_Q_LANES) & (in_datatype == `DP_DT_MX6_E2M3);
  assign select_q          = select_e4 | select_e5 | select_e3 | select_e2;

  assign q_encoding        = in_data[Q_OFFSET+:`DP_QUARTER_W];
  assign e4_exponent_field = q_encoding[`DP_MX8_E4_F+:`DP_MX8_E4_E];
  assign e5_exponent_field = q_encoding[`DP_MX8_E5_F+:`DP_MX8_E5_E];
  assign e3_exponent_field = q_encoding[(`DP_MX6_PAD+`DP_MX6_E3_F)+:`DP_MX6_E3_E];
  assign e2_exponent_field = q_encoding[(`DP_MX6_PAD+`DP_MX6_E2_F)+:`DP_MX6_E2_E];

  // 2. Re-encode finite exponent to common bias=15 (U5; subnormal effective exponent = 1)
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
                           ({`DP_Q_EXP_W{select_e2}} & e2_exponent);

  // 3. Normalize Q magnitude to I1F3 and classify special values
  wire [`DP_EIGHTH_W-1:0] q_magnitude;
  wire                    is_nan;
  wire                    is_inf;
  wire                    is_special;

  assign q_magnitude   = ({`DP_EIGHTH_W{select_e4}} & {(|e4_exponent_field), q_encoding[0+:`DP_MX8_E4_F]}) |
                         ({`DP_EIGHTH_W{select_e5}} & {(|e5_exponent_field), q_encoding[0+:`DP_MX8_E5_F], 1'b0}) |
                         ({`DP_EIGHTH_W{select_e3}} & {(|e3_exponent_field), q_encoding[`DP_MX6_PAD+:`DP_MX6_E3_F], 1'b0}) |
                         ({`DP_EIGHTH_W{select_e2}} & {(|e2_exponent_field), q_encoding[`DP_MX6_PAD+:`DP_MX6_E2_F]});

  assign is_nan        = (select_e4 & (&e4_exponent_field) & (&q_encoding[0+:`DP_MX8_E4_F])) |
                         (select_e5 & (&e5_exponent_field) & (|q_encoding[0+:`DP_MX8_E5_F]));
  assign is_inf        = select_e5 & (&e5_exponent_field) & ~(|q_encoding[0+:`DP_MX8_E5_F]);
  assign is_special    = is_nan | is_inf;

  assign out_signaling = select_e5 & is_nan & ~q_encoding[`DP_MX8_E5_F-1];
  assign out_magnitude = is_special ? {`DP_EIGHTH_W{1'b0}} : q_magnitude;
  assign out_exponent  = is_special ? {{(`DP_Q_EXP_W - 1){1'b0}}, 1'b1} : finite_exponent;
  assign out_negative  = select_q & q_encoding[`DP_QUARTER_W-1];
  assign out_class     = is_nan          ? `DP_CLASS_NAN :
                         is_inf          ? `DP_CLASS_INF :
                         (|q_magnitude)  ? `DP_CLASS_FINITE :
                                           `DP_CLASS_ZERO;

endmodule
