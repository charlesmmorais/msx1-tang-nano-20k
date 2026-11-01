// =============================================================================
// PS/2 keyboard receiver (scan code set 2)
// Frame: start(0), 8 data bits LSB first, odd parity, stop(1).
// Data is sampled on the falling edge of the (filtered) PS/2 clock.
// Outputs one `valid` pulse per make/break code, with E0/F0 prefixes folded
// into `extended` and `released`. A frame that stalls for ~1 ms is dropped,
// so a glitch can never leave the receiver out of step.
// =============================================================================
`default_nettype none

module ps2_decoder (
    input  wire       clk,          // 27 MHz
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_dat,
    output reg  [7:0] scan_code,
    output reg        extended,     // code was preceded by E0
    output reg        released,     // code was preceded by F0
    output reg        valid
);

    // Synchronize and debounce the PS/2 lines
    reg [2:0] clk_sync, dat_sync;
    reg [7:0] clk_filt;
    reg       clk_f, clk_f_prev;
    always @(posedge clk) begin
        clk_sync <= {clk_sync[1:0], ps2_clk};
        dat_sync <= {dat_sync[1:0], ps2_dat};
        clk_filt <= {clk_filt[6:0], clk_sync[2]};
        if (clk_filt == 8'hFF) clk_f <= 1'b1;
        else if (clk_filt == 8'h00) clk_f <= 1'b0;
        clk_f_prev <= clk_f;
    end
    wire fall = clk_f_prev & ~clk_f;
    wire dat  = dat_sync[2];

    reg [9:0]  shift;        // bits received so far (start .. parity)
    reg [3:0]  nbits;
    reg [14:0] idle;         // ~1.2 ms at 27 MHz
    reg        pend_e0, pend_f0;

    always @(posedge clk) begin
        valid <= 1'b0;
        if (rst) begin
            nbits   <= 4'd0;
            idle    <= 15'd0;
            pend_e0 <= 1'b0;
            pend_f0 <= 1'b0;
            scan_code <= 8'h00;
            extended  <= 1'b0;
            released  <= 1'b0;
        end else begin
            if (fall) begin
                idle <= 15'd0;
                if (nbits == 4'd10) begin
                    // 11th bit is the stop bit; shift = {parity, d7..d0, start}
                    nbits <= 4'd0;
                    if (!shift[0] && dat && (^shift[9:1])) begin
                        if (shift[8:1] == 8'hE0)
                            pend_e0 <= 1'b1;
                        else if (shift[8:1] == 8'hF0)
                            pend_f0 <= 1'b1;
                        else begin
                            scan_code <= shift[8:1];
                            extended  <= pend_e0;
                            released  <= pend_f0;
                            valid     <= 1'b1;
                            pend_e0   <= 1'b0;
                            pend_f0   <= 1'b0;
                        end
                    end
                end else begin
                    shift <= {dat, shift[9:1]};
                    nbits <= nbits + 4'd1;
                end
            end else if (nbits != 4'd0) begin
                if (idle == 15'h7FFF) nbits <= 4'd0;
                else idle <= idle + 15'd1;
            end
        end
    end

endmodule
`default_nettype wire
