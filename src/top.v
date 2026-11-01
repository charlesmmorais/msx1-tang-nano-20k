// =============================================================================
// MSX1 for the Tang Nano 20K — top level
//
//   CPU   : Z80 (tv80) at 3.58 MHz, 1 wait state on M1 (as on a real MSX)
//   VDP   : TMS9918A, 16 KB VRAM in block RAM, HDMI 720x480p
//   PSG   : AY-3-8910 at 1.79 MHz, PDM audio
//   PPI   : i8255 (slot select, keyboard, CAPS LED, click)
//   ROM   : 48 KB in block RAM, slot 0 (bios/msx_rom.mem)
//   RAM   : 64 KB in the GW2AR embedded SDRAM, slot 3
//   Input : PS/2 keyboard;  Storage: raw SPI port to the microSD slot
//
// One clock domain: everything runs at the 27 MHz pixel clock, with clock
// enables for the CPU and PSG.
//
// I/O map:  98h-99h VDP | A0h-A2h PSG | A8h-ABh PPI | 40h-41h SD SPI
// =============================================================================
`default_nettype none

`ifndef ROM_FILE
`define ROM_FILE "bios/msx_rom.mem"
`endif

module top (
    input  wire        sys_clk,      // 27 MHz crystal
    input  wire        btn_s1,       // reset (high when pressed)
    input  wire        btn_s2,       // unused for now
    output wire [5:0]  led,          // active low

    output wire        tmds_clk_p, tmds_clk_n,
    output wire [2:0]  tmds_d_p, tmds_d_n,

    output wire        sd_clk,
    output wire        sd_mosi,
    input  wire        sd_miso,
    output wire        sd_cs_n,

    input  wire        ps2_clk,
    input  wire        ps2_dat,
    output wire        audio_pdm,

    // Embedded SDRAM (names fixed by the GW2AR package, no constraints)
    output wire        O_sdram_clk,
    output wire        O_sdram_cke,
    output wire        O_sdram_cs_n,
    output wire        O_sdram_cas_n,
    output wire        O_sdram_ras_n,
    output wire        O_sdram_wen_n,
    inout  wire [31:0] IO_sdram_dq,
    output wire [10:0] O_sdram_addr,
    output wire [1:0]  O_sdram_ba,
    output wire [3:0]  O_sdram_dqm
);

    // ------------------------------------------------------------------
    // Clocks and reset
    // ------------------------------------------------------------------
    wire clk, clk_5x, pll_lock;
    pll_135m pll (.clkin(sys_clk), .clk_5x(clk_5x), .clk_1x(clk), .lock(pll_lock));

    reg [2:0]  btn_sync;
    reg [15:0] rst_cnt;
    reg        rst;
    always @(posedge clk or negedge pll_lock) begin
        if (!pll_lock) begin
            btn_sync <= 3'b000;
            rst_cnt  <= 16'd0;
            rst      <= 1'b1;
        end else begin
            btn_sync <= {btn_sync[1:0], btn_s1};
            if (btn_sync[2]) begin
                rst_cnt <= 16'd0;
                rst     <= 1'b1;
            end else if (rst_cnt != 16'hFFFF) begin
                rst_cnt <= rst_cnt + 16'd1;
            end else
                rst <= 1'b0;
        end
    end

    // CPU clock enable: 27 MHz * 3579545 / 27000000 = 3.579545 MHz exactly
    localparam [24:0] CPU_HZ = 25'd3579545;
    localparam [24:0] SYS_HZ = 25'd27000000;
    reg [24:0] ce_acc;
    reg        cpu_ce;
    reg        psg_ce;
    reg        psg_tog;
    always @(posedge clk) begin
        if (rst) begin
            ce_acc  <= 25'd0;
            cpu_ce  <= 1'b0;
            psg_ce  <= 1'b0;
            psg_tog <= 1'b0;
        end else begin
            psg_ce <= 1'b0;
            if (ce_acc >= SYS_HZ - CPU_HZ) begin
                ce_acc  <= ce_acc + CPU_HZ - SYS_HZ;
                cpu_ce  <= 1'b1;
                psg_tog <= ~psg_tog;
                psg_ce  <= psg_tog;
            end else begin
                ce_acc <= ce_acc + CPU_HZ;
                cpu_ce <= 1'b0;
            end
        end
    end

    // ------------------------------------------------------------------
    // CPU
    // ------------------------------------------------------------------
    wire [15:0] a;
    wire [7:0]  cpu_dout;
    reg  [7:0]  cpu_din;
    wire        mreq_n, iorq_n, rd_n, wr_n, m1_n, rfsh_n, halt_n;
    wire        cpu_int_n;
    wire        wait_n;

    tv80_msx cpu (
        .clk    (clk),
        .cen    (cpu_ce),
        .reset_n(!rst),
        .wait_n (wait_n),
        .int_n  (cpu_int_n),
        .nmi_n  (1'b1),
        .busrq_n(1'b1),
        .di     (cpu_din),
        .m1_n   (m1_n),
        .mreq_n (mreq_n),
        .iorq_n (iorq_n),
        .rd_n   (rd_n),
        .wr_n   (wr_n),
        .rfsh_n (rfsh_n),
        .halt_n (halt_n),
        .busak_n(),
        .A      (a),
        .dout   (cpu_dout)
    );

    // MSX: one wait state on every M1 cycle
    reg m1w_done;
    always @(posedge clk) begin
        if (rst)
            m1w_done <= 1'b0;
        else if (cpu_ce) begin
            if (m1_n)         m1w_done <= 1'b0;
            else if (!mreq_n) m1w_done <= 1'b1;
        end
    end
    wire m1_wait = !m1_n && !mreq_n && !m1w_done;

    // ------------------------------------------------------------------
    // Memory: slot decode, ROM, RAM
    // ------------------------------------------------------------------
    wire [7:0] ppi_port_a;
    wire       rom_sel, ram_sel;
    wire [1:0] cur_slot;
    slot_ctrl slots (.addr(a), .slot_reg(ppi_port_a),
                     .rom_sel(rom_sel), .ram_sel(ram_sel), .cur_slot(cur_slot));

    reg [7:0] rom [0:49151];
    initial $readmemh(`ROM_FILE, rom);
    reg [7:0] rom_q;
    always @(posedge clk) rom_q <= rom[(a[15:14] == 2'd3) ? 16'd0 : a];

    wire       mem_rw  = !mreq_n && rfsh_n && (!rd_n || !wr_n);
    wire       ram_req = mem_rw && ram_sel;
    wire [7:0] ram_q;
    wire       ram_ready, sdram_ok;

    sdram_ctrl sdram (
        .clk        (clk),
        .rst        (rst),
        .req        (ram_req),
        .we         (!wr_n),
        .addr       (a),
        .wdata      (cpu_dout),
        .rdata      (ram_q),
        .ready      (ram_ready),
        .init_done  (sdram_ok),
        .sdram_clk  (O_sdram_clk),
        .sdram_cke  (O_sdram_cke),
        .sdram_cs_n (O_sdram_cs_n),
        .sdram_ras_n(O_sdram_ras_n),
        .sdram_cas_n(O_sdram_cas_n),
        .sdram_we_n (O_sdram_wen_n),
        .sdram_addr (O_sdram_addr),
        .sdram_ba   (O_sdram_ba),
        .sdram_dqm  (O_sdram_dqm),
        .sdram_dq   (IO_sdram_dq)
    );

    assign wait_n = !(ram_req && !ram_ready) && !m1_wait;

    // ------------------------------------------------------------------
    // I/O decode. Strobes fire once, on the first clock of an I/O access.
    // IORQ with M1 low is an interrupt acknowledge, not an I/O access.
    // ------------------------------------------------------------------
    wire io_cyc = !iorq_n && m1_n && (!rd_n || !wr_n);
    reg  io_cyc_d;
    always @(posedge clk) io_cyc_d <= io_cyc;
    wire io_start = io_cyc && !io_cyc_d;
    wire io_rd    = io_start && !rd_n;
    wire io_wr    = io_start && !wr_n;

    wire [7:0] port   = a[7:0];
    wire sel_vdp = (port[7:1] == 7'b1001_100);      // 98h-99h
    wire sel_psg = (port[7:2] == 6'b1010_00);       // A0h-A3h
    wire sel_ppi = (port[7:2] == 6'b1010_10);       // A8h-ABh
    wire sel_sd  = (port[7:1] == 7'b0100_000);      // 40h-41h

    // ------------------------------------------------------------------
    // VDP
    // ------------------------------------------------------------------
    wire [7:0] vdp_dout;
    wire [7:0] vr, vg, vb;
    wire       vhs, vvs, vde;

    tms9918a vdp (
        .clk   (clk),
        .rst   (rst),
        .mode  (a[0]),
        .io_rd (io_rd && sel_vdp),
        .io_wr (io_wr && sel_vdp),
        .d_in  (cpu_dout),
        .d_out (vdp_dout),
        .int_n (cpu_int_n),
        .r(vr), .g(vg), .b(vb),
        .hsync (vhs),
        .vsync (vvs),
        .de    (vde)
    );

    hdmi_out hdmi (
        .clk_pix   (clk),
        .clk_5x    (clk_5x),
        .rst       (rst),
        .r(vr), .g(vg), .b(vb),
        .hsync     (vhs),
        .vsync     (vvs),
        .de        (vde),
        .tmds_clk_p(tmds_clk_p),
        .tmds_clk_n(tmds_clk_n),
        .tmds_d_p  (tmds_d_p),
        .tmds_d_n  (tmds_d_n)
    );

    // ------------------------------------------------------------------
    // PPI + keyboard
    // ------------------------------------------------------------------
    wire [7:0] ppi_dout, ppi_port_c, kbd_cols;

    ppi8255 ppi (
        .clk   (clk),
        .rst   (rst),
        .a     (a[1:0]),
        .d_in  (cpu_dout),
        .d_out (ppi_dout),
        .wr    (io_wr && sel_ppi),
        .port_a(ppi_port_a),
        .port_b(kbd_cols),
        .port_c(ppi_port_c)
    );

    wire [7:0] scan_code;
    wire       kb_ext, kb_rel, kb_valid;
    ps2_decoder ps2 (
        .clk      (clk),
        .rst      (rst),
        .ps2_clk  (ps2_clk),
        .ps2_dat  (ps2_dat),
        .scan_code(scan_code),
        .extended (kb_ext),
        .released (kb_rel),
        .valid    (kb_valid)
    );

    msx_keymap keymap (
        .clk       (clk),
        .rst       (rst),
        .scan_code (scan_code),
        .extended  (kb_ext),
        .released  (kb_rel),
        .valid     (kb_valid),
        .row_select(ppi_port_c[3:0]),
        .col_data  (kbd_cols)
    );

    // ------------------------------------------------------------------
    // PSG + audio
    // ------------------------------------------------------------------
    wire [7:0] psg_dout;
    wire [9:0] psg_audio;
    ay8910 psg (
        .clk       (clk),
        .ce        (psg_ce),
        .rst       (rst),
        .wr_addr   (io_wr && sel_psg && a[1:0] == 2'd0),
        .wr_data   (io_wr && sel_psg && a[1:0] == 2'd1),
        .d_in      (cpu_dout),
        .d_out     (psg_dout),
        .port_a_in (8'hFF),          // no joysticks, no cassette
        .port_b_out(),
        .audio     (psg_audio)
    );

    // key click (PPI C7) mixed in on top of the PSG
    wire [9:0] audio_mix = psg_audio + (ppi_port_c[7] ? 10'd128 : 10'd0);
    pdm_dac dac (.clk(clk), .rst(rst), .data(audio_mix), .pdm(audio_pdm));

    // ------------------------------------------------------------------
    // SD card SPI port
    // ------------------------------------------------------------------
    wire [7:0] sd_dout;
    sd_spi sd (
        .clk    (clk),
        .rst    (rst),
        .a0     (a[0]),
        .d_in   (cpu_dout),
        .d_out  (sd_dout),
        .wr     (io_wr && sel_sd),
        .sd_clk (sd_clk),
        .sd_mosi(sd_mosi),
        .sd_miso(sd_miso),
        .sd_cs_n(sd_cs_n)
    );

    // ------------------------------------------------------------------
    // CPU data-in mux
    // ------------------------------------------------------------------
    always @(*) begin
        cpu_din = 8'hFF;
        if (!mreq_n) begin
            if (rom_sel)      cpu_din = rom_q;
            else if (ram_sel) cpu_din = ram_q;
        end else if (!iorq_n && m1_n) begin
            if (sel_vdp)                         cpu_din = vdp_dout;
            else if (sel_psg && a[1:0] == 2'd2)  cpu_din = psg_dout;
            else if (sel_ppi)                    cpu_din = ppi_dout;
            else if (sel_sd)                     cpu_din = sd_dout;
        end
    end

    // ------------------------------------------------------------------
    // LEDs (active low)
    //   0: CAPS   1: SD selected   2: CPU halted   3: SDRAM not ready
    //   4: heartbeat (~1 Hz)       5: reset
    // ------------------------------------------------------------------
    reg [24:0] beat;
    always @(posedge clk) beat <= beat + 25'd1;

    assign led[0] = ppi_port_c[6];
    assign led[1] = sd_cs_n;
    assign led[2] = halt_n;
    assign led[3] = sdram_ok;
    assign led[4] = beat[24];
    assign led[5] = !rst;

    wire unused = btn_s2;

endmodule
`default_nettype wire
