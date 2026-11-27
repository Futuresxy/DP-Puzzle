`include "dp_defs.vh"

// Combinational E-lane coordinate fusion shifter: sign-extends IN_W to OUT_W and shifts left by
// 0..DP_E_GUARD (2), converting MXFP4/NVFP4 (shift=2) and HiF4 (shift=e2_a+e2_b) to common S1I9F4.
// Precision    | Input S | I | F | Output S | I | F
// ------------ | ------- | - | - | -------- | - | -
// MXFP4/NVFP4  | 1       | 9 | 2 | 1        | 9 | 4
// HiF4         | 1       | 7 | 4 | 1        | 9 | 4
module dp_lane_e_shift #(
  parameter integer IN_W  = 2 * `DP_MUL_LO + 2 + $clog2(`DP_E_LANES / 2),
  parameter integer OUT_W = IN_W + `DP_E_GUARD
) (
  input  wire signed [                  IN_W-1:0] in_sum,
  input  wire [       $clog2(`DP_E_GUARD+1)-1:0] in_shift,
  output wire signed [                 OUT_W-1:0] out_sum
);

  // Sign-extend before shifting so upper bits are never truncated
  wire signed [OUT_W-1:0] extended_sum;

  assign extended_sum = {{(OUT_W - IN_W){in_sum[IN_W-1]}}, in_sum};
  assign out_sum      = extended_sum <<< in_shift;

endmodule
