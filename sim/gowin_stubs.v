// Behavioral stand-ins for the Gowin primitives, for simulation only.
// (Gowin's own prim_sim.v also works but is not redistributable.)
`timescale 1ns/1ps

module rPLL #(
    parameter FCLKIN = "27", parameter DEVICE = "", parameter DYN_IDIV_SEL = "false",
    parameter IDIV_SEL = 0, parameter DYN_FBDIV_SEL = "false", parameter FBDIV_SEL = 0,
    parameter DYN_ODIV_SEL = "false", parameter ODIV_SEL = 8, parameter PSDA_SEL = "0000",
    parameter DYN_DA_EN = "false", parameter DUTYDA_SEL = "1000", parameter CLKOUT_FT_DIR = 1'b1,
    parameter CLKOUTP_FT_DIR = 1'b1, parameter CLKOUT_DLY_STEP = 0, parameter CLKOUTP_DLY_STEP = 0,
    parameter CLKFB_SEL = "internal", parameter CLKOUT_BYPASS = "false",
    parameter CLKOUTP_BYPASS = "false", parameter CLKOUTD_BYPASS = "false",
    parameter DYN_SDIV_SEL = 2, parameter CLKOUTD_SRC = "CLKOUT", parameter CLKOUTD3_SRC = "CLKOUT"
) (
    output reg CLKOUT, output reg LOCK, output CLKOUTP, output CLKOUTD, output CLKOUTD3,
    input RESET, input RESET_P, input CLKIN, input CLKFB,
    input [5:0] FBDSEL, input [5:0] IDSEL, input [5:0] ODSEL,
    input [3:0] PSDA, input [3:0] DUTYDA, input [3:0] FDLY
);
    // 27 MHz * (FBDIV_SEL+1) / (IDIV_SEL+1); only 135 MHz is used here
    real half = 1000.0 / (27.0 * (FBDIV_SEL + 1) / (IDIV_SEL + 1)) / 2.0;
    initial begin
        CLKOUT = 1'b0; LOCK = 1'b0;
        #200 LOCK = 1'b1;
    end
    always #(half) CLKOUT = ~CLKOUT;
    assign CLKOUTP = CLKOUT, CLKOUTD = 1'b0, CLKOUTD3 = 1'b0;
endmodule

module CLKDIV #(parameter DIV_MODE = "5", parameter GSREN = "false")
    (output reg CLKOUT, input HCLKIN, input RESETN, input CALIB);
    reg [2:0] n = 0;
    initial CLKOUT = 1'b0;
    always @(posedge HCLKIN or negedge HCLKIN) begin   // /5 needs both edges
        if (n == 3'd4) begin n <= 0; CLKOUT <= ~CLKOUT; end
        else n <= n + 1;
    end
endmodule

module OSER10 (output Q, input D0, D1, D2, D3, D4, D5, D6, D7, D8, D9,
               input PCLK, input FCLK, input RESET);
    assign Q = D0;
endmodule

module ELVDS_OBUF (input I, output O, output OB);
    assign O = I;
    assign OB = ~I;
endmodule
