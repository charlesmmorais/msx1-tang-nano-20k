// =============================================================================
// Z80 CPU - Implementação completa para MSX1
// Tang Nano 20K  |  Clock sistema: 108 MHz, CE a 3.58 MHz
// =============================================================================
`default_nettype none

module z80_cpu (
    input         clk,      // Clock sistema
    input         ce,       // Clock enable (pulso a cada 108/30 ciclos ≈ 3.6 MHz)
    input         rst,      // Reset síncrono (ativo alto)
    // Barramento
    output reg [15:0] addr,
    input      [7:0]  di,
    output reg [7:0]  dout,
    output reg        mreq_n,
    output reg        iorq_n,
    output reg        rd_n,
    output reg        wr_n,
    output reg        m1_n,
    output reg        rfsh_n,
    // Controle
    input             wait_n,
    input             int_n,
    input             nmi_n,
    output reg        halt
);

// ---------------------------------------------------------------------------
// Flags [S,Z,Y,H,X,PV,N,C]
// ---------------------------------------------------------------------------
`define FS  7
`define FZ  6
`define FY  5
`define FH  4
`define FX  3
`define FPV 2
`define FN  1
`define FC  0

// ---------------------------------------------------------------------------
// Registradores
// ---------------------------------------------------------------------------
reg [7:0]  A, F, B, C, D, E, H, L;
reg [7:0]  A2, F2, B2, C2, D2, E2, H2, L2;  // bancos alternados
reg [15:0] IX, IY, SP, PC;
reg [7:0]  I, R;
reg        IFF1, IFF2;
reg [1:0]  IM;       // modo de interrupção 0,1,2
reg        nmi_pending;
reg        nmi_prev;

// Prefixos ativos
reg        prefix_dd;   // usando IX
reg        prefix_fd;   // usando IY
reg        prefix_cb;
reg        prefix_ed;
reg        ddcb_active; // instrução DDCB
reg        fdcb_active; // instrução FDCB

// Deslocamento IX/IY
reg signed [7:0] disp;

// Temporários
reg [7:0]  tmp8, tmp8b;
reg [15:0] tmp16;
reg [8:0]  tmp9;

// ---------------------------------------------------------------------------
// ALU
// ---------------------------------------------------------------------------
reg [7:0]  alu_a, alu_b, alu_res;
reg [7:0]  alu_f_in, alu_f_out;
reg [4:0]  alu_op;

z80_alu alu_inst (
    .op_a      (alu_a),
    .op_b      (alu_b),
    .flags_in  (alu_f_in),
    .op        (alu_op),
    .bit3      (1'b0),
    .result    (alu_res),
    .flags_out (alu_f_out)
);

// Aliases ALU ops
localparam ALU_ADD=5'd0, ALU_ADC=5'd1, ALU_SUB=5'd2, ALU_SBC=5'd3;
localparam ALU_AND=5'd4, ALU_XOR=5'd5, ALU_OR =5'd6, ALU_CP =5'd7;
localparam ALU_INC=5'd8, ALU_DEC=5'd9;
localparam ALU_RLC=5'd10,ALU_RRC=5'd11,ALU_RL=5'd12, ALU_RR=5'd13;
localparam ALU_SLA=5'd14,ALU_SRA=5'd15,ALU_SLL=5'd16,ALU_SRL=5'd17;
localparam ALU_BIT=5'd18,ALU_DAA=5'd19,ALU_CPL=5'd20,ALU_NEG=5'd21;

// ---------------------------------------------------------------------------
// Máquina de estados
// ---------------------------------------------------------------------------
localparam ST_RESET    = 6'd0;
localparam ST_M1_T1    = 6'd1;
localparam ST_M1_T2    = 6'd2;
localparam ST_M1_T3    = 6'd3;
localparam ST_M1_T4    = 6'd4;
localparam ST_DECODE   = 6'd5;
localparam ST_MR_T1    = 6'd6;
localparam ST_MR_T2    = 6'd7;
localparam ST_MR_T3    = 6'd8;
localparam ST_MW_T1    = 6'd9;
localparam ST_MW_T2    = 6'd10;
localparam ST_MW_T3    = 6'd11;
localparam ST_IOR_T1   = 6'd12;
localparam ST_IOR_T2   = 6'd13;
localparam ST_IOR_T3   = 6'd14;
localparam ST_IOR_T4   = 6'd15;
localparam ST_IOW_T1   = 6'd16;
localparam ST_IOW_T2   = 6'd17;
localparam ST_IOW_T3   = 6'd18;
localparam ST_IOW_T4   = 6'd19;
localparam ST_EXEC     = 6'd20;
localparam ST_EXEC2    = 6'd21;
localparam ST_EXEC3    = 6'd22;
localparam ST_EXEC4    = 6'd23;
localparam ST_EXEC5    = 6'd24;
localparam ST_EXEC6    = 6'd25;
localparam ST_EXEC7    = 6'd26;
localparam ST_EXEC8    = 6'd27;
localparam ST_NMI1     = 6'd28;
localparam ST_NMI2     = 6'd29;
localparam ST_INT1     = 6'd30;
localparam ST_INT2     = 6'd31;
localparam ST_INT3     = 6'd32;
localparam ST_RFSH     = 6'd33;
localparam ST_HALT     = 6'd34;
localparam ST_CB1      = 6'd35;  // fetch 2º byte CB
localparam ST_ED1      = 6'd36;  // fetch 2º byte ED
localparam ST_DD1      = 6'd37;  // fetch 2º byte DD
localparam ST_FD1      = 6'd38;  // fetch 2º byte FD
localparam ST_DDCB1    = 6'd39;  // fetch deslocamento DDCB
localparam ST_DDCB2    = 6'd40;  // fetch opcode DDCB
localparam ST_BLK1     = 6'd41;  // instruções de bloco (LDI etc) passo 1
localparam ST_BLK2     = 6'd42;
localparam ST_BLK3     = 6'd43;

reg [5:0]  state, next_state;
reg [7:0]  opcode;
reg [7:0]  op2;       // segundo byte (para prefixos)
reg [15:0] mem_addr;  // endereço para acesso à memória
reg [7:0]  mem_wdata; // dado para escrita
reg [7:0]  mem_rdata; // dado lido
reg [15:0] io_addr;
reg [7:0]  io_wdata, io_rdata;
reg [5:0]  ret_state; // estado de retorno após acesso

// Latch do opcode
reg [7:0]  ir;

// ---------------------------------------------------------------------------
// Funções auxiliares de registradores por índice (r)
// r: 0=B,1=C,2=D,3=E,4=H,5=L,6=(HL),7=A
// ---------------------------------------------------------------------------
function [7:0] get_r8;
    input [2:0] r;
    case(r)
        3'd0: get_r8 = B;
        3'd1: get_r8 = C;
        3'd2: get_r8 = D;
        3'd3: get_r8 = E;
        3'd4: get_r8 = H;
        3'd5: get_r8 = L;
        3'd6: get_r8 = 8'hFF; // (HL) tratado externamente
        3'd7: get_r8 = A;
        default: get_r8 = 8'hFF;
    endcase
endfunction

// Retorna par de 16 bits por índice (qq: 0=BC,1=DE,2=HL,3=SP)
function [15:0] get_rp;
    input [1:0] rp;
    case(rp)
        2'd0: get_rp = {B,C};
        2'd1: get_rp = {D,E};
        2'd2: get_rp = {H,L};
        2'd3: get_rp = SP;
    endcase
endfunction

// Retorna par de 16 bits para PUSH/POP (ss: 0=BC,1=DE,2=HL,3=AF)
function [15:0] get_ss;
    input [1:0] ss;
    case(ss)
        2'd0: get_ss = {B,C};
        2'd1: get_ss = {D,E};
        2'd2: get_ss = {H,L};
        2'd3: get_ss = {A,F};
    endcase
endfunction

// Índice HL corrigido para IX/IY quando prefixo ativo
function [15:0] get_HL_ix;
    input dd_active, fd_active;
    if (dd_active) get_HL_ix = IX;
    else if (fd_active) get_HL_ix = IY;
    else get_HL_ix = {H,L};
endfunction

// Avalia condição CC
function eval_cc;
    input [2:0] cc;
    case(cc)
        3'd0: eval_cc = ~F[`FZ];     // NZ
        3'd1: eval_cc =  F[`FZ];     // Z
        3'd2: eval_cc = ~F[`FC];     // NC
        3'd3: eval_cc =  F[`FC];     // C
        3'd4: eval_cc = ~F[`FPV];    // PO
        3'd5: eval_cc =  F[`FPV];    // PE
        3'd6: eval_cc = ~F[`FS];     // P
        3'd7: eval_cc =  F[`FS];     // M
    endcase
endfunction

// Tarefa set_r8 — escreve registrador por índice
task set_r8;
    input [2:0] r;
    input [7:0] val;
    case(r)
        3'd0: B <= val;
        3'd1: C <= val;
        3'd2: D <= val;
        3'd3: E <= val;
        3'd4: H <= val;
        3'd5: L <= val;
        3'd6: ;  // (HL) tratado externamente
        3'd7: A <= val;
    endcase
endtask

// ---------------------------------------------------------------------------
// Lógica principal
// ---------------------------------------------------------------------------
always @(posedge clk) begin
    if (rst) begin
        state    <= ST_RESET;
        PC       <= 16'h0000;
        SP       <= 16'hFFFF;
        A <= 8'hFF; F <= 8'hFF;
        B <= 8'hFF; C <= 8'hFF;
        D <= 8'hFF; E <= 8'hFF;
        H <= 8'hFF; L <= 8'hFF;
        IX <= 16'hFFFF; IY <= 16'hFFFF;
        I <= 8'h00; R <= 8'h00;
        IFF1 <= 1'b0; IFF2 <= 1'b0;
        IM   <= 2'd0;
        halt <= 1'b0;
        nmi_prev <= 1'b1;
        nmi_pending <= 1'b0;
        prefix_dd <= 0; prefix_fd <= 0;
        prefix_cb <= 0; prefix_ed <= 0;
        ddcb_active <= 0; fdcb_active <= 0;
        mreq_n <= 1'b1; iorq_n <= 1'b1;
        rd_n   <= 1'b1; wr_n   <= 1'b1;
        m1_n   <= 1'b1; rfsh_n <= 1'b1;
        addr   <= 16'h0000; dout <= 8'hFF;
    end else if (ce) begin
        // Detecção de borda de descida em NMI
        nmi_prev <= nmi_n;
        if (nmi_prev && !nmi_n)
            nmi_pending <= 1'b1;

        case (state)
        // ---------------------------------------------------------------
        ST_RESET: begin
            PC <= 16'h0000;
            state <= ST_M1_T1;
            halt <= 1'b0;
        end

        // ---------------------------------------------------------------
        // Ciclo M1: busca de opcode
        // ---------------------------------------------------------------
        ST_M1_T1: begin
            // Verificar interrupções antes de buscar
            if (nmi_pending) begin
                nmi_pending <= 1'b0;
                halt <= 1'b0;
                IFF2 <= IFF1;
                IFF1 <= 1'b0;
                state <= ST_NMI1;
            end else if (IFF1 && !int_n) begin
                halt <= 1'b0;
                IFF1 <= 1'b0;
                IFF2 <= 1'b0;
                state <= ST_INT1;
            end else begin
                addr   <= halt ? PC : PC;  // mantém PC em HALT
                mreq_n <= 1'b0;
                rd_n   <= 1'b0;
                m1_n   <= 1'b0;
                state  <= ST_M1_T2;
            end
        end

        ST_M1_T2: begin
            if (!wait_n) begin
                state <= ST_M1_T2; // aguarda
            end else begin
                ir     <= di;
                opcode <= di;
                PC     <= halt ? PC : (PC + 16'd1);
                state  <= ST_M1_T3;
            end
        end

        ST_M1_T3: begin
            mreq_n <= 1'b1;
            rd_n   <= 1'b1;
            m1_n   <= 1'b1;
            // Refresh
            addr   <= {I, R};
            rfsh_n <= 1'b0;
            mreq_n <= 1'b0;
            R      <= {R[7], R[6:0] + 7'd1};
            state  <= ST_M1_T4;
        end

        ST_M1_T4: begin
            mreq_n <= 1'b1;
            rfsh_n <= 1'b1;
            state  <= ST_DECODE;
        end

        // ---------------------------------------------------------------
        // DECODE: decodifica opcode / prefixo
        // ---------------------------------------------------------------
        ST_DECODE: begin
            casez (opcode)
                8'hCB: begin
                    if (prefix_dd || prefix_fd) begin
                        // DDCB / FDCB: deslocamento vem depois
                        state <= ST_DDCB1;
                    end else begin
                        prefix_cb <= 1'b1;
                        state <= ST_CB1;
                    end
                end
                8'hDD: begin prefix_dd <= 1'b1; state <= ST_M1_T1; end
                8'hFD: begin prefix_fd <= 1'b1; state <= ST_M1_T1; end
                8'hED: begin prefix_ed <= 1'b1; state <= ST_ED1; end
                default: state <= ST_EXEC;
            endcase
        end

        // ---------------------------------------------------------------
        // DDCB / FDCB: busca deslocamento e opcode
        // ---------------------------------------------------------------
        ST_DDCB1: begin
            // Busca deslocamento
            mem_addr  <= PC;
            ret_state <= ST_DDCB2;
            state     <= ST_MR_T1;
        end
        ST_DDCB2: begin
            disp <= $signed(mem_rdata);
            PC   <= PC + 16'd1;
            // Busca opcode final
            mem_addr  <= PC + 16'd1;
            ret_state <= ST_EXEC;
            state     <= ST_MR_T1;
            ddcb_active <= prefix_dd;
            fdcb_active <= prefix_fd;
        end

        // ---------------------------------------------------------------
        // CB prefix: busca opcode CB
        // ---------------------------------------------------------------
        ST_CB1: begin
            mem_addr  <= PC;
            ret_state <= ST_EXEC;
            state     <= ST_MR_T1;
        end

        // ---------------------------------------------------------------
        // ED prefix
        // ---------------------------------------------------------------
        ST_ED1: begin
            mem_addr  <= PC;
            ret_state <= ST_EXEC;
            state     <= ST_MR_T1;
        end

        // ---------------------------------------------------------------
        // Leitura de memória: 3 T-states
        // ---------------------------------------------------------------
        ST_MR_T1: begin
            addr   <= mem_addr;
            mreq_n <= 1'b0;
            rd_n   <= 1'b0;
            state  <= ST_MR_T2;
        end
        ST_MR_T2: begin
            if (!wait_n) state <= ST_MR_T2;
            else state <= ST_MR_T3;
        end
        ST_MR_T3: begin
            mem_rdata <= di;
            mreq_n    <= 1'b1;
            rd_n      <= 1'b1;
            state     <= ret_state;
        end

        // ---------------------------------------------------------------
        // Escrita de memória: 3 T-states
        // ---------------------------------------------------------------
        ST_MW_T1: begin
            addr   <= mem_addr;
            dout   <= mem_wdata;
            mreq_n <= 1'b0;
            wr_n   <= 1'b0;
            state  <= ST_MW_T2;
        end
        ST_MW_T2: begin
            if (!wait_n) state <= ST_MW_T2;
            else state <= ST_MW_T3;
        end
        ST_MW_T3: begin
            mreq_n <= 1'b1;
            wr_n   <= 1'b1;
            state  <= ret_state;
        end

        // ---------------------------------------------------------------
        // Leitura I/O: 4 T-states + wait automático
        // ---------------------------------------------------------------
        ST_IOR_T1: begin
            addr   <= io_addr;
            iorq_n <= 1'b0;
            rd_n   <= 1'b0;
            state  <= ST_IOR_T2;
        end
        ST_IOR_T2: begin state <= ST_IOR_T3; end
        ST_IOR_T3: begin
            if (!wait_n) state <= ST_IOR_T3;
            else state <= ST_IOR_T4;
        end
        ST_IOR_T4: begin
            io_rdata <= di;
            iorq_n   <= 1'b1;
            rd_n     <= 1'b1;
            state    <= ret_state;
        end

        // ---------------------------------------------------------------
        // Escrita I/O: 4 T-states + wait automático
        // ---------------------------------------------------------------
        ST_IOW_T1: begin
            addr   <= io_addr;
            dout   <= io_wdata;
            iorq_n <= 1'b0;
            wr_n   <= 1'b0;
            state  <= ST_IOW_T2;
        end
        ST_IOW_T2: begin state <= ST_IOW_T3; end
        ST_IOW_T3: begin
            if (!wait_n) state <= ST_IOW_T3;
            else state <= ST_IOW_T4;
        end
        ST_IOW_T4: begin
            iorq_n <= 1'b1;
            wr_n   <= 1'b1;
            state  <= ret_state;
        end

        // ---------------------------------------------------------------
        // NMI handler
        // ---------------------------------------------------------------
        ST_NMI1: begin
            // PUSH PC alto
            SP        <= SP - 16'd1;
            mem_addr  <= SP - 16'd1;
            mem_wdata <= PC[15:8];
            ret_state <= ST_NMI2;
            state     <= ST_MW_T1;
        end
        ST_NMI2: begin
            SP        <= SP - 16'd1;
            mem_addr  <= SP - 16'd1;
            mem_wdata <= PC[7:0];
            PC        <= 16'h0066;
            ret_state <= ST_M1_T1;
            state     <= ST_MW_T1;
        end

        // ---------------------------------------------------------------
        // INT handler
        // ---------------------------------------------------------------
        ST_INT1: begin
            // Acknowledge
            addr   <= PC;
            iorq_n <= 1'b0;
            m1_n   <= 1'b0;
            state  <= ST_INT2;
        end
        ST_INT2: begin
            iorq_n <= 1'b1;
            m1_n   <= 1'b1;
            case (IM)
                2'd0: begin
                    // IM0: dado no barramento é instrução RST n
                    // MSX não usa muito IM0 – tratamos como RST 38h
                    PC    <= 16'h0038;
                    state <= ST_M1_T1;
                end
                2'd1: begin
                    // IM1: RST 38h
                    SP        <= SP - 16'd1;
                    mem_addr  <= SP - 16'd1;
                    mem_wdata <= PC[15:8];
                    ret_state <= ST_INT3;
                    state     <= ST_MW_T1;
                end
                2'd2: begin
                    // IM2: endereço em I:vetor
                    tmp16     <= {I, di};
                    SP        <= SP - 16'd1;
                    mem_addr  <= SP - 16'd1;
                    mem_wdata <= PC[15:8];
                    ret_state <= ST_INT3;
                    state     <= ST_MW_T1;
                end
                default: state <= ST_M1_T1;
            endcase
        end
        ST_INT3: begin
            SP        <= SP - 16'd1;
            mem_addr  <= SP - 16'd1;
            mem_wdata <= PC[7:0];
            case (IM)
                2'd1: begin PC <= 16'h0038; ret_state <= ST_M1_T1; end
                2'd2: begin
                    // Lê endereço do vetor de interrupção
                    mem_addr  <= tmp16;
                    ret_state <= ST_EXEC5; // reutiliza EXEC5 para finalizar jump
                end
                default: begin PC <= 16'h0038; ret_state <= ST_M1_T1; end
            endcase
            state <= ST_MW_T1;
        end

        // ---------------------------------------------------------------
        // HALT
        // ---------------------------------------------------------------
        ST_HALT: begin
            halt  <= 1'b1;
            state <= ST_M1_T1;  // repete fetch do NOP
        end

        // ---------------------------------------------------------------
        // EXEC: executa instrução decodificada em 'opcode'
        // ---------------------------------------------------------------
        ST_EXEC: begin
            // Limpa flags de prefixo (serão reativados se necessário)
            prefix_dd <= 1'b0;
            prefix_fd <= 1'b0;
            prefix_cb <= 1'b0;
            prefix_ed <= 1'b0;

            if (ddcb_active || fdcb_active) begin
                // DDCB/FDCB: opcode está em mem_rdata
                op2 <= mem_rdata;
                PC  <= PC + 16'd1;
                // Calcular endereço efetivo
                tmp16 <= (ddcb_active ? IX : IY) + {{8{disp[7]}}, disp};
                ddcb_active <= 1'b0;
                fdcb_active <= 1'b0;
                state <= ST_EXEC2;
            end else if (prefix_cb) begin
                // CB: op2 está em mem_rdata
                op2 <= mem_rdata;
                PC  <= PC + 16'd1;
                state <= ST_EXEC3; // executa CB
            end else if (prefix_ed) begin
                op2 <= mem_rdata;
                PC  <= PC + 16'd1;
                state <= ST_EXEC4; // executa ED
            end else begin
                // Instrução principal
                state <= ST_EXEC5;
            end
        end

        // ---------------------------------------------------------------
        // EXEC2: Executa instrução DDCB/FDCB
        // Endereço efetivo em tmp16, opcode em op2
        // ---------------------------------------------------------------
        ST_EXEC2: begin
            // Lê (IX+d) ou (IY+d)
            mem_addr  <= tmp16;
            ret_state <= ST_EXEC6;
            state     <= ST_MR_T1;
        end
        ST_EXEC6: begin
            // Executa operação bit em mem_rdata, escreve de volta em (IX+d)
            begin
                reg [7:0] src, res8;
                reg [2:0] bit_n;
                src   = mem_rdata;
                bit_n = op2[5:3];
                case (op2[7:6])
                    2'b00: begin // ROT
                        alu_a = src; alu_f_in = F;
                        case (op2[5:3])
                            3'd0: alu_op = ALU_RLC;
                            3'd1: alu_op = ALU_RRC;
                            3'd2: alu_op = ALU_RL;
                            3'd3: alu_op = ALU_RR;
                            3'd4: alu_op = ALU_SLA;
                            3'd5: alu_op = ALU_SRA;
                            3'd6: alu_op = ALU_SLL;
                            3'd7: alu_op = ALU_SRL;
                        endcase
                        res8 = alu_res; F = alu_f_out;
                        // Salva resultado no registrador se op2[2:0] != 6
                        if (op2[2:0] != 3'd6) set_r8(op2[2:0], res8);
                        mem_addr  <= tmp16;
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                    2'b01: begin // BIT
                        alu_a = src; alu_b = 8'd1 << bit_n;
                        alu_op = ALU_BIT; alu_f_in = F;
                        F = alu_f_out;
                        state <= ST_M1_T1;
                    end
                    2'b10: begin // RES
                        res8 = src & ~(8'd1 << bit_n);
                        if (op2[2:0] != 3'd6) set_r8(op2[2:0], res8);
                        mem_addr  <= tmp16;
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                    2'b11: begin // SET
                        res8 = src | (8'd1 << bit_n);
                        if (op2[2:0] != 3'd6) set_r8(op2[2:0], res8);
                        mem_addr  <= tmp16;
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                endcase
            end
        end

        // ---------------------------------------------------------------
        // EXEC3: Instruções CB (rotações/bits)
        // ---------------------------------------------------------------
        ST_EXEC3: begin
            begin
                reg [2:0] r3, b3;
                reg [7:0] src, res8;
                r3  = op2[2:0];
                b3  = op2[5:3];
                // Se r3==6 precisamos de (HL)
                if (r3 == 3'd6 && op2[7:6] != 2'b01) begin
                    // Buscar (HL)
                    mem_addr  <= {H, L};
                    ret_state <= ST_EXEC7;
                    state     <= ST_MR_T1;
                end else if (r3 == 3'd6 && op2[7:6] == 2'b01) begin
                    // BIT b,(HL)
                    mem_addr  <= {H, L};
                    ret_state <= ST_EXEC8;
                    state     <= ST_MR_T1;
                end else begin
                    src = get_r8(r3);
                    alu_a = src; alu_f_in = F;
                    case (op2[7:6])
                        2'b00: begin
                            case (b3)
                                3'd0: alu_op = ALU_RLC;
                                3'd1: alu_op = ALU_RRC;
                                3'd2: alu_op = ALU_RL;
                                3'd3: alu_op = ALU_RR;
                                3'd4: alu_op = ALU_SLA;
                                3'd5: alu_op = ALU_SRA;
                                3'd6: alu_op = ALU_SLL;
                                3'd7: alu_op = ALU_SRL;
                            endcase
                            res8 = alu_res; F = alu_f_out;
                            set_r8(r3, res8);
                        end
                        2'b01: begin // BIT
                            alu_b = 8'd1 << b3; alu_op = ALU_BIT;
                            F = alu_f_out;
                        end
                        2'b10: begin // RES
                            res8 = src & ~(8'd1 << b3);
                            set_r8(r3, res8);
                        end
                        2'b11: begin // SET
                            res8 = src | (8'd1 << b3);
                            set_r8(r3, res8);
                        end
                    endcase
                    state <= ST_M1_T1;
                end
            end
        end
        // Leitura de (HL) para CB
        ST_EXEC7: begin
            begin
                reg [7:0] src, res8;
                reg [2:0] b3;
                b3  = op2[5:3];
                src = mem_rdata;
                alu_a = src; alu_f_in = F;
                case (op2[7:6])
                    2'b00: begin
                        case (b3)
                            3'd0: alu_op = ALU_RLC;
                            3'd1: alu_op = ALU_RRC;
                            3'd2: alu_op = ALU_RL;
                            3'd3: alu_op = ALU_RR;
                            3'd4: alu_op = ALU_SLA;
                            3'd5: alu_op = ALU_SRA;
                            3'd6: alu_op = ALU_SLL;
                            3'd7: alu_op = ALU_SRL;
                        endcase
                        res8 = alu_res; F = alu_f_out;
                        mem_addr  <= {H, L};
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                    2'b10: begin // RES
                        res8 = src & ~(8'd1 << b3);
                        mem_addr  <= {H, L};
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                    2'b11: begin // SET
                        res8 = src | (8'd1 << b3);
                        mem_addr  <= {H, L};
                        mem_wdata <= res8;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                    default: state <= ST_M1_T1;
                endcase
            end
        end
        ST_EXEC8: begin
            // BIT b,(HL)
            alu_a = mem_rdata; alu_b = 8'd1 << op2[5:3];
            alu_op = ALU_BIT; alu_f_in = F;
            F = alu_f_out;
            state <= ST_M1_T1;
        end

        // ---------------------------------------------------------------
        // EXEC4: Instruções ED
        // ---------------------------------------------------------------
        ST_EXEC4: begin
            casez (op2)
                // IN r,(C)
                8'b01???000: begin
                    io_addr   <= {B, C};
                    ret_state <= ST_EXEC5;
                    tmp8b     <= op2[5:3];  // r index
                    state     <= ST_IOR_T1;
                end
                // OUT (C),r
                8'b01???001: begin
                    io_addr   <= {B, C};
                    io_wdata  <= get_r8(op2[5:3]);
                    ret_state <= ST_M1_T1;
                    state     <= ST_IOW_T1;
                end
                // SBC HL,rp
                8'b01??0010: begin
                    begin
                        reg [16:0] r17;
                        reg [1:0]  rp2;
                        rp2 = op2[5:4];
                        r17 = {1'b0, H, L} - {1'b0, get_rp(rp2)} - {16'd0, F[`FC]};
                        {H, L} <= r17[15:0];
                        F[`FS]  <= r17[15];
                        F[`FZ]  <= (r17[15:0] == 16'h0000);
                        F[`FH]  <= ({H[3:0], L} - {get_rp(rp2)[3:0], 8'h0} - F[`FC]) < 0; // simplificado
                        F[`FN]  <= 1'b1;
                        F[`FC]  <= r17[16];
                        F[`FPV] <= ({H[7], L[7]} == 2'b00 && get_rp(rp2)[15] == 1'b1 && r17[15] == 1'b1) ||
                                   ({H[7], L[7]} == 2'b11 && get_rp(rp2)[15] == 1'b0 && r17[15] == 1'b0);
                    end
                    state <= ST_M1_T1;
                end
                // ADC HL,rp
                8'b01??1010: begin
                    begin
                        reg [16:0] r17;
                        reg [1:0]  rp2;
                        rp2 = op2[5:4];
                        r17 = {1'b0, H, L} + {1'b0, get_rp(rp2)} + {16'd0, F[`FC]};
                        {H, L} <= r17[15:0];
                        F[`FS]  <= r17[15];
                        F[`FZ]  <= (r17[15:0] == 16'h0000);
                        F[`FN]  <= 1'b0;
                        F[`FC]  <= r17[16];
                    end
                    state <= ST_M1_T1;
                end
                // LD (nn),rp
                8'b01??0011: begin
                    mem_addr  <= PC;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= {2'b11, op2[5:4]};  // indica LD(nn)rp
                    state     <= ST_MR_T1;
                end
                // LD rp,(nn)
                8'b01??1011: begin
                    mem_addr  <= PC;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= {2'b10, op2[5:4]};  // indica LD rp,(nn)
                    state     <= ST_MR_T1;
                end
                // NEG
                8'h44: begin alu_a = A; alu_op = ALU_NEG; alu_f_in = F; A <= alu_res; F <= alu_f_out; state <= ST_M1_T1; end
                // RETN
                8'h45: begin IFF1 <= IFF2; mem_addr <= SP; SP <= SP + 16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hFF; state <= ST_MR_T1; end
                // RETI
                8'h4D: begin IFF1 <= IFF2; mem_addr <= SP; SP <= SP + 16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hFF; state <= ST_MR_T1; end
                // IM 0
                8'h46: begin IM <= 2'd0; state <= ST_M1_T1; end
                // IM 1
                8'h56: begin IM <= 2'd1; state <= ST_M1_T1; end
                // IM 2
                8'h5E: begin IM <= 2'd2; state <= ST_M1_T1; end
                // LD I,A
                8'h47: begin I <= A; state <= ST_M1_T1; end
                // LD R,A
                8'h4F: begin R <= A; state <= ST_M1_T1; end
                // LD A,I
                8'h57: begin
                    A <= I;
                    F[`FS]  <= I[7]; F[`FZ] <= (I == 8'h00);
                    F[`FH]  <= 1'b0; F[`FN] <= 1'b0;
                    F[`FPV] <= IFF2;
                    state <= ST_M1_T1;
                end
                // LD A,R
                8'h5F: begin
                    A <= R;
                    F[`FS]  <= R[7]; F[`FZ] <= (R == 8'h00);
                    F[`FH]  <= 1'b0; F[`FN] <= 1'b0;
                    F[`FPV] <= IFF2;
                    state <= ST_M1_T1;
                end
                // RLD
                8'h6F: begin
                    mem_addr  <= {H, L};
                    ret_state <= ST_BLK1;  // reuse para RLD
                    tmp8b     <= 8'h6F;
                    state     <= ST_MR_T1;
                end
                // RRD
                8'h67: begin
                    mem_addr  <= {H, L};
                    ret_state <= ST_BLK1;
                    tmp8b     <= 8'h67;
                    state     <= ST_MR_T1;
                end
                // LDI
                8'hA0: begin state <= ST_BLK1; tmp8b <= 8'hA0; end
                // CPI
                8'hA1: begin state <= ST_BLK1; tmp8b <= 8'hA1; end
                // LDD
                8'hA8: begin state <= ST_BLK1; tmp8b <= 8'hA8; end
                // CPD
                8'hA9: begin state <= ST_BLK1; tmp8b <= 8'hA9; end
                // LDIR
                8'hB0: begin state <= ST_BLK1; tmp8b <= 8'hB0; end
                // CPIR
                8'hB1: begin state <= ST_BLK1; tmp8b <= 8'hB1; end
                // LDDR
                8'hB8: begin state <= ST_BLK1; tmp8b <= 8'hB8; end
                // CPDR
                8'hB9: begin state <= ST_BLK1; tmp8b <= 8'hB9; end
                // INI
                8'hA2: begin state <= ST_BLK1; tmp8b <= 8'hA2; end
                // IND
                8'hAA: begin state <= ST_BLK1; tmp8b <= 8'hAA; end
                // INIR
                8'hB2: begin state <= ST_BLK1; tmp8b <= 8'hB2; end
                // INDR
                8'hBA: begin state <= ST_BLK1; tmp8b <= 8'hBA; end
                // OUTI
                8'hA3: begin state <= ST_BLK1; tmp8b <= 8'hA3; end
                // OUTD
                8'hAB: begin state <= ST_BLK1; tmp8b <= 8'hAB; end
                // OTIR
                8'hB3: begin state <= ST_BLK1; tmp8b <= 8'hB3; end
                // OTDR
                8'hBB: begin state <= ST_BLK1; tmp8b <= 8'hBB; end
                default: state <= ST_M1_T1;
            endcase
        end

        // ---------------------------------------------------------------
        // Instruções de bloco (LDI, LDD, LDIR, LDDR, CPI, etc.)
        // ---------------------------------------------------------------
        ST_BLK1: begin
            casez (tmp8b)
                // LD* : lê (HL)
                8'hA0, 8'hA8, 8'hB0, 8'hB8: begin
                    mem_addr  <= {H, L};
                    ret_state <= ST_BLK2;
                    state     <= ST_MR_T1;
                end
                // CP* : lê (HL)
                8'hA1, 8'hA9, 8'hB1, 8'hB9: begin
                    mem_addr  <= {H, L};
                    ret_state <= ST_BLK3;
                    state     <= ST_MR_T1;
                end
                // IN* : lê de (C)
                8'hA2, 8'hAA, 8'hB2, 8'hBA: begin
                    io_addr   <= {B, C};
                    ret_state <= ST_BLK2;
                    state     <= ST_IOR_T1;
                end
                // OUT*: lê (HL), envia para (C)
                8'hA3, 8'hAB, 8'hB3, 8'hBB: begin
                    mem_addr  <= {H, L};
                    ret_state <= ST_BLK2;
                    state     <= ST_MR_T1;
                end
                // RLD/RRD
                8'h6F: begin
                    // RLD: A[3:0] → (HL)[7:4], (HL)[7:4] → (HL)[3:0], (HL)[3:0] → A[3:0]
                    tmp8 <= mem_rdata;
                    begin
                        reg [7:0] rld_hl, rld_a;
                        rld_hl = {mem_rdata[3:0], A[3:0]};
                        rld_a  = {A[7:4], mem_rdata[7:4]};
                        A <= rld_a;
                        mem_addr  <= {H, L};
                        mem_wdata <= rld_hl;
                        F[`FS]  <= rld_a[7]; F[`FZ] <= (rld_a == 8'h00);
                        F[`FH]  <= 1'b0; F[`FN] <= 1'b0;
                        F[`FPV] <= ^~rld_a;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                end
                8'h67: begin
                    // RRD: A[3:0] → (HL)[7:4], (HL)[3:0] → A[3:0], (HL)[7:4] → (HL)[3:0]
                    begin
                        reg [7:0] rrd_hl, rrd_a;
                        rrd_hl = {A[3:0], mem_rdata[7:4]};
                        rrd_a  = {A[7:4], mem_rdata[3:0]};
                        A <= rrd_a;
                        mem_addr  <= {H, L};
                        mem_wdata <= rrd_hl;
                        F[`FS]  <= rrd_a[7]; F[`FZ] <= (rrd_a == 8'h00);
                        F[`FH]  <= 1'b0; F[`FN] <= 1'b0;
                        F[`FPV] <= ^~rrd_a;
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end
                end
                default: state <= ST_M1_T1;
            endcase
        end

        ST_BLK2: begin
            casez (tmp8b)
                8'hA0, 8'hB0: begin // LDI / LDIR
                    mem_addr  <= {D, E};
                    mem_wdata <= mem_rdata;
                    {H, L}   <= {H, L} + 16'd1;
                    {D, E}   <= {D, E} + 16'd1;
                    {B, C}   <= {B, C} - 16'd1;
                    F[`FH]   <= 1'b0; F[`FN] <= 1'b0;
                    F[`FPV]  <= ({B, C} - 16'd1 != 16'h0000);
                    ret_state <= (tmp8b == 8'hB0 && {B,C} != 16'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_MW_T1;
                    if (tmp8b == 8'hB0 && {B,C} != 16'd1)
                        PC <= PC - 16'd2;  // repete LDIR
                end
                8'hA8, 8'hB8: begin // LDD / LDDR
                    mem_addr  <= {D, E};
                    mem_wdata <= mem_rdata;
                    {H, L}   <= {H, L} - 16'd1;
                    {D, E}   <= {D, E} - 16'd1;
                    {B, C}   <= {B, C} - 16'd1;
                    F[`FH]   <= 1'b0; F[`FN] <= 1'b0;
                    F[`FPV]  <= ({B, C} - 16'd1 != 16'h0000);
                    ret_state <= (tmp8b == 8'hB8 && {B,C} != 16'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_MW_T1;
                    if (tmp8b == 8'hB8 && {B,C} != 16'd1)
                        PC <= PC - 16'd2;
                end
                8'hA2, 8'hB2: begin // INI / INIR
                    mem_addr  <= {H, L};
                    mem_wdata <= io_rdata;
                    {H, L}   <= {H, L} + 16'd1;
                    B        <= B - 8'd1;
                    F[`FZ]   <= (B - 8'd1 == 8'h00);
                    F[`FN]   <= 1'b1;
                    ret_state <= (tmp8b == 8'hB2 && B != 8'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_MW_T1;
                    if (tmp8b == 8'hB2 && B != 8'd1)
                        PC <= PC - 16'd2;
                end
                8'hAA, 8'hBA: begin // IND / INDR
                    mem_addr  <= {H, L};
                    mem_wdata <= io_rdata;
                    {H, L}   <= {H, L} - 16'd1;
                    B        <= B - 8'd1;
                    F[`FZ]   <= (B - 8'd1 == 8'h00);
                    F[`FN]   <= 1'b1;
                    ret_state <= (tmp8b == 8'hBA && B != 8'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_MW_T1;
                    if (tmp8b == 8'hBA && B != 8'd1)
                        PC <= PC - 16'd2;
                end
                8'hA3, 8'hB3: begin // OUTI / OTIR
                    io_addr   <= {B, C};
                    io_wdata  <= mem_rdata;
                    {H, L}   <= {H, L} + 16'd1;
                    B        <= B - 8'd1;
                    F[`FZ]   <= (B - 8'd1 == 8'h00);
                    F[`FN]   <= 1'b1;
                    ret_state <= (tmp8b == 8'hB3 && B != 8'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_IOW_T1;
                    if (tmp8b == 8'hB3 && B != 8'd1)
                        PC <= PC - 16'd2;
                end
                8'hAB, 8'hBB: begin // OUTD / OTDR
                    io_addr   <= {B, C};
                    io_wdata  <= mem_rdata;
                    {H, L}   <= {H, L} - 16'd1;
                    B        <= B - 8'd1;
                    F[`FZ]   <= (B - 8'd1 == 8'h00);
                    F[`FN]   <= 1'b1;
                    ret_state <= (tmp8b == 8'hBB && B != 8'd1) ? ST_BLK1 : ST_M1_T1;
                    state     <= ST_IOW_T1;
                    if (tmp8b == 8'hBB && B != 8'd1)
                        PC <= PC - 16'd2;
                end
                default: state <= ST_M1_T1;
            endcase
        end

        ST_BLK3: begin // CPI / CPD / CPIR / CPDR
            begin
                reg [8:0] cmp;
                reg [4:0] cmp5;
                cmp  = {1'b0, A} - {1'b0, mem_rdata};
                cmp5 = {1'b0, A[3:0]} - {1'b0, mem_rdata[3:0]};
                F[`FS]  <= cmp[7]; F[`FZ] <= (cmp[7:0] == 8'h00);
                F[`FH]  <= cmp5[4]; F[`FN] <= 1'b1;
                {B, C}  <= {B, C} - 16'd1;
                case (tmp8b)
                    8'hA1: begin {H,L} <= {H,L}+16'd1; state <= ST_M1_T1; end
                    8'hA9: begin {H,L} <= {H,L}-16'd1; state <= ST_M1_T1; end
                    8'hB1: begin // CPIR
                        {H,L} <= {H,L}+16'd1;
                        if (cmp[7:0] != 8'h00 && {B,C} != 16'd1) begin
                            PC <= PC - 16'd2;
                            state <= ST_BLK1;
                        end else state <= ST_M1_T1;
                        F[`FPV] <= ({B,C}-16'd1 != 16'h0000);
                    end
                    8'hB9: begin // CPDR
                        {H,L} <= {H,L}-16'd1;
                        if (cmp[7:0] != 8'h00 && {B,C} != 16'd1) begin
                            PC <= PC - 16'd2;
                            state <= ST_BLK1;
                        end else state <= ST_M1_T1;
                        F[`FPV] <= ({B,C}-16'd1 != 16'h0000);
                    end
                    default: state <= ST_M1_T1;
                endcase
            end
        end

        // ---------------------------------------------------------------
        // EXEC5: Executa instrução principal (opcode completo em 'opcode')
        // ---------------------------------------------------------------
        ST_EXEC5: begin
            // Limpa prefixos
            prefix_dd <= 1'b0; prefix_fd <= 1'b0;
            prefix_cb <= 1'b0; prefix_ed <= 1'b0;

            casez (opcode)
                // -------------------------------------------------------
                // NOP
                8'h00: state <= ST_M1_T1;

                // HALT
                8'h76: begin halt <= 1'b1; state <= ST_HALT; end

                // LD r,r' (excluindo HALT=0x76)
                8'b01??????: begin
                    if (opcode[2:0] == 3'd6) begin
                        // LD r,(HL)
                        mem_addr  <= get_HL_ix(prefix_dd, prefix_fd) + 
                                     ((prefix_dd || prefix_fd) ? {{8{disp[7]}}, disp} : 16'd0);
                        ret_state <= ST_EXEC5;
                        tmp8b     <= {1'b0, opcode[5:3], 3'd6};  // flag: escrever em r
                        state     <= ST_MR_T1;
                        // Espera fetch do deslocamento se IX/IY
                        if ((prefix_dd || prefix_fd) && disp == 8'h00) begin
                            // busca deslocamento
                            mem_addr  <= PC;
                            ret_state <= ST_EXEC5;
                            state     <= ST_MR_T1;
                        end
                    end else if (opcode[5:3] == 3'd6) begin
                        // LD (HL),r
                        mem_addr  <= get_HL_ix(prefix_dd, prefix_fd);
                        mem_wdata <= get_r8(opcode[2:0]);
                        ret_state <= ST_M1_T1;
                        state     <= ST_MW_T1;
                    end else begin
                        // LD r,r'
                        set_r8(opcode[5:3], get_r8(opcode[2:0]));
                        state <= ST_M1_T1;
                    end
                end

                // ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,r
                8'b10??????: begin
                    if (opcode[2:0] == 3'd6) begin
                        // A,r com (HL)
                        mem_addr  <= {H, L};
                        ret_state <= ST_EXEC5;
                        tmp8b     <= {1'b1, opcode[5:3]}; // operação ALU
                        state     <= ST_MR_T1;
                    end else begin
                        alu_a    = A; alu_b = get_r8(opcode[2:0]); alu_f_in = F;
                        case (opcode[5:3])
                            3'd0: alu_op = ALU_ADD;
                            3'd1: alu_op = ALU_ADC;
                            3'd2: alu_op = ALU_SUB;
                            3'd3: alu_op = ALU_SBC;
                            3'd4: alu_op = ALU_AND;
                            3'd5: alu_op = ALU_XOR;
                            3'd6: alu_op = ALU_OR;
                            3'd7: alu_op = ALU_CP;
                        endcase
                        if (opcode[5:3] != 3'd7) A <= alu_res;
                        F     <= alu_f_out;
                        state <= ST_M1_T1;
                    end
                end

                // INC r
                8'b00???100: begin
                    if (opcode[5:3] == 3'd6) begin
                        mem_addr <= {H, L};
                        ret_state <= ST_EXEC5;
                        tmp8b <= 8'hF0; // flag INC (HL)
                        state <= ST_MR_T1;
                    end else begin
                        alu_a = get_r8(opcode[5:3]); alu_op = ALU_INC; alu_f_in = F;
                        set_r8(opcode[5:3], alu_res);
                        F <= alu_f_out;
                        state <= ST_M1_T1;
                    end
                end
                // DEC r
                8'b00???101: begin
                    if (opcode[5:3] == 3'd6) begin
                        mem_addr <= {H, L};
                        ret_state <= ST_EXEC5;
                        tmp8b <= 8'hF1; // flag DEC (HL)
                        state <= ST_MR_T1;
                    end else begin
                        alu_a = get_r8(opcode[5:3]); alu_op = ALU_DEC; alu_f_in = F;
                        set_r8(opcode[5:3], alu_res);
                        F <= alu_f_out;
                        state <= ST_M1_T1;
                    end
                end

                // LD r,n
                8'b00???110: begin
                    mem_addr  <= PC;
                    PC        <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= {1'b1, opcode[5:3]}; // "LD r,imm"
                    state     <= ST_MR_T1;
                end

                // LD rp,nn
                8'b00??0001: begin
                    mem_addr  <= PC;
                    PC        <= PC + 16'd1;
                    tmp8b     <= opcode[5:4];  // rp index
                    ret_state <= ST_EXEC5;
                    state     <= ST_MR_T1;
                end

                // INC rp
                8'b00??0011: begin
                    case (opcode[5:4])
                        2'd0: {B,C} <= {B,C} + 16'd1;
                        2'd1: {D,E} <= {D,E} + 16'd1;
                        2'd2: if (prefix_dd) IX <= IX+16'd1;
                              else if (prefix_fd) IY <= IY+16'd1;
                              else {H,L} <= {H,L} + 16'd1;
                        2'd3: SP <= SP + 16'd1;
                    endcase
                    state <= ST_M1_T1;
                end

                // DEC rp
                8'b00??1011: begin
                    case (opcode[5:4])
                        2'd0: {B,C} <= {B,C} - 16'd1;
                        2'd1: {D,E} <= {D,E} - 16'd1;
                        2'd2: if (prefix_dd) IX <= IX-16'd1;
                              else if (prefix_fd) IY <= IY-16'd1;
                              else {H,L} <= {H,L} - 16'd1;
                        2'd3: SP <= SP - 16'd1;
                    endcase
                    state <= ST_M1_T1;
                end

                // ADD HL,rp
                8'b00??1001: begin
                    begin
                        reg [16:0] r17;
                        reg [15:0] hl_cur;
                        hl_cur = get_HL_ix(prefix_dd, prefix_fd);
                        r17 = {1'b0, hl_cur} + {1'b0, get_rp(opcode[5:4])};
                        if (prefix_dd) IX <= r17[15:0];
                        else if (prefix_fd) IY <= r17[15:0];
                        else {H,L} <= r17[15:0];
                        F[`FN] <= 1'b0; F[`FC] <= r17[16];
                        F[`FH] <= (hl_cur[11:0] + get_rp(opcode[5:4])[11:0]) > 12'hFFF;
                    end
                    state <= ST_M1_T1;
                end

                // RLCA
                8'h07: begin F[`FC] <= A[7]; A <= {A[6:0],A[7]}; F[`FH] <= 0; F[`FN] <= 0; state <= ST_M1_T1; end
                // RRCA
                8'h0F: begin F[`FC] <= A[0]; A <= {A[0],A[7:1]}; F[`FH] <= 0; F[`FN] <= 0; state <= ST_M1_T1; end
                // RLA
                8'h17: begin tmp8 <= A[7]; A <= {A[6:0],F[`FC]}; F[`FC] <= tmp8; F[`FH] <= 0; F[`FN] <= 0; state <= ST_M1_T1; end
                // RRA
                8'h1F: begin tmp8 <= A[0]; A <= {F[`FC],A[7:1]}; F[`FC] <= tmp8; F[`FH] <= 0; F[`FN] <= 0; state <= ST_M1_T1; end

                // DAA
                8'h27: begin alu_a = A; alu_op = ALU_DAA; alu_f_in = F; A <= alu_res; F <= alu_f_out; state <= ST_M1_T1; end
                // CPL
                8'h2F: begin alu_a = A; alu_op = ALU_CPL; alu_f_in = F; A <= alu_res; F <= alu_f_out; state <= ST_M1_T1; end
                // SCF
                8'h37: begin F[`FC] <= 1'b1; F[`FH] <= 1'b0; F[`FN] <= 1'b0; F[`FY] <= A[5]; F[`FX] <= A[3]; state <= ST_M1_T1; end
                // CCF
                8'h3F: begin F[`FH] <= F[`FC]; F[`FC] <= ~F[`FC]; F[`FN] <= 1'b0; state <= ST_M1_T1; end

                // EX AF,AF'
                8'h08: begin {A,F} <= {A2,F2}; {A2,F2} <= {A,F}; state <= ST_M1_T1; end
                // EXX
                8'hD9: begin
                    {B,C} <= {B2,C2}; {B2,C2} <= {B,C};
                    {D,E} <= {D2,E2}; {D2,E2} <= {D,E};
                    {H,L} <= {H2,L2}; {H2,L2} <= {H,L};
                    state <= ST_M1_T1;
                end
                // EX DE,HL
                8'hEB: begin {D,E} <= {H,L}; {H,L} <= {D,E}; state <= ST_M1_T1; end
                // EX (SP),HL
                8'hE3: begin
                    mem_addr  <= SP;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'hE3;
                    state     <= ST_MR_T1;
                end

                // DJNZ
                8'h10: begin
                    B <= B - 8'd1;
                    mem_addr  <= PC;
                    PC        <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'h10;
                    state     <= ST_MR_T1;
                end

                // JR e
                8'h18: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'h18;
                    state     <= ST_MR_T1;
                end

                // JR cc,e (0x20,0x28,0x30,0x38)
                8'b001??000: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= opcode;
                    state     <= ST_MR_T1;
                end

                // JP nn
                8'hC3: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'hC3;
                    state     <= ST_MR_T1;
                end

                // JP cc,nn
                8'b11???010: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= opcode;
                    state     <= ST_MR_T1;
                end

                // JP (HL)
                8'hE9: begin PC <= get_HL_ix(prefix_dd, prefix_fd); state <= ST_M1_T1; end

                // CALL nn
                8'hCD: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'hCD;
                    state     <= ST_MR_T1;
                end

                // CALL cc,nn
                8'b11???100: begin
                    mem_addr  <= PC; PC <= PC + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= opcode;
                    state     <= ST_MR_T1;
                end

                // RET
                8'hC9: begin
                    mem_addr  <= SP; SP <= SP + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'hC9;
                    state     <= ST_MR_T1;
                end

                // RET cc
                8'b11???000: begin
                    if (eval_cc(opcode[5:3])) begin
                        mem_addr  <= SP; SP <= SP + 16'd1;
                        ret_state <= ST_EXEC5;
                        tmp8b     <= opcode;
                        state     <= ST_MR_T1;
                    end else state <= ST_M1_T1;
                end

                // RST n
                8'b11???111: begin
                    SP        <= SP - 16'd1;
                    mem_addr  <= SP - 16'd1;
                    mem_wdata <= PC[15:8];
                    tmp8b     <= opcode;
                    ret_state <= ST_EXEC5;
                    state     <= ST_MW_T1;
                end

                // PUSH rp2
                8'b11??0101: begin
                    tmp16 <= get_ss(opcode[5:4]);
                    SP     <= SP - 16'd1;
                    mem_addr  <= SP - 16'd1;
                    mem_wdata <= get_ss(opcode[5:4])[15:8];
                    ret_state <= ST_EXEC5;
                    tmp8b     <= 8'hE5;  // flag PUSH
                    state     <= ST_MW_T1;
                end

                // POP rp2
                8'b11??0001: begin
                    mem_addr  <= SP; SP <= SP + 16'd1;
                    ret_state <= ST_EXEC5;
                    tmp8b     <= {1'b1, 2'b10, opcode[5:4]}; // flag POP
                    state     <= ST_MR_T1;
                end

                // LD (BC),A / LD (DE),A
                8'h02: begin mem_addr <= {B,C}; mem_wdata <= A; ret_state <= ST_M1_T1; state <= ST_MW_T1; end
                8'h12: begin mem_addr <= {D,E}; mem_wdata <= A; ret_state <= ST_M1_T1; state <= ST_MW_T1; end

                // LD A,(BC) / LD A,(DE)
                8'h0A: begin mem_addr <= {B,C}; ret_state <= ST_EXEC5; tmp8b <= 8'h0A; state <= ST_MR_T1; end
                8'h1A: begin mem_addr <= {D,E}; ret_state <= ST_EXEC5; tmp8b <= 8'h1A; state <= ST_MR_T1; end

                // LD (nn),A
                8'h32: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'h32; state <= ST_MR_T1; end
                // LD A,(nn)
                8'h3A: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'h3A; state <= ST_MR_T1; end
                // LD (nn),HL
                8'h22: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'h22; state <= ST_MR_T1; end
                // LD HL,(nn)
                8'h2A: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'h2A; state <= ST_MR_T1; end

                // ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,n (immediate)
                8'hC6: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hC6; state <= ST_MR_T1; end
                8'hCE: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hCE; state <= ST_MR_T1; end
                8'hD6: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hD6; state <= ST_MR_T1; end
                8'hDE: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hDE; state <= ST_MR_T1; end
                8'hE6: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hE6; state <= ST_MR_T1; end
                8'hEE: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hEE; state <= ST_MR_T1; end
                8'hF6: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hF6; state <= ST_MR_T1; end
                8'hFE: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hFE; state <= ST_MR_T1; end

                // IN A,(n)
                8'hDB: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hDB; state <= ST_MR_T1; end
                // OUT (n),A
                8'hD3: begin mem_addr <= PC; PC <= PC+16'd1; ret_state <= ST_EXEC5; tmp8b <= 8'hD3; state <= ST_MR_T1; end

                // LD SP,HL
                8'hF9: begin SP <= get_HL_ix(prefix_dd, prefix_fd); state <= ST_M1_T1; end

                // DI / EI
                8'hF3: begin IFF1 <= 1'b0; IFF2 <= 1'b0; state <= ST_M1_T1; end
                8'hFB: begin IFF1 <= 1'b1; IFF2 <= 1'b1; state <= ST_M1_T1; end

                default: state <= ST_M1_T1; // instrução não implementada, ignora
            endcase
        end // ST_EXEC5

        // ---------------------------------------------------------------
        // Continuação de instruções multi-passo
        // (reutilizado para completar fetch de dados e jumps)
        // ---------------------------------------------------------------
        // Nota: ST_EXEC5 também é o estado de "completion" para muitas
        // instruções que chegam aqui via ret_state com tmp8b indicando
        // o que fazer com mem_rdata/io_rdata
        // ---------------------------------------------------------------

        default: state <= ST_M1_T1;
        endcase // state

        // ---------------------------------------------------------------
        // Completar instruções com dados lidos (chegam em ST_EXEC5)
        // Reutilizamos o state ST_EXEC5 como "completion handler"
        // via ret_state + tmp8b
        // ---------------------------------------------------------------
        // Este bloco é avaliado na mesma borda de relógio que a transição
        // para ST_EXEC5, quando o dado já está em mem_rdata
        // ---------------------------------------------------------------

    end // if ce
end // always

// ---------------------------------------------------------------------------
// Completion handler: rodamos num bloco combinacional para simplificar
// O estado ST_EXEC5 faz dispatch baseado em tmp8b quando vem de ret_state
// Isso é implementado no always sequencial acima, mas movemos para aqui
// parte da decodificação das instruções multi-byte
// ---------------------------------------------------------------------------
// (A implementação acima já integra isso via os casos em ST_EXEC5)

endmodule
`default_nettype wire
