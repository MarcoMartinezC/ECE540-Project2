// simple_vga_wb_controller.sv
// Description: A very simple Wishbone slave VGA controller.
//              Displays a single solid color controllable via a Wishbone register.
//              Designed for maximum synthesizer compatibility.

module vga_wb_controller (
    // Wishbone Interface (wb_clk_i domain)
    input  logic        wb_clk_i,       // Wishbone clock
    input  logic        wb_rst_i,       // Wishbone reset (active-high)
    input  logic [31:0] wb_adr_i,       // Wishbone address (full address from interconnect)
    input  logic [31:0] wb_dat_i,       // Wishbone data input
    input  logic [3:0]  wb_sel_i,       // Wishbone byte select
    input  logic        wb_we_i,        // Wishbone write enable
    input  logic        wb_cyc_i,       // Wishbone cycle
    input  logic        wb_stb_i,       // Wishbone strobe
    output logic [31:0] wb_dat_o,       // Wishbone data output
    output logic        wb_ack_o,       // Wishbone acknowledge
    output logic        wb_err_o,       // Wishbone error (tied low)

    // VGA Pixel Clock Domain Interface
    input  logic        vga_pix_clk_i,  // VGA pixel clock
    input  logic        vga_rst_i,      // VGA domain reset (active-high, synchronous to vga_pix_clk_i)
    input  logic        video_on_i,     // Active display area from DTG (Display Timing Generator)

    // VGA Output Signals (vga_pix_clk_i domain)
    output logic [3:0]  vga_r_o,        // 4-bit Red
    output logic [3:0]  vga_g_o,        // 4-bit Green
    output logic [3:0]  vga_b_o         // 4-bit Blue
);


    localparam REG_COLOR_OFFSET = 4'h0; //Color register at word offset 0

    //internal register for RGB values
    //[11:8] = Red, [7:4] = Green, [3:0] = Blue
    logic [11:0] reg_rgb_color_wb;

    //Synchronized color value (VGA pixel clock domain)
    logic [11:0] synced_rgb_color_vga;
    logic [11:0] synced_rgb_color_vga_s1;

    logic        wb_select_color_reg;
    logic [3:0]  local_addr_offset;

    assign local_addr_offset   = wb_adr_i[5:2];
    assign wb_select_color_reg = (wb_cyc_i && wb_stb_i && (local_addr_offset == REG_COLOR_OFFSET));

    //Wishbone write and acknowledge
    always_ff @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            reg_rgb_color_wb <= 12'hF00; // Default to Red color
            wb_ack_o         <= 1'b0;
        end else begin
            wb_ack_o <= 1'b0; // Default to no acknowledge

            if (wb_select_color_reg && !wb_ack_o) begin // Check !wb_ack_o to prevent re-acking in a multi-cycle scenario (though this is single cycle)
                wb_ack_o <= 1'b1; // Acknowledge the transaction
                if (wb_we_i) begin
                    // Write to the color register (only lower 12 bits are used from wb_dat_i)
                    // Byte selects allow partial writes if desired by master, but here we take the relevant bits.
                    if (wb_sel_i[0]) reg_rgb_color_wb[7:0]  <= wb_dat_i[7:0];   // Blue and Green LSBs
                    if (wb_sel_i[1]) reg_rgb_color_wb[11:8] <= wb_dat_i[11:8];  // Red MSBs
                                        // Alternatively, for a full word write of the color:
                                        // reg_rgb_color_wb <= wb_dat_i[11:0]; (if wb_sel_i == 4'b0011 or 4'b1111)
                end
            end
        end
    end

    // Wishbone read data path
    // Output the content of the color register (padded to 32 bits)
    assign wb_dat_o = (wb_select_color_reg) ? {20'h00000, reg_rgb_color_wb} : 32'hDEADBEEF;
    assign wb_err_o = 1'b0; // No error conditions implemented

    always_ff @(posedge vga_pix_clk_i or posedge vga_rst_i) begin
        if (vga_rst_i) begin
            synced_rgb_color_vga_s1 <= 12'hF00; //Default Red
            synced_rgb_color_vga    <= 12'hF00; // Default Red
        end else begin

         
    synced_rgb_color_vga_s1 <= 12'h0F0; //debugging, force GREEN
    synced_rgb_color_vga    <= 12'h0F0;
    end

    logic [11:0] current_pixel_rgb_comb;

    always_comb begin
        if (video_on_i) begin
            current_pixel_rgb_comb = synced_rgb_color_vga;
        end else begin
            current_pixel_rgb_comb = 12'h000; //Black during blanking intervals
        end
    end

    //VGA outputs, 4 bits
    assign vga_r_o = current_pixel_rgb_comb[11:8]; // Red component
    assign vga_g_o = current_pixel_rgb_comb[7:4];  // Green component
    assign vga_b_o = current_pixel_rgb_comb[3:0];  // Blue component

endmodule
