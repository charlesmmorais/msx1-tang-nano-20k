// =============================================================================
// MSX1 para Tang Nano 20K — Módulo Top-Level
// CPU: Z80 @ 3.6 MHz  |  VDP: TMS9918A  |  PSG: AY-3-8910
// PPI: Intel 8255  |  HDMI 720×480p60  |  SD Card  |  Teclado PS/2
//
// Clock do cristal: 27 MHz
// PLL1: 27 → 108 MHz (clock sistema)
// PLL2: 27 → 135 MHz (TMDS para HDMI)
//
// Divisão de clock:
//   CPU:      108/30 ≈ 3.6 MHz (clock enable)
//   PSG:      108/60 ≈ 1.8 MHz (clock enable)
//   Pixel:    108/4  = 27 MHz
//   TMDS:     135 MHz
// =============================================================================
`default_nettype none

module top (
    // Clock e reset
    input         sys_clk,      // 27 MHz crystal
    input         sys_rst_n,    // Botão reset (ativo baixo)

    // HDMI (onboard connector)
    output        tmds_clk_p, tmds_clk_n,
    output        tmds_d0_p,  tmds_d0_n,
    output        tmds_d1_p,  tmds_d1_n,
    output        tmds_d2_p,  tmds_d2_n,

    // SD Card (onboard)
    output        sd_clk,
    output        sd_mosi,
    input         sd_miso,
    output        sd_cs_n,

    // Teclado PS/2 (PMOD 1, pinos 1-2)
    input         ps2_clk,
    input         ps2_dat,

    // Áudio PDM (PMOD 1, pino 3)
    output        audio_pdm,

    // LEDs indicadores (ativo baixo)
    output [1:0]  led,

    // Botões auxiliares
    input         btn1,    // F1 (PMOD ou botão)
    input         btn2     // RESET soft
);

// ---------------------------------------------------------------------------
// Reset síncrono
// ---------------------------------------------------------------------------
reg [3:0] rst_cnt;
wire      rst = ~sys_rst_n | ~pll_lock1 | ~pll_lock2;
reg       rst_sync;

always @(posedge clk_sys) begin
    if (rst) begin
        rst_cnt  <= 4'hF;
        rst_sync <= 1'b1;
    end else if (rst_cnt != 4'd0) begin
        rst_cnt  <= rst_cnt - 4'd1;
    end else begin
        rst_sync <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// PLLs
// ---------------------------------------------------------------------------
wire clk_sys, clk_tmds;
wire pll_lock1, pll_lock2;

pll_108m pll1 (.clkin(sys_clk), .clkout(clk_sys),  .lock(pll_lock1));
pll_135m pll2 (.clkin(sys_clk), .clkout(clk_tmds), .lock(pll_lock2));

// Pixel clock (27 MHz): divide clk_sys por 4
reg [1:0] pix_div;
wire      clk_pix_en = (pix_div == 2'd3);
always @(posedge clk_sys) pix_div <= pix_div + 2'd1;

// ---------------------------------------------------------------------------
// Clock enables
// ---------------------------------------------------------------------------
reg [4:0] cpu_div;
wire      cpu_ce = (cpu_div == 5'd29); // 108/30 = 3.6 MHz
always @(posedge clk_sys) begin
    cpu_div <= (cpu_div == 5'd29) ? 5'd0 : cpu_div + 5'd1;
end

reg [5:0] psg_div;
wire      psg_ce = (psg_div == 6'd59); // 108/60 = 1.8 MHz
always @(posedge clk_sys) begin
    psg_div <= (psg_div == 6'd59) ? 6'd0 : psg_div + 6'd1;
end

// ---------------------------------------------------------------------------
// Z80 CPU
// ---------------------------------------------------------------------------
wire [15:0] cpu_addr;
wire [7:0]  cpu_do;
reg  [7:0]  cpu_di;
wire        cpu_mreq_n, cpu_iorq_n;
wire        cpu_rd_n,   cpu_wr_n;
wire        cpu_m1_n,   cpu_rfsh_n;
wire        cpu_halt;
wire        cpu_wait_n = 1'b1;
wire        cpu_int_n;
wire        cpu_nmi_n  = 1'b1;

z80_cpu cpu (
    .clk    (clk_sys),
    .ce     (cpu_ce),
    .rst    (rst_sync),
    .addr   (cpu_addr),
    .di     (cpu_di),
    .dout   (cpu_do),
    .mreq_n (cpu_mreq_n),
    .iorq_n (cpu_iorq_n),
    .rd_n   (cpu_rd_n),
    .wr_n   (cpu_wr_n),
    .m1_n   (cpu_m1_n),
    .rfsh_n (cpu_rfsh_n),
    .wait_n (cpu_wait_n),
    .int_n  (cpu_int_n),
    .nmi_n  (cpu_nmi_n),
    .halt   (cpu_halt)
);

// ---------------------------------------------------------------------------
// ROM BIOS/BASIC (48KB em BRAM)
// ---------------------------------------------------------------------------
// O arquivo bios/cbios_main_msx1.mem deve conter o C-BIOS em formato hex
wire [14:0] rom_addr;
reg  [7:0]  rom_data;

reg [7:0] bios_rom [0:32767]; // 32KB BIOS
initial $readmemh("../bios/cbios_main_msx1.mem", bios_rom);

always @(posedge clk_sys) begin
    rom_data <= bios_rom[rom_addr[14:0]];
end

// ---------------------------------------------------------------------------
// RAM 64KB (BRAM ou PSRAM)
// Usamos Block RAM da GW2AR-18 (96 blocos × 18Kbit = ~216KB disponíveis)
// ---------------------------------------------------------------------------
wire [15:0] ram_addr;
wire [7:0]  ram_wdata, ram_rdata;
wire        ram_we;

(* ram_style = "block" *)
reg [7:0] main_ram [0:65535];

always @(posedge clk_sys) begin
    if (ram_we) main_ram[ram_addr] <= ram_wdata;
    else        ram_rdata_reg      <= main_ram[ram_addr];
end
reg [7:0] ram_rdata_reg;
assign ram_rdata = ram_rdata_reg;

// ---------------------------------------------------------------------------
// VDP TMS9918A
// ---------------------------------------------------------------------------
wire        vdp_csr_n_io, vdp_csw_n_io, vdp_mode_io;
wire [7:0]  vdp_do;
wire        vdp_int_n;
wire [3:0]  vdp_r, vdp_g, vdp_b;
wire        vdp_hsync, vdp_vsync, vdp_de;

// VDP acessa portas: 0x98 (dados), 0x99 (ctrl/status)
wire vdp_access = !cpu_iorq_n && (cpu_addr[7:1] == 7'b1001100); // 0x98-0x99
assign vdp_csr_n_io = !(vdp_access && !cpu_rd_n);
assign vdp_csw_n_io = !(vdp_access && !cpu_wr_n);
assign vdp_mode_io  = cpu_addr[0]; // bit 0: 0=dados, 1=controle

tms9918a vdp (
    .clk    (clk_sys),
    .rst    (rst_sync),
    .csr_n  (vdp_csr_n_io),
    .csw_n  (vdp_csw_n_io),
    .mode   (vdp_mode_io),
    .cd_i   (cpu_do),
    .cd_o   (vdp_do),
    .int_n  (vdp_int_n),
    .r_out  (vdp_r),
    .g_out  (vdp_g),
    .b_out  (vdp_b),
    .hsync  (vdp_hsync),
    .vsync  (vdp_vsync),
    .de     (vdp_de)
);

assign cpu_int_n = vdp_int_n;

// ---------------------------------------------------------------------------
// PPI 8255
// ---------------------------------------------------------------------------
wire [7:0] ppi_do;
wire [7:0] ppi_port_a;   // slot select
wire [3:0] ppi_port_c_lo; // linha de teclado
wire       ppi_cs_n_io;
wire [1:0] ppi_a_io;
wire       ppi_cap_led, ppi_cas_out, ppi_cas_motor;

// PPI portas: 0xA8-0xAB
wire ppi_access = !cpu_iorq_n && (cpu_addr[7:2] == 6'b101000); // 0xA8-0xAB
assign ppi_cs_n_io = !ppi_access;
assign ppi_a_io    = cpu_addr[1:0];

// Leitura das colunas do teclado
wire [7:0] kbd_col_data;

ppi8255 ppi (
    .clk      (clk_sys),
    .rst      (rst_sync),
    .a        (ppi_a_io),
    .d_in     (cpu_do),
    .d_out    (ppi_do),
    .cs_n     (ppi_cs_n_io),
    .rd_n     (cpu_rd_n),
    .wr_n     (cpu_wr_n),
    .port_a   (ppi_port_a),
    .port_b_i (kbd_col_data),
    .port_c_lo(ppi_port_c_lo),
    .cap_led  (ppi_cap_led),
    .cas_out  (ppi_cas_out),
    .cas_motor(ppi_cas_motor)
);

// ---------------------------------------------------------------------------
// PSG AY-3-8910
// ---------------------------------------------------------------------------
wire [7:0] psg_do;
wire [7:0] psg_port_a;
wire [9:0] psg_audio;
wire       psg_bdir_io, psg_bc1_io;

// PSG: 0xA0 write data, 0xA1 write reg addr, 0xA2 read data
wire psg_access = !cpu_iorq_n && (cpu_addr[7:2] == 6'b101000) &&
                  (cpu_addr[1:0] != 2'b11);  // não conflita com PPI 0xA3
// Mais correto: 0xA0-0xA2
wire psg_acc2 = !cpu_iorq_n && (cpu_addr[7:1] == 7'b1010000); // 0xA0-0xA1
assign psg_bdir_io = psg_acc2 && !cpu_wr_n;
assign psg_bc1_io  = !cpu_iorq_n && (cpu_addr[7:0] == 8'hA1) && !cpu_wr_n;

ay8910 psg (
    .clk    (clk_sys),
    .ce     (psg_ce),
    .rst    (rst_sync),
    .bdir   (psg_bdir_io),
    .bc1    (psg_bc1_io),
    .d_in   (cpu_do),
    .d_out  (psg_do),
    .port_a (psg_port_a),
    .port_b (8'hFF),      // Joystick não implementado → 0xFF (solto)
    .audio_out(psg_audio)
);

// ---------------------------------------------------------------------------
// Teclado PS/2
// ---------------------------------------------------------------------------
wire [7:0] scan_code;
wire       key_pressed, key_released, kbd_valid;

ps2_decoder ps2 (
    .clk         (clk_sys),
    .rst         (rst_sync),
    .ps2_clk     (ps2_clk),
    .ps2_dat     (ps2_dat),
    .scan_code   (scan_code),
    .key_pressed (key_pressed),
    .key_released(key_released),
    .valid       (kbd_valid)
);

msx_keymap keymap (
    .clk       (clk_sys),
    .rst       (rst_sync),
    .scan_code (scan_code),
    .key_pressed (key_pressed),
    .key_released(key_released),
    .valid     (kbd_valid),
    .row_select(ppi_port_c_lo),
    .col_data  (kbd_col_data)
);

// ---------------------------------------------------------------------------
// SD Card
// ---------------------------------------------------------------------------
wire [7:0] sd_do;
wire       sd_cs_io;
wire [7:0] sd_io_addr_sig;

// SD: portas 0x40-0x47
wire sd_access = !cpu_iorq_n && (cpu_addr[7:3] == 5'b01000);

sd_ctrl sd (
    .clk       (clk_sys),
    .rst       (rst_sync),
    .io_addr   (cpu_addr[7:0]),
    .d_in      (cpu_do),
    .d_out     (sd_do),
    .io_cs     (sd_access),
    .io_wr     (!cpu_wr_n),
    .io_rd     (!cpu_rd_n),
    .sd_clk    (sd_clk),
    .sd_mosi   (sd_mosi),
    .sd_miso   (sd_miso),
    .sd_cs_n   (sd_cs_n),
    .buf_addr  (),
    .buf_dout  (),
    .buf_addr_r(9'd0),
    .buf_din   ()
);

// ---------------------------------------------------------------------------
// Controlador de slots/memória
// ---------------------------------------------------------------------------
slot_ctrl slots (
    .clk       (clk_sys),
    .rst       (rst_sync),
    .addr      (cpu_addr),
    .cpu_dout  (cpu_do),
    .cpu_din   (mem_dout),
    .mreq_n    (cpu_mreq_n),
    .rd_n      (cpu_rd_n),
    .wr_n      (cpu_wr_n),
    .slot_reg  (ppi_port_a),
    .rom_addr  (rom_addr),
    .rom_data  (rom_data),
    .ram_addr  (ram_addr),
    .ram_wdata (ram_wdata),
    .ram_we    (ram_we),
    .ram_data  (ram_rdata),
    // sinais de IO (não usados aqui, tratados diretamente)
    .vdp_csr_n (), .vdp_csw_n (), .vdp_mode  (),
    .ppi_cs_n  (), .ppi_a      (),
    .psg_bdir  (), .psg_bc1    (),
    .sd_cs     (), .sd_io_addr ()
);
wire [7:0] mem_dout;

// ---------------------------------------------------------------------------
// Multiplexador do barramento de dados para a CPU
// ---------------------------------------------------------------------------
always @(*) begin
    cpu_di = 8'hFF;
    if (!cpu_mreq_n) begin
        cpu_di = mem_dout;
    end else if (!cpu_iorq_n) begin
        if (vdp_access)  cpu_di = vdp_do;
        else if (ppi_access && !cpu_rd_n) cpu_di = ppi_do;
        else if (psg_acc2 && !cpu_rd_n) cpu_di = psg_do;
        else if (sd_access && !cpu_rd_n) cpu_di = sd_do;
        else cpu_di = 8'hFF;
    end
end

// ---------------------------------------------------------------------------
// Áudio — DAC sigma-delta
// ---------------------------------------------------------------------------
pdm_dac dac (
    .clk  (clk_sys),
    .rst  (rst_sync),
    .data (psg_audio),
    .pdm  (audio_pdm)
);

// ---------------------------------------------------------------------------
// Saída HDMI
// ---------------------------------------------------------------------------
// Pixel clock gerado como enable do clock_sys
// Para HDMI precisamos de um clock real de 27 MHz → usamos clk_sys/4 via BUFG
// Nota: OSER10 requer clock real, não enable. Usamos PLL2 como pixel clock.
// Solução: extrair 27 MHz do PLL2 via feedback interno

hdmi_out hdmi (
    .clk_pix (sys_clk),    // 27 MHz direto do cristal
    .clk_5x  (clk_tmds),  // 135 MHz do PLL2
    .rst     (rst_sync),
    .r_in    (vdp_r),
    .g_in    (vdp_g),
    .b_in    (vdp_b),
    .hsync   (vdp_hsync),
    .vsync   (vdp_vsync),
    .de      (vdp_de),
    .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
    .tmds_d0_p (tmds_d0_p),  .tmds_d0_n (tmds_d0_n),
    .tmds_d1_p (tmds_d1_p),  .tmds_d1_n (tmds_d1_n),
    .tmds_d2_p (tmds_d2_p),  .tmds_d2_n (tmds_d2_n)
);

// ---------------------------------------------------------------------------
// LEDs indicadores
// ---------------------------------------------------------------------------
assign led[0] = ~cpu_halt;     // LED apagado quando HALT
assign led[1] = ~ppi_cap_led;  // CAPS LOCK

endmodule
`default_nettype wire
