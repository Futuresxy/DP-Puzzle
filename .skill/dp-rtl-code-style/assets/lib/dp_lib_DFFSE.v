// Shared DFF primitive: synchronous active-low preset to 1 with write enable (WIDTH >= 1).
module dp_lib_DFFSE #(
  parameter integer WIDTH = 8
) (
  input  wire             clock,
  input  wire             rst_n,
  input  wire             in_en,
  input  wire [WIDTH-1:0] in_d,
  output wire [WIDTH-1:0] out_q
);

  dp_dff_sync_reset #(
    .WIDTH       (WIDTH),
    .RESET_VALUE ({WIDTH{1'b1}})
  ) ff_storage (
    .clock (clock),
    .rst_n (rst_n),
    .in_en (in_en),
    .in_d  (in_d),
    .out_q (out_q)
  );

endmodule
