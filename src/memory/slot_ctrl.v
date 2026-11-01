// =============================================================================
// MSX1 primary-slot decoder
//
// PPI port A selects the primary slot for each 16 KB page:
//   bits 1:0 page 0 (0000-3FFF)   bits 3:2 page 1 (4000-7FFF)
//   bits 5:4 page 2 (8000-BFFF)   bits 7:6 page 3 (C000-FFFF)
//
// Slot map of this machine:
//   slot 0 : system ROM, 48 KB at 0000-BFFF (C-BIOS main 32 KB + logo 16 KB,
//            or a real MSX1 BIOS+BASIC 32 KB). Page 3 is empty.
//   slot 1 : empty (cartridge, future)
//   slot 2 : empty (cartridge, future)
//   slot 3 : 64 KB RAM (embedded SDRAM)
// Expanded slots are not implemented. Empty space reads 0xFF.
// =============================================================================
`default_nettype none

module slot_ctrl (
    input  wire [15:0] addr,
    input  wire [7:0]  slot_reg,   // PPI port A
    output wire        rom_sel,
    output wire        ram_sel,
    output wire [1:0]  cur_slot
);

    assign cur_slot = (addr[15:14] == 2'd0) ? slot_reg[1:0] :
                      (addr[15:14] == 2'd1) ? slot_reg[3:2] :
                      (addr[15:14] == 2'd2) ? slot_reg[5:4] :
                                              slot_reg[7:6];

    assign rom_sel = (cur_slot == 2'd0) && (addr[15:14] != 2'd3);
    assign ram_sel = (cur_slot == 2'd3);

endmodule
`default_nettype wire
