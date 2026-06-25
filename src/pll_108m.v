// =============================================================================
// PLL Gowin rPLL — 27 MHz → 108 MHz (clock sistema)
// GW2AR-18 Tang Nano 20K
// =============================================================================
module pll_108m (
    input  clkin,    // 27 MHz
    output clkout,   // 108 MHz
    output lock
);

rPLL #(
    .FCLKIN    ("27"),
    .DEVICE    ("GW2AR-18C"),
    .DYN_IDIV_SEL("false"),
    .IDIV_SEL  (0),
    .DYN_FBDIV_SEL("false"),
    .FBDIV_SEL (3),    // VCO = 27*(3+1) = 108 MHz
    .DYN_ODIV_SEL("false"),
    .ODIV_SEL  (2),    // OUT = VCO/2 ... não. OUT = 108 com ODIV=2 → 54? 
    // Gowin rPLL: Fout = Fin * (FBDIV+1) / ((IDIV+1) * ODIV)
    // 27 * 4 / (1 * 1) = 108 MHz, ODIV_SEL deve ser mínimo 2
    // Ajuste: FBDIV=7, IDIV=1, ODIV=2 → 27*8/(2*2) = 54 MHz (errado)
    // Correto: FBDIV=7, IDIV=0, ODIV=2 → 27*8/2 = 108 MHz ✓
    .FBDIV_SEL (7),   // override: 27*(7+1)/(0+1)/2 = 108 MHz
    .IDIV_SEL  (0),
    .ODIV_SEL  (2),
    .CLKOUT_FT_DIR (1'b1),
    .CLKOUT_DLY_STEP(0),
    .CLKFB_SEL ("internal"),
    .CLKOUT_BYPASS("false"),
    .CLKIN_BYPASS("false"),
    .GMCMODE(1'b0),
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
