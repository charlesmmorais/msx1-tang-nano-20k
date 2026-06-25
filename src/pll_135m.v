// =============================================================================
// PLL Gowin rPLL — 27 MHz → 135 MHz (TMDS serial clock = 5x pixel clock)
// GW2AR-18 Tang Nano 20K
// =============================================================================
module pll_135m (
    input  clkin,    // 27 MHz
    output clkout,   // 135 MHz
    output lock
);

rPLL #(
    .FCLKIN      ("27"),
    .DEVICE      ("GW2AR-18C"),
    .DYN_IDIV_SEL("false"),
    .IDIV_SEL    (0),       // IDIV = 0 → divisor = 1
    .DYN_FBDIV_SEL("false"),
    .FBDIV_SEL   (4),       // FBDIV = 4 → multiplicador = 5
    .DYN_ODIV_SEL("false"),
    .ODIV_SEL    (2),       // ODIV = 2 → Fout = 27*5/1/2 = 67.5... 
    // Fout = Fin*(FBDIV+1)/((IDIV+1)*ODIV) = 27*5/(1*1) = 135 se ODIV_SEL=1
    // Mas mínimo ODIV_SEL para GW2AR é 2. Então FBDIV=9, ODIV=2:
    // 27*10/2 = 135 MHz ✓
    .FBDIV_SEL   (9),
    .ODIV_SEL    (2),
    .CLKFB_SEL   ("internal"),
    .CLKOUT_BYPASS("false"),
    .CLKIN_BYPASS ("false"),
    .GMCMODE     (1'b0),
    .FREQ_LOCK_WAIT(2),
    .FREQ_LOCK_ADDON(0)
) pll (
    .CLKIN  (clkin),
    .CLKOUT (clkout),
    .LOCK   (lock),
    .CLKFB  (1'b0),
    .RESET  (1'b0),
    .RESET_P(1'b0),
    .FBDSEL (6'd0),
    .IDSEL  (6'd0),
    .ODSEL  (6'd0),
    .PSDA   (4'd0),
    .DUTYDA (4'd0),
    .FDLY   (4'd0)
);

endmodule
