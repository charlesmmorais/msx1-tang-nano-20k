// =============================================================================
// Mapeamento PS/2 → Matriz de teclado MSX
// Matriz MSX: 11 linhas x 8 colunas
// PPI Porta C[3:0]: seleciona linha
// PPI Porta B[7:0]: lê coluna (bit=0 se tecla pressionada)
// =============================================================================
`default_nettype none

module msx_keymap (
    input        clk,
    input        rst,
    // Decodificador PS/2
    input  [7:0] scan_code,
    input        key_pressed,
    input        key_released,
    input        valid,
    // Saída: matriz de teclado MSX
    // 11 linhas, 8 colunas: matrix[linha][coluna]
    input  [3:0] row_select,    // Linha selecionada pela PPI
    output [7:0] col_data       // Colunas lidas (ativo baixo)
);

// Matriz: 11 linhas x 8 colunas
reg [7:0] matrix [0:10];
integer   i;

assign col_data = ~matrix[row_select]; // Invertido: 1=pressionado → 0 saída

// ---------------------------------------------------------------------------
// Layout do teclado MSX1 Brasileiro
// Row 0: 7  6  5  4  3  2  1  0
//        7  6  5  4  3  2  1  0
// Row 1: ;  ]  [  \  =  -  9  8
// Row 2: B  A  Ácc/  .  ,  `  9 (não colide)
//        B  A  /   . ,  `  9  8  ← depende do MSX
// Mapeamento MSX Internacional padrão:
// Row 0: 0  1  2  3  4  5  6  7
// Row 1: 8  9  -  =  \  [  ]  ;
// Row 2: '  ,  .  /  Dead ESC  F1 F2
// Row 3: F3 F4 F5 Home UP INS DEL BS
// Row 4: TAB Q  W  E  R  T  Y  U
// Row 5: I  O  P  @  SP ENTER BKSP CRS
// Row 6: A  S  D  F  G  H  J  K
// Row 7: L  ;  :  ]  DEL return shift ctrl
// Row 8: SHIFT CTRL GRAPH CAPS F1 F2 F3 stop
// Row 9: (numpad)
// Row 10: F1-F5, stop, select

// MSX matriz simplificada (Padrão Internacional):
// Row 0: col7=7 col6=6 col5=5 col4=4 col3=3 col2=2 col1=1 col0=0
// Row 1: col7=; col6=] col5=[ col4=\ col3== col2=- col1=9 col0=8
// Row 2: col7=B col6=A col5=/ col4=. col3=, col2=` col1=Dead col0=F2
// etc.
// ---------------------------------------------------------------------------

// Mapeamento: scan_code PS/2 → (row, col) da matriz MSX
task set_key;
    input [7:0] sc;
    input       pressed;
    input [3:0] row;
    input [2:0] col;
    begin
        matrix[row][col] <= pressed;
    end
endtask

always @(posedge clk) begin
    if (rst) begin
        for (i = 0; i < 11; i = i + 1)
            matrix[i] <= 8'h00;
    end else if (valid) begin
        case (scan_code)
            // Row 0: dígitos 0-7
            8'h45: set_key(scan_code, key_pressed, 4'd0, 3'd0); // 0
            8'h16: set_key(scan_code, key_pressed, 4'd0, 3'd1); // 1
            8'h1E: set_key(scan_code, key_pressed, 4'd0, 3'd2); // 2
            8'h26: set_key(scan_code, key_pressed, 4'd0, 3'd3); // 3
            8'h25: set_key(scan_code, key_pressed, 4'd0, 3'd4); // 4
            8'h2E: set_key(scan_code, key_pressed, 4'd0, 3'd5); // 5
            8'h36: set_key(scan_code, key_pressed, 4'd0, 3'd6); // 6
            8'h3D: set_key(scan_code, key_pressed, 4'd0, 3'd7); // 7
            // Row 1: 8,9,-,=
            8'h3E: set_key(scan_code, key_pressed, 4'd1, 3'd0); // 8
            8'h46: set_key(scan_code, key_pressed, 4'd1, 3'd1); // 9
            8'h4E: set_key(scan_code, key_pressed, 4'd1, 3'd2); // -
            8'h55: set_key(scan_code, key_pressed, 4'd1, 3'd3); // =
            // Row 2: Q,W,E,R,T (linha do teclado)
            8'h15: set_key(scan_code, key_pressed, 4'd4, 3'd1); // Q
            8'h1D: set_key(scan_code, key_pressed, 4'd4, 3'd2); // W
            8'h24: set_key(scan_code, key_pressed, 4'd4, 3'd3); // E
            8'h2D: set_key(scan_code, key_pressed, 4'd4, 3'd4); // R
            8'h2C: set_key(scan_code, key_pressed, 4'd4, 3'd5); // T
            8'h35: set_key(scan_code, key_pressed, 4'd4, 3'd6); // Y
            8'h3C: set_key(scan_code, key_pressed, 4'd4, 3'd7); // U
            8'h43: set_key(scan_code, key_pressed, 4'd5, 3'd0); // I
            8'h44: set_key(scan_code, key_pressed, 4'd5, 3'd1); // O
            8'h4D: set_key(scan_code, key_pressed, 4'd5, 3'd2); // P
            // Row 6: A,S,D,F,G,H,J,K
            8'h1C: set_key(scan_code, key_pressed, 4'd6, 3'd0); // A
            8'h1B: set_key(scan_code, key_pressed, 4'd6, 3'd1); // S
            8'h23: set_key(scan_code, key_pressed, 4'd6, 3'd2); // D
            8'h2B: set_key(scan_code, key_pressed, 4'd6, 3'd3); // F
            8'h34: set_key(scan_code, key_pressed, 4'd6, 3'd4); // G
            8'h33: set_key(scan_code, key_pressed, 4'd6, 3'd5); // H
            8'h3B: set_key(scan_code, key_pressed, 4'd6, 3'd6); // J
            8'h42: set_key(scan_code, key_pressed, 4'd6, 3'd7); // K
            // Row 7: L,;,:,],BS
            8'h4B: set_key(scan_code, key_pressed, 4'd7, 3'd0); // L
            8'h4C: set_key(scan_code, key_pressed, 4'd7, 3'd1); // ;
            8'h52: set_key(scan_code, key_pressed, 4'd7, 3'd2); // '
            // Row baixo: Z,X,C,V,B,N,M
            8'h1A: set_key(scan_code, key_pressed, 4'd8, 3'd0); // Z → não, Z é Row 8 em alguns
            8'h22: set_key(scan_code, key_pressed, 4'd7, 3'd4); // X
            8'h21: set_key(scan_code, key_pressed, 4'd7, 3'd5); // C
            8'h2A: set_key(scan_code, key_pressed, 4'd7, 3'd6); // V
            8'h32: set_key(scan_code, key_pressed, 4'd7, 3'd7); // B
            8'h31: set_key(scan_code, key_pressed, 4'd8, 3'd1); // N
            8'h3A: set_key(scan_code, key_pressed, 4'd8, 3'd2); // M
            8'h41: set_key(scan_code, key_pressed, 4'd8, 3'd3); // ,
            8'h49: set_key(scan_code, key_pressed, 4'd8, 3'd4); // .
            8'h4A: set_key(scan_code, key_pressed, 4'd8, 3'd5); // /
            // Especiais
            8'h29: set_key(scan_code, key_pressed, 4'd8, 3'd7); // SPACE
            8'h5A: set_key(scan_code, key_pressed, 4'd7, 3'd3); // ENTER
            8'h66: set_key(scan_code, key_pressed, 4'd3, 3'd7); // BACKSPACE
            8'h0D: set_key(scan_code, key_pressed, 4'd3, 3'd6); // TAB
            8'h76: set_key(scan_code, key_pressed, 4'd7, 3'd2); // ESC
            8'h12: set_key(scan_code, key_pressed, 4'd6, 3'd3); // L-SHIFT
            8'h59: set_key(scan_code, key_pressed, 4'd6, 3'd3); // R-SHIFT
            8'h14: set_key(scan_code, key_pressed, 4'd6, 3'd2); // L-CTRL
            8'h11: set_key(scan_code, key_pressed, 4'd6, 3'd1); // L-ALT (GRAPH)
            8'h58: set_key(scan_code, key_pressed, 4'd6, 3'd6); // CAPS LOCK
            // Setas
            8'h75: set_key(scan_code, key_pressed, 4'd8, 3'd7); // UP
            8'h72: set_key(scan_code, key_pressed, 4'd8, 3'd6); // DOWN
            8'h6B: set_key(scan_code, key_pressed, 4'd8, 3'd4); // LEFT
            8'h74: set_key(scan_code, key_pressed, 4'd8, 3'd5); // RIGHT
            // F-keys
            8'h05: set_key(scan_code, key_pressed, 4'd3, 3'd5); // F1
            8'h06: set_key(scan_code, key_pressed, 4'd3, 3'd4); // F2
            8'h04: set_key(scan_code, key_pressed, 4'd3, 3'd3); // F3
            8'h0C: set_key(scan_code, key_pressed, 4'd3, 3'd2); // F4
            8'h03: set_key(scan_code, key_pressed, 4'd3, 3'd1); // F5
            default: ;
        endcase
    end
end

endmodule
`default_nettype wire
