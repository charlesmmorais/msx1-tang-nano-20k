// =============================================================================
// Controlador de Slots/Memória MSX1
// Slots:
//   Slot 0: ROM BIOS (0000h-7FFFh) + BASIC (8000h-BFFFh)
//   Slot 1: Cartucho (não implementado — retorna 0xFF)
//   Slot 2: Cartucho (não implementado — retorna 0xFF)
//   Slot 3: RAM 64KB
// Seleção por página via PPI Porta A:
//   bits 1:0 → Página 0 (0000h-3FFFh)
//   bits 3:2 → Página 1 (4000h-7FFFh)
//   bits 5:4 → Página 2 (8000h-BFFFh)
//   bits 7:6 → Página 3 (C000h-FFFFh)
// =============================================================================
`default_nettype none

module slot_ctrl (
    input         clk,
    input         rst,
    // Barramento CPU
    input  [15:0] addr,
    input  [7:0]  cpu_dout,
    output reg [7:0] cpu_din,
    input         mreq_n,
    input         rd_n,
    input         wr_n,
    // Seleção de slot (PPI Porta A)
    input  [7:0]  slot_reg,     // Valor da Porta A do PPI
    // ROM BIOS + BASIC (48KB)
    output [14:0] rom_addr,
    input  [7:0]  rom_data,
    // RAM 64KB
    output [15:0] ram_addr,
    output [7:0]  ram_wdata,
    output        ram_we,
    input  [7:0]  ram_data,
    // VDP (portas 0x98-0x9B)
    output        vdp_csr_n,
    output        vdp_csw_n,
    output        vdp_mode,
    // PPI (portas 0xA8-0xAB)
    output        ppi_cs_n,
    output [1:0]  ppi_a,
    // PSG (portas 0xA0-0xA2)
    output        psg_bdir,
    output        psg_bc1,
    // SD Card (portas 0x40-0x47)
    output        sd_cs,
    output [7:0]  sd_io_addr
);

// Página de cada slot
wire [1:0] page0_slot = slot_reg[1:0];
wire [1:0] page1_slot = slot_reg[3:2];
wire [1:0] page2_slot = slot_reg[5:4];
wire [1:0] page3_slot = slot_reg[7:6];

// Slot da página atual baseado no endereço
wire [1:0] cur_slot = (addr[15:14] == 2'b00) ? page0_slot :
                      (addr[15:14] == 2'b01) ? page1_slot :
                      (addr[15:14] == 2'b10) ? page2_slot :
                                               page3_slot;

// ROM cobre slot 0, endereços 0000h-BFFFh
wire rom_en = (cur_slot == 2'd0) && (addr[15:14] != 2'b11);

// RAM é no slot 3
wire ram_en = (cur_slot == 2'd3);

assign rom_addr = addr[14:0];
assign ram_addr = addr;
assign ram_wdata = cpu_dout;
assign ram_we   = ram_en && !wr_n && !mreq_n;

// Leitura de memória
always @(*) begin
    cpu_din = 8'hFF;
    if (!mreq_n && !rd_n) begin
        if (rom_en)  cpu_din = rom_data;
        if (ram_en)  cpu_din = ram_data;
    end
end

// ---------------------------------------------------------------------------
// Decodificação de portas I/O
// ---------------------------------------------------------------------------
// VDP: 0x98=data, 0x99=control, 0x9A,0x9B (palette/color, MSX2, não usado)
assign vdp_csr_n = !(addr[7:0] == 8'h98 && !mreq_n == 1'b0 && !rd_n == 1'b0);
// Simplificado: VDP acessa quando IORQ=0 (tratado no top)
// Aqui usamos mreq_n=1 e sinais iorq derivados no top

// PPI: 0xA8-0xAB
assign ppi_cs_n = !(addr[7:2] == 6'b101000 && !mreq_n == 1'b0);
assign ppi_a    = addr[1:0];

// PSG: 0xA0=write data, 0xA1=write addr, 0xA2=read data
assign psg_bc1  = (addr[1:0] == 2'b01);
assign psg_bdir = !wr_n && (addr[7:1] == 7'b1010000);

// SD Card: 0x40-0x47
assign sd_cs      = (addr[7:3] == 5'b01000);
assign sd_io_addr = addr;

endmodule
`default_nettype wire
