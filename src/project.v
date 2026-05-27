`default_nettype none

module tt_um_fast_auth (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Tie off bidirectional — not used
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Control signals from ui_in
    wire        start    = ui_in[0];
    wire        soft_rst = ui_in[1];
    wire [1:0]  mode     = ui_in[3:2];
    wire [7:0]  data_in  = ui_in;
    wire        rst_combined = rst_n & ~soft_rst;

    // Internal wires
    wire auth_valid, auth_reject, busy, ecc_done, key_loaded, packet_ready;

    // Outputs
    assign uo_out[0] = auth_valid;
    assign uo_out[1] = auth_reject;
    assign uo_out[2] = busy;
    assign uo_out[3] = ecc_done;
    assign uo_out[4] = key_loaded;
    assign uo_out[5] = packet_ready;
    assign uo_out[7:6] = 2'b00;

    key_manager u_key_mgr (
        .clk        (clk),
        .rst_n      (rst_combined),
        .mode       (mode),
        .start      (start),
        .data_in    (data_in),
        .key_loaded (key_loaded)
    );

    auth_coprocessor u_auth_cop (
        .clk          (clk),
        .rst_n        (rst_combined),
        .start        (start),
        .mode         (mode),
        .data_in      (data_in),
        .key_loaded   (key_loaded),
        .packet_ready (packet_ready),
        .busy         (busy),
        .ecc_done     (ecc_done),
        .auth_valid   (auth_valid),
        .auth_reject  (auth_reject)
    );

endmodule
