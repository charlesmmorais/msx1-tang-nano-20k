// =============================================================================
// Z80 ALU - Unidade Aritmética e Lógica
// MSX1 para Tang Nano 20K
// =============================================================================
module z80_alu (
    input      [7:0]  op_a,
    input      [7:0]  op_b,
    input      [7:0]  flags_in,  // [S,Z,Y,H,X,P/V,N,C]
    input      [4:0]  op,        // operação
    input             bit3,      // carry_in para ADC/SBC
    output reg [7:0]  result,
    output reg [7:0]  flags_out
);

// Flags: S Z Y H X PV N C
`define FS  7
`define FZ  6
`define FY  5
`define FH  4
`define FX  3
`define FPV 2
`define FN  1
`define FC  0

// Operações ALU
localparam ALU_ADD  = 5'd0;
localparam ALU_ADC  = 5'd1;
localparam ALU_SUB  = 5'd2;
localparam ALU_SBC  = 5'd3;
localparam ALU_AND  = 5'd4;
localparam ALU_XOR  = 5'd5;
localparam ALU_OR   = 5'd6;
localparam ALU_CP   = 5'd7;
localparam ALU_INC  = 5'd8;
localparam ALU_DEC  = 5'd9;
localparam ALU_RLC  = 5'd10;
localparam ALU_RRC  = 5'd11;
localparam ALU_RL   = 5'd12;
localparam ALU_RR   = 5'd13;
localparam ALU_SLA  = 5'd14;
localparam ALU_SRA  = 5'd15;
localparam ALU_SLL  = 5'd16;
localparam ALU_SRL  = 5'd17;
localparam ALU_BIT  = 5'd18;
localparam ALU_DAA  = 5'd19;
localparam ALU_CPL  = 5'd20;
localparam ALU_NEG  = 5'd21;
localparam ALU_RLD  = 5'd22;
localparam ALU_RRD  = 5'd23;

function parity;
    input [7:0] v;
    parity = ~^v;
endfunction

always @(*) begin
    flags_out = flags_in;
    result    = op_a;
    
    case (op)
        ALU_ADD, ALU_ADC: begin
            reg [8:0] sum9;
            reg [4:0] sum5;
            reg        cin;
            cin   = (op == ALU_ADC) ? flags_in[`FC] : 1'b0;
            sum9  = {1'b0, op_a} + {1'b0, op_b} + {8'd0, cin};
            sum5  = {1'b0, op_a[3:0]} + {1'b0, op_b[3:0]} + {4'd0, cin};
            result = sum9[7:0];
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = sum5[4];
            flags_out[`FPV] = (~op_a[7] & ~op_b[7] & result[7]) |
                               ( op_a[7] &  op_b[7] & ~result[7]);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = sum9[8];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_SUB, ALU_SBC, ALU_CP: begin
            reg [8:0] sub9;
            reg [4:0] sub5;
            reg        bin;
            bin   = (op == ALU_SBC) ? flags_in[`FC] : 1'b0;
            sub9  = {1'b0, op_a} - {1'b0, op_b} - {8'd0, bin};
            sub5  = {1'b0, op_a[3:0]} - {1'b0, op_b[3:0]} - {4'd0, bin};
            result = sub9[7:0];
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = sub5[4];
            flags_out[`FPV] = ( op_a[7] & ~op_b[7] & ~result[7]) |
                               (~op_a[7] &  op_b[7] &  result[7]);
            flags_out[`FN]  = 1'b1;
            flags_out[`FC]  = sub9[8];
            if (op == ALU_CP) begin
                // CP não altera resultado, mas Y/X do operando
                result = op_a;
                flags_out[`FY] = op_b[5];
                flags_out[`FX] = op_b[3];
            end else begin
                flags_out[`FY] = result[5];
                flags_out[`FX] = result[3];
            end
        end

        ALU_AND: begin
            result = op_a & op_b;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b1;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = 1'b0;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_XOR: begin
            result = op_a ^ op_b;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = 1'b0;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_OR: begin
            result = op_a | op_b;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = 1'b0;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_INC: begin
            result = op_a + 8'd1;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = (op_a[3:0] == 4'hF);
            flags_out[`FPV] = (op_a == 8'h7F);
            flags_out[`FN]  = 1'b0;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
            // C não afetado
        end

        ALU_DEC: begin
            result = op_a - 8'd1;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = (op_a[3:0] == 4'h0);
            flags_out[`FPV] = (op_a == 8'h80);
            flags_out[`FN]  = 1'b1;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_RLC: begin
            result = {op_a[6:0], op_a[7]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[7];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_RRC: begin
            result = {op_a[0], op_a[7:1]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[0];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_RL: begin
            result = {op_a[6:0], flags_in[`FC]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[7];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_RR: begin
            result = {flags_in[`FC], op_a[7:1]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[0];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_SLA: begin
            result = {op_a[6:0], 1'b0};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[7];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_SRA: begin
            result = {op_a[7], op_a[7:1]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[0];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_SLL: begin
            result = {op_a[6:0], 1'b1};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[7];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_SRL: begin
            result = {1'b0, op_a[7:1]};
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = 1'b0;
            flags_out[`FPV] = parity(result);
            flags_out[`FN]  = 1'b0;
            flags_out[`FC]  = op_a[0];
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_BIT: begin
            // op_b contém máscara do bit (2^n)
            flags_out[`FZ]  = ~|(op_a & op_b);
            flags_out[`FH]  = 1'b1;
            flags_out[`FN]  = 1'b0;
            flags_out[`FS]  = (op_b == 8'h80) ? op_a[7] : 1'b0;
            flags_out[`FPV] = flags_out[`FZ];
            flags_out[`FY]  = (op_b == 8'h20) ? ~flags_out[`FZ] : 1'b0;
            flags_out[`FX]  = (op_b == 8'h08) ? ~flags_out[`FZ] : 1'b0;
            result = op_a;
        end

        ALU_DAA: begin
            reg [7:0] daa_v;
            reg        daa_c;
            daa_v = op_a;
            daa_c = flags_in[`FC];
            if (!flags_in[`FN]) begin
                if (flags_in[`FH] || (daa_v[3:0] > 4'd9))
                    daa_v = daa_v + 8'h06;
                if (flags_in[`FC] || (daa_v > 8'h99)) begin
                    daa_v = daa_v + 8'h60;
                    daa_c = 1'b1;
                end
            end else begin
                if (flags_in[`FH] || (daa_v[3:0] > 4'd9))
                    daa_v = daa_v - 8'h06;
                if (flags_in[`FC] || (op_a > 8'h99)) begin
                    daa_v = daa_v - 8'h60;
                    daa_c = 1'b1;
                end
            end
            result = daa_v;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = flags_in[`FN] ? (flags_in[`FH] && (op_a[3:0] < 4'd6)) :
                               (op_a[3:0] > 4'd9);
            flags_out[`FPV] = parity(result);
            flags_out[`FC]  = daa_c;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_CPL: begin
            result = ~op_a;
            flags_out[`FH]  = 1'b1;
            flags_out[`FN]  = 1'b1;
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        ALU_NEG: begin
            result = 8'h00 - op_a;
            flags_out[`FS]  = result[7];
            flags_out[`FZ]  = (result == 8'h00);
            flags_out[`FH]  = (op_a[3:0] != 4'h0);
            flags_out[`FPV] = (op_a == 8'h80);
            flags_out[`FN]  = 1'b1;
            flags_out[`FC]  = (op_a != 8'h00);
            flags_out[`FY]  = result[5];
            flags_out[`FX]  = result[3];
        end

        default: begin
            result    = op_a;
            flags_out = flags_in;
        end
    endcase
end

endmodule
