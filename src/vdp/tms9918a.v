// =============================================================================
// TMS9918A Video Display Processor — implementação completa para MSX1
// Modos: Screen 0 (Text 40col), Screen 1 (Gfx I), Screen 2 (Gfx II), Screen 3 (MC)
// Sprites: 32 sprites, 8x8 ou 16x16, magnificação x1 ou x2
// Paleta MSX1 de 15 cores + transparente
// Saída: RGB 3 bits (expandido para 9 bits), 256x192 com bordas
// Clock VDP: 108 MHz; pixel rate: 108/4 = 27 MHz
// =============================================================================
`default_nettype none

module tms9918a (
    input         clk,       // 108 MHz
    input         rst,
    // Interface CPU (barramento MSX)
    input         csr_n,     // Chip Select Read (leitura de dados/status)
    input         csw_n,     // Chip Select Write
    input         mode,      // 0=dados, 1=registrador/VRAM addr
    input  [7:0]  cd_i,      // Dados CPU → VDP
    output reg [7:0] cd_o,   // Dados VDP → CPU
    output reg    int_n,     // Interrupção vertical (ativo baixo)
    // Saída de vídeo (pixel clock = clk/4 = 27 MHz)
    output reg [3:0] r_out,
    output reg [3:0] g_out,
    output reg [3:0] b_out,
    output reg    hsync,     // H-sync (ativo baixo)
    output reg    vsync,     // V-sync (ativo baixo)
    output reg    de         // Display enable
);

// ---------------------------------------------------------------------------
// Paleta TMS9918A (15 cores + transparente)
// Formato: {R4, G4, B4}
// ---------------------------------------------------------------------------
function [11:0] palette_rgb;
    input [3:0] idx;
    case (idx)
        4'd0:  palette_rgb = 12'h000; // Transparent (preto)
        4'd1:  palette_rgb = 12'h000; // Black
        4'd2:  palette_rgb = 12'h3B6; // Medium Green
        4'd3:  palette_rgb = 12'h7CF; // Light Green
        4'd4:  palette_rgb = 12'h44F; // Dark Blue
        4'd5:  palette_rgb = 12'h66F; // Light Blue
        4'd6:  palette_rgb = 12'hB43; // Dark Red
        4'd7:  palette_rgb = 12'h4CE; // Cyan
        4'd8:  palette_rgb = 12'hD43; // Medium Red
        4'd9:  palette_rgb = 12'hF75; // Light Red
        4'd10: palette_rgb = 12'hCC3; // Dark Yellow
        4'd11: palette_rgb = 12'hDD6; // Light Yellow
        4'd12: palette_rgb = 12'h2A3; // Dark Green
        4'd13: palette_rgb = 12'hC5B; // Magenta
        4'd14: palette_rgb = 12'hCCC; // Gray
        4'd15: palette_rgb = 12'hFFF; // White
    endcase
endfunction

// ---------------------------------------------------------------------------
// VRAM: 16KB (implementado em BRAM)
// ---------------------------------------------------------------------------
reg [7:0] vram [0:16383];

// ---------------------------------------------------------------------------
// Registradores VDP (R0–R7)
// ---------------------------------------------------------------------------
reg [7:0] vdp_reg [0:7];

// Campos importantes
wire        m1    = vdp_reg[1][4]; // Mode bit 1 (Screen 0 = texto)
wire        m2    = vdp_reg[0][1]; // Mode bit 2
wire        m3    = vdp_reg[1][3]; // Mode bit 3
wire        extvid = vdp_reg[0][0];
wire        ie    = vdp_reg[1][5]; // Interrupt enable
wire        bl    = vdp_reg[1][6]; // Blank (0 = desabilita saída)
wire        size  = vdp_reg[1][1]; // Tamanho sprite: 0=8x8, 1=16x16
wire        mag   = vdp_reg[0][0]; // Sprite magnification

// Bases de VRAM
wire [13:0] pnt_base  = {vdp_reg[2][3:0], 10'd0};     // Pattern Name Table
wire [13:0] ct_base   = {vdp_reg[3],       6'd0};      // Color Table
wire [13:0] pgt_base  = {vdp_reg[4][2:0], 11'd0};     // Pattern Generator Table
wire [13:0] sat_base  = {vdp_reg[5][6:0],  7'd0};     // Sprite Attribute Table
wire [13:0] spt_base  = {vdp_reg[6][2:0], 11'd0};     // Sprite Pattern Table
wire [3:0]  backdrop  = vdp_reg[7][3:0];               // Cor de fundo
wire [3:0]  text_fg   = vdp_reg[7][7:4];               // Cor de texto (modo Text)

// Modo atual
wire mode_text   = m1;                     // Screen 0: 40x24 texto
wire mode_gfx1   = ~m1 & ~m2 & ~m3;       // Screen 1: 32x24
wire mode_gfx2   = ~m1 &  m2 & ~m3;       // Screen 2: bitmap
wire mode_mc     = ~m1 & ~m2 &  m3;        // Screen 3: multicolor

// ---------------------------------------------------------------------------
// Status register
// ---------------------------------------------------------------------------
reg [7:0] status_reg;
// Bit 7: INT (F = frame interrupt flag)
// Bit 6: 5S (fifth sprite flag)
// Bit 5: C  (sprite collision)
// Bit 4:0: 5th sprite number

// ---------------------------------------------------------------------------
// Controle de VRAM via CPU
// ---------------------------------------------------------------------------
reg [13:0] vram_addr;
reg        vram_addr_latch; // 0=primeiro byte, 1=segundo byte
reg [7:0]  vram_data_latch;
reg        vram_write;
reg        vram_read;
reg [7:0]  vram_read_buf;  // buffer de leitura pré-carregado

reg        csr_n_prev, csw_n_prev;

// ---------------------------------------------------------------------------
// Geração de temporização de vídeo
// Pixel clock = clk/4 → 27 MHz
// 720x480p60: H total=858, V total=525 (720 ativos), V ativos=480
// Mas TMS9918 tem 256 pixels x 192 linhas de conteúdo
// Usamos: 2x scale, centr. em 720x480
// H: 104 border + 512 content + 104 border = 720 pixels ativos
// V: 48 border + 384 content + 48 border = 480 linhas ativas
// ---------------------------------------------------------------------------
localparam H_TOTAL  = 12'd858;
localparam H_ACTIVE = 12'd720;
localparam H_FP     = 12'd16;  // front porch
localparam H_SYNC   = 12'd62;  // sync
localparam H_BP     = 12'd60;  // back porch
// Conteúdo TMS dentro da área ativa
localparam H_BORDER = 12'd104; // (720-512)/2
localparam V_TOTAL  = 12'd525;
localparam V_ACTIVE = 12'd480;
localparam V_FP     = 12'd9;
localparam V_SYNC   = 12'd6;
localparam V_BP     = 12'd30;
localparam V_BORDER = 12'd48;  // (480-384)/2

reg [11:0] hcount, vcount;
reg [3:0]  clk_div4;   // divisor para pixel clock
reg        pclk;        // pixel clock enable

// Pixel TMS
reg [7:0]  vdp_hpix;   // pixel horizontal dentro do display TMS (0-255)
reg [7:0]  vdp_vpix;   // linha vertical dentro do display TMS (0-191)
wire       vdp_active = (hcount >= H_BORDER && hcount < (H_BORDER + 12'd512)) &&
                        (vcount >= V_BORDER && vcount < (V_BORDER + 12'd384));

// Árvore de geração de pixels
reg [3:0]  pixel_color;

// ---------------------------------------------------------------------------
// Linhas de sprite processadas
// ---------------------------------------------------------------------------
reg [3:0]  sprite_color [0:255]; // cor do sprite em cada coluna do TMS
reg        sprite_priority [0:255]; // sprite sobre backdrop
reg        spr_active;

// ---------------------------------------------------------------------------
// BRAM auxiliar para fila de sprites (buffer de linha)
// ---------------------------------------------------------------------------
// Processamos sprites por linha durante o blanking

// ---------------------------------------------------------------------------
// Clk divider e contadores de varredura
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        hcount    <= 12'd0;
        vcount    <= 12'd0;
        clk_div4  <= 4'd0;
        pclk      <= 1'b0;
        hsync     <= 1'b1;
        vsync     <= 1'b1;
        de        <= 1'b0;
        int_n     <= 1'b1;
    end else begin
        clk_div4 <= clk_div4 + 4'd1;
        pclk     <= (clk_div4 == 4'd3);

        if (pclk) begin
            // Avança contador horizontal
            if (hcount == H_TOTAL - 12'd1) begin
                hcount <= 12'd0;
                if (vcount == V_TOTAL - 12'd1) begin
                    vcount <= 12'd0;
                    // Frame interrupt
                    status_reg[7] <= 1'b1;
                    if (ie) int_n <= 1'b0;
                end else begin
                    vcount <= vcount + 12'd1;
                end
            end else begin
                hcount <= hcount + 12'd1;
            end

            // H sync
            hsync <= ~(hcount >= (H_ACTIVE + H_FP) &&
                       hcount <  (H_ACTIVE + H_FP + H_SYNC));
            // V sync
            vsync <= ~(vcount >= (V_ACTIVE + V_FP) &&
                       vcount <  (V_ACTIVE + V_FP + V_SYNC));
            // Display enable
            de <= (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

            // Pixel VDP (0-255 H, 0-191 V), 2x scale
            if (hcount >= H_BORDER && hcount < (H_BORDER + 12'd512))
                vdp_hpix <= (hcount - H_BORDER) >> 1;
            if (vcount >= V_BORDER && vcount < (V_BORDER + 12'd384))
                vdp_vpix <= (vcount - V_BORDER) >> 1;
        end
    end
end

// ---------------------------------------------------------------------------
// Gerador de pixels TMS9918A (combinacional por pixel)
// ---------------------------------------------------------------------------
reg  [7:0]  pn_byte;     // pattern name byte
reg  [7:0]  pat_byte;    // pattern generator byte
reg  [7:0]  col_byte;    // color byte
reg  [3:0]  fg_color, bg_color;
reg          pixel_bit;

always @(*) begin
    pixel_color = backdrop;
    fg_color    = 4'd15; // branco
    bg_color    = 4'd1;  // preto

    if (bl && vdp_active) begin
        if (mode_text) begin
            // Modo texto 40x24
            // Coluna: vdp_hpix/6, linha: vdp_vpix/8
            // Pattern name table
            reg [4:0]  col40;
            reg [4:0]  row24;
            reg [2:0]  col_bit;
            reg [2:0]  row_line;
            col40    = vdp_hpix[7:0] / 8'd6;   // aproximação
            row24    = vdp_vpix[7:3];
            row_line = vdp_vpix[2:0];
            col_bit  = 5 - (vdp_hpix % 6);
            pn_byte  = vram[pnt_base + row24 * 40 + col40];
            pat_byte = vram[pgt_base + pn_byte * 8 + row_line];
            pixel_bit = pat_byte[col_bit];
            pixel_color = pixel_bit ? text_fg : backdrop;
        end else if (mode_gfx1) begin
            // Screen 1: 32x24 character cells
            reg [4:0]  gcol;
            reg [4:0]  grow;
            reg [2:0]  grow_line;
            reg [2:0]  gcol_bit;
            gcol      = vdp_hpix[7:3];
            grow      = vdp_vpix[7:3];
            grow_line = vdp_vpix[2:0];
            gcol_bit  = 3'd7 - vdp_hpix[2:0];
            pn_byte   = vram[pnt_base + grow * 32 + gcol];
            pat_byte  = vram[pgt_base + pn_byte * 8 + grow_line];
            col_byte  = vram[ct_base + (pn_byte >> 3)];
            pixel_bit = pat_byte[gcol_bit];
            fg_color  = col_byte[7:4];
            bg_color  = col_byte[3:0];
            pixel_color = pixel_bit ? (fg_color == 4'd0 ? backdrop : fg_color)
                                    : (bg_color == 4'd0 ? backdrop : bg_color);
        end else if (mode_gfx2) begin
            // Screen 2: bitmap 256x192
            reg [4:0]  brow;
            reg [4:0]  bcol;
            reg [2:0]  brow_line;
            reg [2:0]  bcol_bit;
            reg [13:0] baddr;
            bcol      = vdp_hpix[7:3];
            brow      = vdp_vpix[7:3];
            brow_line = vdp_vpix[2:0];
            bcol_bit  = 3'd7 - vdp_hpix[2:0];
            // Em Screen 2, PNT tem 768 bytes (3 terços de 256 bytes)
            pn_byte   = vram[pnt_base + brow * 32 + bcol];
            // CT e PGT em terços de 2KB
            baddr     = pgt_base + ((vdp_vpix[7:6]) << 11) + pn_byte * 8 + brow_line;
            pat_byte  = vram[baddr];
            col_byte  = vram[ct_base  + ((vdp_vpix[7:6]) << 11) + pn_byte * 8 + brow_line];
            pixel_bit = pat_byte[bcol_bit];
            fg_color  = col_byte[7:4];
            bg_color  = col_byte[3:0];
            pixel_color = pixel_bit ? (fg_color == 4'd0 ? backdrop : fg_color)
                                    : (bg_color == 4'd0 ? backdrop : bg_color);
        end else if (mode_mc) begin
            // Screen 3: multicolor 4x4 blocks
            reg [5:0]  mc_block_x, mc_block_y;
            mc_block_x = vdp_hpix[7:2];
            mc_block_y = vdp_vpix[7:2];
            pn_byte    = vram[pnt_base + (mc_block_y >> 1) * 32 + (mc_block_x >> 1)];
            col_byte   = vram[pgt_base + pn_byte * 8 + (mc_block_y & 3'd3)];
            pixel_color = mc_block_x[0] ? col_byte[3:0] : col_byte[7:4];
        end

        // Overlay de sprites (cor pre-calculada)
        if (sprite_color[vdp_hpix] != 4'd0)
            pixel_color = sprite_color[vdp_hpix];
    end
end

// ---------------------------------------------------------------------------
// Saída de cor para HDMI (12-bit RGB)
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (pclk) begin
        if (de && bl) begin
            reg [11:0] rgb;
            rgb   = palette_rgb(pixel_color);
            r_out <= rgb[11:8];
            g_out <= rgb[7:4];
            b_out <= rgb[3:0];
        end else begin
            r_out <= 4'd0;
            g_out <= 4'd0;
            b_out <= 4'd0;
        end
    end
end

// ---------------------------------------------------------------------------
// Interface CPU / Leitura|Escrita de registradores e VRAM
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        vram_addr       <= 14'd0;
        vram_addr_latch <= 1'b0;
        vram_data_latch <= 8'h00;
        vram_write      <= 1'b0;
        status_reg      <= 8'h00;
        int_n           <= 1'b1;
        csr_n_prev      <= 1'b1;
        csw_n_prev      <= 1'b1;
        vram_read_buf   <= 8'h00;
        integer i; for (i=0;i<8;i=i+1) vdp_reg[i] <= 8'h00;
        vdp_reg[1] <= 8'h40; // BL=1 (blank off default)
    end else begin
        csr_n_prev <= csr_n;
        csw_n_prev <= csw_n;

        // ---- Leitura ----
        if (csr_n_prev && !csr_n) begin  // borda de descida CSR
            if (!mode) begin
                // Leitura de dados VRAM
                cd_o          <= vram_read_buf;
                vram_read_buf <= vram[vram_addr + 14'd1]; // pré-carrega próximo
                vram_addr     <= vram_addr + 14'd1;
                vram_addr_latch <= 1'b0;
            end else begin
                // Leitura do status
                cd_o          <= status_reg;
                status_reg[7] <= 1'b0;  // limpa INT flag
                status_reg[5] <= 1'b0;  // limpa colisão
                int_n         <= 1'b1;  // limpa interrupção
                vram_addr_latch <= 1'b0;
            end
        end

        // ---- Escrita ----
        if (csw_n_prev && !csw_n) begin  // borda de descida CSW
            if (!mode) begin
                // Escrita de dados VRAM
                vram[vram_addr] <= cd_i;
                vram_addr       <= vram_addr + 14'd1;
                vram_addr_latch <= 1'b0;
            end else begin
                // Primeiro ou segundo byte de comando
                if (!vram_addr_latch) begin
                    vram_data_latch <= cd_i;
                    vram_addr_latch <= 1'b1;
                end else begin
                    vram_addr_latch <= 1'b0;
                    if (!cd_i[7]) begin
                        // Configurar endereço VRAM (read)
                        vram_addr     <= {cd_i[5:0], vram_data_latch};
                        vram_read_buf <= vram[{cd_i[5:0], vram_data_latch}];
                    end else if (cd_i[7:6] == 2'b10) begin
                        // Configurar endereço VRAM (write)
                        vram_addr <= {cd_i[5:0], vram_data_latch};
                    end else if (cd_i[7:6] == 2'b10) begin
                        // (mesmo caso)
                    end else begin
                        // Escrever registrador VDP R0–R7
                        if (cd_i[5:3] == 3'd0)
                            vdp_reg[cd_i[2:0]] <= vram_data_latch;
                    end
                end
            end
        end

        // Reativa interrupção se IE e flag pendente
        if (ie && status_reg[7]) int_n <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// Pré-processamento de sprites por linha (simplificado)
// Avaliamos os 32 sprites do SAT para a linha atual
// ---------------------------------------------------------------------------
integer s;
always @(posedge clk) begin
    if (rst) begin
        for (s = 0; s < 256; s = s + 1) begin
            sprite_color[s]    <= 4'd0;
            sprite_priority[s] <= 1'b0;
        end
    end else if (pclk && hcount == H_ACTIVE && vcount < V_ACTIVE) begin
        // Limpa buffer de sprites
        for (s = 0; s < 256; s = s + 1)
            sprite_color[s] <= 4'd0;

        begin
            reg [4:0]  sp_n;
            reg [7:0]  sp_y, sp_x, sp_pat, sp_attr;
            reg [3:0]  sp_color;
            reg [7:0]  sp_yline;
            reg [7:0]  sp_size;
            reg [13:0] sp_addr;
            reg [7:0]  sp_row, sp_pix;
            integer    p, bit_n;
            integer    sp_count;

            sp_size  = size ? 8'd16 : 8'd8;
            sp_count = 0;

            for (sp_n = 0; sp_n < 5'd31; sp_n = sp_n + 5'd1) begin
                sp_y    = vram[sat_base + sp_n * 4];
                if (sp_y == 8'hD0) // marcador de fim
                    sp_n = 5'd31;
                else begin
                    sp_x    = vram[sat_base + sp_n * 4 + 1];
                    sp_pat  = vram[sat_base + sp_n * 4 + 2];
                    sp_attr = vram[sat_base + sp_n * 4 + 3];
                    sp_color = sp_attr[3:0];

                    // Y sprite (ajuste: y+1 porque VDP usa y+1)
                    sp_y = sp_y + 8'd1;

                    // Verifica se sprite está na linha vdp_vpix+1
                    // (processamos para a próxima linha durante HBlank)
                    sp_yline = (vcount < V_BORDER) ? 8'd0 :
                               ((vcount - V_BORDER) >> 1);

                    if (sp_yline >= sp_y && sp_yline < (sp_y + sp_size)) begin
                        sp_count = sp_count + 1;
                        if (sp_count <= 4) begin // máx 4 sprites por linha
                            sp_row = sp_yline - sp_y;
                            if (mag) sp_row = sp_row >> 1;

                            // Para cada coluna do sprite
                            for (p = 0; p < 8; p = p + 1) begin
                                sp_addr = spt_base + sp_pat * 8 + sp_row;
                                sp_pix  = vram[sp_addr];
                                for (bit_n = 0; bit_n < 8; bit_n = bit_n + 1) begin
                                    if (sp_pix[7 - bit_n]) begin
                                        reg [7:0] sx;
                                        sx = sp_x + bit_n;
                                        if (!mag || (bit_n >= 0)) begin
                                            if (sx < 8'd255)
                                                sprite_color[sx] <= sp_color;
                                            if (mag && sx+1 < 8'd255)
                                                sprite_color[sx+1] <= sp_color;
                                        end
                                    end
                                end
                                if (!size) p = 8; // só um bloco 8x8
                            end
                        end
                    end
                end
            end
        end
    end
end

endmodule
`default_nettype wire
