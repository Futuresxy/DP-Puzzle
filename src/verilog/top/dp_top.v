`include "dp_defs.vh"

// Baseline multi-precision DP top (T8/H16/Q32/E64 at K_FP16 = 16, v1.8 contract).
// Fixed latency L=8, II=1, atomic A/B/C input handshake, no output backpressure.
// S7 final SOP format (N = GROUPS + 1, L = ceil(log2(N))):
// - All floating modes: S1 I(1+L) F(GLOBAL_W-2)
// - INT8 + INT32:       S1 I(32+L) F(GLOBAL_W-33)
module dp_top #(
  parameter integer K_FP16   = `DP_DEFAULT_K,
  parameter integer LOCAL_W  = `DP_DEFAULT_LOCAL_W,
  parameter integer GLOBAL_W = `DP_DEFAULT_GLOBAL_W,
  parameter integer GROUPS   = K_FP16 / `DP_GROUP_H
) (
  // Clock, reset, and atomic input handshake
  input  wire                               clock,
  input  wire                               rst_n,
  input  wire                               in_a_valid,
  input  wire                               in_b_valid,
  input  wire                               in_c_valid,
  output wire                               out_a_ready,
  output wire                               out_b_ready,
  output wire                               out_c_ready,

  // Packed A/B operands, datatypes, block scales, and HiF4 shared exponents
  input  wire [     K_FP16*`DP_HALF_W-1:0]  in_a,
  input  wire [     K_FP16*`DP_HALF_W-1:0]  in_b,
  input  wire [             `DP_TYPE_W-1:0] in_a_datatype,
  input  wire [             `DP_TYPE_W-1:0] in_b_datatype,
  input  wire [    GROUPS*`DP_SCALE_W-1:0]  in_scale_a,
  input  wire [    GROUPS*`DP_SCALE_W-1:0]  in_scale_b,
  input  wire [       `DP_SCALE_TYPE_W-1:0] in_scale_a_datatype,
  input  wire [       `DP_SCALE_TYPE_W-1:0] in_scale_b_datatype,
  input  wire [              GROUPS*4-1:0]  in_hif4_e1_a,
  input  wire [              GROUPS*4-1:0]  in_hif4_e1_b,
  input  wire [              GROUPS*2-1:0]  in_hif4_e2_a,
  input  wire [              GROUPS*2-1:0]  in_hif4_e2_b,

  // Accumulator C input and transaction framing
  input  wire [             `DP_FP32_W-1:0] in_c,
  input  wire                               in_c_datatype,
  input  wire                               in_last,

  // Stage 8 result outputs
  output wire                               out_valid,
  output wire [             `DP_FP32_W-1:0] out_d,
  output wire                               out_d_datatype,
  output wire                               out_last
);

  `include "dp_functions.vh"

  localparam integer GROUP_W      = LOCAL_W + 1 + $clog2(`DP_Q_LANES) + $clog2(`DP_LANES);
  localparam integer GROUP_MAG_W  = GROUP_W - 1;
  localparam integer GLOBAL_MAG_W = GLOBAL_W - 1;
  localparam integer N            = GROUPS + 1;
  localparam integer SUM_W        = GLOBAL_W + $clog2(N);
  localparam integer ANCHOR_W     = anchor_width(GLOBAL_MAG_W);
  localparam integer Z_W          = $clog2(GLOBAL_MAG_W + 1);
  localparam integer INT_GROUP_F  = GROUP_W - 1 - `DP_INT_PRODUCT_W - $clog2(`DP_Q_LANES);
  localparam integer INT_GLOBAL_F = GLOBAL_MAG_W - `DP_FP32_W;

  // ==== Input Protocol & Atomic Handshake ====
  wire tuple_legal;
  wire req_fire;

  assign tuple_legal = (in_a_datatype <= `DP_DT_INT8) &
                       (in_a_datatype == in_b_datatype) &
                       (in_c_datatype == (in_a_datatype == `DP_DT_INT8)) &
                       (in_scale_a_datatype == scale_type(in_a_datatype)) &
                       (in_scale_b_datatype == scale_type(in_a_datatype));
  assign req_fire    = rst_n & in_a_valid & in_b_valid & in_c_valid & tuple_legal;

  assign out_a_ready = req_fire;
  assign out_b_ready = req_fire;
  assign out_c_ready = req_fire;

  // Stage valid, last, c_type, and raw C pipeline tracking (valid_q[0..7] probed by testbench)
  wire [`DP_BASE_LATENCY-1:0] valid_q;
  wire [`DP_BASE_LATENCY-1:0] last_q;
  wire [`DP_BASE_LATENCY-1:0] c_type_q;
  wire [      `DP_FP32_W-1:0] c_raw_q [0:3];

  assign out_valid      = valid_q[`DP_BASE_LATENCY-1];
  assign out_last       = last_q[`DP_BASE_LATENCY-1] & out_valid;
  assign out_d_datatype = c_type_q[`DP_BASE_LATENCY-1];

  // ==== Stages 1-5: Multi-Precision Group Frontends and Raw C Pipeline ====
  wire [       N*GLOBAL_MAG_W-1:0] source_magnitude;
  wire [           N*ANCHOR_W-1:0] source_anchor;
  wire [           N*ANCHOR_W-1:0] source_compare_exp;
  wire [                N*Z_W-1:0] source_z;
  wire [                    N-1:0] source_negative;
  wire [     N*`DP_SPECIAL_W-1:0]  source_special;

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

      dp_group #(
        .LOCAL_W      (LOCAL_W),
        .BASELINE_V18 (1),
        .ANCHOR_W     (ANCHOR_W)
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

      assign source_magnitude[group_index*GLOBAL_MAG_W+:GLOBAL_MAG_W] = c_type_q[4] ?
        (({{(GLOBAL_MAG_W - GROUP_MAG_W){1'b0}}, group_align_magnitude} >> INT_GROUP_F) << INT_GLOBAL_F) :
        {group_align_magnitude, {(GLOBAL_MAG_W - GROUP_MAG_W){1'b0}}};
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
  ff_s0_s1_valid (.clock(clock), .rst_n(rst_n), .in_d(req_fire), .out_q(valid_q[0]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s0_s1_last (.clock(clock), .rst_n(rst_n), .in_d(req_fire & in_last), .out_q(last_q[0]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s0_s1_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(req_fire), .in_d(in_c_datatype), .out_q(c_type_q[0]));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s0_s1_c_raw (.clock(clock), .in_en(rst_n & req_fire), .in_d(in_c), .out_q(c_raw_q[0]));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[0]), .out_q(valid_q[1]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s1_s2_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[0]), .out_q(last_q[1]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s1_s2_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[0]), .in_d(c_type_q[0]), .out_q(c_type_q[1]));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s1_s2_c_raw (.clock(clock), .in_en(rst_n & valid_q[0]), .in_d(c_raw_q[0]), .out_q(c_raw_q[1]));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[1]), .out_q(valid_q[2]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[1]), .out_q(last_q[2]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s2_s3_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[1]), .in_d(c_type_q[1]), .out_q(c_type_q[2]));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s2_s3_c_raw (.clock(clock), .in_en(rst_n & valid_q[1]), .in_d(c_raw_q[1]), .out_q(c_raw_q[2]));

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[2]), .out_q(valid_q[3]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s3_s4_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[2]), .out_q(last_q[3]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s3_s4_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[2]), .in_d(c_type_q[2]), .out_q(c_type_q[3]));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s3_s4_c_raw (.clock(clock), .in_en(rst_n & valid_q[2]), .in_d(c_raw_q[2]), .out_q(c_raw_q[3]));

  // Stage 5 accumulator C unpack and token registers (no LZD on C in v1.8)
  wire                              c_negative_d;
  wire [            `DP_FP32_W-1:0] c_magnitude_d;
  wire signed [       ANCHOR_W-1:0] c_anchor_d;
  wire [$clog2(`DP_FP32_W+1)-1:0]   c_z_d;
  wire [         `DP_SPECIAL_W-1:0] c_special_d;

  wire                              c_negative_q;
  wire [            `DP_FP32_W-1:0] c_magnitude_q;
  wire signed [       ANCHOR_W-1:0] c_anchor_q;
  wire [$clog2(`DP_FP32_W+1)-1:0]   c_z_q;
  wire [         `DP_SPECIAL_W-1:0] c_special_q;

  dp_c_unpack #(
    .DETECT_LEADING_ZERO (0),
    .ANCHOR_W            (ANCHOR_W)
  ) u_c_unpack (
    .in_data       (c_raw_q[3]),
    .in_datatype   (c_type_q[3]),
    .out_negative  (c_negative_d),
    .out_magnitude (c_magnitude_d),
    .out_anchor    (c_anchor_d),
    .out_z         (c_z_d),
    .out_special   (c_special_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[3]), .out_q(valid_q[4]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s4_s5_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[3]), .out_q(last_q[4]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s4_s5_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[3]), .in_d(c_type_q[3]), .out_q(c_type_q[4]));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s4_s5_c_negative (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(c_negative_d), .out_q(c_negative_q));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s4_s5_c_magnitude (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(c_magnitude_d), .out_q(c_magnitude_q));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s4_s5_c_anchor (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(c_anchor_d), .out_q(c_anchor_q));
  assign c_z_q = {$clog2(`DP_FP32_W+1){1'b0}};
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s4_s5_c_special (.clock(clock), .in_en(rst_n & valid_q[3]), .in_d(c_special_d), .out_q(c_special_q));

  assign source_magnitude[GROUPS*GLOBAL_MAG_W+:GLOBAL_MAG_W] = {
    c_magnitude_q,
    {(GLOBAL_MAG_W - `DP_FP32_W){1'b0}}
  };
  assign source_negative[GROUPS]                             = c_negative_q;
  assign source_anchor[GROUPS*ANCHOR_W+:ANCHOR_W]            = c_anchor_q;
  assign source_compare_exp[GROUPS*ANCHOR_W+:ANCHOR_W]       = c_anchor_q;
  assign source_z[GROUPS*Z_W+:Z_W]                           = c_z_q;
  assign source_special[GROUPS*`DP_SPECIAL_W+:`DP_SPECIAL_W] = c_special_q;

  // ==== Stage 6: Global Alignment ====
  wire [            N*GLOBAL_W-1:0] leaves_d;
  wire [            N*GLOBAL_W-1:0] leaves_q;
  wire signed [       ANCHOR_W-1:0] common_d;
  wire signed [       ANCHOR_W-1:0] common_s6_q;
  wire                              negative_zero_d;
  wire                              negative_zero_s6_q;
  wire [         `DP_SPECIAL_W-1:0] special_d;
  wire [         `DP_SPECIAL_W-1:0] special_s6_q;

  dp_global_align #(
    .PRECOMPUTED_EXPONENT (1),
    .N                    (N),
    .MAG_W                (GLOBAL_MAG_W),
    .ANCHOR_W             (ANCHOR_W)
  ) u_global_alignment (
    .in_integer        (c_type_q[4]),
    .in_enable         (valid_q[4]),
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
  ff_s5_s6_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[4]), .out_q(valid_q[5]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s5_s6_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[4]), .out_q(last_q[5]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s5_s6_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[4]), .in_d(c_type_q[4]), .out_q(c_type_q[5]));
  dp_lib_DFFE #(.WIDTH(N * GLOBAL_W))
  ff_s5_s6_leaves (.clock(clock), .in_en(rst_n & valid_q[4]), .in_d(leaves_d), .out_q(leaves_q));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s5_s6_common_s6 (.clock(clock), .in_en(rst_n & valid_q[4]), .in_d(common_d), .out_q(common_s6_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s5_s6_negative_zero_s6 (.clock(clock), .in_en(rst_n & valid_q[4]), .in_d(negative_zero_d), .out_q(negative_zero_s6_q));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s5_s6_special_s6 (.clock(clock), .in_en(rst_n & valid_q[4]), .in_d(special_d), .out_q(special_s6_q));

  // ==== Stage 7: Final Carry-Save SOP Reduction ====
  wire signed [    SUM_W-1:0] sum_d;
  wire signed [    SUM_W-1:0] sum_q;
  wire signed [ ANCHOR_W-1:0] common_s7_q;
  wire                        negative_zero_s7_q;
  wire [   `DP_SPECIAL_W-1:0] special_s7_q;

  dp_final_csa_sum #(
    .N (N),
    .W (GLOBAL_W)
  ) u_final_sop_tree (
    .in_values (leaves_q),
    .out_sum   (sum_d)
  );

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s6_s7_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[5]), .out_q(valid_q[6]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s6_s7_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[5]), .out_q(last_q[6]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s6_s7_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[5]), .in_d(c_type_q[5]), .out_q(c_type_q[6]));
  dp_lib_DFFE #(.WIDTH(SUM_W))
  ff_s6_s7_sum (.clock(clock), .in_en(rst_n & valid_q[5]), .in_d(sum_d), .out_q(sum_q));
  dp_lib_DFFE #(.WIDTH(ANCHOR_W))
  ff_s6_s7_common_s7 (.clock(clock), .in_en(rst_n & valid_q[5]), .in_d(common_s6_q), .out_q(common_s7_q));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s6_s7_negative_zero_s7 (.clock(clock), .in_en(rst_n & valid_q[5]), .in_d(negative_zero_s6_q), .out_q(negative_zero_s7_q));
  dp_lib_DFFE #(.WIDTH(`DP_SPECIAL_W))
  ff_s6_s7_special_s7 (.clock(clock), .in_en(rst_n & valid_q[5]), .in_d(special_s6_q), .out_q(special_s7_q));

  // ==== Stage 8: FP32 RNE / INT32 Output Selection ====
  wire signed [      SUM_W-1:0] float_sum;
  wire [        `DP_FP32_W-1:0] finite_result;
  wire [        `DP_FP32_W-1:0] result_s8_d;

  assign float_sum = c_type_q[6] ? {SUM_W{1'b0}} : sum_q;

  dp_fp32_round #(
    .SUM_W        (SUM_W),
    .ANCHOR_W     (ANCHOR_W),
    .GLOBAL_MAG_W (GLOBAL_MAG_W)
  ) u_fp32_output (
    .in_sum           (float_sum),
    .in_anchor        (common_s7_q),
    .in_negative_zero (negative_zero_s7_q),
    .out_bits         (finite_result)
  );

  assign result_s8_d = c_type_q[6] ?
                       sum_q[INT_GLOBAL_F+:`DP_FP32_W] :
                       (special_s7_q[`DP_SP_NAN] | special_s7_q[`DP_SP_INVALID]) ?
                       `DP_FP32_QNAN :
                       (special_s7_q[`DP_SP_POS_INF] | special_s7_q[`DP_SP_NEG_INF]) ?
                       (`DP_FP32_INF | {special_s7_q[`DP_SP_NEG_INF], {(`DP_FP32_W - 1){1'b0}}}) :
                       finite_result;

  dp_lib_DFFRU #(.WIDTH(1))
  ff_s7_s8_valid (.clock(clock), .rst_n(rst_n), .in_d(valid_q[6]), .out_q(valid_q[7]));
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s7_s8_last (.clock(clock), .rst_n(rst_n), .in_d(last_q[6]), .out_q(last_q[7]));
  dp_lib_DFFRE #(.WIDTH(1))
  ff_s7_s8_c_datatype (.clock(clock), .rst_n(rst_n), .in_en(valid_q[6]), .in_d(c_type_q[6]), .out_q(c_type_q[7]));
  dp_lib_DFFE #(.WIDTH(`DP_FP32_W))
  ff_s7_s8_out_d (.clock(clock), .in_en(rst_n & valid_q[6]), .in_d(result_s8_d), .out_q(out_d));

  // synthesis translate_off
  initial begin
    if ((K_FP16 != 4) && (K_FP16 != 8) && (K_FP16 != 16)) begin
      $display("FAIL: %s", "K_FP16 must be 4, 8 or 16");
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
