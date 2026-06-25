// =============================================================================
// Decodificador de teclado PS/2
// Protocolo: 11 bits (1 start + 8 data + 1 parity + 1 stop)
// Clock PS/2: ~10-16.7 kHz, dados capturados na borda de descida do clock
// =============================================================================
`default_nettype none

module ps2_decoder (
    input        clk,
    input        rst,
    input        ps2_clk,
    input        ps2_dat,
    output reg [7:0] scan_code,
    output reg   key_pressed,   // 1 = tecla pressionada
    output reg   key_released,  // 1 = tecla liberada
    output reg   valid          // pulso de 1 ciclo com novo código
);

// Filtro de ruído no clock PS/2
reg [7:0] ps2_clk_filter;
reg       ps2_clk_f;

always @(posedge clk) begin
    ps2_clk_filter <= {ps2_clk_filter[6:0], ps2_clk};
    if (ps2_clk_filter == 8'hFF) ps2_clk_f <= 1'b1;
    else if (ps2_clk_filter == 8'h00) ps2_clk_f <= 1'b0;
end

reg ps2_clk_prev;
wire ps2_clk_fall = ps2_clk_prev && !ps2_clk_f;

always @(posedge clk) ps2_clk_prev <= ps2_clk_f;

// Receptor de 11 bits
reg [10:0] shift_reg;
reg [3:0]  bit_count;
reg        receiving;

// Detecção do código E0 (teclas extendidas)
reg        ext_code;
reg        release_code;  // Código F0 (release)

always @(posedge clk) begin
    if (rst) begin
        shift_reg    <= 11'd0;
        bit_count    <= 4'd0;
        receiving    <= 1'b0;
        scan_code    <= 8'h00;
        key_pressed  <= 1'b0;
        key_released <= 1'b0;
        valid        <= 1'b0;
        ext_code     <= 1'b0;
        release_code <= 1'b0;
    end else begin
        valid        <= 1'b0;
        key_pressed  <= 1'b0;
        key_released <= 1'b0;

        if (ps2_clk_fall) begin
            shift_reg  <= {ps2_dat, shift_reg[10:1]};
            bit_count  <= bit_count + 4'd1;

            if (bit_count == 4'd10) begin
                // Frame completo
                bit_count <= 4'd0;
                // Verifica start (bit 0 = 0) e stop (bit 10 = 1)
                if (shift_reg[0] == 1'b0 && ps2_dat == 1'b1) begin
                    reg [7:0] code;
                    code = shift_reg[8:1];

                    if (code == 8'hE0) begin
                        ext_code <= 1'b1;
                    end else if (code == 8'hF0) begin
                        release_code <= 1'b1;
                    end else begin
                        scan_code    <= code;
                        key_pressed  <= !release_code;
                        key_released <= release_code;
                        valid        <= 1'b1;
                        ext_code     <= 1'b0;
                        release_code <= 1'b0;
                    end
                end
            end
        end
    end
end

endmodule
`default_nettype wire
