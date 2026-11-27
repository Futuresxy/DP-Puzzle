`include "dp_defs.vh"

// Fixed T8H16Q32E128 mixed-precision DP profile (4 base + 4 E groups, L=8, II=1).
module dp_top_t8h16q32e128 #(
  parameter integer K_FP16      = `DP_DEFAULT_K,
  parameter integer LOCAL_W     = `DP_DEFAULT_LOCAL_W,
  parameter integer GLOBAL_W    = `DP_DEFAULT_GLOBAL_W,
  parameter integer EXT_GROUPS  = 4,
  parameter integer EXT_QE      = 0,
  parameter integer BASE_GROUPS = `DP_DEFAULT_K / `DP_GROUP_H,
  parameter integer GROUPS      = BASE_GROUPS + EXT_GROUPS
) (
  // Clock, reset, and atomic input handshake
  input  wire                                   clock,
  input  wire                                   rst_n,
  input  wire                                   in_a_valid,
  input  wire                                   in_b_valid,
  input  wire                                   in_c_valid,
  output wire                                   out_a_ready,
  output wire                                   out_b_ready,
  output wire                                   out_c_ready,

  // Packed A/B operands, datatypes, block scales, and HiF4 shared exponents
  input  wire [GROUPS*`DP_LANES*`DP_LANE_W-1:0] in_a,
  input  wire [GROUPS*`DP_LANES*`DP_LANE_W-1:0] in_b,
  input  wire [                 `DP_TYPE_W-1:0] in_a_datatype,
  input  wire [                 `DP_TYPE_W-1:0] in_b_datatype,
  input  wire [        GROUPS*`DP_SCALE_W-1:0]  in_scale_a,
  input  wire [        GROUPS*`DP_SCALE_W-1:0]  in_scale_b,
  input  wire [           `DP_SCALE_TYPE_W-1:0] in_scale_a_datatype,
  input  wire [           `DP_SCALE_TYPE_W-1:0] in_scale_b_datatype,
  input  wire [                  GROUPS*4-1:0]  in_hif4_e1_a,
  input  wire [                  GROUPS*4-1:0]  in_hif4_e1_b,
  input  wire [                  GROUPS*2-1:0]  in_hif4_e2_a,
  input  wire [                  GROUPS*2-1:0]  in_hif4_e2_b,

  // Accumulator C input and transaction framing
  input  wire [                 `DP_FP32_W-1:0] in_c,
  input  wire                                   in_c_datatype,
  input  wire                                   in_last,

  // Stage 8 result outputs
  output wire                                   out_valid,
  output wire [                 `DP_FP32_W-1:0] out_d,
  output wire                                   out_d_datatype,
  output wire                                   out_last
);

  dp_top_mixed #(
    .K_FP16     (K_FP16),
    .LOCAL_W    (LOCAL_W),
    .GLOBAL_W   (GLOBAL_W),
    .EXT_GROUPS (EXT_GROUPS),
    .EXT_QE     (EXT_QE)
  ) u_core (
    .clock               (clock),
    .rst_n               (rst_n),
    .in_a_valid          (in_a_valid),
    .in_b_valid          (in_b_valid),
    .in_c_valid          (in_c_valid),
    .out_a_ready         (out_a_ready),
    .out_b_ready         (out_b_ready),
    .out_c_ready         (out_c_ready),
    .in_a                (in_a),
    .in_b                (in_b),
    .in_a_datatype       (in_a_datatype),
    .in_b_datatype       (in_b_datatype),
    .in_scale_a          (in_scale_a),
    .in_scale_b          (in_scale_b),
    .in_scale_a_datatype (in_scale_a_datatype),
    .in_scale_b_datatype (in_scale_b_datatype),
    .in_hif4_e1_a        (in_hif4_e1_a),
    .in_hif4_e1_b        (in_hif4_e1_b),
    .in_hif4_e2_a        (in_hif4_e2_a),
    .in_hif4_e2_b        (in_hif4_e2_b),
    .in_c                (in_c),
    .in_c_datatype       (in_c_datatype),
    .in_last             (in_last),
    .out_valid           (out_valid),
    .out_d               (out_d),
    .out_d_datatype      (out_d_datatype),
    .out_last            (out_last)
  );

  // synthesis translate_off
  initial begin
    if ((EXT_GROUPS != 4) || (EXT_QE != 0) || (GROUPS != 8) || (BASE_GROUPS != 4)) begin
      $display("ERROR: fixed profile mismatch");
      $finish;
    end
  end
  // synthesis translate_on

endmodule
