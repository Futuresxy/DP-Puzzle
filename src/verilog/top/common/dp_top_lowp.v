`include "dp_defs.vh"

// Shared 4-group low-precision top core (QE_FRONTEND=0 for E64; QE_FRONTEND=1 for Q32E64).
// Fixed latency L=8, II=1, atomic A/B/C input handshake, no output backpressure.
// S6 aligned leaf format: S1 I1 F(GLOBAL_W-2); S7 5-source sum format: S1 I4 F(GLOBAL_W-2).
module dp_top_lowp #(
  parameter integer QE_FRONTEND = 0, // 0: E-only frontend (E64); 1: compact QE frontend (Q32E64)
  parameter integer K_FP16      = `DP_DEFAULT_K,
  parameter integer LOCAL_W     = `DP_DEFAULT_LOCAL_W,
  parameter integer GLOBAL_W    = `DP_DEFAULT_GLOBAL_W,
  parameter integer GROUPS      = `DP_DEFAULT_K / `DP_GROUP_H
) (
  // Clock, reset, and atomic input handshake
  input  wire                                       clock,
  input  wire                                       rst_n,
  input  wire                                       in_a_valid,
  input  wire                                       in_b_valid,
  input  wire                                       in_c_valid,
  output wire                                       out_a_ready,
  output wire                                       out_b_ready,
  output wire                                       out_c_ready,

  // Packed A/B operands, datatypes, block scales, and HiF4 shared exponents
  input  wire [GROUPS*`DP_LANES*`DP_LANE_W-1:0]     in_a,
  input  wire [GROUPS*`DP_LANES*`DP_LANE_W-1:0]     in_b,
  input  wire [                     `DP_TYPE_W-1:0] in_a_datatype,
  input  wire [                     `DP_TYPE_W-1:0] in_b_datatype,
  input  wire [            GROUPS*`DP_SCALE_W-1:0]  in_scale_a,
  input  wire [            GROUPS*`DP_SCALE_W-1:0]  in_scale_b,
  input  wire [               `DP_SCALE_TYPE_W-1:0] in_scale_a_datatype,
  input  wire [               `DP_SCALE_TYPE_W-1:0] in_scale_b_datatype,
  input  wire [                      GROUPS*4-1:0]  in_hif4_e1_a,
  input  wire [                      GROUPS*4-1:0]  in_hif4_e1_b,
  input  wire [                      GROUPS*2-1:0]  in_hif4_e2_a,
  input  wire [                      GROUPS*2-1:0]  in_hif4_e2_b,

  // Accumulator C input and transaction framing
  input  wire [                     `DP_FP32_W-1:0] in_c,
  input  wire                                       in_c_datatype,
  input  wire                                       in_last,

  // Stage 8 result outputs
  output wire                                       out_valid,
  output wire [                     `DP_FP32_W-1:0] out_d,
  output wire                                       out_d_datatype,
  output wire                                       out_last
);

  `include "dp_functions.vh"

  localparam integer GROUP_MAG_W  = LOCAL_W + 3;
  localparam integer GLOBAL_MAG_W = GLOBAL_W - 1;
  localparam integer SOURCE_COUNT = GROUPS + 1;
  localparam integer SUM_W        = GLOBAL_W + $clog2(SOURCE_COUNT);
  localparam integer ANCHOR_W     = anchor_width(GLOBAL_MAG_W);
  localparam integer Z_W          = $clog2(GLOBAL_MAG_W + 1);

  // ==== Input Protocol & Atomic Handshake ====
  wire e_type;
  wire q_type;
  wire tuple_legal;
  wire req_fire;

  assign e_type      = (in_a_datatype == `DP_DT_MXFP4) |
                       (in_a_datatype == `DP_DT_NVFP4) |
                       (in_a_datatype == `DP_DT_HIF4);
  assign q_type      = (in_a_datatype == `DP_DT_MX8_E4M3) |
                       (in_a_datatype == `DP_DT_MX8_E5M2) |
                       (in_a_datatype == `DP_DT_MX6_E2M3) |
                       (in_a_datatype == `DP_DT_MX6_E3M2);
  assign tuple_legal = (e_type | ((QE_FRONTEND != 0) & q_type)) &
                       (in_a_datatype == in_b_datatype) & ~in_c_datatype &
                       (in_scale_a_datatype == scale_type(in_a_datatype)) &
                       (in_scale_b_datatype == scale_type(in_a_datatype));
  assign req_fire    = rst_n & in_a_valid & in_b_valid & in_c_valid & tuple_legal;

  assign out_a_ready = req_fire;
  assign out_b_ready = req_fire;
  assign out_c_ready = req_fire;

  // Stage valid, last, and raw C pipeline signals (r1..r8)
  wire                  r1_valid;
  wire                  r2_valid;
  wire                  r3_valid;
  wire                  r4_valid;
  wire                  r5_valid;
  wire                  r6_valid;
  wire                  r7_valid;
  wire                  r8_valid;
  wire                  r1_last;
  wire                  r2_last;
  wire                  r3_last;
  wire                  r4_last;
  wire                  r5_last;
  wire                  r6_last;
  wire                  r7_last;
  wire                  r8_last;
  wire [`DP_FP32_W-1:0] r1_c_raw;
  wire [`DP_FP32_W-1:0] r2_c_raw;
  wire [`DP_FP32_W-1:0] r3_c_raw;
  wire [`DP_FP32_W-1:0] r4_c_raw;

  assign out_valid      = r8_valid;
  assign out_last       = r8_last & out_valid;
  assign out_d_datatype = 1'b0;

  // ==== Stages 1-5: Group Frontends and Raw C Pipeline ====
  wire [  SOURCE_COUNT*GLOBAL_MAG_W-1:0] source_magnitude;
  wire [      SOURCE_COUNT*ANCHOR_W-1:0] source_anchor;
  wire [      SOURCE_COUNT*ANCHOR_W-1:0] source_compare_exp;
  wire [           SOURCE_COUNT*Z_W-1:0] source_z;
  wire [               SOURCE_COUNT-1:0] source_negative;
  wire [SOURCE_COUNT*`DP_SPECIAL_W-1:0]  source_special;

  genvar group_index;
  generate
    for (group_index = 0; group_index < GROUPS; group_index = group_index + 1) begin : g_group
      wire [              GROUP_MAG_W-1:0] group_align_magnitude;
      wire signed [          ANCHOR_W-1:0] group_align_anchor;
      wire signed [          ANCHOR_W-1:0] group_align_compare_exp;
      wire [$clog2(GROUP_MAG_W+1)-1:0]     group_align_leading_zero_count;
      wire                                 group_align_negative;
      wire                                 group_top_valid;
      wire [            `DP_SPECIAL_W-1:0] group_align_special;

      if (QE_FRONTEND != 0) begin : g_qe
        dp_group_qe #(
          .ARCHITECTURE_V19 (1),
          .COMPACT_UNPACK   (1),
          .LOCAL_W          (LOCAL_W),
          .ANCHOR_W         (ANCHOR_W)
        ) u_group_unit (
          .clock             (clock),
          .rst_n             (rst_n),
          .in_valid          (req_fire),
          .in_datatype       (in_a_datatype),
          .in_a              (in_a[group_index*`DP_LANES*`DP_LANE_W+:`DP_LANES*`DP_LANE_W]),
          .in_b              (in_b[group_index*`DP_LANES*`DP_LANE_W+:`DP_LANES*`DP_LANE_W]),
          .in_scale_a        (in_scale_a[group_index*`DP_SCALE_W+:`DP_SCALE_W]),
          .in_scale_b        (in_scale_b[group_index*`DP_SCALE_W+:`DP_SCALE_W]),
          .in_scale_datatype (in_scale_a_datatype),
          .in_e1_a           (in_hif4_e1_a[group_index*4+:4]),
          .in_e1_b           (in_hif4_e1_b[group_index*4+:4]),
          .in_e2_a           (in_hif4_e2_a[group_index*2+:2]),
          .in_e2_b           (in_hif4_e2_b[group_index*2+:2]),
          .out_valid         (group_top_valid),
          .out_negative      (group_align_negative),
          .out_magnitude     (group_align_magnitude),
          .out_anchor        (group_align_anchor),
          .out_compare_exp   (group_align_compare_exp),
          .out_z             (group_align_leading_zero_count),
          .out_special       (group_align_special)
        );
      end else begin : g_e
        dp_group_e #(
          .LOCAL_W  (LOCAL_W),
          .ANCHOR_W (ANCHOR_W)
        ) u_group_unit (
          .clock             (clock),
          .rst_n             (rst_n),
          .in_valid          (req_fire),
          .in_datatype       (in_a_datatype),
          .in_a              (in_a[group_index*`DP_LANES*`DP_LANE_W+:`DP_LANES*`DP_LANE_W]),
          .in_b              (in_b[group_index*`DP_LANES*`DP_LANE_W+:`DP_LANES*`DP_LANE_W]),
          .in_scale_a        (in_scale_a[group_index*`DP_SCALE_W+:`DP_SCALE_W]),
          .in_scale_b        (in_scale_b[group_index*`DP_SCALE_W+:`DP_SCALE_W]),
          .in_scale_datatype (in_scale_a_datatype),
          .in_e1_a           (in_hif4_e1_a[group_index*4+:4]),
          .in_e1_b           (in_hif4_e1_b[group_index*4+:4]),
          .in_e2_a           (in_hif4_e2_a[group_index*2+:2]),
          .in_e2_b           (in_hif4_e2_b[group_index*2+:2]),
          .out_valid         (group_top_valid),
          .out_negative      (group_align_negative),
          .out_magnitude     (group_align_magnitude),
          .out_anchor        (group_align_anchor),
          .out_compare_exp   (group_align_compare_exp),
          .out_z             (group_align_leading_zero_count),
          .out_special       (group_align_special)
        );
      end

      assign source_magnitude[group_index*GLOBAL_MAG_W+:GLOBAL_MAG_W] = {
        group_align_magnitude,
        {(GLOBAL_MAG_W - GROUP_MAG_W){1'b0}}
      };
      assign source_negative[group_index]                             = group_align_negative;
      assign source_anchor[group_index*ANCHOR_W+:ANCHOR_W]            = group_align_anchor;
      assign source_compare_exp[group_index*ANCHOR_W+:ANCHOR_W]       = group_align_compare_exp;
      assign source_z[group_index*Z_W+:Z_W]                           = {
        {(Z_W - $clog2(GROUP_MAG_W + 1)){1'b0}},
        group_align_leading_zero_count
      };
      assign source_special[group_index*`DP_SPECIAL_W+:`DP_SPECIAL_W] = group_align_special;
    end
  endgenerate

  // Stages 1-4 raw C and control delay pipeline
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(req_fire), .out_q(r1_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_last (.clock(clock), .rst_n(rst_n), .in_d(req_fire & in_last), .out_q(r1_last));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s0_s1_c_raw (.clock(clock), .in_en(rst_n & req_fire), .in_d(in_c), .out_q(r1_c_raw));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(r1_valid), .out_q(r2_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_last (.clock(clock), .rst_n(rst_n), .in_d(r1_last), .out_q(r2_last));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s1_s2_c_raw (.clock(clock), .in_en(rst_n & r1_valid), .in_d(r1_c_raw), .out_q(r2_c_raw));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(r2_valid), .out_q(r3_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_last (.clock(clock), .rst_n(rst_n), .in_d(r2_last), .out_q(r3_last));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s2_s3_c_raw (.clock(clock), .in_en(rst_n & r2_valid), .in_d(r2_c_raw), .out_q(r3_c_raw));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(r3_valid), .out_q(r4_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_last (.clock(clock), .rst_n(rst_n), .in_d(r3_last), .out_q(r4_last));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s3_s4_c_raw (.clock(clock), .in_en(rst_n & r3_valid), .in_d(r3_c_raw), .out_q(r4_c_raw));

  // Stage 5 accumulator C unpack and token registers
  wire                              c_negative_d;
  wire [            `DP_FP32_W-1:0] c_magnitude_d;
  wire signed [       ANCHOR_W-1:0] c_anchor_d;
  wire [$clog2(`DP_FP32_W+1)-1:0]   c_z_d;
  wire [         `DP_SPECIAL_W-1:0] c_special_d;

  wire                              r5_c_negative;
  wire [            `DP_FP32_W-1:0] r5_c_magnitude;
  wire signed [       ANCHOR_W-1:0] r5_c_anchor;
  wire [$clog2(`DP_FP32_W+1)-1:0]   r5_c_z;
  wire [         `DP_SPECIAL_W-1:0] r5_c_special;

  dp_c_unpack #(
    .DETECT_LEADING_ZERO ((QE_FRONTEND == 0) ? 1 : 0),
    .ANCHOR_W            (ANCHOR_W)
  ) u_c_unpack (
    .in_data       (r4_c_raw),
    .in_datatype   (1'b0),
    .out_negative  (c_negative_d),
    .out_magnitude (c_magnitude_d),
    .out_anchor    (c_anchor_d),
    .out_z         (c_z_d),
    .out_special   (c_special_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_valid (.clock(clock), .rst_n(rst_n), .in_d(r4_valid), .out_q(r5_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_last (.clock(clock), .rst_n(rst_n), .in_d(r4_last), .out_q(r5_last));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s4_s5_c_negative (.clock(clock), .in_en(rst_n & r4_valid), .in_d(c_negative_d), .out_q(r5_c_negative));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s4_s5_c_magnitude (.clock(clock), .in_en(rst_n & r4_valid), .in_d(c_magnitude_d), .out_q(r5_c_magnitude));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s4_s5_c_anchor (.clock(clock), .in_en(rst_n & r4_valid), .in_d(c_anchor_d), .out_q(r5_c_anchor));
  dp_lib_DFFE #(.WIDTH($clog2(`DP_FP32_W + 1)))
  ff_s4_s5_c_z (.clock(clock), .in_en(rst_n & r4_valid), .in_d(c_z_d), .out_q(r5_c_z));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s4_s5_c_special (.clock(clock), .in_en(rst_n & r4_valid), .in_d(c_special_d), .out_q(r5_c_special));

  assign source_magnitude[GROUPS*GLOBAL_MAG_W+:GLOBAL_MAG_W] = {
    r5_c_magnitude,
    {(GLOBAL_MAG_W - `DP_FP32_W){1'b0}}
  };
  assign source_negative[GROUPS]                             = r5_c_negative;
  assign source_compare_exp[GROUPS*ANCHOR_W+:ANCHOR_W]       = r5_c_anchor;
  assign source_anchor[GROUPS*ANCHOR_W+:ANCHOR_W]            = r5_c_anchor;
  assign source_z[GROUPS*Z_W+:Z_W]                           = r5_c_z;
  assign source_special[GROUPS*`DP_SPECIAL_W+:`DP_SPECIAL_W] = r5_c_special;

  // ==== Stage 6: Global Alignment ====
  wire [SOURCE_COUNT*GLOBAL_W-1:0] leaves_d;
  wire [SOURCE_COUNT*GLOBAL_W-1:0] r6_leaves;
  wire signed [      ANCHOR_W-1:0] common_d;
  wire signed [      ANCHOR_W-1:0] r6_common;
  wire                             negative_zero_d;
  wire                             r6_negative_zero;
  wire [        `DP_SPECIAL_W-1:0] special_d;
  wire [        `DP_SPECIAL_W-1:0] r6_special;

  dp_global_align #(
    .PRECOMPUTED_EXPONENT (QE_FRONTEND),
    .N                    (SOURCE_COUNT),
    .MAG_W                (GLOBAL_MAG_W),
    .ANCHOR_W             (ANCHOR_W)
  ) u_global_alignment (
    .in_integer        (1'b0),
    .in_enable         (r5_valid),
    .in_magnitude      (source_magnitude),
    .in_anchor         (source_anchor),
    .in_compare_exp    (source_compare_exp),
    .in_z              (source_z),
    .in_negative       (source_negative),
    .in_special        (source_special),
    .out_leaves        (leaves_d),
    .out_anchor        (common_d),
    .out_negative_zero (negative_zero_d),
    .out_special       (special_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s5_s6_valid (.clock(clock), .rst_n(rst_n), .in_d(r5_valid), .out_q(r6_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s5_s6_last (.clock(clock), .rst_n(rst_n), .in_d(r5_last), .out_q(r6_last));
  dp_lib_DFFE #(.WIDTH(SOURCE_COUNT * GLOBAL_W))
  ff_s5_s6_leaves (.clock(clock), .in_en(rst_n & r5_valid), .in_d(leaves_d), .out_q(r6_leaves));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s5_s6_common_s6 (.clock(clock), .in_en(rst_n & r5_valid), .in_d(common_d), .out_q(r6_common));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s5_s6_negative_zero_s6 (.clock(clock), .in_en(rst_n & r5_valid), .in_d(negative_zero_d), .out_q(r6_negative_zero));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s5_s6_special_s6 (.clock(clock), .in_en(rst_n & r5_valid), .in_d(special_d), .out_q(r6_special));

  // ==== Stage 7: Final 5-Source SOP Reduction ====
  wire signed [    SUM_W-1:0] sum_d;
  wire signed [    SUM_W-1:0] r7_sum;
  wire signed [ ANCHOR_W-1:0] r7_common;
  wire                        r7_negative_zero;
  wire [   `DP_SPECIAL_W-1:0] r7_special;

  generate
    if (QE_FRONTEND != 0) begin : g_v19_sum
      dp_final_csa_sum #(
        .N (SOURCE_COUNT),
        .W (GLOBAL_W)
      ) u_final_sop_compress (
        .in_values (r6_leaves),
        .out_sum   (sum_d)
      );
    end else begin : g_legacy_sum
      dp_sum_tree #(
        .N (SOURCE_COUNT),
        .W (GLOBAL_W)
      ) u_final_sop_tree (
        .in_values (r6_leaves),
        .out_sum   (sum_d)
      );
    end
  endgenerate

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s6_s7_valid (.clock(clock), .rst_n(rst_n), .in_d(r6_valid), .out_q(r7_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s6_s7_last (.clock(clock), .rst_n(rst_n), .in_d(r6_last), .out_q(r7_last));
  dp_lib_DFFE #(.WIDTH(SUM_W))
  ff_s6_s7_sum (.clock(clock), .in_en(rst_n & r6_valid), .in_d(sum_d), .out_q(r7_sum));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s6_s7_common_s7 (.clock(clock), .in_en(rst_n & r6_valid), .in_d(r6_common), .out_q(r7_common));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s6_s7_negative_zero_s7 (.clock(clock), .in_en(rst_n & r6_valid), .in_d(r6_negative_zero), .out_q(r7_negative_zero));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s6_s7_special_s7 (.clock(clock), .in_en(rst_n & r6_valid), .in_d(r6_special), .out_q(r7_special));

  // ==== Stage 8: FP32 RNE Normalization and Special-Value Output Selection ====
  wire [`DP_FP32_W-1:0] finite_result;
  wire [`DP_FP32_W-1:0] result_d;

  dp_fp32_round #(
    .SUM_W        (SUM_W),
    .ANCHOR_W     (ANCHOR_W),
    .GLOBAL_MAG_W (GLOBAL_MAG_W)
  ) u_fp32_output (
    .in_sum           (r7_sum),
    .in_anchor        (r7_common),
    .in_negative_zero (r7_negative_zero),
    .out_bits         (finite_result)
  );

  assign result_d = (r7_special[`DP_SP_NAN] | r7_special[`DP_SP_INVALID]) ?
                    `DP_FP32_QNAN :
                    (r7_special[`DP_SP_POS_INF] | r7_special[`DP_SP_NEG_INF]) ?
                    (`DP_FP32_INF | {r7_special[`DP_SP_NEG_INF], {(`DP_FP32_W - 1){1'b0}}}) :
                    finite_result;

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s7_s8_valid (.clock(clock), .rst_n(rst_n), .in_d(r7_valid), .out_q(r8_valid));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s7_s8_last (.clock(clock), .rst_n(rst_n), .in_d(r7_last), .out_q(r8_last));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s7_s8_out_d (.clock(clock), .in_en(rst_n & r7_valid), .in_d(result_d), .out_q(out_d));

  // synthesis translate_off
  initial begin
    if ((K_FP16 != `DP_DEFAULT_K) || (GROUPS != (`DP_DEFAULT_K / `DP_GROUP_H)) ||
        ((QE_FRONTEND != 0) && (QE_FRONTEND != 1))) begin
      $display("FAIL: %s", "fixed lowp profile requires K16, four groups and E/QE selection");
      $finish;
    end
    if (GROUPS != (K_FP16 / `DP_GROUP_H)) begin
      $display("FAIL: %s", "GROUPS is derived");
      $finish;
    end
    if (LOCAL_W < `DP_MIN_LOCAL_W) begin
      $display("FAIL: %s", "LOCAL_W requires at least F25");
      $finish;
    end
    if ((GLOBAL_MAG_W < GROUP_MAG_W) || (GLOBAL_MAG_W < `DP_FP32_W)) begin
      $display("FAIL: %s", "global window is smaller than source");
      $finish;
    end
  end
  // synthesis translate_on

endmodule
