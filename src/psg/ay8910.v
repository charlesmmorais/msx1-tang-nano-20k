// =============================================================================
// AY-3-8910 PSG for the MSX
//   I/O A0h (w): register address latch
//   I/O A1h (w): register data write
//   I/O A2h (r): register data read
//
// `ce` is the PSG master clock (~1.79 MHz).
//   tone   f = ce / (16 * TP)        noise shift = ce / (16 * NP)
//   envelope step = ce / (256 * EP), 16 steps per ramp
//
// On the MSX, port A (R14) is an input (joystick, keyboard layout, cassette
// in) and port B (R15) is an output (joystick select, KANA LED).
// =============================================================================
`default_nettype none

module ay8910 (
    input  wire       clk,
    input  wire       ce,
    input  wire       rst,
    input  wire       wr_addr,     // one-cycle strobes
    input  wire       wr_data,
    input  wire [7:0] d_in,
    output reg  [7:0] d_out,       // combinational read of the latched register
    input  wire [7:0] port_a_in,
    output wire [7:0] port_b_out,
    output reg  [9:0] audio        // sum of 3 channels, 0..765
);

    reg [7:0] regs [0:15];
    reg [3:0] addr;

    // Read-back masks: unused bits read as 0, like the real chip
    always @(*) begin
        case (addr)
            4'd1, 4'd3, 4'd5: d_out = {4'd0, regs[addr][3:0]};
            4'd6:             d_out = {3'd0, regs[6][4:0]};
            4'd8, 4'd9, 4'd10:d_out = {3'd0, regs[addr][4:0]};
            4'd13:            d_out = {4'd0, regs[13][3:0]};
            4'd14:            d_out = port_a_in;
            default:          d_out = regs[addr];
        endcase
    end

    assign port_b_out = regs[15];

    reg env_restart;
    integer k;
    always @(posedge clk) begin
        env_restart <= 1'b0;
        if (rst) begin
            for (k = 0; k < 16; k = k + 1) regs[k] <= 8'h00;
            regs[7] <= 8'hFF;              // all channels off
            addr    <= 4'd0;
        end else begin
            if (wr_addr) addr <= d_in[3:0];
            if (wr_data) begin
                regs[addr] <= d_in;
                if (addr == 4'd13) env_restart <= 1'b1;
            end
        end
    end

    wire [11:0] tp_a = {regs[1][3:0], regs[0]};
    wire [11:0] tp_b = {regs[3][3:0], regs[2]};
    wire [11:0] tp_c = {regs[5][3:0], regs[4]};
    wire [4:0]  np   = regs[6][4:0];
    wire [7:0]  mix  = regs[7];
    wire [15:0] ep   = {regs[12], regs[11]};
    wire        env_cont = regs[13][3];
    wire        env_att  = regs[13][2];
    wire        env_alt  = regs[13][1];
    wire        env_hold = regs[13][0];

    // Prescalers
    reg [2:0] pre8;
    reg       pre16;
    reg [3:0] pre256;
    wire tick8   = ce && (pre8 == 3'd7);
    wire tick16  = tick8 && pre16;
    wire tick256 = tick16 && (pre256 == 4'd15);

    reg [11:0] cnt_a, cnt_b, cnt_c;
    reg        sq_a, sq_b, sq_c;
    reg [4:0]  cnt_n;
    reg [16:0] lfsr;
    reg [15:0] cnt_e;
    reg [3:0]  e_step;
    reg        e_up, e_holding, e_zero;

    // A period of 0 behaves like 1
    function [11:0] per12(input [11:0] p); per12 = (p == 12'd0) ? 12'd1 : p; endfunction

    always @(posedge clk) begin
        if (rst) begin
            pre8 <= 3'd0; pre16 <= 1'b0; pre256 <= 4'd0;
            cnt_a <= 12'd0; cnt_b <= 12'd0; cnt_c <= 12'd0;
            sq_a <= 1'b0; sq_b <= 1'b0; sq_c <= 1'b0;
            cnt_n <= 5'd0; lfsr <= 17'h1;
            cnt_e <= 16'd0; e_step <= 4'd0; e_up <= 1'b0;
            e_holding <= 1'b1; e_zero <= 1'b1;
        end else begin
            if (ce) pre8 <= pre8 + 3'd1;
            if (tick8) pre16 <= ~pre16;
            if (tick16) pre256 <= pre256 + 4'd1;

            // Tone: toggle every TP ticks of ce/8 -> f = ce / (16*TP)
            if (tick8) begin
                if (cnt_a >= per12(tp_a) - 12'd1) begin cnt_a <= 12'd0; sq_a <= ~sq_a; end
                else cnt_a <= cnt_a + 12'd1;
                if (cnt_b >= per12(tp_b) - 12'd1) begin cnt_b <= 12'd0; sq_b <= ~sq_b; end
                else cnt_b <= cnt_b + 12'd1;
                if (cnt_c >= per12(tp_c) - 12'd1) begin cnt_c <= 12'd0; sq_c <= ~sq_c; end
                else cnt_c <= cnt_c + 12'd1;
            end

            // Noise: 17-bit LFSR (taps 0 and 3), shifted every NP ticks of ce/16
            if (tick16) begin
                if (cnt_n >= ((np == 5'd0) ? 5'd0 : np - 5'd1)) begin
                    cnt_n <= 5'd0;
                    lfsr  <= {lfsr[0] ^ lfsr[3], lfsr[16:1]};
                end else cnt_n <= cnt_n + 5'd1;
            end

            // Envelope
            if (env_restart) begin
                cnt_e     <= 16'd0;
                e_step    <= 4'd0;
                e_up      <= env_att;
                e_holding <= 1'b0;
                e_zero    <= 1'b0;
            end else if (tick256) begin
                if (cnt_e >= ((ep == 16'd0) ? 16'd0 : ep - 16'd1)) begin
                    cnt_e <= 16'd0;
                    if (!e_holding) begin
                        if (e_step == 4'd15) begin
                            if (!env_cont) begin
                                e_holding <= 1'b1;
                                e_zero    <= 1'b1;
                            end else if (env_hold) begin
                                e_holding <= 1'b1;
                                if (env_alt) e_up <= ~e_up;
                            end else begin
                                if (env_alt) e_up <= ~e_up;
                                e_step <= 4'd0;
                            end
                        end else
                            e_step <= e_step + 4'd1;
                    end
                end else cnt_e <= cnt_e + 16'd1;
            end
        end
    end

    wire [3:0] e_vol = e_zero ? 4'd0 : (e_up ? e_step : 4'd15 - e_step);

    // Logarithmic DAC (~3 dB per step), 8-bit
    function [7:0] dac(input [3:0] v);
        case (v)
            4'd0: dac = 8'd0;    4'd1: dac = 8'd2;    4'd2: dac = 8'd3;    4'd3: dac = 8'd4;
            4'd4: dac = 8'd6;    4'd5: dac = 8'd8;    4'd6: dac = 8'd11;   4'd7: dac = 8'd16;
            4'd8: dac = 8'd23;   4'd9: dac = 8'd32;   4'd10: dac = 8'd45;  4'd11: dac = 8'd64;
            4'd12: dac = 8'd90;  4'd13: dac = 8'd128; 4'd14: dac = 8'd180; default: dac = 8'd255;
        endcase
    endfunction

    // Mixer bits are active low (0 = enabled)
    wire on_a = (sq_a | mix[0]) & (lfsr[0] | mix[3]);
    wire on_b = (sq_b | mix[1]) & (lfsr[0] | mix[4]);
    wire on_c = (sq_c | mix[2]) & (lfsr[0] | mix[5]);

    wire [3:0] v_a = regs[8][4]  ? e_vol : regs[8][3:0];
    wire [3:0] v_b = regs[9][4]  ? e_vol : regs[9][3:0];
    wire [3:0] v_c = regs[10][4] ? e_vol : regs[10][3:0];

    always @(posedge clk) begin
        audio <= (on_a ? {2'b00, dac(v_a)} : 10'd0) +
                 (on_b ? {2'b00, dac(v_b)} : 10'd0) +
                 (on_c ? {2'b00, dac(v_c)} : 10'd0);
    end

endmodule
`default_nettype wire
