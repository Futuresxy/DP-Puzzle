`include "dp_defs.vh"

// Stage 5 combinational accumulator C unpacker (raw C travels through S1-S4 without decoding).
// Both FP32 and INT32 produce sign plus 32-bit magnitude; FP32 appends 8 structural low zeros.
// Precision / signal | S | I  | F
// ------------------ | - | -- | --
// FP32 natural M24   | 0 | 1  | 23
// FP32 padded M32    | 0 | 1  | 31
// INT32 absolute M32 | 0 | 32 | 0
module dp_c_unpack #(
  parameter integer ANCHOR_W            = 10,
  parameter integer DETECT_LEADING_ZERO = 1  // 0 in v1.8+ raw C exponent mode; 1 in legacy LZD mode
) (
  input  wire [             `DP_FP32_W-1:0] in_data,
  input  wire                               in_datatype,
  output wire                               out_negative,
  output wire [             `DP_FP32_W-1:0] out_magnitude,
  output wire signed [        ANCHOR_W-1:0] out_anchor,
  output wire [$clog2(`DP_FP32_W+1)-1:0]    out_z,
  output wire [          `DP_SPECIAL_W-1:0] out_special
);

  localparam signed [ANCHOR_W-1:0] EXPONENT_BIAS = `DP_FP32_BIAS;

  // 1. Decode FP32/INT32 fields and unbiased exponent
  wire [            `DP_FP32_E-1:0] exponent_field;
  wire [            `DP_FP32_F-1:0] fraction_field;
  wire signed [       ANCHOR_W-1:0] exponent_unbiased;
  wire                              is_integer;
  wire                              is_special;
  wire                              has_fraction;

  assign exponent_field    = in_data[`DP_FP32_F+:`DP_FP32_E];
  assign fraction_field    = in_data[0+:`DP_FP32_F];
  assign is_integer        = (in_datatype == `DP_CT_INT32);
  assign is_special        = ~is_integer & (&exponent_field);
  assign has_fraction      = |fraction_field;
  assign exponent_unbiased = ((exponent_field == 0) ?
                              {{(ANCHOR_W - 1){1'b0}}, 1'b1} :
                              $signed({{(ANCHOR_W - `DP_FP32_E){1'b0}}, exponent_field})) -
                             EXPONENT_BIAS;

  // 2. Construct magnitude, anchor, and special flags
  assign out_negative                = in_data[`DP_FP32_W-1];
  assign out_magnitude               = is_integer ? (out_negative ? -in_data : in_data) :
                                       is_special ? {`DP_FP32_W{1'b0}} :
                                                    {(|exponent_field), fraction_field, {(`DP_FP32_W - `DP_FP32_M){1'b0}}};
  assign out_anchor                  = (~is_integer & ~is_special & (out_magnitude != 0)) ?
                                       exponent_unbiased :
                                       {ANCHOR_W{1'b0}};
  assign out_special[`DP_SP_NAN]     = is_special & has_fraction;
  assign out_special[`DP_SP_INVALID] = is_special & has_fraction & ~fraction_field[`DP_FP32_F-1];
  assign out_special[`DP_SP_POS_INF] = is_special & ~has_fraction & ~out_negative;
  assign out_special[`DP_SP_NEG_INF] = is_special & ~has_fraction & out_negative;

  // 3. Optional subnormal LZD (disabled in v1.8+ raw C exponent mode)
  wire [$clog2(`DP_FP32_W+1)-1:0] leading_zero_count;
  wire                            magnitude_active;

  generate
    if (DETECT_LEADING_ZERO != 0) begin : g_legacy_lzd
      dp_lzd #(
        .W (`DP_FP32_W)
      ) u_subnormal_detect (
        .in_magnitude (out_magnitude),
        .out_count    (leading_zero_count),
        .out_active   (magnitude_active)
      );
      assign out_z = (~is_integer & (out_special == 0)) ? leading_zero_count : {$clog2(`DP_FP32_W+1){1'b0}};
    end else begin : g_raw_c_exponent
      assign leading_zero_count = {$clog2(`DP_FP32_W+1){1'b0}};
      assign magnitude_active   = (out_magnitude != 0);
      assign out_z              = {$clog2(`DP_FP32_W+1){1'b0}};
    end
  endgenerate

endmodule
