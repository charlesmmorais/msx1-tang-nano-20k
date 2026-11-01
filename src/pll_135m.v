// =============================================================================
// Clock generation — Tang Nano 20K (GW2AR-18C)
//
//   27 MHz crystal -> rPLL -> 135 MHz  (HDMI serial clock, 5x pixel, DDR)
//   135 MHz -> CLKDIV /5   -> 27 MHz   (pixel clock = whole-system clock)
//
// rPLL formula (Gowin UG286):
//   CLKOUT = FCLKIN * (FBDIV_SEL+1) / (IDIV_SEL+1) = 27 * 5 / 1 = 135 MHz
//   VCO    = CLKOUT * ODIV_SEL = 135 * 4 = 540 MHz  (valid: 500..1250 MHz)
//
// Taking the 27 MHz from CLKDIV (instead of the crystal) keeps it
// phase-aligned with the 135 MHz clock, which OSER10 requires.
// =============================================================================
module pll_135m (
    input  clkin,     // 27 MHz crystal
    output clk_5x,    // 135 MHz
    output clk_1x,    // 27 MHz, aligned with clk_5x
    output lock
);

    rPLL #(
        .FCLKIN          ("27"),
        .DEVICE          ("GW2AR-18C"),
        .DYN_IDIV_SEL    ("false"),
        .IDIV_SEL        (0),
        .DYN_FBDIV_SEL   ("false"),
        .FBDIV_SEL       (4),
        .DYN_ODIV_SEL    ("false"),
        .ODIV_SEL        (4),
        .PSDA_SEL        ("0000"),
        .DYN_DA_EN       ("false"),
        .DUTYDA_SEL      ("1000"),
        .CLKOUT_FT_DIR   (1'b1),
        .CLKOUTP_FT_DIR  (1'b1),
        .CLKOUT_DLY_STEP (0),
        .CLKOUTP_DLY_STEP(0),
        .CLKFB_SEL       ("internal"),
        .CLKOUT_BYPASS   ("false"),
        .CLKOUTP_BYPASS  ("false"),
        .CLKOUTD_BYPASS  ("false"),
        .DYN_SDIV_SEL    (2),
        .CLKOUTD_SRC     ("CLKOUT"),
        .CLKOUTD3_SRC    ("CLKOUT")
    ) pll (
        .CLKOUT  (clk_5x),
        .LOCK    (lock),
        .CLKOUTP (),
        .CLKOUTD (),
        .CLKOUTD3(),
        .RESET   (1'b0),
        .RESET_P (1'b0),
        .CLKIN   (clkin),
        .CLKFB   (1'b0),
        .FBDSEL  (6'd0),
        .IDSEL   (6'd0),
        .ODSEL   (6'd0),
        .PSDA    (4'd0),
        .DUTYDA  (4'd0),
        .FDLY    (4'd0)
    );

    CLKDIV #(
        .DIV_MODE("5"),
        .GSREN   ("false")
    ) div5 (
        .CLKOUT(clk_1x),
        .HCLKIN(clk_5x),
        .RESETN(lock),
        .CALIB (1'b0)
    );

endmodule
