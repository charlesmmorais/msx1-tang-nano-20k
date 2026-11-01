// System testbench: runs sim/test_rom.mem on the whole machine
// (CPU, ROM, SDRAM controller + model, VDP, PSG, PPI, PS/2 keyboard).
// Build: see sim/run.sh
`timescale 1ns/1ps

module tb_top;
    reg sys_clk = 1'b0;
    always #18.518 sys_clk = ~sys_clk;          // 27 MHz

    reg btn_s1 = 1'b0;
    reg ps2_clk = 1'b1, ps2_dat = 1'b1;

    wire        sdram_clk, sdram_cke, sdram_cs_n, sdram_cas_n, sdram_ras_n, sdram_we_n;
    wire [31:0] sdram_dq;
    wire [10:0] sdram_addr;
    wire [1:0]  sdram_ba;
    wire [3:0]  sdram_dqm;
    wire [5:0]  led;
    wire        tmds_clk_p, tmds_clk_n;
    wire [2:0]  tmds_d_p, tmds_d_n;

    top dut (
        .sys_clk(sys_clk), .btn_s1(btn_s1), .btn_s2(1'b0), .led(led),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n), .tmds_d_p(tmds_d_p), .tmds_d_n(tmds_d_n),
        .sd_clk(), .sd_mosi(), .sd_miso(1'b1), .sd_cs_n(),
        .ps2_clk(ps2_clk), .ps2_dat(ps2_dat), .audio_pdm(),
        .O_sdram_clk(sdram_clk), .O_sdram_cke(sdram_cke), .O_sdram_cs_n(sdram_cs_n),
        .O_sdram_cas_n(sdram_cas_n), .O_sdram_ras_n(sdram_ras_n), .O_sdram_wen_n(sdram_we_n),
        .IO_sdram_dq(sdram_dq), .O_sdram_addr(sdram_addr), .O_sdram_ba(sdram_ba), .O_sdram_dqm(sdram_dqm)
    );

    sdram_model sdram (
        .clk(sdram_clk), .cke(sdram_cke), .cs_n(sdram_cs_n), .ras_n(sdram_ras_n),
        .cas_n(sdram_cas_n), .we_n(sdram_we_n), .addr(sdram_addr), .ba(sdram_ba),
        .dqm(sdram_dqm), .dq(sdram_dq)
    );

    // Send one PS/2 byte (~12.5 kHz clock)
    task ps2_send(input [7:0] b);
        integer i;
        reg [10:0] f;
        begin
            f = {1'b1, ~^b, b, 1'b0};
            for (i = 0; i < 11; i = i + 1) begin
                ps2_dat = f[i];
                #20000 ps2_clk = 1'b0;
                #40000 ps2_clk = 1'b1;
                #20000;
            end
            #100000;
        end
    endtask

    // Expected OUT (10h) values, in order
    reg [7:0] expect [0:8];
    integer n_out = 0, errors = 0, n_int = 0;
    initial begin
        expect[0] = 8'h55; expect[1] = 8'hAA; expect[2] = 8'h77;
        expect[3] = 8'h3C; expect[4] = 8'hC3; expect[5] = 8'hB8;
        expect[6] = 8'hFE; expect[7] = 8'hF0;
    end

    // Watch the CPU bus for writes to the test ports
    wire io_wr = dut.io_wr;
    wire [7:0] port = dut.a[7:0];
    always @(posedge dut.clk) if (io_wr) begin
        case (port)
            8'h10: begin
                if (n_out > 7 || dut.cpu_dout !== expect[n_out]) begin
                    $display("FAIL: check %0d got %h, expected %h", n_out, dut.cpu_dout, expect[n_out]);
                    errors = errors + 1;
                end else
                    $display("ok  : check %0d = %h", n_out, dut.cpu_dout);
                n_out = n_out + 1;
            end
            8'h12: begin
                n_int = n_int + 1;
                $display("ok  : interrupt, VDP status = %h", dut.cpu_dout);
                if (!dut.cpu_dout[7]) begin
                    $display("FAIL: frame flag not set in status");
                    errors = errors + 1;
                end
            end
            8'h11: end_seen = 1'b1;
        endcase
    end

    // Dump one full HDMI frame (active area) to sim/frame.ppm
    reg     end_seen = 1'b0, dumped = 1'b0;
    integer fd, px_count;
    initial begin
        wait (n_int >= 1);
        wait (dut.vdp.vcnt == 0 && dut.vdp.hcnt == 0);
        @(posedge dut.clk);
        fd = $fopen("sim/frame.ppm", "w");
        $fwrite(fd, "P3\n720 480\n255\n");
        px_count = 0;
        while (px_count < 720 * 480) begin
            @(posedge dut.clk);
            if (dut.vde) begin
                $fwrite(fd, "%0d %0d %0d\n", dut.vr, dut.vg, dut.vb);
                px_count = px_count + 1;
            end
        end
        $fclose(fd);
        dumped = 1'b1;
    end

    // Count RAM accesses and the extra wait states they cost the CPU
    integer ram_acc = 0, ram_waits = 0;
    reg     ram_req_d = 1'b0;
    always @(posedge dut.clk) begin
        ram_req_d <= dut.ram_req;
        if (dut.ram_req && !ram_req_d) ram_acc = ram_acc + 1;
        // waits after the one-time SDRAM power-up delay
        if (dut.cpu_ce && dut.ram_req && !dut.ram_ready && dut.sdram_ok)
            ram_waits = ram_waits + 1;
    end

    initial begin
        wait (end_seen && dumped);
        $display("info: %0d RAM accesses, %0d extra wait states (after SDRAM init)", ram_acc, ram_waits);
        if (n_out != 8) begin
            $display("FAIL: only %0d checks ran", n_out); errors = errors + 1;
        end
        if (n_int < 1) begin
            $display("FAIL: no interrupt"); errors = errors + 1;
        end
        if (!dut.vdp.st_c) begin
            $display("FAIL: sprite collision flag not set"); errors = errors + 1;
        end
        errors = errors + sdram.errors;
        if (errors == 0) $display("PASS - frame written to sim/frame.ppm");
        else             $display("FAILED with %0d errors", errors);
        $finish;
    end

    initial begin
        // press SPACE once the machine is out of reset (the program waits for it)
        wait (dut.rst == 1'b0);
        #100000 ps2_send(8'h29);
        #60000000;
        $display("FAIL: timeout, %0d checks done, PC=%h", n_out, dut.cpu.core.PC);
        $finish;
    end
endmodule
