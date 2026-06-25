// =============================================================================
// Intel 8255 PPI — Interface de Periférico Programável para MSX1
// Porta A: bits 7:6=page3_slot, 5:4=page2_slot, 3:2=page1_slot, 1:0=page0_slot
// Porta B: leitura de coluna do teclado
// Porta C: bits 3:0 = linha de teclado; bit 4 = cassete; bit 5 = CAS motor
//          bit 6 = Caps Lock; bit 7 = Click
// =============================================================================
`default_nettype none

module ppi8255 (
    input        clk,
    input        rst,
    // Barramento CPU
    input  [1:0] a,        // A1:A0 — seleciona porta (0=A,1=B,2=C,3=ctrl)
    input  [7:0] d_in,
    output reg [7:0] d_out,
    input        cs_n,
    input        rd_n,
    input        wr_n,
    // Portas externas
    output reg [7:0] port_a,   // Seleção de slot por página
    input      [7:0] port_b_i, // Dados do teclado (colunas)
    output reg [3:0] port_c_lo, // Seleção de linha do teclado (bits 3:0)
    output reg       cap_led,   // Caps Lock LED
    output reg       cas_out,   // Cassete output
    output reg       cas_motor  // Motor cassete
);

reg [7:0] ctrl_word;
reg [7:0] port_b_latch;

always @(posedge clk) begin
    if (rst) begin
        port_a      <= 8'h00;
        port_c_lo   <= 4'hF;
        ctrl_word   <= 8'h9B; // modo 0, A/B/C saída
        cap_led     <= 1'b0;
        cas_out     <= 1'b0;
        cas_motor   <= 1'b0;
    end else begin
        if (!cs_n && !wr_n) begin
            case (a)
                2'd0: port_a    <= d_in;
                2'd1: ;          // Porta B é entrada
                2'd2: begin
                    port_c_lo <= d_in[3:0];
                    cap_led   <= d_in[6];
                    cas_out   <= d_in[4]; // bit 4 = CAS saída
                    cas_motor <= ~d_in[5]; // bit 5 = CAS motor (invertido)
                end
                2'd3: begin
                    if (d_in[7]) begin
                        ctrl_word <= d_in;
                    end else begin
                        // Bit set/reset de porta C
                        reg [2:0] bit_sel;
                        bit_sel = d_in[3:1];
                        case (bit_sel)
                            3'd0: port_c_lo[0] <= d_in[0];
                            3'd1: port_c_lo[1] <= d_in[0];
                            3'd2: port_c_lo[2] <= d_in[0];
                            3'd3: port_c_lo[3] <= d_in[0];
                            3'd4: cas_out <= d_in[0];
                            3'd5: cas_motor <= ~d_in[0];
                            3'd6: cap_led <= d_in[0];
                            default: ;
                        endcase
                    end
                end
            endcase
        end

        if (!cs_n && !rd_n) begin
            case (a)
                2'd0: d_out <= port_a;
                2'd1: d_out <= port_b_i;  // Lê dados do teclado
                2'd2: d_out <= {cap_led, 1'b0, cas_motor, cas_out, port_c_lo};
                2'd3: d_out <= ctrl_word;
            endcase
        end
    end
end

endmodule
`default_nettype wire
