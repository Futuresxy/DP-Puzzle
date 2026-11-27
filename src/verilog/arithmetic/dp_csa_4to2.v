// Combinational 4:2 carry-save compressor built from two cascaded 3:2 stages.
// out_carry is pre-shifted to equal weight: out_sum + out_carry == in_a + in_b + in_c + in_d (mod 2^W).
module dp_csa_4to2 #(
  parameter integer W = 43 // Sign-extended two's-complement row width
) (
  input  wire [W-1:0] in_a,
  input  wire [W-1:0] in_b,
  input  wire [W-1:0] in_c,
  input  wire [W-1:0] in_d,
  output wire [W-1:0] out_sum,
  output wire [W-1:0] out_carry
);

  wire [W-1:0] first_sum;
  wire [W-1:0] first_carry;

  dp_csa_3to2 #(
    .W (W)
  ) u_first_compress (
    .in_a      (in_a),
    .in_b      (in_b),
    .in_c      (in_c),
    .out_sum   (first_sum),
    .out_carry (first_carry)
  );

  dp_csa_3to2 #(
    .W (W)
  ) u_second_compress (
    .in_a      (first_sum),
    .in_b      (first_carry),
    .in_c      (in_d),
    .out_sum   (out_sum),
    .out_carry (out_carry)
  );

endmodule
