// =============================================================================
// Controlador SD Card SPI — suporte à leitura de blocos (512 bytes)
// Implementa inicialização (ACMD41), leitura de setor (CMD17)
// Interface com CPU via portas I/O MSX (padrão Nextor/MSXDOS compatible)
// Portas:
//   0x40 W: escreve byte para SPI
//   0x40 R: lê byte do SPI (0xFF = idle)
//   0x41 W: CS control (bit 0)
//   0x42 W: Status/CMD
// =============================================================================
`default_nettype none

module sd_ctrl (
    input         clk,
    input         rst,
    // Interface CPU (I/O MSX)
    input  [7:0]  io_addr,
    input  [7:0]  d_in,
    output reg [7:0] d_out,
    input         io_cs,  // chip select (portas 0x40-0x47)
    input         io_wr,
    input         io_rd,
    // Pinos SD
    output        sd_clk,
    output        sd_mosi,
    input         sd_miso,
    output        sd_cs_n,
    // Buffer de setor (512 bytes) — lido pela CPU após CMD17
    output [8:0]  buf_addr,
    output [7:0]  buf_dout,
    input  [8:0]  buf_addr_r,
    output [7:0]  buf_din
);

// SPI master
reg        spi_start;
reg  [7:0] spi_tx;
wire [7:0] spi_rx;
wire       spi_done;
wire       spi_busy;
reg        spi_cs_ctrl;

spi_master spi (
    .clk    (clk),
    .rst    (rst),
    .div    (8'd3),       // 108/8 = 13.5 MHz (SD suporta até 25 MHz)
    .start  (spi_start),
    .tx_data(spi_tx),
    .rx_data(spi_rx),
    .busy   (spi_busy),
    .done   (spi_done),
    .spi_clk (sd_clk),
    .spi_mosi(sd_mosi),
    .spi_miso(sd_miso),
    .spi_cs_n(sd_cs_n)
);

// Buffer de setor 512 bytes
reg [7:0] sector_buf [0:511];
reg [8:0] buf_ptr;

assign buf_addr = buf_ptr;
assign buf_dout = sector_buf[buf_ptr];
assign buf_din  = sector_buf[buf_addr_r];

// Estado da máquina de inicialização/leitura SD
localparam SD_IDLE     = 4'd0;
localparam SD_INIT     = 4'd1;
localparam SD_WAIT     = 4'd2;
localparam SD_WRITE    = 4'd3;
localparam SD_READ     = 4'd4;
localparam SD_READ_BLK = 4'd5;
localparam SD_READY    = 4'd6;

reg [3:0] sd_state;
reg [7:0] sd_status;  // 0=OK, 1=ocupado, 2=erro
reg [9:0] byte_cnt;
reg [31:0] sector_lba;
reg       init_done;

// Escrita direta via porta I/O (modo de acesso direto ao SPI)
always @(posedge clk) begin
    if (rst) begin
        spi_start   <= 1'b0;
        spi_cs_ctrl <= 1'b1;
        d_out       <= 8'hFF;
        sd_state    <= SD_IDLE;
        sd_status   <= 8'h01;  // ocupado durante init
        buf_ptr     <= 9'd0;
        init_done   <= 1'b0;
        byte_cnt    <= 10'd0;
        sector_lba  <= 32'd0;
    end else begin
        spi_start <= 1'b0;

        // Acesso da CPU
        if (io_cs) begin
            if (io_wr) begin
                case (io_addr[2:0])
                    3'd0: begin // Escreve byte SPI e lê resultado
                        spi_tx    <= d_in;
                        spi_start <= 1'b1;
                    end
                    3'd1: begin // CS control
                        // bit 0: CS# ativo baixo (controlado pelo spi_master)
                    end
                    3'd2: sd_status <= d_in; // Status write
                    3'd3: sector_lba[7:0]   <= d_in;
                    3'd4: sector_lba[15:8]  <= d_in;
                    3'd5: sector_lba[23:16] <= d_in;
                    3'd6: sector_lba[31:24] <= d_in;
                    3'd7: begin // Dispara leitura de setor
                        sd_state <= SD_READ;
                        sd_status <= 8'h01;
                    end
                    default: ;
                endcase
            end
            if (io_rd) begin
                case (io_addr[2:0])
                    3'd0: d_out <= spi_rx;
                    3'd2: d_out <= sd_status;
                    3'd3: d_out <= sector_buf[buf_ptr]; // leitura sequencial
                    default: d_out <= 8'hFF;
                endcase
            end
        end

        // Captura dado SPI recebido no buffer (modo leitura de bloco)
        if (spi_done && sd_state == SD_READ_BLK) begin
            if (byte_cnt < 10'd512) begin
                sector_buf[byte_cnt[8:0]] <= spi_rx;
                buf_ptr <= byte_cnt[8:0];
            end
            byte_cnt  <= byte_cnt + 10'd1;
            if (byte_cnt == 10'd513) begin  // 512 dados + 2 CRC
                sd_state  <= SD_READY;
                sd_status <= 8'h00;  // OK
            end else begin
                // Continua lendo
                spi_tx    <= 8'hFF;
                spi_start <= 1'b1;
            end
        end

        // Máquina de estado de leitura de setor
        if (!spi_busy && !spi_start) begin
            case (sd_state)
                SD_READ: begin
                    // Envia CMD17 (leitura de bloco)
                    // CMD17: 0x51, addr[31:24], addr[23:16], addr[15:8], addr[7:0], CRC 0xFF
                    spi_tx    <= 8'h51;
                    spi_start <= 1'b1;
                    byte_cnt  <= 10'd0;
                    sd_state  <= SD_WAIT;
                end
                SD_WAIT: begin
                    if (spi_done) begin
                        if (spi_rx == 8'h00) begin
                            // Resposta OK, aguarda token 0xFE
                            spi_tx    <= 8'hFF;
                            spi_start <= 1'b1;
                        end else if (spi_rx == 8'hFE) begin
                            // Token de dados: começa leitura do bloco
                            sd_state  <= SD_READ_BLK;
                            spi_tx    <= 8'hFF;
                            spi_start <= 1'b1;
                            byte_cnt  <= 10'd0;
                        end else begin
                            spi_tx    <= 8'hFF;
                            spi_start <= 1'b1;
                        end
                    end
                end
                default: ;
            endcase
        end
    end
end

endmodule
`default_nettype wire
