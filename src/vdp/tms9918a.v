// =============================================================================
// TMS9918A video display processor for the MSX1
//
// Output: 720x480p59.94 (CEA-861 mode 2/3, 27 MHz pixel clock). The 256x192
// TMS picture is doubled to 512x384 and centred; the rest is the backdrop.
//
// How it works
//   * VRAM is a 16 KB dual-port block RAM: port A for the CPU, port B for
//     the renderer.
//   * Each TMS line is rendered into a line buffer (256 x 4-bit colour
//     index, two halves = double buffer) while the previous line is shown.
//     Every TMS line lasts two HDMI lines (1716 clocks); rendering takes
//     at most ~750 clocks, so there is plenty of slack.
//   * Background: Graphics I, Graphics II, Multicolor and Text modes.
//   * Sprites: 32 sprites, 8x8/16x16, magnification, early clock, 4 per
//     line with 5th-sprite flag, collision flag, transparent colour 0.
//
// CPU side (MSX ports 98h/99h):
//   io_rd / io_wr are one-cycle strobes at the start of an I/O access.
//   d_out is latched at the strobe and held, as the CPU samples it later.
// =============================================================================
`default_nettype none

module tms9918a (
    input  wire       clk,       // 27 MHz
    input  wire       rst,
    // CPU interface
    input  wire       mode,      // 0 = 98h (VRAM data), 1 = 99h (control/status)
    input  wire       io_rd,
    input  wire       io_wr,
    input  wire [7:0] d_in,
    output reg  [7:0] d_out,
    output wire       int_n,
    // Video
    output reg  [7:0] r,
    output reg  [7:0] g,
    output reg  [7:0] b,
    output reg        hsync,     // active low
    output reg        vsync,     // active low
    output reg        de
);

    // ------------------------------------------------------------------
    // Video timing: 858 x 525 total, 720 x 480 active
    // ------------------------------------------------------------------
    localparam H_ACTIVE = 720, H_SYNC_START = 736, H_SYNC_END = 798, H_TOTAL = 858;
    localparam V_ACTIVE = 480, V_SYNC_START = 489, V_SYNC_END = 495, V_TOTAL = 525;
    localparam X0 = 104;   // left edge of the 512-pixel TMS window
    localparam Y0 = 48;    // top edge of the 384-line TMS window

    // ------------------------------------------------------------------
    // Registers
    // ------------------------------------------------------------------
    reg [7:0] r0, r1, r2, r3, r4, r5, r6, r7;

    wire        m3     = r0[1];
    wire        blank_n= r1[6];        // 1 = display enabled
    wire        ie     = r1[5];
    wire        m1     = r1[4];
    wire        m2     = r1[3];
    wire        spr16  = r1[1];
    wire        mag    = r1[0];

    wire mode_text = m1;
    wire mode_mc   = !m1 && m2;
    wire mode_g2   = !m1 && !m2 && m3;

    // ------------------------------------------------------------------
    // VRAM, 16 KB dual port
    // ------------------------------------------------------------------
    reg  [7:0]  vram [0:16383];
    reg  [13:0] va_addr;               // CPU address pointer
    wire        va_we;
    reg  [7:0]  va_dout;
    reg  [13:0] vb_addr;               // renderer address
    reg  [7:0]  vb_dout;

    // "normal" write mode: the output port is not updated on a write
    // (GW2AR block RAM does not support read-before-write)
    always @(posedge clk) begin
        if (va_we) vram[va_addr] <= d_in;
        else       va_dout <= vram[va_addr];
    end
    always @(posedge clk) vb_dout <= vram[vb_addr];

    // ------------------------------------------------------------------
    // Line buffer: 2 x 256 colour indexes (0 = transparent -> backdrop)
    // ------------------------------------------------------------------
    reg  [3:0] lbuf [0:511];
    reg        lb_we;
    reg  [8:0] lb_waddr;
    reg  [3:0] lb_wdata;
    reg  [8:0] lb_raddr;
    reg  [3:0] lb_rdata;
    always @(posedge clk) begin
        if (lb_we) lbuf[lb_waddr] <= lb_wdata;
        lb_rdata <= lbuf[lb_raddr];
    end

    // ------------------------------------------------------------------
    // Raster counters
    // ------------------------------------------------------------------
    reg [9:0] hcnt, vcnt;
    always @(posedge clk) begin
        if (rst) begin
            hcnt <= 10'd0;
            vcnt <= 10'd0;
        end else if (hcnt == H_TOTAL - 1) begin
            hcnt <= 10'd0;
            vcnt <= (vcnt == V_TOTAL - 1) ? 10'd0 : vcnt + 10'd1;
        end else
            hcnt <= hcnt + 10'd1;
    end

    // ------------------------------------------------------------------
    // Display pipeline (3 stages: address -> line-buffer read -> colour)
    // ------------------------------------------------------------------
    wire [9:0] xw = hcnt - X0;
    wire [9:0] yw = vcnt - Y0;
    wire       in_win = (hcnt >= X0) && (hcnt < X0 + 512) &&
                        (vcnt >= Y0) && (vcnt < Y0 + 384);

    reg de1, hs1, vs1, win1;
    reg de2, hs2, vs2, win2;
    always @(posedge clk) begin
        de1  <= (hcnt < H_ACTIVE) && (vcnt < V_ACTIVE);
        hs1  <= !((hcnt >= H_SYNC_START) && (hcnt < H_SYNC_END));
        vs1  <= !((vcnt >= V_SYNC_START) && (vcnt < V_SYNC_END));
        win1 <= in_win;
        lb_raddr <= {yw[1], xw[8:1]};        // TMS line parity, TMS pixel
        // lb_rdata becomes valid together with these
        de2  <= de1;
        hs2  <= hs1;
        vs2  <= vs1;
        win2 <= win1;
    end

    function [23:0] palette(input [3:0] c);
        case (c)
            4'd0:  palette = 24'h000000;
            4'd1:  palette = 24'h000000;
            4'd2:  palette = 24'h21C842;
            4'd3:  palette = 24'h5EDC78;
            4'd4:  palette = 24'h5455ED;
            4'd5:  palette = 24'h7D76FC;
            4'd6:  palette = 24'hD4524D;
            4'd7:  palette = 24'h42EBF5;
            4'd8:  palette = 24'hFC5554;
            4'd9:  palette = 24'hFF7978;
            4'd10: palette = 24'hD4C154;
            4'd11: palette = 24'hE6CE80;
            4'd12: palette = 24'h21B03B;
            4'd13: palette = 24'hC95BBA;
            4'd14: palette = 24'hCCCCCC;
            default: palette = 24'hFFFFFF;
        endcase
    endfunction

    wire [3:0] pix = (win2 && blank_n && lb_rdata != 4'd0) ? lb_rdata : r7[3:0];
    always @(posedge clk) begin
        hsync <= hs2;
        vsync <= vs2;
        de    <= de2;
        {r, g, b} <= de2 ? palette(pix) : 24'h000000;
    end

    // ------------------------------------------------------------------
    // Line renderer
    // ------------------------------------------------------------------
    // TMS line N is rendered during HDMI lines Y0-2+2N and Y0-1+2N.
    wire [9:0] rl_v      = vcnt - (Y0 - 2);
    wire       start_line = (hcnt == 0) && (vcnt >= Y0 - 2) &&
                            (vcnt < Y0 - 2 + 384) && !rl_v[0];

    localparam [4:0]
        R_IDLE   = 5'd0,  R_WAIT   = 5'd1,  R_TCLR  = 5'd2,
        R_NAME   = 5'd3,  R_PAT    = 5'd4,  R_COL   = 5'd5,
        R_DRAW_A = 5'd6,  R_DRAW   = 5'd7,  R_SPR0  = 5'd8,
        R_SPY    = 5'd9,  R_SPX    = 5'd10, R_SPN   = 5'd11,
        R_SPA    = 5'd12, R_SPPL   = 5'd13, R_SPPR  = 5'd14,
        R_SPDRAW = 5'd15;

    reg [4:0]  rs, rs_ret;
    reg [7:0]  line;          // TMS line being rendered (0..191)
    reg [5:0]  col;           // tile column
    reg [7:0]  name, pat, colr;
    reg [3:0]  pcnt;          // pixel counter inside a tile
    reg [7:0]  px;            // x position being written
    // sprites
    reg [4:0]  sn;            // sprite number
    reg [2:0]  scount;        // sprites found on this line
    reg [7:0]  sdiff;
    reg [7:0]  sx;
    reg [7:0]  sname;
    reg [7:0]  sattr;
    reg [15:0] spat;
    reg [5:0]  spx;           // pixel inside the sprite (0..31)
    reg [255:0] coll_map;     // a sprite pixel already here (any colour)
    reg [255:0] draw_map;     // a non-transparent sprite pixel already drawn
    // pulses to the status register
    reg        set_coll, set_5s;
    reg [4:0]  num_5s;

    wire [13:0] pnt = {r2[3:0], 10'd0};
    wire [13:0] ct  = {r3, 6'd0};
    wire [13:0] pgt = {r4[2:0], 11'd0};
    wire [13:0] sat = {r5[6:0], 7'd0};
    wire [13:0] spt = {r6[2:0], 11'd0};

    wire [5:0]  ncols    = mode_text ? 6'd40 : 6'd32;
    wire [12:0] g2_idx   = {line[7:6], name, line[2:0]};
    wire [5:0]  sp_h     = (spr16 ? 6'd16 : 6'd8) << mag;   // 8,16,32
    wire [5:0]  sp_w     = sp_h;
    wire [7:0]  ydiff    = line - vb_dout - 8'd1;            // line - (Y+1)
    wire [3:0]  sp_row   = mag ? sdiff[4:1] : sdiff[3:0];
    wire [4:0]  sp_bit   = mag ? spx[5:1] : spx[4:0];
    wire [8:0]  sp_xpos  = {1'b0, sx} - (sattr[7] ? 9'd32 : 9'd0) + {3'd0, spx};
    wire        sp_on    = spat[5'd15 - sp_bit[3:0]];
    wire        sp_vis   = !sp_xpos[8];                     // 0..255 only

    always @(posedge clk) begin
        lb_we    <= 1'b0;
        set_coll <= 1'b0;
        set_5s   <= 1'b0;
        if (rst) begin
            rs <= R_IDLE;
        end else begin
            case (rs)
            R_IDLE: if (start_line) begin
                line     <= rl_v[8:1];
                col      <= 6'd0;
                px       <= 8'd0;
                coll_map <= 256'd0;
                draw_map <= 256'd0;
                rs       <= mode_text ? R_TCLR : R_NAME;
            end

            // one-cycle wait for a VRAM read
            R_WAIT: rs <= rs_ret;

            // Text mode: clear the 8-pixel borders (whole line, simplest)
            R_TCLR: begin
                lb_we    <= 1'b1;
                lb_waddr <= {line[0], px};
                lb_wdata <= 4'd0;
                px       <= px + 8'd1;
                if (px == 8'd255) begin
                    px <= 8'd8;
                    rs <= R_NAME;
                end
            end

            // ---------------- background tiles ----------------
            R_NAME: begin
                if (col == ncols) begin
                    rs <= (mode_text || !blank_n) ? R_IDLE : R_SPR0;
                end else begin
                    if (mode_text)
                        vb_addr <= pnt + line[7:3] * 6'd40 + col;
                    else if (mode_mc)
                        vb_addr <= pnt + {line[7:3], col[4:0]};
                    else
                        vb_addr <= pnt + {line[7:3], col[4:0]};
                    rs_ret <= R_PAT; rs <= R_WAIT;
                end
            end

            R_PAT: begin
                name <= vb_dout;
                if (mode_g2)
                    vb_addr <= {r4[2], {line[7:6], vb_dout, line[2:0]} & {r4[1:0], 11'h7FF}};
                else if (mode_mc)
                    vb_addr <= pgt + {vb_dout, line[4:2]};
                else
                    vb_addr <= pgt + {vb_dout, line[2:0]};
                rs_ret <= (mode_text || mode_mc) ? R_DRAW_A : R_COL;
                rs     <= R_WAIT;
            end

            R_COL: begin
                pat <= vb_dout;
                if (mode_g2)
                    vb_addr <= {r3[7], g2_idx & {r3[6:0], 6'h3F}};
                else
                    vb_addr <= ct + name[7:3];
                rs_ret <= R_DRAW_A; rs <= R_WAIT;
            end

            R_DRAW_A: begin
                // text / multicolor: vb_dout is the pattern byte
                // graphics I / II : vb_dout is the colour byte
                if (mode_text) begin
                    pat  <= vb_dout;
                    colr <= r7;
                end else if (mode_mc) begin
                    pat  <= 8'hF0;              // left 4 pixels = high nibble
                    colr <= vb_dout;
                end else
                    colr <= vb_dout;
                pcnt <= 4'd0;
                rs   <= R_DRAW;
            end

            R_DRAW: begin
                lb_we    <= 1'b1;
                lb_waddr <= {line[0], px};
                lb_wdata <= pat[7] ? colr[7:4] : colr[3:0];
                pat      <= {pat[6:0], 1'b0};
                px       <= px + 8'd1;
                pcnt     <= pcnt + 4'd1;
                if (pcnt == (mode_text ? 4'd5 : 4'd7)) begin
                    col <= col + 6'd1;
                    rs  <= R_NAME;
                end
            end

            // ---------------- sprites ----------------
            R_SPR0: begin
                sn      <= 5'd0;
                scount  <= 3'd0;
                vb_addr <= sat;
                rs_ret  <= R_SPY; rs <= R_WAIT;
            end

            R_SPY: begin
                if (vb_dout == 8'hD0) begin
                    rs <= R_IDLE;                         // end of sprite list
                end else if (ydiff < {2'd0, sp_h}) begin
                    if (scount == 3'd4) begin
                        set_5s <= 1'b1;                   // 5th sprite on line
                        num_5s <= sn;
                        rs     <= R_IDLE;
                    end else begin
                        scount  <= scount + 3'd1;
                        sdiff   <= ydiff;
                        vb_addr <= sat + {sn, 2'd1};
                        rs_ret  <= R_SPX; rs <= R_WAIT;
                    end
                end else if (sn == 5'd31) begin
                    rs <= R_IDLE;
                end else begin
                    sn      <= sn + 5'd1;
                    vb_addr <= sat + {sn + 5'd1, 2'd0};
                    rs_ret  <= R_SPY; rs <= R_WAIT;
                end
            end

            R_SPX: begin
                sx      <= vb_dout;
                vb_addr <= sat + {sn, 2'd2};
                rs_ret  <= R_SPN; rs <= R_WAIT;
            end

            R_SPN: begin
                sname   <= spr16 ? {vb_dout[7:2], 2'b00} : vb_dout;
                vb_addr <= sat + {sn, 2'd3};
                rs_ret  <= R_SPA; rs <= R_WAIT;
            end

            R_SPA: begin
                sattr   <= vb_dout;
                vb_addr <= spt + {sname, 3'd0} + sp_row;
                rs_ret  <= R_SPPL; rs <= R_WAIT;
            end

            R_SPPL: begin
                spat[15:8] <= vb_dout;
                spat[7:0]  <= 8'h00;
                spx        <= 6'd0;
                if (spr16) begin
                    vb_addr <= vb_addr + 14'd16;          // right half
                    rs_ret  <= R_SPPR; rs <= R_WAIT;
                end else
                    rs <= R_SPDRAW;
            end

            R_SPPR: begin
                spat[7:0] <= vb_dout;
                rs        <= R_SPDRAW;
            end

            R_SPDRAW: begin
                if (sp_vis && sp_on) begin
                    if (coll_map[sp_xpos[7:0]]) set_coll <= 1'b1;
                    coll_map[sp_xpos[7:0]] <= 1'b1;
                    if (!draw_map[sp_xpos[7:0]] && sattr[3:0] != 4'd0) begin
                        draw_map[sp_xpos[7:0]] <= 1'b1;
                        lb_we    <= 1'b1;
                        lb_waddr <= {line[0], sp_xpos[7:0]};
                        lb_wdata <= sattr[3:0];
                    end
                end
                spx <= spx + 6'd1;
                if (spx == sp_w - 6'd1) begin
                    if (sn == 5'd31) rs <= R_IDLE;
                    else begin
                        sn      <= sn + 5'd1;
                        vb_addr <= sat + {sn + 5'd1, 2'd0};
                        rs_ret  <= R_SPY; rs <= R_WAIT;
                    end
                end
            end

            default: rs <= R_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // CPU interface, status register, interrupt
    // ------------------------------------------------------------------
    reg       ff;               // 0 = expecting first control byte
    reg [7:0] latch;
    reg [7:0] rd_buf;           // read-ahead buffer
    reg [1:0] pf;               // prefetch sequencer
    reg       st_f, st_5s, st_c;
    reg [4:0] st_num;

    // vertical blank starts right after the last TMS line is shown
    wire frame_end = (hcnt == 0) && (vcnt == Y0 + 384);

    assign va_we = io_wr && !mode;
    assign int_n = !(st_f && ie);

    always @(posedge clk) begin
        if (rst) begin
            r0 <= 8'h00; r1 <= 8'h00; r2 <= 8'h00; r3 <= 8'h00;
            r4 <= 8'h00; r5 <= 8'h00; r6 <= 8'h00; r7 <= 8'h00;
            ff <= 1'b0; latch <= 8'h00; rd_buf <= 8'h00;
            va_addr <= 14'd0; pf <= 2'd0; d_out <= 8'hFF;
            st_f <= 1'b0; st_5s <= 1'b0; st_c <= 1'b0; st_num <= 5'd0;
        end else begin
            // flags set by the video side
            if (frame_end) st_f <= 1'b1;
            if (set_coll)  st_c <= 1'b1;
            if (set_5s && !st_5s) begin
                st_5s  <= 1'b1;
                st_num <= num_5s;
            end

            // read-ahead: va_addr was stable last cycle, va_dout now valid
            case (pf)
                2'd1: pf <= 2'd2;
                2'd2: begin
                    rd_buf  <= va_dout;
                    va_addr <= va_addr + 14'd1;
                    pf      <= 2'd0;
                end
                default: ;
            endcase

            if (io_rd) begin
                ff <= 1'b0;
                if (!mode) begin
                    d_out <= rd_buf;
                    pf    <= 2'd1;
                end else begin
                    d_out  <= {st_f, st_5s, st_c, st_num};
                    st_f   <= 1'b0;
                    st_5s  <= 1'b0;
                    st_c   <= 1'b0;
                end
            end

            if (io_wr) begin
                if (!mode) begin
                    // VRAM write (va_we does the write at va_addr)
                    ff      <= 1'b0;
                    rd_buf  <= d_in;
                    va_addr <= va_addr + 14'd1;
                end else if (!ff) begin
                    ff            <= 1'b1;
                    latch         <= d_in;
                    va_addr[7:0]  <= d_in;
                end else begin
                    ff <= 1'b0;
                    if (d_in[7]) begin
                        case (d_in[2:0])
                            3'd0: r0 <= latch;
                            3'd1: r1 <= latch;
                            3'd2: r2 <= latch;
                            3'd3: r3 <= latch;
                            3'd4: r4 <= latch;
                            3'd5: r5 <= latch;
                            3'd6: r6 <= latch;
                            3'd7: r7 <= latch;
                        endcase
                    end else begin
                        va_addr <= {d_in[5:0], latch};
                        if (!d_in[6]) pf <= 2'd1;     // read setup: prefetch
                    end
                end
            end
        end
    end

endmodule
`default_nettype wire
