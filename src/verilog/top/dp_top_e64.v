`include "dp_defs.vh"

// Standalone 4-group E64 low-precision DP wrapper (L=8, II=1); shared core is dp_top_lowp.
module dp_top_e64 #(
  parameter integer K_FP16   = `DP_DEFAULT_K,
  parameter integer LOCAL_W  = `DP_DEFAULT_LOCAL_W,
  parameter integer GLOBAL_W = `DP_DEFAULT_GLOBAL_W,
  parameter integer GROUPS   = `DP_DEFAULT_K / `DP_GROUP_H
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

  dp_top_lowp #(
    .QE_FRONTEND (0),
    .K_FP16      (K_FP16),
    .LOCAL_W     (LOCAL_W),
    .GLOBAL_W    (GLOBAL_W),
    .GROUPS      (GROUPS)
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

endmodule
