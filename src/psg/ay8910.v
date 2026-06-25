// =============================================================================
// AY-3-8910 Programmable Sound Generator — implementação completa
// 3 canais de onda quadrada + ruído + envelope
// Porta A: linha de saída da matriz de teclado MSX
// Porta B: leitura de linha de teclado / joystick
// Clock: 1.789 MHz (derivado do clock sistema)
// =============================================================================
`default_nettype none

module ay8910 (
    input         clk,       // Clock sistema (108 MHz)
    input         ce,        // Clock enable para PSG (~1.79 MHz)
    input         rst,
    // Interface CPU
    input         bdir,      // Bus direction (1=write)
    input         bc1,       // Bus control 1
    input  [7:0]  d_in,
    output reg [7:0] d_out,
    // Portas de I/O
    output reg [7:0] port_a, // Saída porta A (seleção linha teclado)
    input  [7:0]     port_b, // Entrada porta B (leitura colunas teclado)
    // Saída de áudio (somado: 10 bits não saturado)
    output reg [9:0] audio_out
);

// ---------------------------------------------------------------------------
// Registradores internos R0–R15
// ---------------------------------------------------------------------------
reg [7:0] regs [0:15];
reg [3:0] addr_latch;

// Divisores de tom: canais A, B, C (12 bits)
wire [11:0] tone_a = {regs[1][3:0], regs[0]};
wire [11:0] tone_b = {regs[3][3:0], regs[2]};
wire [11:0] tone_c = {regs[5][3:0], regs[4]};
// Divisor de ruído (5 bits)
wire [4:0]  noise_period = regs[6][4:0];
// Mixer
wire [5:0]  mixer = regs[7];
// Volumes
wire [4:0]  vol_a = regs[8][4:0];
wire [4:0]  vol_b = regs[9][4:0];
wire [4:0]  vol_c = regs[10][4:0];
// Envelope
wire [15:0] env_period = {regs[12], regs[11]};
wire [3:0]  env_shape  = regs[13][3:0];

// ---------------------------------------------------------------------------
// Contadores de tom
// ---------------------------------------------------------------------------
reg [11:0] cnt_a, cnt_b, cnt_c;
reg        out_a, out_b, out_c;

// Contador de ruído e LFSR 17-bit
reg [11:0] cnt_noise;
reg [16:0] lfsr;
reg        noise_out;

// Contador e gerador de envelope
reg [15:0] cnt_env;
reg [4:0]  env_vol;
reg        env_dir;   // 0=descendo, 1=subindo
reg        env_hold;
reg        env_alt;

// Tabela de volume (logarítmica 4-bit → linear 9-bit)
function [8:0] vol_to_lin;
    input [4:0] v;
    case (v[3:0])
        4'd0:  vol_to_lin = 9'd0;
        4'd1:  vol_to_lin = 9'd1;
        4'd2:  vol_to_lin = 9'd2;
        4'd3:  vol_to_lin = 9'd4;
        4'd4:  vol_to_lin = 9'd6;
        4'd5:  vol_to_lin = 9'd9;
        4'd6:  vol_to_lin = 9'd13;
        4'd7:  vol_to_lin = 9'd19;
        4'd8:  vol_to_lin = 9'd27;
        4'd9:  vol_to_lin = 9'd40;
        4'd10: vol_to_lin = 9'd57;
        4'd11: vol_to_lin = 9'd82;
        4'd12: vol_to_lin = 9'd116;
        4'd13: vol_to_lin = 9'd165;
        4'd14: vol_to_lin = 9'd234;
        4'd15: vol_to_lin = 9'd255;
        default: vol_to_lin = 9'd0;
    endcase
endfunction

// ---------------------------------------------------------------------------
// Interface CPU: BDIR/BC1 combinações
// BDIR BC1 | Modo
//   0    0  | Inativo
//   0    1  | Leitura de registrador
//   1    0  | Escrita de dado
//   1    1  | Latch de endereço
// ---------------------------------------------------------------------------
reg bdir_prev, bc1_prev;

always @(posedge clk) begin
    if (rst) begin
        integer i; for (i=0;i<16;i=i+1) regs[i] <= 8'h00;
        addr_latch <= 4'd0;
        d_out      <= 8'hFF;
        port_a     <= 8'hFF;
    end else begin
        bdir_prev <= bdir; bc1_prev <= bc1;

        // Latch de endereço (BDIR=1, BC1=1)
        if (bdir && bc1 && !(bdir_prev && bc1_prev))
            addr_latch <= d_in[3:0];

        // Escrita (BDIR=1, BC1=0)
        if (bdir && !bc1 && (bdir_prev || !bc1_prev)) begin
            regs[addr_latch] <= d_in;
            if (addr_latch == 4'd14) port_a <= d_in;
        end

        // Leitura (BDIR=0, BC1=1)
        if (!bdir && bc1) begin
            case (addr_latch)
                4'd14: d_out <= port_a;
                4'd15: d_out <= port_b;
                default: d_out <= regs[addr_latch];
            endcase
        end
    end
end

// ---------------------------------------------------------------------------
// Geração de áudio
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        cnt_a <= 12'd0; cnt_b <= 12'd0; cnt_c <= 12'd0;
        cnt_noise <= 12'd0; cnt_env <= 16'd0;
        out_a <= 1'b0; out_b <= 1'b0; out_c <= 1'b0;
        lfsr <= 17'h1FFFF;
        noise_out <= 1'b1;
        env_vol <= 5'd0; env_dir <= 1'b0; env_hold <= 1'b0; env_alt <= 1'b0;
        audio_out <= 10'd0;
    end else if (ce) begin
        // Contadores de tom
        if (cnt_a == 12'd0) begin
            cnt_a <= (tone_a == 12'd0) ? 12'd0 : tone_a;
            out_a <= ~out_a;
        end else cnt_a <= cnt_a - 12'd1;

        if (cnt_b == 12'd0) begin
            cnt_b <= (tone_b == 12'd0) ? 12'd0 : tone_b;
            out_b <= ~out_b;
        end else cnt_b <= cnt_b - 12'd1;

        if (cnt_c == 12'd0) begin
            cnt_c <= (tone_c == 12'd0) ? 12'd0 : tone_c;
            out_c <= ~out_c;
        end else cnt_c <= cnt_c - 12'd1;

        // Gerador de ruído (LFSR Galois 17-bit)
        if (cnt_noise == 12'd0) begin
            cnt_noise <= {7'd0, noise_period};
            noise_out <= lfsr[0];
            lfsr <= {1'b0, lfsr[16:1]} ^ (lfsr[0] ? 17'h12000 : 17'h00000);
        end else cnt_noise <= cnt_noise - 12'd1;

        // Gerador de envelope
        if (cnt_env == 16'd0) begin
            cnt_env <= (env_period == 16'd0) ? 16'd1 : env_period;
            if (!env_hold) begin
                if (env_dir) begin
                    if (env_vol == 5'd31) begin
                        if (env_alt) begin env_dir <= 1'b0; end
                        else if (!env_shape[3]) begin env_hold <= 1'b1; env_vol <= 5'd0; end
                        else begin env_vol <= 5'd31; env_hold <= 1'b1; end
                    end else env_vol <= env_vol + 5'd1;
                end else begin
                    if (env_vol == 5'd0) begin
                        if (env_alt) begin env_dir <= 1'b1; end
                        else if (env_shape[0]) begin env_hold <= 1'b1; env_vol <= 5'd31; end
                        else begin env_vol <= 5'd0; env_hold <= 1'b1; end
                    end else env_vol <= env_vol - 5'd1;
                end
            end
        end else cnt_env <= cnt_env - 16'd1;

        // Reiniciar envelope ao escrever R13
        if (regs[13] != env_shape) begin
            env_vol  <= env_shape[2] ? 5'd0 : 5'd31;
            env_dir  <= env_shape[2];
            env_hold <= 1'b0;
            env_alt  <= env_shape[1];
        end

        // Misturador e saída de áudio
        begin
            reg [3:0]  va, vb, vc;
            reg [8:0]  sa, sb, sc;
            reg        ca, cb, cc;

            // Tom + ruído por canal (mixer: bit 0=tone_A en, bit 3=noise_A en)
            ca = (out_a | mixer[0]) & (noise_out | mixer[3]);
            cb = (out_b | mixer[1]) & (noise_out | mixer[4]);
            cc = (out_c | mixer[2]) & (noise_out | mixer[5]);

            // Volume: se bit 4 do reg volume = 1, usa envelope
            va = vol_a[4] ? env_vol[4:1] : vol_a[3:0];
            vb = vol_b[4] ? env_vol[4:1] : vol_b[3:0];
            vc = vol_c[4] ? env_vol[4:1] : vol_c[3:0];

            sa = ca ? vol_to_lin({1'b0, va}) : 9'd0;
            sb = cb ? vol_to_lin({1'b0, vb}) : 9'd0;
            sc = cc ? vol_to_lin({1'b0, vc}) : 9'd0;

            audio_out <= {1'b0, sa} + {1'b0, sb} + {1'b0, sc};
        end
    end
end

endmodule
`default_nettype wire
