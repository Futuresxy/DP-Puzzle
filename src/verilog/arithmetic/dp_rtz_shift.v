`include "dp_defs.vh"

// Fixed-width unsigned logical right barrel shifter implementing round-toward-zero (RTZ).
// Shift counts >= W flush the output to zero without wrap-around.
// Precision / signal | S | I | F
// ------------------ | - | - | -
// Input/output       | 0 | i | f
module dp_rtz_shift #(
  parameter integer W       = 27,
  parameter integer SHIFT_W = 9
) (
  input  wire [      W-1:0] in_magnitude,
  input  wire [SHIFT_W-1:0] in_shift,
  output wire [      W-1:0] out_magnitude
);

  // Compare full shift amount against W before truncating to barrel-control width
  localparam integer WINDOW_COUNT_W = ($clog2(W) < 1) ? 1 : $clog2(W);
  localparam integer COUNT_W        = (WINDOW_COUNT_W < SHIFT_W) ? WINDOW_COUNT_W : SHIFT_W;
  localparam integer COMPARE_W      = ($clog2(W + 1) > SHIFT_W) ? $clog2(W + 1) : SHIFT_W;

  wire [COMPARE_W-1:0] full_amount;

  assign full_amount   = {{(COMPARE_W - SHIFT_W){1'b0}}, in_shift};
  assign out_magnitude = (full_amount >= W[COMPARE_W-1:0]) ?
                         {W{1'b0}} :
                         (in_magnitude >> in_shift[COUNT_W-1:0]);

endmodule
