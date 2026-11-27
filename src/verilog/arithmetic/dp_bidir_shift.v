`include "dp_defs.vh"

// Shared bidirectional unsigned shifter using static bit reversal around one right-shift core.
// Positive in_net shifts left (consuming leading zeros); negative in_net shifts right with RTZ.
// Precision / signal | S | I | F
// ------------------ | - | - | ---
// Padded source      | 0 | I | W-I
// Aligned magnitude  | 0 | 1 | W-1
module dp_bidir_shift #(
  parameter integer W     = 39,
  parameter integer NET_W = 11
) (
  input  wire [      W-1:0] in_magnitude,
  input  wire signed [NET_W-1:0] in_net,
  output wire [      W-1:0] out_magnitude
);

  // 1. Decode shift direction and unsigned shift amount
  wire             left_direction;
  wire [NET_W-1:0] amount;

  assign left_direction = ~in_net[NET_W-1];
  assign amount         = left_direction ? in_net : -in_net;

  // 2. Shared right-shift core via static bit reversal: (x << k) == reverse(reverse(x) >> k)
  wire [W-1:0] reversed;
  wire [W-1:0] input_mux;
  wire [W-1:0] shifted;

  genvar bit_index;
  generate
    for (bit_index = 0; bit_index < W; bit_index = bit_index + 1) begin : g_reverse
      assign reversed[bit_index]      = in_magnitude[W-1-bit_index];
      assign out_magnitude[bit_index] = left_direction ? shifted[W-1-bit_index] : shifted[bit_index];
    end
  endgenerate

  assign input_mux = left_direction ? reversed : in_magnitude;

  dp_rtz_shift #(
    .W       (W),
    .SHIFT_W (NET_W)
  ) u_right_shift_core (
    .in_magnitude  (input_mux),
    .in_shift      (amount),
    .out_magnitude (shifted)
  );

endmodule
