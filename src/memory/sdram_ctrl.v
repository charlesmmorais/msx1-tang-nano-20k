// =============================================================================
// Minimal controller for the SDRAM embedded in the GW2AR-18C
// (64 Mbit, 2M x 32, 4 banks, 11-bit row, 8-bit column).
//
// It only serves the MSX 64 KB main RAM, one byte per access:
//   byte address [15:0] -> row = addr[15:10], column = addr[9:2],
//                          byte lane = addr[1:0], bank 0.
// Every access is ACTIVATE + READ/WRITE with auto-precharge.
//
// Runs at 27 MHz. The SDRAM clock is the inverted system clock, so commands
// are sampled half a cycle after we launch them. With CAS latency 2, read
// data is registered on the 3rd rising edge after the READ command.
// At 37 ns per cycle every tRCD/tRP/tRC/tWR requirement is met with the
// one-cycle gaps below.
//
// Handshake: hold `req` high for the whole CPU access (it must drop between
// accesses). `ready` goes high when that access is done and stays high until
// `req` drops. While req && !ready the CPU must be held in WAIT.
// =============================================================================
`default_nettype none

module sdram_ctrl (
    input  wire        clk,
    input  wire        rst,
    // Request side
    input  wire        req,
    input  wire        we,
    input  wire [15:0] addr,
    input  wire [7:0]  wdata,
    output reg  [7:0]  rdata,
    output wire        ready,
    output wire        init_done,
    // SDRAM pins (names must match the GW2AR embedded-SDRAM ports at the top)
    output wire        sdram_clk,
    output reg         sdram_cke,
    output wire        sdram_cs_n,
    output reg         sdram_ras_n,
    output reg         sdram_cas_n,
    output reg         sdram_we_n,
    output reg  [10:0] sdram_addr,
    output reg  [1:0]  sdram_ba,
    output reg  [3:0]  sdram_dqm,
    inout  wire [31:0] sdram_dq
);

    // {ras_n, cas_n, we_n}
    localparam [2:0] CMD_NOP   = 3'b111,
                     CMD_ACT   = 3'b011,
                     CMD_READ  = 3'b101,
                     CMD_WRITE = 3'b100,
                     CMD_PRE   = 3'b010,
                     CMD_REF   = 3'b001,
                     CMD_LMR   = 3'b000;

    // Mode register: burst length 1, sequential, CAS latency 2
    localparam [10:0] MODE_REG = 11'b000_0_010_0_000;

    localparam REFRESH_INTERVAL = 9'd384;   // 14.2 us (< 15.6 us for 4K/64 ms)

    localparam [3:0] S_POWERUP  = 4'd0,
                     S_PRECHG   = 4'd1,
                     S_INIT_REF = 4'd2,
                     S_LMR      = 4'd3,
                     S_IDLE     = 4'd4,
                     S_ACT      = 4'd5,
                     S_RW       = 4'd6,
                     S_WAIT     = 4'd7;

    assign sdram_clk  = ~clk;
    assign sdram_cs_n = 1'b0;

    reg  [3:0]  state;
    reg  [13:0] delay;          // general-purpose wait counter
    reg  [3:0]  init_refs;
    reg  [8:0]  ref_cnt;
    reg         ref_due;
    reg         served;         // current req has been taken
    reg         done;           // current req has finished
    reg         is_read;
    reg  [1:0]  lane;
    reg  [2:0]  rd_pipe;        // shifts a 1 towards the read-capture edge
    reg         dq_oe;
    reg  [31:0] dq_out;
    reg         init_ok;

    assign sdram_dq  = dq_oe ? dq_out : 32'bz;
    assign ready     = served & done;
    assign init_done = init_ok;

    task cmd(input [2:0] c);
        {sdram_ras_n, sdram_cas_n, sdram_we_n} <= c;
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state      <= S_POWERUP;
            delay      <= 14'd8191;        // > 200 us at 27 MHz
            init_refs  <= 4'd0;
            ref_cnt    <= 9'd0;
            ref_due    <= 1'b0;
            served     <= 1'b0;
            done       <= 1'b0;
            rd_pipe    <= 3'b000;
            dq_oe      <= 1'b0;
            dq_out     <= 32'd0;
            sdram_cke  <= 1'b0;
            sdram_addr <= 11'd0;
            sdram_ba   <= 2'd0;
            sdram_dqm  <= 4'b1111;
            init_ok    <= 1'b0;
            is_read    <= 1'b0;
            lane       <= 2'd0;
            rdata      <= 8'hFF;
            cmd(CMD_NOP);
        end else begin
            cmd(CMD_NOP);
            dq_oe <= 1'b0;

            // Refresh timer
            if (ref_cnt == REFRESH_INTERVAL) begin
                ref_cnt <= 9'd0;
                ref_due <= 1'b1;
            end else begin
                ref_cnt <= ref_cnt + 9'd1;
            end

            // Release the handshake when the CPU drops req
            if (!req) begin
                served <= 1'b0;
                done   <= 1'b0;
            end

            // Read data capture: 3rd rising edge after the READ command
            rd_pipe <= {rd_pipe[1:0], 1'b0};
            if (rd_pipe[2]) begin
                case (lane)
                    2'd0: rdata <= sdram_dq[7:0];
                    2'd1: rdata <= sdram_dq[15:8];
                    2'd2: rdata <= sdram_dq[23:16];
                    2'd3: rdata <= sdram_dq[31:24];
                endcase
                done <= 1'b1;
            end

            case (state)
            // ---------------------------------------------------- init
            S_POWERUP: begin
                sdram_cke <= 1'b1;
                if (delay == 14'd0) begin
                    cmd(CMD_PRE);
                    sdram_addr[10] <= 1'b1;          // precharge all banks
                    delay <= 14'd3;
                    state <= S_PRECHG;
                end else
                    delay <= delay - 14'd1;
            end

            S_PRECHG: begin
                if (delay == 14'd0) begin
                    cmd(CMD_REF);
                    init_refs <= 4'd1;
                    delay <= 14'd7;
                    state <= S_INIT_REF;
                end else
                    delay <= delay - 14'd1;
            end

            S_INIT_REF: begin
                if (delay == 14'd0) begin
                    if (init_refs == 4'd8) begin
                        cmd(CMD_LMR);
                        sdram_ba   <= 2'd0;
                        sdram_addr <= MODE_REG;
                        delay <= 14'd3;
                        state <= S_LMR;
                    end else begin
                        cmd(CMD_REF);
                        init_refs <= init_refs + 4'd1;
                        delay <= 14'd7;
                    end
                end else
                    delay <= delay - 14'd1;
            end

            S_LMR: begin
                if (delay == 14'd0) begin
                    init_ok <= 1'b1;
                    ref_due <= 1'b0;
                    state   <= S_IDLE;
                end else
                    delay <= delay - 14'd1;
            end

            // ---------------------------------------------------- normal
            S_IDLE: begin
                if (ref_due) begin
                    cmd(CMD_REF);
                    ref_due <= 1'b0;
                    delay   <= 14'd3;                // tRFC ~ 4 cycles
                    state   <= S_WAIT;
                end else if (req && !served) begin
                    served     <= 1'b1;
                    done       <= 1'b0;
                    is_read    <= !we;
                    lane       <= addr[1:0];
                    cmd(CMD_ACT);
                    sdram_ba   <= 2'd0;
                    sdram_addr <= {5'd0, addr[15:10]};
                    state      <= S_ACT;
                end
            end

            S_ACT: begin                              // tRCD satisfied (37 ns)
                sdram_addr <= {3'b001, addr[9:2]};    // A10 = auto-precharge
                if (is_read) begin
                    cmd(CMD_READ);
                    sdram_dqm <= 4'b0000;
                    rd_pipe[0] <= 1'b1;
                end else begin
                    cmd(CMD_WRITE);
                    sdram_dqm <= ~(4'b0001 << lane);  // only the addressed byte
                    dq_out    <= {4{wdata}};
                    dq_oe     <= 1'b1;
                    done      <= 1'b1;                // posted: data is latched
                end
                delay <= 14'd4;                       // covers tWR + tRP / CL
                state <= S_RW;
            end

            S_RW, S_WAIT: begin
                if (delay == 14'd0)
                    state <= S_IDLE;
                else
                    delay <= delay - 14'd1;
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
`default_nettype wire
