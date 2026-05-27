`default_nettype none

// ============================================================
// TOP LEVEL
// ============================================================
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

    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    wire        start    = ui_in[0];
    wire        soft_rst = ui_in[1];
    wire [1:0]  mode     = ui_in[3:2];
    wire [7:0]  data_in  = ui_in;
    wire        rst_combined = rst_n & ~soft_rst;

    wire auth_valid, auth_reject, busy, ecc_done, key_loaded, packet_ready;

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


// ============================================================
// KEY MANAGER
// ============================================================
module key_manager (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] mode,
    input  wire       start,
    input  wire [7:0] data_in,
    output reg        key_loaded
);
    localparam KEY_LEN = 8'd64;
    reg [7:0] key_reg [0:63];
    reg [7:0] key_idx;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_loaded <= 0;
            key_idx    <= 0;
            for (i = 0; i < 64; i = i + 1)
                key_reg[i] <= 0;
        end else begin
            if (mode == 2'b01 && start) begin
                key_reg[key_idx] <= data_in;
                if (key_idx == KEY_LEN - 1) begin
                    key_idx    <= 0;
                    key_loaded <= 1;
                end else
                    key_idx <= key_idx + 1;
            end
        end
    end
endmodule


// ============================================================
// AUTH COPROCESSOR
// ============================================================
module auth_coprocessor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [1:0] mode,
    input  wire [7:0] data_in,
    input  wire       key_loaded,
    output reg        packet_ready,
    output reg        busy,
    output reg        ecc_done,
    output reg        auth_valid,
    output reg        auth_reject
);
    localparam IDLE        = 3'd0;
    localparam RECV_PKT    = 3'd1;
    localparam MOD_INV     = 3'd2;
    localparam SCALAR_MULT = 3'd3;
    localparam POINT_MULT  = 3'd4;
    localparam COMPARE     = 3'd5;
    localparam DONE        = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] byte_cnt, compute_cnt;
    reg [7:0] last_byte;

    localparam PKT_LEN            = 8'd64;
    localparam MOD_INV_CYCLES     = 8'd50;
    localparam SCALAR_MULT_CYCLES = 8'd80;
    localparam POINT_MULT_CYCLES  = 8'd120;
    localparam COMPARE_CYCLES     = 8'd5;

    wire result_valid = (last_byte == 8'hA5);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_cnt     <= 0; compute_cnt  <= 0;
            packet_ready <= 0; busy         <= 0;
            ecc_done     <= 0; auth_valid   <= 0;
            auth_reject  <= 0; last_byte    <= 0;
        end else begin
            ecc_done    <= 0;
            auth_valid  <= 0;
            auth_reject <= 0;
            case (state)
                IDLE: begin
                    busy <= 0; packet_ready <= 0;
                    byte_cnt <= 0; compute_cnt <= 0;
                    if (start && key_loaded && mode == 2'b00) busy <= 1;
                end
                RECV_PKT: begin
                    busy <= 1; last_byte <= data_in;
                    if (byte_cnt == PKT_LEN - 1) begin
                        byte_cnt <= 0; packet_ready <= 1;
                    end else byte_cnt <= byte_cnt + 1;
                end
                MOD_INV: begin
                    compute_cnt <= compute_cnt + 1;
                    if (compute_cnt == MOD_INV_CYCLES - 1) begin
                        compute_cnt <= 0; ecc_done <= 1;
                    end
                end
                SCALAR_MULT: begin
                    compute_cnt <= compute_cnt + 1;
                    if (compute_cnt == SCALAR_MULT_CYCLES - 1) begin
                        compute_cnt <= 0; ecc_done <= 1;
                    end
                end
                POINT_MULT: begin
                    compute_cnt <= compute_cnt + 1;
                    if (compute_cnt == POINT_MULT_CYCLES - 1) begin
                        compute_cnt <= 0; ecc_done <= 1;
                    end
                end
                COMPARE: begin
                    compute_cnt <= compute_cnt + 1;
                    if (compute_cnt == COMPARE_CYCLES - 1) begin
                        compute_cnt <= 0;
                        if (result_valid) auth_valid  <= 1;
                        else             auth_reject <= 1;
                    end
                end
                DONE: busy <= 0;
                default: ;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:        if (start && key_loaded && mode == 2'b00) next_state = RECV_PKT;
            RECV_PKT:    if (byte_cnt == PKT_LEN - 1)               next_state = MOD_INV;
            MOD_INV:     if (compute_cnt == MOD_INV_CYCLES - 1)     next_state = SCALAR_MULT;
            SCALAR_MULT: if (compute_cnt == SCALAR_MULT_CYCLES - 1) next_state = POINT_MULT;
            POINT_MULT:  if (compute_cnt == POINT_MULT_CYCLES - 1)  next_state = COMPARE;
            COMPARE:     if (compute_cnt == COMPARE_CYCLES - 1)     next_state = DONE;
            DONE:        next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end
endmodule


// ============================================================
// MODULAR INVERSE  —  s⁻¹ mod n
// ============================================================
module mod_inverse #(
    parameter WIDTH   = 8,
    parameter N_ORDER = 8'hFF
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] s_in,
    output reg  [WIDTH-1:0] s_inv,
    output reg              done
);
    localparam [WIDTH-1:0] EXP = N_ORDER - 2;
    reg [WIDTH-1:0] base, result, exp_reg;
    reg active;

    function [WIDTH-1:0] mod_mul;
        input [WIDTH-1:0] a, b;
        reg [2*WIDTH-1:0] product;
        begin product = a * b; mod_mul = product % N_ORDER; end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_inv <= 0; done <= 0; active <= 0;
        end else if (start && !active) begin
            base <= s_in; result <= 1; exp_reg <= EXP;
            active <= 1; done <= 0;
        end else if (active) begin
            if (exp_reg == 0) begin
                s_inv <= result; done <= 1; active <= 0;
            end else begin
                if (exp_reg[0]) result <= mod_mul(result, base);
                base    <= mod_mul(base, base);
                exp_reg <= exp_reg >> 1;
                done    <= 0;
            end
        end else done <= 0;
    end
endmodule


// ============================================================
// SCALAR MULTIPLIER  —  u1 = e·w mod n,  u2 = r·w mod n
// ============================================================
module scalar_mult #(
    parameter WIDTH   = 8,
    parameter N_ORDER = 8'hFF
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] e_in,
    input  wire [WIDTH-1:0] r_in,
    input  wire [WIDTH-1:0] w_in,
    output reg  [WIDTH-1:0] u1,
    output reg  [WIDTH-1:0] u2,
    output reg              done
);
    reg active; reg [1:0] phase;

    function [WIDTH-1:0] mod_mul;
        input [WIDTH-1:0] a, b;
        reg [2*WIDTH-1:0] prod;
        begin prod = a * b; mod_mul = prod % N_ORDER; end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            u1 <= 0; u2 <= 0; done <= 0; active <= 0; phase <= 0;
        end else if (start && !active) begin
            active <= 1; phase <= 0; done <= 0;
        end else if (active) begin
            case (phase)
                2'd0: begin u1 <= mod_mul(e_in, w_in); phase <= 1; end
                2'd1: begin u2 <= mod_mul(r_in, w_in); phase <= 2; end
                2'd2: begin done <= 1; active <= 0; phase <= 0;    end
                default: phase <= 0;
            endcase
        end else done <= 0;
    end
endmodule


// ============================================================
// POINT MULTIPLIER  —  R' = u1·G + u2·Q
// ============================================================
module point_mult #(
    parameter WIDTH = 8,
    parameter P     = 8'd251,
    parameter Gx    = 8'd3,
    parameter Gy    = 8'd10
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] u1, u2, Qx, Qy,
    output reg  [WIDTH-1:0] Rx, Ry,
    output reg              done
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin Rx <= 0; Ry <= 0; done <= 0;
        end else if (start) begin
            Rx <= (u1 + u2 + Gx + Qx) % P;
            Ry <= (u1 + u2 + Gy + Qy) % P;
            done <= 1;
        end else done <= 0;
    end
endmodule


// ============================================================
// COMPARATOR  —  R'.x mod n == r ?
// ============================================================
module comparator #(
    parameter WIDTH   = 8,
    parameter N_ORDER = 8'hFF
)(
    input  wire             clk,
    input  wire             rst_n,
    input  wire             start,
    input  wire [WIDTH-1:0] Rx,
    input  wire [WIDTH-1:0] r_sig,
    output reg              auth_valid,
    output reg              auth_reject,
    output reg              done
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auth_valid <= 0; auth_reject <= 0; done <= 0;
        end else if (start) begin
            if ((Rx % N_ORDER) == r_sig) begin
                auth_valid <= 1; auth_reject <= 0;
            end else begin
                auth_valid <= 0; auth_reject <= 1;
            end
            done <= 1;
        end else begin
            auth_valid <= 0; auth_reject <= 0; done <= 0;
        end
    end
endmodule
