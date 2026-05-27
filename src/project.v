/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_fast_auth (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Tie off all bidirectional pins — not used
    assign uio = 8'bz;

    // Control signals decoded from ui_in
    wire        start    = ui_in[0];
    wire        soft_rst = ui_in[1];
    wire [1:0]  mode     = ui_in[3:2];
    wire [7:0]  data_in  = ui_in;

    wire rst_combined = rst_n & ~soft_rst;

    // Inputs
    wire auth_valid;
    wire auth_reject;
    wire busy;
    wire ecc_done;
    wire key_loaded;
    wire packet_ready;

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

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
