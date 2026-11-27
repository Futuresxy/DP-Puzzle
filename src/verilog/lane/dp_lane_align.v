`include "dp_defs.vh"

// Stage 3 combinational local alignment: maps S2 products and group anchor into 4 signed S3 leaves.
// E_FIXED_COORD=1 bypasses the wide right-shifter for E pairs and INT8 products; 0 retains legacy RTZ.
// Output leaf formats (P = LOCAL_W - 2):
// Precision                 | S | I  | F
// ------------------------- | - | -- | ----
// TF32 / FP16 / BF16 / MXQ  | 1 | 2  | P
// MXFP4 / NVFP4 (legacy)    | 1 | 7  | P-5
// HiF4 (legacy)             | 1 | 5  | P-3
// v1.8+ MX/NV pair          | 1 | 9  | P-7
// v1.8+ HiF4 pair           | 1 | 7  | P-5
// INT8                      | 1 | 15 | P-13
module dp_lane_align #(
  parameter integer LOCAL_W       = `DP_DEFAULT_LOCAL_W,
  parameter integer LEAF_W        = LOCAL_W + 1,
  parameter integer QE_ONLY       = 0,                   // 1 prunes T/H/INT8 paths statically
  parameter integer E_FIXED_COORD = 0,                   // 1 bypasses wide shifter for E pairs and INT8
  parameter integer PRODUCT_W     = `DP_PRODUCT_W,
  parameter integer EXPONENT_W    = `DP_PRODUCT_EXP_W
) (
  input  wire                               in_valid,
  input  wire [             `DP_TYPE_W-1:0] in_datatype,
  input  wire [  `DP_E_LANES*PRODUCT_W-1:0] in_products,
  input  wire [            `DP_E_LANES-1:0] in_negative,
  input  wire [            `DP_E_LANES-1:0] in_active,
  input  wire [             EXPONENT_W-1:0] in_anchor,
  input  wire [ `DP_E_LANES*EXPONENT_W-1:0] in_exponents,
  output wire [     `DP_Q_LANES*LEAF_W-1:0] out_leaves
);

  `include "dp_functions.vh"

  genvar pair_index;
  generate
    for (pair_index = 0; pair_index < `DP_Q_LANES; pair_index = pair_index + 1) begin : g_align
      wire                   select_pair;
      wire                   select_element;
      wire                   select_float;
      wire [  PRODUCT_W-1:0] product_value;
      wire [`DP_E_PAIR_W-1:0] pair_magnitude_a;
      wire [`DP_E_PAIR_W-1:0] pair_magnitude_b;

      assign product_value    = in_products[pair_index*PRODUCT_W+:PRODUCT_W];
      assign select_pair      = in_valid &
                                (((QE_ONLY != 0) ?
                                  (((in_datatype >= `DP_DT_MXFP4) & (in_datatype <= `DP_DT_HIF4)) ? `DP_E_LANES : `DP_Q_LANES) :
                                  elements(in_datatype)) == `DP_E_LANES);
      assign select_element   = in_valid & ~select_pair &
                                (pair_index < ((QE_ONLY != 0) ?
                                               (((in_datatype >= `DP_DT_MXFP4) & (in_datatype <= `DP_DT_HIF4)) ? `DP_E_LANES : `DP_Q_LANES) :
                                               elements(in_datatype)));
      assign select_float     = select_element & (in_datatype != `DP_DT_INT8) & in_active[pair_index];
      assign pair_magnitude_a = {{(`DP_E_PAIR_W - 2 * `DP_EIGHTH_W){1'b0}}, in_products[(2*pair_index)*PRODUCT_W+:2*`DP_EIGHTH_W]};
      assign pair_magnitude_b = {{(`DP_E_PAIR_W - 2 * `DP_EIGHTH_W){1'b0}}, in_products[(2*pair_index+1)*PRODUCT_W+:2*`DP_EIGHTH_W]};

      // 1. E-mode signed pair reduction (two 8b products -> signed 10b pair sum)
      wire signed [`DP_E_PAIR_W-1:0] pair_a;
      wire signed [`DP_E_PAIR_W-1:0] pair_b;
      wire signed [`DP_E_PAIR_W-1:0] pair_sum;
      wire [      `DP_E_PAIR_W-1:0] pair_abs;
      wire                          sign_value;

      assign pair_a     = select_pair ? (in_negative[2*pair_index]   ? -pair_magnitude_a : pair_magnitude_a) : {`DP_E_PAIR_W{1'b0}};
      assign pair_b     = select_pair ? (in_negative[2*pair_index+1] ? -pair_magnitude_b : pair_magnitude_b) : {`DP_E_PAIR_W{1'b0}};
      assign pair_sum   = pair_a + pair_b;
      assign pair_abs   = pair_sum[`DP_E_PAIR_W-1] ? -pair_sum : pair_sum;
      assign sign_value = select_pair ? pair_sum[`DP_E_PAIR_W-1] : (select_element & in_negative[pair_index]);

      // 2. Position unsigned magnitude into the LOCAL_W alignment window
      wire [   LOCAL_W-1:0] shift_input;
      wire [EXPONENT_W-1:0] delta;
      wire [   LOCAL_W-1:0] shifted;

      assign shift_input = ((E_FIXED_COORD != 0) & (select_pair | (in_datatype == `DP_DT_INT8))) ?
                           {LOCAL_W{1'b0}} :
                           select_pair ?
                           ({{(LOCAL_W - `DP_E_PAIR_W){1'b0}}, pair_abs} << (LEAF_W - `DP_E_PAIR_W)) :
                           (select_element & ((QE_ONLY == 0) & (in_datatype == `DP_DT_INT8))) ?
                           ({{(LOCAL_W - PRODUCT_W){1'b0}}, product_value} << (LEAF_W - `DP_INT_PRODUCT_W)) :
                           select_float ?
                           ({{(LOCAL_W - PRODUCT_W){1'b0}}, product_value} <<
                            (LOCAL_W - 2 - ((QE_ONLY != 0) ? (2 * `DP_SCALE_F) : product_fraction(in_datatype)))) :
                           {LOCAL_W{1'b0}};

      // 3. Compute non-negative alignment shift distance relative to group anchor
      assign delta = ((E_FIXED_COORD == 0) & select_pair & (in_datatype == `DP_DT_HIF4) & (pair_abs != 0)) ?
                     (in_anchor - in_exponents[(2*pair_index)*EXPONENT_W+:EXPONENT_W]) :
                     select_float ?
                     (in_anchor - in_exponents[pair_index*EXPONENT_W+:EXPONENT_W]) :
                     {EXPONENT_W{1'b0}};

      // 4. Shared unsigned RTZ right-shifter
      dp_rtz_shift #(
        .W       (LOCAL_W),
        .SHIFT_W (EXPONENT_W)
      ) u_local_align_shift (
        .in_magnitude  (shift_input),
        .in_shift      (delta),
        .out_magnitude (shifted)
      );

      // 5. Restore two's-complement sign or select fixed-coordinate E/INT8 bypass leaf
      wire signed [LEAF_W-1:0] pair_leaf;
      wire [       LEAF_W-1:0] integer_magnitude;
      wire signed [LEAF_W-1:0] integer_leaf;

      assign pair_leaf         = {
        {`DP_E_GUARD{pair_sum[`DP_E_PAIR_W-1]}},
        pair_sum,
        {(LEAF_W - `DP_E_PAIR_W - `DP_E_GUARD){1'b0}}
      };
      assign integer_magnitude = {{(LEAF_W - PRODUCT_W){1'b0}}, product_value} << (LEAF_W - `DP_INT_PRODUCT_W);
      assign integer_leaf      = select_element ?
                                 (sign_value ? -$signed(integer_magnitude) : $signed(integer_magnitude)) :
                                 {LEAF_W{1'b0}};

      assign out_leaves[pair_index*LEAF_W+:LEAF_W] =
        ((E_FIXED_COORD != 0) & select_pair)                ? pair_leaf :
        ((E_FIXED_COORD != 0) & (in_datatype == `DP_DT_INT8)) ? integer_leaf :
        sign_value                                          ? -$signed({1'b0, shifted}) :
                                                              $signed({1'b0, shifted});
    end
  endgenerate

endmodule
