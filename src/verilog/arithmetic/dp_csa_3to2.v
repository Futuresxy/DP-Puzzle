// Combinational 3:2 carry-save compressor without internal carry propagation.
// out_carry is pre-shifted left by 1 bit: in_a + in_b + in_c == out_sum + out_carry (mod 2^W).
module dp_csa_3to2 #(
  parameter integer W = 43 // Row width including all sign-extension growth bits (W >= 2)
) (
  input  wire [W-1:0] in_a,
  input  wire [W-1:0] in_b,
  input  wire [W-1:0] in_c,
  output wire [W-1:0] out_sum,
  output wire [W-1:0] out_carry
);

  assign out_sum   = in_a ^ in_b ^ in_c;
  assign out_carry = ((in_a & in_b) | (in_a & in_c) | (in_b & in_c)) << 1;

endmodule
