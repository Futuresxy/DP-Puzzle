// Stage 7 baseline carry-save reduction: 4 groups via 4:2 CSA, then +C via 3:2 CSA, then single CPA.
// Supports N=2/3/5 (1/2/4 active groups + C); unused group slots pad to zero and C is added once.
// Float format: S1 I(1+clog2(N)) F(W-2); INT format: S1 I(32+clog2(N)) F(W-33).
module dp_final_csa_sum #(
  parameter integer N     = 5,              // Active group count plus one C leaf (2, 3, or 5)
  parameter integer W     = 40,             // Stage 6 two's-complement leaf width
  parameter integer SUM_W = W + $clog2(N)   // Full output width including reduction growth bits
) (
  input  wire [        N*W-1:0] in_values,
  output wire signed [SUM_W-1:0] out_sum
);

  // 1. Sign-extend all group and accumulator leaves to SUM_W
  wire [SUM_W-1:0] group_values [0:3];
  wire [SUM_W-1:0] c_value;

  genvar group_index;
  generate
    for (group_index = 0; group_index < 4; group_index = group_index + 1) begin : g_extend
      if (group_index < N - 1) begin : g_active
        assign group_values[group_index] = {
          {(SUM_W - W){in_values[(group_index+1)*W-1]}},
          in_values[group_index*W+:W]
        };
      end else begin : g_unused
        assign group_values[group_index] = {SUM_W{1'b0}};
      end
    end
  endgenerate

  assign c_value = {{(SUM_W - W){in_values[N*W-1]}}, in_values[(N-1)*W+:W]};

  // 2. Compress 4 group leaves into 2 carry-save rows
  wire [SUM_W-1:0] group_sum;
  wire [SUM_W-1:0] group_carry;

  dp_csa_4to2 #(
    .W (SUM_W)
  ) u_group_compress (
    .in_a      (group_values[0]),
    .in_b      (group_values[1]),
    .in_c      (group_values[2]),
    .in_d      (group_values[3]),
    .out_sum   (group_sum),
    .out_carry (group_carry)
  );

  // 3. Fold C leaf via 3:2 CSA and resolve with a single final CPA
  wire [SUM_W-1:0] total_sum;
  wire [SUM_W-1:0] total_carry;

  dp_csa_3to2 #(
    .W (SUM_W)
  ) u_c_compress (
    .in_a      (group_sum),
    .in_b      (group_carry),
    .in_c      (c_value),
    .out_sum   (total_sum),
    .out_carry (total_carry)
  );

  assign out_sum = $signed(total_sum) + $signed(total_carry);

  // synthesis translate_off
  initial begin
    if ((N != 2) && (N != 3) && (N != 5)) begin
      $display("ERROR: dp_final_csa_sum requires N=2/3/5");
      $finish;
    end
    if ((W < 2) || (SUM_W < W + $clog2(N))) begin
      $display("ERROR: insufficient carry-save width");
      $finish;
    end
  end
  // synthesis translate_on

endmodule
