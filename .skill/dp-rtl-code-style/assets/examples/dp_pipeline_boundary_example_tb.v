`timescale 1ns/1ps

// Self-checking unit testbench for dp_pipeline_boundary_example.
// Covers directed corners (zeros, full-scale, narrow/wide switching), bubbles,
// mid-flight synchronous reset cancellation, and seeded LFSR random traffic.
module dp_pipeline_boundary_example_tb;

  parameter integer DATA_W   = 28;
  parameter integer NARROW_W = 12;

  localparam integer LOWER_PAD_W = DATA_W - NARROW_W;
  localparam integer MAX_VECTORS = 512;

  // Clock and DUT interface signals
  reg                   clock;
  reg                   rst_n;
  reg                   in_valid;
  reg                   in_narrow_mode;
  reg  [DATA_W-1:0]     in_magnitude;
  reg                   in_sign;
  wire                  out_valid;
  wire                  out_narrow_mode;
  wire [DATA_W-1:0]     out_magnitude;
  wire                  out_sign;

  // Scoreboard and verification accounting
  integer               pending_req_id;
  integer               next_req_id;
  integer               cycle_count;
  integer               accepted_count;
  integer               checked_count;
  integer               cancelled_count;
  integer               sample_index;
  reg  [31:0]           random_state;

  // Expected golden storage indexed by request ID
  reg                   expected_narrow [0:MAX_VECTORS-1];
  reg  [DATA_W-1:0]     expected_mag    [0:MAX_VECTORS-1];
  reg                   expected_sign   [0:MAX_VECTORS-1];

  dp_pipeline_boundary_example #(
    .DATA_W   (DATA_W),
    .NARROW_W (NARROW_W)
  ) u_dut (
    .clock           (clock),
    .rst_n           (rst_n),
    .in_valid        (in_valid),
    .in_narrow_mode  (in_narrow_mode),
    .in_magnitude    (in_magnitude),
    .in_sign         (in_sign),
    .out_valid       (out_valid),
    .out_narrow_mode (out_narrow_mode),
    .out_magnitude   (out_magnitude),
    .out_sign        (out_sign)
  );

  always #5 clock = ~clock;

  // Deterministic 32-bit xorshift PRNG
  task random_step;
    begin
      random_state = random_state ^ (random_state << 13);
      random_state = random_state ^ (random_state >> 17);
      random_state = random_state ^ (random_state << 5);
    end
  endtask

  // Drive stimulus on negedge and verify scoreboard on posedge before NBA update
  task step_cycle(
    input reg              drive_rst_n,
    input reg              drive_valid,
    input reg              drive_narrow,
    input reg [DATA_W-1:0] drive_mag,
    input reg              drive_sign
  );
    begin
      @(negedge clock);
      rst_n          = drive_rst_n;
      in_valid       = drive_valid;
      in_narrow_mode = drive_narrow;
      in_magnitude   = drive_mag;
      in_sign        = drive_sign;

      if (drive_rst_n & drive_valid) begin
        expected_narrow[next_req_id] = drive_narrow;
        expected_sign[next_req_id]   = drive_sign;
        expected_mag[next_req_id]    = drive_narrow
          ? {drive_mag[DATA_W-1:LOWER_PAD_W], {LOWER_PAD_W{1'b0}}}
          : drive_mag;
      end

      @(posedge clock);
      if (~rst_n) begin
        if (pending_req_id >= 0) begin
          cancelled_count = cancelled_count + 1;
        end
        pending_req_id = -1;
      end else begin
        if (out_valid !== (pending_req_id >= 0)) begin
          $display("FAIL cycle=%0d: out_valid=%b expected=%b",
                   cycle_count, out_valid, (pending_req_id >= 0));
          $finish;
        end
        if (pending_req_id >= 0) begin
          if ((out_magnitude !== expected_mag[pending_req_id]) ||
              (out_sign !== expected_sign[pending_req_id]) ||
              (out_narrow_mode !== expected_narrow[pending_req_id])) begin
            $display("FAIL cycle=%0d req=%0d: got={narrow=%b, sign=%b, mag=%h} exp={narrow=%b, sign=%b, mag=%h}",
                     cycle_count, pending_req_id,
                     out_narrow_mode, out_sign, out_magnitude,
                     expected_narrow[pending_req_id], expected_sign[pending_req_id], expected_mag[pending_req_id]);
            $finish;
          end
          checked_count = checked_count + 1;
        end
        if (in_valid) begin
          pending_req_id = next_req_id;
          next_req_id    = next_req_id + 1;
          accepted_count = accepted_count + 1;
        end else begin
          pending_req_id = -1;
        end
      end
      cycle_count = cycle_count + 1;
    end
  endtask

  initial begin
    clock           = 1'b0;
    rst_n           = 1'b0;
    in_valid        = 1'b0;
    in_narrow_mode  = 1'b0;
    in_magnitude    = {DATA_W{1'b0}};
    in_sign         = 1'b0;
    pending_req_id  = -1;
    next_req_id     = 0;
    cycle_count     = 0;
    accepted_count  = 0;
    checked_count   = 0;
    cancelled_count = 0;
    random_state    = 32'h20261127;

    // 1. Initial synchronous reset
    step_cycle(1'b0, 1'b0, 1'b0, {DATA_W{1'b0}}, 1'b0);
    step_cycle(1'b0, 1'b1, 1'b0, {DATA_W{1'b1}}, 1'b1);

    // 2. Directed corners: wide all-ones -> narrow mode (verify lower-slice zero restoration)
    step_cycle(1'b1, 1'b1, 1'b0, {DATA_W{1'b1}}, 1'b0);
    step_cycle(1'b1, 1'b1, 1'b1, {DATA_W{1'b1}}, 1'b1);
    step_cycle(1'b1, 1'b0, 1'b0, 28'hbadbeef, 1'b0);
    step_cycle(1'b1, 1'b1, 1'b0, {DATA_W{1'b0}}, 1'b1);

    // 3. Mid-flight synchronous reset cancellation check
    step_cycle(1'b1, 1'b1, 1'b0, 28'h5a5a5a5, 1'b1);
    step_cycle(1'b0, 1'b0, 1'b0, 28'h0000000, 1'b0);
    step_cycle(1'b1, 1'b1, 1'b1, 28'hafebabe, 1'b0);

    // 4. Seeded pseudo-random traffic with dynamic mode switching, bubbles and resets
    for (sample_index = 0; sample_index < 256; sample_index = sample_index + 1) begin
      random_step;
      step_cycle(
        (sample_index % 47 != 23),
        (sample_index % 5 != 2),
        random_state[28],
        random_state[DATA_W-1:0],
        random_state[29]
      );
    end

    // 5. Drain pipeline and verify conservation invariant
    step_cycle(1'b1, 1'b0, 1'b0, {DATA_W{1'b0}}, 1'b0);
    step_cycle(1'b1, 1'b0, 1'b0, {DATA_W{1'b0}}, 1'b0);

    if ((accepted_count != checked_count + cancelled_count) || (checked_count == 0)) begin
      $display("FAIL conservation mismatch: accepted=%0d checked=%0d cancelled=%0d",
               accepted_count, checked_count, cancelled_count);
      $finish;
    end

    $display("PASS cycles=%0d accepted=%0d checked=%0d cancelled=%0d seed=20261127",
             cycle_count, accepted_count, checked_count, cancelled_count);
    $finish;
  end

endmodule
