// =============================================================================
// DAC Sigma-Delta (PDM) — converte sinal digital 10-bit em saída PWM/PDM
// Para saída de áudio via pino de I/O com filtro RC externo
// Frequência de chaveamento: 108 MHz / 1 = 108 MHz (oversampling)
// =============================================================================
`default_nettype none

module pdm_dac (
    input        clk,    // 108 MHz
    input        rst,
    input [9:0]  data,   // dado de entrada 10-bit (0 a 1023)
    output       pdm     // saída PDM
);

reg [10:0] acc;

always @(posedge clk) begin
    if (rst)
        acc <= 11'd0;
    else
        acc <= acc + {1'b0, data};
end

assign pdm = acc[10];

endmodule
`default_nettype wire
