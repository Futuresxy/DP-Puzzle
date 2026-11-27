`include "dp_defs.vh"

// Stage 6 combinational global alignment: common E_max selection, single bidirectional shift per
// source (fusing normalization and inter-group alignment), and two's-complement sign restoration.
// Precision          | Mag S | Leaf S | I  | F
// ------------------ | ----- | ------ | -- | --------
// All floating modes | 0     | 1      | 1  | MAG_W-1
// INT8 + INT32       | 0     | 1      | 32 | MAG_W-32
module dp_global_align #(
  parameter integer PRECOMPUTED_EXPONENT = 0, // 1 uses S5 registered compare_exp for E_max
  parameter integer N                    = 5,
  parameter integer MAG_W                = 39,
  parameter integer ANCHOR_W             = 10,
  parameter integer Z_W                  = $clog2(MAG_W + 1)
) (
  input  wire                        in_integer,
  input  wire                        in_enable,
  input  wire [         N*MAG_W-1:0] in_magnitude,
  input  wire [      N*ANCHOR_W-1:0] in_anchor,
  input  wire [      N*ANCHOR_W-1:0] in_compare_exp,
  input  wire [           N*Z_W-1:0] in_z,
  input  wire [               N-1:0] in_negative,
  input  wire [N*`DP_SPECIAL_W-1:0]  in_special,
  output wire [     N*(MAG_W+1)-1:0] out_leaves,
  output wire signed [ ANCHOR_W-1:0] out_anchor,
  output wire                        out_negative_zero,
  output wire [   `DP_SPECIAL_W-1:0] out_special
);

  `include "dp_functions.vh"

  localparam integer NET_W = ANCHOR_W + 1;

  // 1. Reduce special-value flags across all N sources
  wire [               N-1:0] nan_sources;
  wire [               N-1:0] invalid_sources;
  wire [               N-1:0] positive_inf_sources;
  wire [               N-1:0] negative_inf_sources;
  wire [   `DP_SPECIAL_W-1:0] special_comb;

  genvar source_index;
  generate
    for (source_index = 0; source_index < N; source_index = source_index + 1) begin : g_special_reduce
      assign nan_sources[source_index]          = in_special[source_index*`DP_SPECIAL_W+`DP_SP_NAN];
      assign invalid_sources[source_index]      = in_special[source_index*`DP_SPECIAL_W+`DP_SP_INVALID];
      assign positive_inf_sources[source_index] = in_special[source_index*`DP_SPECIAL_W+`DP_SP_POS_INF];
      assign negative_inf_sources[source_index] = in_special[source_index*`DP_SPECIAL_W+`DP_SP_NEG_INF];
    end
  endgenerate

  assign special_comb[`DP_SP_NAN]     = |nan_sources;
  assign special_comb[`DP_SP_POS_INF] = |positive_inf_sources;
  assign special_comb[`DP_SP_NEG_INF] = |negative_inf_sources;
  assign special_comb[`DP_SP_INVALID] = (|invalid_sources) | ((|positive_inf_sources) & (|negative_inf_sources));
  assign out_special                  = special_comb;

  // 2. Select common E_max across all active finite non-zero floating-point sources
  wire [N*ANCHOR_W-1:0] exponents;
  wire [         N-1:0] active;
  wire [         N-1:0] negative_zero;
  wire                  any_active;

  dp_max_tree #(
    .N (N),
    .W (ANCHOR_W)
  ) u_global_anchor_max (
    .in_values  (exponents),
    .in_active  (active),
    .out_max    (out_anchor),
    .out_active (any_active)
  );

  // 3. Per-source net shift (net = A_raw - E_max), bidirectional shift, and sign restoration
  generate
    for (source_index = 0; source_index < N; source_index = source_index + 1) begin : g_source
      wire signed [ANCHOR_W-1:0] raw_anchor;
      wire [            Z_W-1:0] leading;
      wire [          MAG_W-1:0] magnitude;
      wire signed [   NET_W-1:0] net_shift;
      wire [          MAG_W-1:0] isolated_magnitude;
      wire [          MAG_W-1:0] shifted;
      wire [          MAG_W-1:0] result_magnitude;

      assign raw_anchor         = in_anchor[source_index*ANCHOR_W+:ANCHOR_W];
      assign leading            = in_z[source_index*Z_W+:Z_W];
      assign magnitude          = in_magnitude[source_index*MAG_W+:MAG_W];
      assign active[source_index] = in_enable & ~in_integer & (magnitude != 0) &
                                    (in_special[source_index*`DP_SPECIAL_W+:`DP_SPECIAL_W] == 0);
      assign exponents[source_index*ANCHOR_W+:ANCHOR_W] =
        (PRECOMPUTED_EXPONENT != 0) ?
        in_compare_exp[source_index*ANCHOR_W+:ANCHOR_W] :
        (raw_anchor - $signed({{(ANCHOR_W - Z_W){1'b0}}, leading}));

      assign net_shift          = $signed({raw_anchor[ANCHOR_W-1], raw_anchor}) -
                                  $signed({out_anchor[ANCHOR_W-1], out_anchor});
      assign isolated_magnitude = active[source_index] ? magnitude : {MAG_W{1'b0}};
      assign result_magnitude   = in_integer ? magnitude : shifted;

      dp_bidir_shift #(
        .W     (MAG_W),
        .NET_W (NET_W)
      ) u_global_align_shift (
        .in_magnitude  (isolated_magnitude),
        .in_net        (net_shift),
        .out_magnitude (shifted)
      );

      assign out_leaves[source_index*(MAG_W+1)+:MAG_W+1] =
        in_negative[source_index] ? -$signed({1'b0, result_magnitude}) : $signed({1'b0, result_magnitude});
      assign negative_zero[source_index] = in_negative[source_index] & (result_magnitude == 0);
    end
  endgenerate

  assign out_negative_zero = &negative_zero;

endmodule
