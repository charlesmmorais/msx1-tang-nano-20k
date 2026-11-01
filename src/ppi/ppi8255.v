// =============================================================================
// i8255 PPI as used in the MSX (mode 0 only), I/O ports A8h-ABh
//   Port A (A8h, out): primary slot select
//   Port B (A9h, in) : keyboard matrix columns of the selected row (0 = key down)
//   Port C (AAh, out): bits 3:0 keyboard row
//                      bit 4  CASON  (0 = cassette motor on)
//                      bit 5  CASW   (cassette write data)
//                      bit 6  CAPS   (0 = CAPS LED on)
//                      bit 7  CLICK  (key click sound)
//   Control (ABh, w) : bit 7 = 1 -> mode set (outputs cleared, like the 8255)
//                      bit 7 = 0 -> bit set/reset on port C
// Reads are combinational; writes happen on the cycle `wr` is high.
// =============================================================================
`default_nettype none

module ppi8255 (
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] a,
    input  wire [7:0] d_in,
    output reg  [7:0] d_out,
    input  wire       wr,        // one-cycle write strobe
    output reg  [7:0] port_a,
    input  wire [7:0] port_b,
    output reg  [7:0] port_c
);

    reg [7:0] ctrl;

    always @(posedge clk) begin
        if (rst) begin
            port_a <= 8'h00;     // all pages -> slot 0 (ROM) at reset
            port_c <= 8'h00;
            ctrl   <= 8'h82;     // MSX mode: A out, B in, C out
        end else if (wr) begin
            case (a)
                2'd0: port_a <= d_in;
                2'd1: ;                               // port B is input
                2'd2: port_c <= d_in;
                2'd3: begin
                    if (d_in[7]) begin
                        ctrl   <= d_in;
                        port_a <= 8'h00;
                        port_c <= 8'h00;
                    end else begin
                        port_c[d_in[3:1]] <= d_in[0];
                    end
                end
            endcase
        end
    end

    always @(*) begin
        case (a)
            2'd0:    d_out = port_a;
            2'd1:    d_out = port_b;
            2'd2:    d_out = port_c;
            default: d_out = ctrl;
        endcase
    end

endmodule
`default_nettype wire
