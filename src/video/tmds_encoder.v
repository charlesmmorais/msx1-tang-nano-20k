// =============================================================================
// Codificador TMDS (Transition-Minimized Differential Signaling)
// Converte 8 bits de dado RGB + 2 bits de controle → 10 bits TMDS
// Algoritmo DVI/HDMI spec, seção 3.3.3
// =============================================================================
`default_nettype none

module tmds_encoder (
    input         clk,
    input         rst,
    input  [7:0]  data,     // 8-bit pixel data
    input  [1:0]  ctrl,     // 2-bit sync control
    input         de,       // display enable (1=dados, 0=controle)
    output reg [9:0] tmds   // 10-bit TMDS output
);

// Tokens de controle
localparam CTRL_00 = 10'b1101010100;
localparam CTRL_01 = 10'b0010101011;
localparam CTRL_10 = 10'b0101010100;
localparam CTRL_11 = 10'b1010101011;

// Conta de disparidade (signed)
reg signed [4:0] disp_cnt;

// Estágio 1: Decide XOR/XNOR (minimiza transições)
wire [3:0] n1 = data[0]+data[1]+data[2]+data[3]+
                data[4]+data[5]+data[6]+data[7];
wire       use_xnor = (n1 > 4'd4) || (n1 == 4'd4 && !data[0]);

wire [8:0] q_m;
assign q_m[0] = data[0];
assign q_m[1] = use_xnor ? (q_m[0] ^~ data[1]) : (q_m[0] ^ data[1]);
assign q_m[2] = use_xnor ? (q_m[1] ^~ data[2]) : (q_m[1] ^ data[2]);
assign q_m[3] = use_xnor ? (q_m[2] ^~ data[3]) : (q_m[2] ^ data[3]);
assign q_m[4] = use_xnor ? (q_m[3] ^~ data[4]) : (q_m[3] ^ data[4]);
assign q_m[5] = use_xnor ? (q_m[4] ^~ data[5]) : (q_m[4] ^ data[5]);
assign q_m[6] = use_xnor ? (q_m[5] ^~ data[6]) : (q_m[5] ^ data[6]);
assign q_m[7] = use_xnor ? (q_m[6] ^~ data[7]) : (q_m[6] ^ data[7]);
assign q_m[8] = !use_xnor;

wire [3:0] n1_qm = q_m[0]+q_m[1]+q_m[2]+q_m[3]+
                   q_m[4]+q_m[5]+q_m[6]+q_m[7];
wire [3:0] n0_qm = 4'd8 - n1_qm;

// Estágio 2: Decide inversão para balancear disparidade
always @(posedge clk) begin
    if (rst) begin
        tmds     <= CTRL_00;
        disp_cnt <= 5'sd0;
    end else if (!de) begin
        case (ctrl)
            2'b00: tmds <= CTRL_00;
            2'b01: tmds <= CTRL_01;
            2'b10: tmds <= CTRL_10;
            2'b11: tmds <= CTRL_11;
        endcase
        disp_cnt <= 5'sd0;
    end else begin
        reg signed [4:0] diff;
        diff = $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});

        if (disp_cnt == 5'sd0 || n1_qm == n0_qm) begin
            if (!q_m[8]) begin
                tmds     <= {2'b10, ~q_m[7:0]};
                disp_cnt <= disp_cnt + $signed({1'b0, n0_qm}) - $signed({1'b0, n1_qm});
            end else begin
                tmds     <= {2'b01, q_m[7:0]};
                disp_cnt <= disp_cnt + $signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm});
            end
        end else if ((disp_cnt > 5'sd0 && n1_qm > n0_qm) ||
                     (disp_cnt < 5'sd0 && n0_qm > n1_qm)) begin
            tmds     <= {1'b1, q_m[8], ~q_m[7:0]};
            disp_cnt <= disp_cnt + (q_m[8] ? 5'sd2 : 5'sd0) +
                        ($signed({1'b0, n0_qm}) - $signed({1'b0, n1_qm}));
        end else begin
            tmds     <= {1'b0, q_m[8], q_m[7:0]};
            disp_cnt <= disp_cnt - (q_m[8] ? 5'sd0 : 5'sd2) +
                        ($signed({1'b0, n1_qm}) - $signed({1'b0, n0_qm}));
        end
    end
end

endmodule
`default_nettype wire
