// =============================================================================
// SPI Master — interface de baixo nível para SD card no modo SPI
// CLK divisor: clock_sistema / (2*(div+1))
// =============================================================================
`default_nettype none

module spi_master (
    input         clk,
    input         rst,
    // Configuração
    input  [7:0]  div,      // Divisor de clock (0=máx velocidade)
    // Interface de transferência
    input         start,    // Inicia transferência
    input  [7:0]  tx_data,
    output reg [7:0] rx_data,
    output reg    busy,
    output reg    done,
    // Pinos SPI
    output reg    spi_clk,
    output reg    spi_mosi,
    input         spi_miso,
    output reg    spi_cs_n
);

reg [7:0]  div_cnt;
reg [7:0]  shift_reg;
reg [3:0]  bit_cnt;
reg        clk_phase;

always @(posedge clk) begin
    if (rst) begin
        spi_clk  <= 1'b0;
        spi_mosi <= 1'b1;
        spi_cs_n <= 1'b1;
        busy     <= 1'b0;
        done     <= 1'b0;
        div_cnt  <= 8'd0;
        bit_cnt  <= 4'd0;
        shift_reg<= 8'hFF;
        rx_data  <= 8'hFF;
        clk_phase<= 1'b0;
    end else begin
        done <= 1'b0;

        if (!busy && start) begin
            shift_reg <= tx_data;
            bit_cnt   <= 4'd8;
            busy      <= 1'b1;
            div_cnt   <= div;
            spi_cs_n  <= 1'b0;
        end else if (busy) begin
            if (div_cnt == 8'd0) begin
                div_cnt   <= div;
                clk_phase <= ~clk_phase;

                if (!clk_phase) begin
                    // Borda de subida: amostrar MISO
                    spi_clk  <= 1'b1;
                    rx_data  <= {rx_data[6:0], spi_miso};
                end else begin
                    // Borda de descida: alterar MOSI
                    spi_clk  <= 1'b0;
                    if (bit_cnt > 4'd0) begin
                        spi_mosi  <= shift_reg[7];
                        shift_reg <= {shift_reg[6:0], 1'b0};
                        bit_cnt   <= bit_cnt - 4'd1;
                        if (bit_cnt == 4'd1) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                        end
                    end
                end
            end else div_cnt <= div_cnt - 8'd1;
        end
    end
end

endmodule
`default_nettype wire
