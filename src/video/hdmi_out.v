// =============================================================================
// DVI/HDMI output for the Tang Nano 20K
// TMDS encode at the pixel clock, 10:1 serialize with OSER10 (DDR, so the
// serial clock is 5x pixel), differential output with ELVDS_OBUF.
// All inputs are in the clk_pix domain. clk_pix must come from CLKDIV(clk_5x).
// =============================================================================
`default_nettype none

module hdmi_out (
    input  wire       clk_pix,   // 27 MHz
    input  wire       clk_5x,    // 135 MHz
    input  wire       rst,
    input  wire [7:0] r,
    input  wire [7:0] g,
    input  wire [7:0] b,
    input  wire       hsync,     // already at the polarity the mode needs
    input  wire       vsync,
    input  wire       de,
    output wire       tmds_clk_p, tmds_clk_n,
    output wire [2:0] tmds_d_p,   // 0 = blue, 1 = green, 2 = red
    output wire [2:0] tmds_d_n
);

    wire [9:0] sym [0:2];

    tmds_encoder enc_b (.clk(clk_pix), .rst(rst), .data(b), .ctrl({vsync, hsync}), .de(de), .tmds(sym[0]));
    tmds_encoder enc_g (.clk(clk_pix), .rst(rst), .data(g), .ctrl(2'b00),          .de(de), .tmds(sym[1]));
    tmds_encoder enc_r (.clk(clk_pix), .rst(rst), .data(r), .ctrl(2'b00),          .de(de), .tmds(sym[2]));

    wire [2:0] ser;
    wire       ser_clk;

    genvar i;
    generate
        for (i = 0; i < 3; i = i + 1) begin : lane
            OSER10 ser10 (
                .Q    (ser[i]),
                .D0   (sym[i][0]), .D1(sym[i][1]), .D2(sym[i][2]), .D3(sym[i][3]), .D4(sym[i][4]),
                .D5   (sym[i][5]), .D6(sym[i][6]), .D7(sym[i][7]), .D8(sym[i][8]), .D9(sym[i][9]),
                .PCLK (clk_pix),
                .FCLK (clk_5x),
                .RESET(rst)
            );
            ELVDS_OBUF obuf (.I(ser[i]), .O(tmds_d_p[i]), .OB(tmds_d_n[i]));
        end
    endgenerate

    // TMDS clock lane: 5 ones, 5 zeros per pixel
    OSER10 ser_clk10 (
        .Q    (ser_clk),
        .D0   (1'b1), .D1(1'b1), .D2(1'b1), .D3(1'b1), .D4(1'b1),
        .D5   (1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0), .D9(1'b0),
        .PCLK (clk_pix),
        .FCLK (clk_5x),
        .RESET(rst)
    );
    ELVDS_OBUF obuf_clk (.I(ser_clk), .O(tmds_clk_p), .OB(tmds_clk_n));

endmodule
`default_nettype wire
