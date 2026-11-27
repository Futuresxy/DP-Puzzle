// Multi-precision S2 -> S3 pipeline boundary reference template.
// Demonstrates Vortex-TCU-style grouped comments, vertical column alignment,
// precision-gated split payload registers (write-gating + read zero-restoration),
// and synchronous active-low reset control (1-cycle latency, II=1, no backpressure).
//
// Fixed-point coordinates (S=0 unsigned magnitude, sign carried separately):
//   Mode                  | Active Bits | Lower Pad Bits | Output Container
//   --------------------- | ----------- | -------------- | ----------------
//   in_narrow_mode = 1'b0 | DATA_W      | 0              | S=1(sep), DATA_W
//   in_narrow_mode = 1'b1 | NARROW_W    | DATA_W-NARROW_W| S=1(sep), DATA_W (low zeros)
module dp_pipeline_boundary_example #(
  parameter integer DATA_W   = 28,
  parameter integer NARROW_W = 12   // upper active bits retained in narrow precision mode
) (
  input  wire                clock,
  input  wire                rst_n,

  // S2 input request and payload
  input  wire                in_valid,
  input  wire                in_narrow_mode,
  input  wire [DATA_W-1:0]   in_magnitude,
  input  wire                in_sign,

  // S3 registered output
  output wire                out_valid,
  output wire                out_narrow_mode,
  output wire [DATA_W-1:0]   out_magnitude,
  output wire                out_sign
);

  localparam integer LOWER_PAD_W = DATA_W - NARROW_W;

  // ========================================================================
  // Stage 2 -> Stage 3: Precision-Gated Capture & Structural Zero Restoration
  // ========================================================================

  // Control and write-enable signals
  wire                  r3_valid;
  wire                  r3_narrow_mode;
  wire                  r3_sign;
  wire                  payload_en;
  wire                  lower_slice_en;

  // Split magnitude slices: upper slice always updates on valid, lower slice
  // is clock-gated in narrow mode and restored to zero at the S3 read boundary.
  wire [NARROW_W-1:0]    upper_magnitude_d;
  wire [LOWER_PAD_W-1:0] lower_magnitude_d;
  wire [NARROW_W-1:0]    r3_upper_magnitude;
  wire [LOWER_PAD_W-1:0] r3_lower_magnitude;

  assign payload_en        = rst_n & in_valid;
  assign lower_slice_en    = payload_en & (~in_narrow_mode);
  assign upper_magnitude_d = in_magnitude[DATA_W-1:LOWER_PAD_W];
  assign lower_magnitude_d = in_magnitude[LOWER_PAD_W-1:0];

  // S2 -> S3 control and metadata registers
  dp_lib_DFFRU #(.WIDTH(1))
  ff_s2_s3_valid (.clock(clock), .rst_n(rst_n), .in_d(in_valid), .out_q(r3_valid));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_narrow_mode (.clock(clock), .in_en(payload_en), .in_d(in_narrow_mode), .out_q(r3_narrow_mode));
  dp_lib_DFFE #(.WIDTH(1))
  ff_s2_s3_sign (.clock(clock), .in_en(payload_en), .in_d(in_sign), .out_q(r3_sign));

  // S2 -> S3 precision-gated datapath registers
  dp_lib_DFFE #(.WIDTH(NARROW_W))
  ff_s2_s3_upper_mag (.clock(clock), .in_en(payload_en), .in_d(upper_magnitude_d), .out_q(r3_upper_magnitude));
  dp_lib_DFFE #(.WIDTH(LOWER_PAD_W))
  ff_s2_s3_lower_mag (.clock(clock), .in_en(lower_slice_en), .in_d(lower_magnitude_d), .out_q(r3_lower_magnitude));

  // Output assignment with destination-stage structural zero restoration
  assign out_valid       = r3_valid;
  assign out_narrow_mode = r3_narrow_mode;
  assign out_sign        = r3_sign;
  assign out_magnitude   = {
    r3_upper_magnitude,
    (r3_narrow_mode ? {LOWER_PAD_W{1'b0}} : r3_lower_magnitude)
  };

  // synthesis translate_off
  initial begin
    if ((DATA_W < 2) || (NARROW_W < 1) || (NARROW_W >= DATA_W)) begin
      $display("FAIL [%m]: requires 1 <= NARROW_W (%0d) < DATA_W (%0d)", NARROW_W, DATA_W);
      $finish;
    end
  end
  // synthesis translate_on

endmodule
