// Small behavioral SDR SDRAM model (x32, CAS latency 2, burst length 1).
// Enough to check the controller's command sequence and data timing.
// Flags any access before the mode register is loaded.
`timescale 1ns/1ps

module sdram_model (
    input        clk,
    input        cke,
    input        cs_n,
    input        ras_n,
    input        cas_n,
    input        we_n,
    input [10:0] addr,
    input [1:0]  ba,
    input [3:0]  dqm,
    inout [31:0] dq
);
    reg [31:0] mem [0:65535];          // only the part the MSX uses
    reg [10:0] row [0:3];
    reg        row_open [0:3];
    reg        mode_ok = 1'b0;
    integer    errors = 0;

    reg [31:0] rd_data [0:2];
    reg [2:0]  rd_valid = 3'b000;
    reg [31:0] dq_drive;
    reg        dq_oe = 1'b0;
    assign dq = dq_oe ? dq_drive : 32'bz;

    wire [2:0] cmd = {ras_n, cas_n, we_n};
    wire [15:0] widx_a = {row[ba][5:0], addr[7:0], ba};   // word index
    integer i;
    initial for (i = 0; i < 4; i = i + 1) row_open[i] = 1'b0;

    always @(posedge clk) begin
        // CAS latency 2 pipeline: data appears tAC after the 2nd edge
        rd_valid <= {rd_valid[1:0], 1'b0};
        rd_data[1] <= rd_data[0];
        if (rd_valid[1]) begin
            #5 dq_drive = rd_data[1]; dq_oe = 1'b1;
        end else begin
            #2 dq_oe = 1'b0;
        end
    end

    always @(posedge clk) if (cke && !cs_n) begin
        case (cmd)
            3'b000: begin                                   // LOAD MODE
                if (addr[6:4] != 3'b010 || addr[2:0] != 3'b000) begin
                    $display("SDRAM: unexpected mode %h", addr); errors = errors + 1;
                end
                mode_ok = 1'b1;
            end
            3'b011: begin row[ba] = addr; row_open[ba] = 1'b1; end   // ACTIVATE
            3'b101: begin                                   // READ
                if (!mode_ok || !row_open[ba]) begin
                    $display("SDRAM: bad READ at %t", $time); errors = errors + 1;
                end
                rd_data[0] <= mem[widx_a];
                rd_valid[0] <= 1'b1;
                if (addr[10]) row_open[ba] = 1'b0;
            end
            3'b100: begin                                   // WRITE
                if (!mode_ok || !row_open[ba]) begin
                    $display("SDRAM: bad WRITE at %t", $time); errors = errors + 1;
                end
                if (!dqm[0]) mem[widx_a][7:0]   = dq[7:0];
                if (!dqm[1]) mem[widx_a][15:8]  = dq[15:8];
                if (!dqm[2]) mem[widx_a][23:16] = dq[23:16];
                if (!dqm[3]) mem[widx_a][31:24] = dq[31:24];
                if (addr[10]) row_open[ba] = 1'b0;
            end
            3'b010: begin                                   // PRECHARGE
                if (addr[10]) for (i = 0; i < 4; i = i + 1) row_open[i] = 1'b0;
                else row_open[ba] = 1'b0;
            end
            default: ;                                      // NOP / REFRESH
        endcase
    end
endmodule
