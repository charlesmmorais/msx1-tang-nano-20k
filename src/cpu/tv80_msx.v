// =============================================================================
// Z80 for the MSX: tv80 core (Verilog port of T80) with a clock enable.
//
// Based on tv80s.v by Guy Hutchison (MIT license, see src/cpu/tv80/LICENSE).
// The only change from tv80s is that `cen` is an input instead of being tied
// to 1, so the CPU runs at ~3.58 MHz inside the 27 MHz system clock domain.
// The bus-control register block below also only advances when cen=1.
// =============================================================================
module tv80_msx (
    input         clk,
    input         cen,
    input         reset_n,
    input         wait_n,
    input         int_n,
    input         nmi_n,
    input         busrq_n,
    input  [7:0]  di,
    output        m1_n,
    output reg    mreq_n,
    output reg    iorq_n,
    output reg    rd_n,
    output reg    wr_n,
    output        rfsh_n,
    output        halt_n,
    output        busak_n,
    output [15:0] A,
    output [7:0]  dout
);

    wire       intcycle_n;
    wire       no_read;
    wire       write;
    wire       iorq;
    reg  [7:0] di_reg;
    wire [6:0] mcycle;
    wire [6:0] tstate;

    tv80_core #(.Mode(0), .IOWait(1)) core (
        .cen        (cen),
        .m1_n       (m1_n),
        .iorq       (iorq),
        .no_read    (no_read),
        .write      (write),
        .rfsh_n     (rfsh_n),
        .halt_n     (halt_n),
        .wait_n     (wait_n),
        .int_n      (int_n),
        .nmi_n      (nmi_n),
        .reset_n    (reset_n),
        .busrq_n    (busrq_n),
        .busak_n    (busak_n),
        .clk        (clk),
        .IntE       (),
        .stop       (),
        .A          (A),
        .dinst      (di),
        .di         (di_reg),
        .dout       (dout),
        .mc         (mcycle),
        .ts         (tstate),
        .intcycle_n (intcycle_n)
    );

    // Bus strobes. Same logic as tv80s (T2Write = 1), gated by cen.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rd_n   <= 1'b1;
            wr_n   <= 1'b1;
            iorq_n <= 1'b1;
            mreq_n <= 1'b1;
            di_reg <= 8'h00;
        end else if (cen) begin
            rd_n   <= 1'b1;
            wr_n   <= 1'b1;
            iorq_n <= 1'b1;
            mreq_n <= 1'b1;
            if (mcycle[0]) begin
                if (tstate[1] || (tstate[2] && !wait_n)) begin
                    rd_n   <= ~intcycle_n;
                    mreq_n <= ~intcycle_n;
                    iorq_n <= intcycle_n;
                end
            end else begin
                if ((tstate[1] || (tstate[2] && !wait_n)) && !no_read && !write) begin
                    rd_n   <= 1'b0;
                    iorq_n <= ~iorq;
                    mreq_n <= iorq;
                end
                if ((tstate[1] || (tstate[2] && !wait_n)) && write) begin
                    wr_n   <= 1'b0;
                    iorq_n <= ~iorq;
                    mreq_n <= iorq;
                end
            end
            if (tstate[2] && wait_n && !write && !no_read)
                di_reg <= di;
        end
    end

endmodule
