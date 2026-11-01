// =============================================================================
// PS/2 (set 2) -> MSX keyboard matrix, international layout
//
//        bit7   bit6   bit5   bit4   bit3   bit2   bit1   bit0
// row 0   7      6      5      4      3      2      1      0
// row 1   ;      ]      [      \      =      -      9      8
// row 2   B      A      DEAD   /      .      ,      `      '
// row 3   J      I      H      G      F      E      D      C
// row 4   R      Q      P      O      N      M      L      K
// row 5   Z      Y      X      W      V      U      T      S
// row 6   F3     F2     F1     CODE   CAPS   GRAPH  CTRL   SHIFT
// row 7   RET    SELECT BS     STOP   TAB    ESC    F5     F4
// row 8   RIGHT  DOWN   UP     LEFT   DEL    INS    HOME   SPACE
//
// PC extras: Left Alt = GRAPH, Right Alt = CODE, F6 = SELECT, F7 = STOP,
//            End = STOP, PgUp = DEAD key.
// Symbols follow the MSX keycap, not the PC keycap (as on a real MSX).
// Port B returns 0 for a pressed key.
// =============================================================================
`default_nettype none

module msx_keymap (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] scan_code,
    input  wire       extended,
    input  wire       released,
    input  wire       valid,
    input  wire [3:0] row_select,
    output wire [7:0] col_data
);

    reg [7:0] matrix [0:8];   // 1 = pressed

    assign col_data = (row_select <= 4'd8) ? ~matrix[row_select] : 8'hFF;

    // {found, row[3:0], col[2:0]}
    reg [7:0] key;
    always @(*) begin
        key = 8'h00;
        if (!extended) begin
            case (scan_code)
                // row 0
                8'h45: key = {1'b1, 4'd0, 3'd0};  // 0
                8'h16: key = {1'b1, 4'd0, 3'd1};  // 1
                8'h1E: key = {1'b1, 4'd0, 3'd2};  // 2
                8'h26: key = {1'b1, 4'd0, 3'd3};  // 3
                8'h25: key = {1'b1, 4'd0, 3'd4};  // 4
                8'h2E: key = {1'b1, 4'd0, 3'd5};  // 5
                8'h36: key = {1'b1, 4'd0, 3'd6};  // 6
                8'h3D: key = {1'b1, 4'd0, 3'd7};  // 7
                // row 1
                8'h3E: key = {1'b1, 4'd1, 3'd0};  // 8
                8'h46: key = {1'b1, 4'd1, 3'd1};  // 9
                8'h4E: key = {1'b1, 4'd1, 3'd2};  // -
                8'h55: key = {1'b1, 4'd1, 3'd3};  // =
                8'h5D: key = {1'b1, 4'd1, 3'd4};  // backslash
                8'h54: key = {1'b1, 4'd1, 3'd5};  // [
                8'h5B: key = {1'b1, 4'd1, 3'd6};  // ]
                8'h4C: key = {1'b1, 4'd1, 3'd7};  // ;
                // row 2
                8'h52: key = {1'b1, 4'd2, 3'd0};  // '
                8'h0E: key = {1'b1, 4'd2, 3'd1};  // `
                8'h41: key = {1'b1, 4'd2, 3'd2};  // ,
                8'h49: key = {1'b1, 4'd2, 3'd3};  // .
                8'h4A: key = {1'b1, 4'd2, 3'd4};  // /
                8'h1C: key = {1'b1, 4'd2, 3'd6};  // A
                8'h32: key = {1'b1, 4'd2, 3'd7};  // B
                // row 3
                8'h21: key = {1'b1, 4'd3, 3'd0};  // C
                8'h23: key = {1'b1, 4'd3, 3'd1};  // D
                8'h24: key = {1'b1, 4'd3, 3'd2};  // E
                8'h2B: key = {1'b1, 4'd3, 3'd3};  // F
                8'h34: key = {1'b1, 4'd3, 3'd4};  // G
                8'h33: key = {1'b1, 4'd3, 3'd5};  // H
                8'h43: key = {1'b1, 4'd3, 3'd6};  // I
                8'h3B: key = {1'b1, 4'd3, 3'd7};  // J
                // row 4
                8'h42: key = {1'b1, 4'd4, 3'd0};  // K
                8'h4B: key = {1'b1, 4'd4, 3'd1};  // L
                8'h3A: key = {1'b1, 4'd4, 3'd2};  // M
                8'h31: key = {1'b1, 4'd4, 3'd3};  // N
                8'h44: key = {1'b1, 4'd4, 3'd4};  // O
                8'h4D: key = {1'b1, 4'd4, 3'd5};  // P
                8'h15: key = {1'b1, 4'd4, 3'd6};  // Q
                8'h2D: key = {1'b1, 4'd4, 3'd7};  // R
                // row 5
                8'h1B: key = {1'b1, 4'd5, 3'd0};  // S
                8'h2C: key = {1'b1, 4'd5, 3'd1};  // T
                8'h3C: key = {1'b1, 4'd5, 3'd2};  // U
                8'h2A: key = {1'b1, 4'd5, 3'd3};  // V
                8'h1D: key = {1'b1, 4'd5, 3'd4};  // W
                8'h22: key = {1'b1, 4'd5, 3'd5};  // X
                8'h35: key = {1'b1, 4'd5, 3'd6};  // Y
                8'h1A: key = {1'b1, 4'd5, 3'd7};  // Z
                // row 6
                8'h12: key = {1'b1, 4'd6, 3'd0};  // left shift
                8'h59: key = {1'b1, 4'd6, 3'd0};  // right shift
                8'h14: key = {1'b1, 4'd6, 3'd1};  // left ctrl
                8'h11: key = {1'b1, 4'd6, 3'd2};  // left alt -> GRAPH
                8'h58: key = {1'b1, 4'd6, 3'd3};  // caps lock
                8'h05: key = {1'b1, 4'd6, 3'd5};  // F1
                8'h06: key = {1'b1, 4'd6, 3'd6};  // F2
                8'h04: key = {1'b1, 4'd6, 3'd7};  // F3
                // row 7
                8'h0C: key = {1'b1, 4'd7, 3'd0};  // F4
                8'h03: key = {1'b1, 4'd7, 3'd1};  // F5
                8'h76: key = {1'b1, 4'd7, 3'd2};  // ESC
                8'h0D: key = {1'b1, 4'd7, 3'd3};  // TAB
                8'h83: key = {1'b1, 4'd7, 3'd4};  // F7 -> STOP
                8'h66: key = {1'b1, 4'd7, 3'd5};  // backspace
                8'h0B: key = {1'b1, 4'd7, 3'd6};  // F6 -> SELECT
                8'h5A: key = {1'b1, 4'd7, 3'd7};  // enter
                // row 8
                8'h29: key = {1'b1, 4'd8, 3'd0};  // space
                default: key = 8'h00;
            endcase
        end else begin
            case (scan_code)
                8'h11: key = {1'b1, 4'd6, 3'd4};  // right alt -> CODE
                8'h14: key = {1'b1, 4'd6, 3'd1};  // right ctrl
                8'h5A: key = {1'b1, 4'd7, 3'd7};  // keypad enter
                8'h69: key = {1'b1, 4'd7, 3'd4};  // End -> STOP
                8'h7D: key = {1'b1, 4'd2, 3'd5};  // PgUp -> DEAD
                8'h6C: key = {1'b1, 4'd8, 3'd1};  // Home
                8'h70: key = {1'b1, 4'd8, 3'd2};  // Insert
                8'h71: key = {1'b1, 4'd8, 3'd3};  // Delete
                8'h6B: key = {1'b1, 4'd8, 3'd4};  // left
                8'h75: key = {1'b1, 4'd8, 3'd5};  // up
                8'h72: key = {1'b1, 4'd8, 3'd6};  // down
                8'h74: key = {1'b1, 4'd8, 3'd7};  // right
                default: key = 8'h00;
            endcase
        end
    end

    integer i;
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i <= 8; i = i + 1) matrix[i] <= 8'h00;
        end else if (valid && key[7]) begin
            matrix[key[6:3]][key[2:0]] <= ~released;
        end
    end

endmodule
`default_nettype wire
