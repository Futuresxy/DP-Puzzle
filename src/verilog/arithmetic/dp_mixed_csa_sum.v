// Stage 7 mixed-precision carry-save reduction: 4 base groups + C and 2/4/8/12 extension groups.
// Keeps carry-save representation across all compression stages, selecting base vs. combined rows
// via a dual-row MUX before the single final CPA.
// W=40 growth: N=7 -> S43, N=9/13 -> S44, N=17 -> S45.
module dp_mixed_csa_sum #(
  parameter integer EXT_GROUPS = 2,                          // Number of extension groups (2, 4, 8, or 12)
  parameter integer W          = 40,                         // Stage 6 two's-complement leaf width
  parameter integer SUM_W      = W + $clog2(5 + EXT_GROUPS)  // Output width including all reduction growth bits
) (
  input  wire                          in_extension_active,
  input  wire [(5+EXT_GROUPS)*W-1:0]   in_values,
  output wire signed [      SUM_W-1:0] out_sum
);

  // 1. Sign-extend all leaves to SUM_W and gate extension leaves when inactive
  wire [SUM_W-1:0] source_values [0:4+EXT_GROUPS];

  genvar source_index;
  generate
    for (source_index = 0; source_index < 5 + EXT_GROUPS; source_index = source_index + 1) begin : g_extend
      if ((source_index >= 4) & (source_index < 4 + EXT_GROUPS)) begin : g_extension
        assign source_values[source_index] = in_extension_active ?
          {{(SUM_W - W){in_values[(source_index+1)*W-1]}}, in_values[source_index*W+:W]} :
          {SUM_W{1'b0}};
      end else begin : g_base
        assign source_values[source_index] =
          {{(SUM_W - W){in_values[(source_index+1)*W-1]}}, in_values[source_index*W+:W]};
      end
    end
  endgenerate

  // 2. Base 4-group + C carry-save compression (no intermediate CPA)
  wire [SUM_W-1:0] base_group_sum;
  wire [SUM_W-1:0] base_group_carry;
  wire [SUM_W-1:0] base_sum;
  wire [SUM_W-1:0] base_carry;

  dp_csa_4to2 #(
    .W (SUM_W)
  ) u_base_group_compress (
    .in_a      (source_values[0]),
    .in_b      (source_values[1]),
    .in_c      (source_values[2]),
    .in_d      (source_values[3]),
    .out_sum   (base_group_sum),
    .out_carry (base_group_carry)
  );

  dp_csa_3to2 #(
    .W (SUM_W)
  ) u_c_compress (
    .in_a      (base_group_sum),
    .in_b      (base_group_carry),
    .in_c      (source_values[4+EXT_GROUPS]),
    .out_sum   (base_sum),
    .out_carry (base_carry)
  );

  // 3. Extension group carry-save compression and merge with base rows
  wire [SUM_W-1:0] combined_sum;
  wire [SUM_W-1:0] combined_carry;

  generate
    if (EXT_GROUPS == 2) begin : g_two_groups
      dp_csa_4to2 #(
        .W (SUM_W)
      ) u_combine (
        .in_a      (base_sum),
        .in_b      (base_carry),
        .in_c      (source_values[4]),
        .in_d      (source_values[5]),
        .out_sum   (combined_sum),
        .out_carry (combined_carry)
      );
    end else if (EXT_GROUPS == 4) begin : g_four_groups
      wire [SUM_W-1:0] extension_sum;
      wire [SUM_W-1:0] extension_carry;

      dp_csa_4to2 #(
        .W (SUM_W)
      ) u_extension_compress (
        .in_a      (source_values[4]),
        .in_b      (source_values[5]),
        .in_c      (source_values[6]),
        .in_d      (source_values[7]),
        .out_sum   (extension_sum),
        .out_carry (extension_carry)
      );

      dp_csa_4to2 #(
        .W (SUM_W)
      ) u_combine (
        .in_a      (base_sum),
        .in_b      (base_carry),
        .in_c      (extension_sum),
        .in_d      (extension_carry),
        .out_sum   (combined_sum),
        .out_carry (combined_carry)
      );
    end else begin : g_many_groups
      // Compress independent 4-leaf blocks first (8 -> 4 rows, or 12 -> 6 rows)
      localparam integer BLOCK_COUNT = EXT_GROUPS / 4;

      wire [SUM_W-1:0] block_sum   [0:BLOCK_COUNT-1];
      wire [SUM_W-1:0] block_carry [0:BLOCK_COUNT-1];

      genvar block_index;
      for (block_index = 0; block_index < BLOCK_COUNT; block_index = block_index + 1) begin : g_block
        dp_csa_4to2 #(
          .W (SUM_W)
        ) u_compress (
          .in_a      (source_values[4+block_index*4]),
          .in_b      (source_values[5+block_index*4]),
          .in_c      (source_values[6+block_index*4]),
          .in_d      (source_values[7+block_index*4]),
          .out_sum   (block_sum[block_index]),
          .out_carry (block_carry[block_index])
        );
      end

      wire [SUM_W-1:0] first_eight_sum;
      wire [SUM_W-1:0] first_eight_carry;
      wire [SUM_W-1:0] extension_sum;
      wire [SUM_W-1:0] extension_carry;

      dp_csa_4to2 #(
        .W (SUM_W)
      ) u_first_eight_compress (
        .in_a      (block_sum[0]),
        .in_b      (block_carry[0]),
        .in_c      (block_sum[1]),
        .in_d      (block_carry[1]),
        .out_sum   (first_eight_sum),
        .out_carry (first_eight_carry)
      );

      if (EXT_GROUPS == 8) begin : g_eight_groups
        assign extension_sum   = first_eight_sum;
        assign extension_carry = first_eight_carry;
      end else begin : g_twelve_groups
        dp_csa_4to2 #(
          .W (SUM_W)
        ) u_last_four_compress (
          .in_a      (first_eight_sum),
          .in_b      (first_eight_carry),
          .in_c      (block_sum[2]),
          .in_d      (block_carry[2]),
          .out_sum   (extension_sum),
          .out_carry (extension_carry)
        );
      end

      dp_csa_4to2 #(
        .W (SUM_W)
      ) u_combine (
        .in_a      (base_sum),
        .in_b      (base_carry),
        .in_c      (extension_sum),
        .in_d      (extension_carry),
        .out_sum   (combined_sum),
        .out_carry (combined_carry)
      );
    end
  endgenerate

  // 4. Dual-row carry-save MUX and single final CPA
  wire [SUM_W-1:0] selected_sum;
  wire [SUM_W-1:0] selected_carry;

  assign selected_sum   = in_extension_active ? combined_sum   : base_sum;
  assign selected_carry = in_extension_active ? combined_carry : base_carry;
  assign out_sum        = $signed(selected_sum) + $signed(selected_carry);

  // synthesis translate_off
  initial begin
    if ((EXT_GROUPS != 2) && (EXT_GROUPS != 4) && (EXT_GROUPS != 8) && (EXT_GROUPS != 12)) begin
      $display("ERROR: dp_mixed_csa_sum requires 2/4/8/12 extension groups");
      $finish;
    end
    if (SUM_W < W + $clog2(5 + EXT_GROUPS)) begin
      $display("ERROR: dp_mixed_csa_sum insufficient output width");
      $finish;
    end
  end
  // synthesis translate_on

endmodule
