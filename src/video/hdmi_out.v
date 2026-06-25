// =============================================================================
// Saída HDMI para Tang Nano 20K
// Usa OSER10 (serializer 10:1 da Gowin) e ELVDS_OBUF (diferencial LVDS)
// Pixel clock: 27 MHz (clk/4)
// TMDS clock: 135 MHz (clk_5x)
// =============================================================================
`default_nettype none

module hdmi_out (
    input         clk_pix,   // 27 MHz pixel clock
    input         clk_5x,    // 135 MHz serial clock (5x pixel)
    input         rst,
    // Dados de pixel
    input  [3:0]  r_in,
    input  [3:0]  g_in,
    input  [3:0]  b_in,
    input         hsync,
    input         vsync,
    input         de,
    // Saídas diferenciadas HDMI
    output        tmds_clk_p, tmds_clk_n,
    output        tmds_d0_p,  tmds_d0_n,   // azul
    output        tmds_d1_p,  tmds_d1_n,   // verde
    output        tmds_d2_p,  tmds_d2_n    // vermelho
);

// Expande 4-bit para 8-bit
wire [7:0] r8 = {r_in, r_in};
wire [7:0] g8 = {g_in, g_in};
wire [7:0] b8 = {b_in, b_in};

// Codificadores TMDS
wire [9:0] tmds_r, tmds_g, tmds_b;

tmds_encoder enc_r (.clk(clk_pix), .rst(rst), .data(r8), .ctrl(2'b00),         .de(de), .tmds(tmds_r));
tmds_encoder enc_g (.clk(clk_pix), .rst(rst), .data(g8), .ctrl(2'b00),         .de(de), .tmds(tmds_g));
tmds_encoder enc_b (.clk(clk_pix), .rst(rst), .data(b8), .ctrl({vsync,hsync}), .de(de), .tmds(tmds_b));

// Serialização 10:1 com OSER10 Gowin
wire tmds_clk_ser, tmds_d0_ser, tmds_d1_ser, tmds_d2_ser;

// OSER10 para clock TMDS (padrão de clock: 5'b11111_00000)
OSER10 ser_clk (
    .Q  (tmds_clk_ser),
    .D0 (1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1),
    .D5 (1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0),
    .PCLK(clk_pix), .FCLK(clk_5x), .RESET(rst)
);

OSER10 ser_d0 (
    .Q  (tmds_d0_ser),
    .D0(tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]), .D3(tmds_b[3]), .D4(tmds_b[4]),
    .D5(tmds_b[5]), .D6(tmds_b[6]), .D7(tmds_b[7]), .D8(tmds_b[8]), .D9(tmds_b[9]),
    .PCLK(clk_pix), .FCLK(clk_5x), .RESET(rst)
);

OSER10 ser_d1 (
    .Q  (tmds_d1_ser),
    .D0(tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]), .D3(tmds_g[3]), .D4(tmds_g[4]),
    .D5(tmds_g[5]), .D6(tmds_g[6]), .D7(tmds_g[7]), .D8(tmds_g[8]), .D9(tmds_g[9]),
    .PCLK(clk_pix), .FCLK(clk_5x), .RESET(rst)
);

OSER10 ser_d2 (
    .Q  (tmds_d2_ser),
    .D0(tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]), .D3(tmds_r[3]), .D4(tmds_r[4]),
    .D5(tmds_r[5]), .D6(tmds_r[6]), .D7(tmds_r[7]), .D8(tmds_r[8]), .D9(tmds_r[9]),
    .PCLK(clk_pix), .FCLK(clk_5x), .RESET(rst)
);

// Buffers diferenciados LVDS
ELVDS_OBUF obuf_clk (.I(tmds_clk_ser), .O(tmds_clk_p), .OB(tmds_clk_n));
ELVDS_OBUF obuf_d0  (.I(tmds_d0_ser),  .O(tmds_d0_p),  .OB(tmds_d0_n));
ELVDS_OBUF obuf_d1  (.I(tmds_d1_ser),  .O(tmds_d1_p),  .OB(tmds_d1_n));
ELVDS_OBUF obuf_d2  (.I(tmds_d2_ser),  .O(tmds_d2_p),  .OB(tmds_d2_n));

endmodule
`default_nettype wire
