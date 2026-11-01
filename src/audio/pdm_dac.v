// =============================================================================
// First-order sigma-delta DAC (PDM) for audio on a single pin.
// Add an RC low-pass on the pin (e.g. 1 kOhm + 10 nF, ~16 kHz) and an AC
// coupling capacitor before an amplifier or line input.
// =============================================================================
`default_nettype none

module pdm_dac (
    input  wire       clk,    // 27 MHz
    input  wire       rst,
    input  wire [9:0] data,   // 0..1023
    output wire       pdm
);

    reg [10:0] acc;

    always @(posedge clk) begin
        if (rst) acc <= 11'd0;
        else     acc <= {1'b0, acc[9:0]} + {1'b0, data};
    end

    assign pdm = acc[10];

endmodule
`default_nettype wire
