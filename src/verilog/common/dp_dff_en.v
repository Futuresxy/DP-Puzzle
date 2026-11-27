// Parameterized payload register primitive (WIDTH >= 1).
// Rising-edge triggered, no reset, holds value when in_en is deasserted.
module dp_dff_en #(
  parameter integer WIDTH = 1
) (
  input  wire             clock,
  input  wire             in_en,
  input  wire [WIDTH-1:0] in_d,
  output reg  [WIDTH-1:0] out_q
);

  always @(posedge clock) begin
    if (in_en) begin
      out_q <= in_d;
    end
  end

endmodule
