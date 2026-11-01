// =============================================================================
// Raw SPI port for the microSD slot (SPI mode 0).
// The card protocol (CMD0/CMD8/ACMD41/CMD17...) is left to MSX software.
//
//   port base+0  W : send a byte (starts an 8-bit transfer)
//                R : last byte received
//   port base+1  W : bit 0 = 1 selects the card (CS low)
//                    bit 1 = 1 fast clock (6.75 MHz), 0 = slow (~200 kHz, init)
//                R : bit 0 = busy, bit 1 = fast, bit 2 = card selected
// =============================================================================
`default_nettype none

module sd_spi (
    input  wire       clk,          // 27 MHz
    input  wire       rst,
    input  wire       a0,
    input  wire [7:0] d_in,
    output wire [7:0] d_out,
    input  wire       wr,           // one-cycle strobes
    output reg        sd_clk,
    output wire       sd_mosi,
    input  wire       sd_miso,
    output wire       sd_cs_n
);

    reg       sel, fast, busy;
    reg [7:0] tx, rx;
    reg [3:0] bits;
    reg [6:0] div;

    wire [6:0] half = fast ? 7'd1 : 7'd67;   // 27 MHz / (2*(half+1))

    assign sd_cs_n = ~sel;
    assign sd_mosi = tx[7];
    assign d_out   = a0 ? {5'd0, sel, fast, busy} : rx;

    always @(posedge clk) begin
        if (rst) begin
            sel <= 1'b0; fast <= 1'b0; busy <= 1'b0;
            tx  <= 8'hFF; rx <= 8'hFF;
            bits <= 4'd0; div <= 7'd0;
            sd_clk <= 1'b0;
        end else begin
            if (wr && a0) begin
                sel  <= d_in[0];
                fast <= d_in[1];
            end else if (wr && !a0 && !busy) begin
                tx   <= d_in;
                bits <= 4'd8;
                busy <= 1'b1;
                div  <= 7'd0;
            end

            if (busy) begin
                if (div == half) begin
                    div <= 7'd0;
                    if (!sd_clk) begin
                        sd_clk <= 1'b1;                    // rising: sample
                        rx     <= {rx[6:0], sd_miso};
                    end else begin
                        sd_clk <= 1'b0;                    // falling: next bit
                        tx     <= {tx[6:0], 1'b1};
                        bits   <= bits - 4'd1;
                        if (bits == 4'd1) busy <= 1'b0;
                    end
                end else
                    div <= div + 7'd1;
            end
        end
    end

endmodule
`default_nettype wire
