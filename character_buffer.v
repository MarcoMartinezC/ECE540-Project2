//character_buffer.v
//Handles character framebuffer RAM and 8x8 Font ROM.
//Determines if a pixel is foreground based on character data.
//Verilog-2001 Compliant

module character_buffer (
    //Clocks and Reset
    input wire i_vga_clk,       //Pixel clock
    input wire i_sys_clk,       //System clock for Wishbone interface & RAM write
    input wire i_rst,           //System reset

    //Pixel Position Inputs (from dtg via vga_controller)
    input wire [11:0] i_pixel_row,    //Current screen pixel row
    input wire [11:0] i_pixel_col,    //Current screen pixel column
    input wire        i_video_on,     //True if in active display area

    //Wishbone Slave Interface (for CPU to write to character framebuffer)
    input wire [5:0]  i_wb_fb_adr,    //Framebuffer address (limited to 64 bytes by this width)
    input wire [31:0] i_wb_fb_dat_w,  //Data to write (CPU writes ASCII char)
    input wire [3:0]  i_wb_fb_sel,    //Byte select
    input wire        i_wb_fb_we,     //Write enable
    input wire        i_wb_fb_cyc,    //Wishbone cycle
    input wire        i_wb_fb_stb,    //Wishbone strobe
    output reg        o_wb_fb_ack,    //Wishbone acknowledge

    //Output
    output reg outputPixel_is_foreground     //True if the current pixel is part of a character's foreground
);

    //Parameters for display and character rendering
    localparam H_ACTIVE_PIXELS = 640;
    localparam V_ACTIVE_PIXELS = 480;

    localparam CHAR_WIDTH_PIXELS  = 8;
    localparam CHAR_HEIGHT_PIXELS = 8; //Changed to 8 for 8x8 font

    localparam SCREEN_CHAR_COLS = H_ACTIVE_PIXELS / CHAR_WIDTH_PIXELS; //80
    localparam SCREEN_CHAR_ROWS = V_ACTIVE_PIXELS / CHAR_HEIGHT_PIXELS; //480 / 8 = 60

    localparam FRAMEBUFFER_SIZE = SCREEN_CHAR_COLS * SCREEN_CHAR_ROWS;     //80 * 60 = 4800 bytes
    localparam FRAMEBUFFER_ADDR_BITS = 13;//13 bits

    //Font ROM: 128 ASCII characters, 8x8 pixels each.
    localparam FONT_NUM_CHARS      = 128;
    localparam FONT_BYTES_PER_CHAR = CHAR_HEIGHT_PIXELS; //8 bytes
    localparam FONT_ROM_SIZE_BYTES = FONT_NUM_CHARS * FONT_BYTES_PER_CHAR; //128 * 8 = 1024 bytes
    localparam FONT_ROM_ADDR_BITS  = 10; //10 bits

    //framebuffer for character
    reg [7:0] char_framebuffer [0:FRAMEBUFFER_SIZE-1];

    //Font ROM
    reg [7:0] font_rom [0:FONT_ROM_SIZE_BYTES-1];

    integer k;
    initial begin
        //Initialize framebuffer to spaces (ASCII 32)
        for (k = 0; k < FRAMEBUFFER_SIZE; k = k + 1) begin
            char_framebuffer[k] = 8'h20; //ASCII for space 
        end

        //Initialize Font ROM from provided 8x8 font data
        for (k = 0; k < (32 * FONT_BYTES_PER_CHAR); k = k + 1) begin //First 32 chars
            font_rom[k] = 8'h00;
        end
        //ASCII table for characters
        //ASCII ' ' (U+0020, dec 32)
        font_rom[(32*8) + 0] = 8'h00; font_rom[(32*8) + 1] = 8'h00; font_rom[(32*8) + 2] = 8'h00; font_rom[(32*8) + 3] = 8'h00;
        font_rom[(32*8) + 4] = 8'h00; font_rom[(32*8) + 5] = 8'h00; font_rom[(32*8) + 6] = 8'h00; font_rom[(32*8) + 7] = 8'h00;
        //ASCII '!' (U+0021, dec 33)
        font_rom[(33*8) + 0] = 8'h18; font_rom[(33*8) + 1] = 8'h3C; font_rom[(33*8) + 2] = 8'h3C; font_rom[(33*8) + 3] = 8'h18;
        font_rom[(33*8) + 4] = 8'h18; font_rom[(33*8) + 5] = 8'h00; font_rom[(33*8) + 6] = 8'h18; font_rom[(33*8) + 7] = 8'h00;
        //ASCII '"' (U+0022, dec 34)
        font_rom[(34*8) + 0] = 8'h36; font_rom[(34*8) + 1] = 8'h36; font_rom[(34*8) + 2] = 8'h00; font_rom[(34*8) + 3] = 8'h00;
        font_rom[(34*8) + 4] = 8'h00; font_rom[(34*8) + 5] = 8'h00; font_rom[(34*8) + 6] = 8'h00; font_rom[(34*8) + 7] = 8'h00;
        //ASCII '#' (U+0023, dec 35)
        font_rom[(35*8) + 0] = 8'h36; font_rom[(35*8) + 1] = 8'h36; font_rom[(35*8) + 2] = 8'h7F; font_rom[(35*8) + 3] = 8'h36;
        font_rom[(35*8) + 4] = 8'h7F; font_rom[(35*8) + 5] = 8'h36; font_rom[(35*8) + 6] = 8'h36; font_rom[(35*8) + 7] = 8'h00;
        //ASCII '$' (U+0024, dec 36)
        font_rom[(36*8) + 0] = 8'h0C; font_rom[(36*8) + 1] = 8'h3E; font_rom[(36*8) + 2] = 8'h03; font_rom[(36*8) + 3] = 8'h1E;
        font_rom[(36*8) + 4] = 8'h30; font_rom[(36*8) + 5] = 8'h1F; font_rom[(36*8) + 6] = 8'h0C; font_rom[(36*8) + 7] = 8'h00;
        //ASCII '%' (U+0025, dec 37)
        font_rom[(37*8) + 0] = 8'h00; font_rom[(37*8) + 1] = 8'h63; font_rom[(37*8) + 2] = 8'h33; font_rom[(37*8) + 3] = 8'h18;
        font_rom[(37*8) + 4] = 8'h0C; font_rom[(37*8) + 5] = 8'h66; font_rom[(37*8) + 6] = 8'h63; font_rom[(37*8) + 7] = 8'h00;
        //ASCII '&' (U+0026, dec 38)
        font_rom[(38*8) + 0] = 8'h1C; font_rom[(38*8) + 1] = 8'h36; font_rom[(38*8) + 2] = 8'h1C; font_rom[(38*8) + 3] = 8'h6E;
        font_rom[(38*8) + 4] = 8'h3B; font_rom[(38*8) + 5] = 8'h33; font_rom[(38*8) + 6] = 8'h6E; font_rom[(38*8) + 7] = 8'h00;
        //ASCII ''' (U+0027, dec 39)
        font_rom[(39*8) + 0] = 8'h06; font_rom[(39*8) + 1] = 8'h06; font_rom[(39*8) + 2] = 8'h03; font_rom[(39*8) + 3] = 8'h00;
        font_rom[(39*8) + 4] = 8'h00; font_rom[(39*8) + 5] = 8'h00; font_rom[(39*8) + 6] = 8'h00; font_rom[(39*8) + 7] = 8'h00;
        //ASCII '(' (U+0028, dec 40)
        font_rom[(40*8) + 0] = 8'h18; font_rom[(40*8) + 1] = 8'h0C; font_rom[(40*8) + 2] = 8'h06; font_rom[(40*8) + 3] = 8'h06;
        font_rom[(40*8) + 4] = 8'h06; font_rom[(40*8) + 5] = 8'h0C; font_rom[(40*8) + 6] = 8'h18; font_rom[(40*8) + 7] = 8'h00;
        //ASCII ')' (U+0029, dec 41)
        font_rom[(41*8) + 0] = 8'h06; font_rom[(41*8) + 1] = 8'h0C; font_rom[(41*8) + 2] = 8'h18; font_rom[(41*8) + 3] = 8'h18;
        font_rom[(41*8) + 4] = 8'h18; font_rom[(41*8) + 5] = 8'h0C; font_rom[(41*8) + 6] = 8'h06; font_rom[(41*8) + 7] = 8'h00;
        //ASCII '*' (U+002A, dec 42)
        font_rom[(42*8) + 0] = 8'h00; font_rom[(42*8) + 1] = 8'h66; font_rom[(42*8) + 2] = 8'h3C; font_rom[(42*8) + 3] = 8'hFF;
        font_rom[(42*8) + 4] = 8'h3C; font_rom[(42*8) + 5] = 8'h66; font_rom[(42*8) + 6] = 8'h00; font_rom[(42*8) + 7] = 8'h00;
        //ASCII '+' (U+002B, dec 43)
        font_rom[(43*8) + 0] = 8'h00; font_rom[(43*8) + 1] = 8'h0C; font_rom[(43*8) + 2] = 8'h0C; font_rom[(43*8) + 3] = 8'h3F;
        font_rom[(43*8) + 4] = 8'h0C; font_rom[(43*8) + 5] = 8'h0C; font_rom[(43*8) + 6] = 8'h00; font_rom[(43*8) + 7] = 8'h00;
        //ASCII ',' (U+002C, dec 44)
        font_rom[(44*8) + 0] = 8'h00; font_rom[(44*8) + 1] = 8'h00; font_rom[(44*8) + 2] = 8'h00; font_rom[(44*8) + 3] = 8'h00;
        font_rom[(44*8) + 4] = 8'h00; font_rom[(44*8) + 5] = 8'h0C; font_rom[(44*8) + 6] = 8'h0C; font_rom[(44*8) + 7] = 8'h06;
        //ASCII '-' (U+002D, dec 45)
        font_rom[(45*8) + 0] = 8'h00; font_rom[(45*8) + 1] = 8'h00; font_rom[(45*8) + 2] = 8'h00; font_rom[(45*8) + 3] = 8'h3F;
        font_rom[(45*8) + 4] = 8'h00; font_rom[(45*8) + 5] = 8'h00; font_rom[(45*8) + 6] = 8'h00; font_rom[(45*8) + 7] = 8'h00;
        //ASCII '.' (U+002E, dec 46)
        font_rom[(46*8) + 0] = 8'h00; font_rom[(46*8) + 1] = 8'h00; font_rom[(46*8) + 2] = 8'h00; font_rom[(46*8) + 3] = 8'h00;
        font_rom[(46*8) + 4] = 8'h00; font_rom[(46*8) + 5] = 8'h0C; font_rom[(46*8) + 6] = 8'h0C; font_rom[(46*8) + 7] = 8'h00;
        //ASCII '/' (U+002F, dec 47)
        font_rom[(47*8) + 0] = 8'h60; font_rom[(47*8) + 1] = 8'h30; font_rom[(47*8) + 2] = 8'h18; font_rom[(47*8) + 3] = 8'h0C;
        font_rom[(47*8) + 4] = 8'h06; font_rom[(47*8) + 5] = 8'h03; font_rom[(47*8) + 6] = 8'h01; font_rom[(47*8) + 7] = 8'h00;
        //ASCII '0' (U+0030, dec 48)
        font_rom[(48*8) + 0] = 8'h3E; font_rom[(48*8) + 1] = 8'h63; font_rom[(48*8) + 2] = 8'h73; font_rom[(48*8) + 3] = 8'h7B;
        font_rom[(48*8) + 4] = 8'h6F; font_rom[(48*8) + 5] = 8'h67; font_rom[(48*8) + 6] = 8'h3E; font_rom[(48*8) + 7] = 8'h00;
        //ASCII '1' (U+0031, dec 49)
        font_rom[(49*8) + 0] = 8'h0C; font_rom[(49*8) + 1] = 8'h0E; font_rom[(49*8) + 2] = 8'h0C; font_rom[(49*8) + 3] = 8'h0C;
        font_rom[(49*8) + 4] = 8'h0C; font_rom[(49*8) + 5] = 8'h0C; font_rom[(49*8) + 6] = 8'h3F; font_rom[(49*8) + 7] = 8'h00;
        //ASCII '2' (U+0032, dec 50)
        font_rom[(50*8) + 0] = 8'h1E; font_rom[(50*8) + 1] = 8'h33; font_rom[(50*8) + 2] = 8'h30; font_rom[(50*8) + 3] = 8'h1C;
        font_rom[(50*8) + 4] = 8'h06; font_rom[(50*8) + 5] = 8'h33; font_rom[(50*8) + 6] = 8'h3F; font_rom[(50*8) + 7] = 8'h00;
        //ASCII '3' (U+0033, dec 51)
        font_rom[(51*8) + 0] = 8'h1E; font_rom[(51*8) + 1] = 8'h33; font_rom[(51*8) + 2] = 8'h30; font_rom[(51*8) + 3] = 8'h1C;
        font_rom[(51*8) + 4] = 8'h30; font_rom[(51*8) + 5] = 8'h33; font_rom[(51*8) + 6] = 8'h1E; font_rom[(51*8) + 7] = 8'h00;
        //ASCII '4' (U+0034, dec 52)
        font_rom[(52*8) + 0] = 8'h38; font_rom[(52*8) + 1] = 8'h3C; font_rom[(52*8) + 2] = 8'h36; font_rom[(52*8) + 3] = 8'h33;
        font_rom[(52*8) + 4] = 8'h7F; font_rom[(52*8) + 5] = 8'h30; font_rom[(52*8) + 6] = 8'h78; font_rom[(52*8) + 7] = 8'h00;
        //ASCII '5' (U+0035, dec 53)
        font_rom[(53*8) + 0] = 8'h3F; font_rom[(53*8) + 1] = 8'h03; font_rom[(53*8) + 2] = 8'h1F; font_rom[(53*8) + 3] = 8'h30;
        font_rom[(53*8) + 4] = 8'h30; font_rom[(53*8) + 5] = 8'h33; font_rom[(53*8) + 6] = 8'h1E; font_rom[(53*8) + 7] = 8'h00;
        //ASCII '6' (U+0036, dec 54)
        font_rom[(54*8) + 0] = 8'h1C; font_rom[(54*8) + 1] = 8'h06; font_rom[(54*8) + 2] = 8'h03; font_rom[(54*8) + 3] = 8'h1F;
        font_rom[(54*8) + 4] = 8'h33; font_rom[(54*8) + 5] = 8'h33; font_rom[(54*8) + 6] = 8'h1E; font_rom[(54*8) + 7] = 8'h00;
        //ASCII '7' (U+0037, dec 55)
        font_rom[(55*8) + 0] = 8'h3F; font_rom[(55*8) + 1] = 8'h33; font_rom[(55*8) + 2] = 8'h30; font_rom[(55*8) + 3] = 8'h18;
        font_rom[(55*8) + 4] = 8'h0C; font_rom[(55*8) + 5] = 8'h0C; font_rom[(55*8) + 6] = 8'h0C; font_rom[(55*8) + 7] = 8'h00;
        //ASCII '8' (U+0038, dec 56)
        font_rom[(56*8) + 0] = 8'h1E; font_rom[(56*8) + 1] = 8'h33; font_rom[(56*8) + 2] = 8'h33; font_rom[(56*8) + 3] = 8'h1E;
        font_rom[(56*8) + 4] = 8'h33; font_rom[(56*8) + 5] = 8'h33; font_rom[(56*8) + 6] = 8'h1E; font_rom[(56*8) + 7] = 8'h00;
        //ASCII '9' (U+0039, dec 57)
        font_rom[(57*8) + 0] = 8'h1E; font_rom[(57*8) + 1] = 8'h33; font_rom[(57*8) + 2] = 8'h33; font_rom[(57*8) + 3] = 8'h3E;
        font_rom[(57*8) + 4] = 8'h30; font_rom[(57*8) + 5] = 8'h18; font_rom[(57*8) + 6] = 8'h0E; font_rom[(57*8) + 7] = 8'h00;
        //ASCII ':' (U+003A, dec 58)
        font_rom[(58*8) + 0] = 8'h00; font_rom[(58*8) + 1] = 8'h0C; font_rom[(58*8) + 2] = 8'h0C; font_rom[(58*8) + 3] = 8'h00;
        font_rom[(58*8) + 4] = 8'h00; font_rom[(58*8) + 5] = 8'h0C; font_rom[(58*8) + 6] = 8'h0C; font_rom[(58*8) + 7] = 8'h00;
        //ASCII ';' (U+003B, dec 59)
        font_rom[(59*8) + 0] = 8'h00; font_rom[(59*8) + 1] = 8'h0C; font_rom[(59*8) + 2] = 8'h0C; font_rom[(59*8) + 3] = 8'h00;
        font_rom[(59*8) + 4] = 8'h00; font_rom[(59*8) + 5] = 8'h0C; font_rom[(59*8) + 6] = 8'h0C; font_rom[(59*8) + 7] = 8'h06;
        //ASCII '<' (U+003C, dec 60)
        font_rom[(60*8) + 0] = 8'h18; font_rom[(60*8) + 1] = 8'h0C; font_rom[(60*8) + 2] = 8'h06; font_rom[(60*8) + 3] = 8'h03;
        font_rom[(60*8) + 4] = 8'h06; font_rom[(60*8) + 5] = 8'h0C; font_rom[(60*8) + 6] = 8'h18; font_rom[(60*8) + 7] = 8'h00;
        //ASCII '=' (U+003D, dec 61)
        font_rom[(61*8) + 0] = 8'h00; font_rom[(61*8) + 1] = 8'h00; font_rom[(61*8) + 2] = 8'h3F; font_rom[(61*8) + 3] = 8'h00;
        font_rom[(61*8) + 4] = 8'h00; font_rom[(61*8) + 5] = 8'h3F; font_rom[(61*8) + 6] = 8'h00; font_rom[(61*8) + 7] = 8'h00;
        //ASCII '>' (U+003E, dec 62)
        font_rom[(62*8) + 0] = 8'h06; font_rom[(62*8) + 1] = 8'h0C; font_rom[(62*8) + 2] = 8'h18; font_rom[(62*8) + 3] = 8'h30;
        font_rom[(62*8) + 4] = 8'h18; font_rom[(62*8) + 5] = 8'h0C; font_rom[(62*8) + 6] = 8'h06; font_rom[(62*8) + 7] = 8'h00;
        //ASCII '?' (U+003F, dec 63)
        font_rom[(63*8) + 0] = 8'h1E; font_rom[(63*8) + 1] = 8'h33; font_rom[(63*8) + 2] = 8'h30; font_rom[(63*8) + 3] = 8'h18;
        font_rom[(63*8) + 4] = 8'h0C; font_rom[(63*8) + 5] = 8'h00; font_rom[(63*8) + 6] = 8'h0C; font_rom[(63*8) + 7] = 8'h00;
        //ASCII '@' (U+0040, dec 64)
        font_rom[(64*8) + 0] = 8'h3E; font_rom[(64*8) + 1] = 8'h63; font_rom[(64*8) + 2] = 8'h7B; font_rom[(64*8) + 3] = 8'h7B;
        font_rom[(64*8) + 4] = 8'h7B; font_rom[(64*8) + 5] = 8'h03; font_rom[(64*8) + 6] = 8'h1E; font_rom[(64*8) + 7] = 8'h00;
        //ASCII 'A' (U+0041, dec 65)
        font_rom[(65*8) + 0] = 8'h0C; font_rom[(65*8) + 1] = 8'h1E; font_rom[(65*8) + 2] = 8'h33; font_rom[(65*8) + 3] = 8'h33;
        font_rom[(65*8) + 4] = 8'h3F; font_rom[(65*8) + 5] = 8'h33; font_rom[(65*8) + 6] = 8'h33; font_rom[(65*8) + 7] = 8'h00;
        //ASCII 'B' (U+0042, dec 66)
        font_rom[(66*8) + 0] = 8'h3F; font_rom[(66*8) + 1] = 8'h66; font_rom[(66*8) + 2] = 8'h66; font_rom[(66*8) + 3] = 8'h3E;
        font_rom[(66*8) + 4] = 8'h66; font_rom[(66*8) + 5] = 8'h66; font_rom[(66*8) + 6] = 8'h3F; font_rom[(66*8) + 7] = 8'h00;
        //ASCII 'C' (U+0043, dec 67)
        font_rom[(67*8) + 0] = 8'h3C; font_rom[(67*8) + 1] = 8'h66; font_rom[(67*8) + 2] = 8'h03; font_rom[(67*8) + 3] = 8'h03;
        font_rom[(67*8) + 4] = 8'h03; font_rom[(67*8) + 5] = 8'h66; font_rom[(67*8) + 6] = 8'h3C; font_rom[(67*8) + 7] = 8'h00;
        //ASCII 'D' (U+0044, dec 68)
        font_rom[(68*8) + 0] = 8'h1F; font_rom[(68*8) + 1] = 8'h36; font_rom[(68*8) + 2] = 8'h66; font_rom[(68*8) + 3] = 8'h66;
        font_rom[(68*8) + 4] = 8'h66; font_rom[(68*8) + 5] = 8'h36; font_rom[(68*8) + 6] = 8'h1F; font_rom[(68*8) + 7] = 8'h00;
        //ASCII 'E' (U+0045, dec 69)
        font_rom[(69*8) + 0] = 8'h7F; font_rom[(69*8) + 1] = 8'h46; font_rom[(69*8) + 2] = 8'h16; font_rom[(69*8) + 3] = 8'h1E;
        font_rom[(69*8) + 4] = 8'h16; font_rom[(69*8) + 5] = 8'h46; font_rom[(69*8) + 6] = 8'h7F; font_rom[(69*8) + 7] = 8'h00;
        //ASCII 'F' (U+0046, dec 70)
        font_rom[(70*8) + 0] = 8'h7F; font_rom[(70*8) + 1] = 8'h46; font_rom[(70*8) + 2] = 8'h16; font_rom[(70*8) + 3] = 8'h1E;
        font_rom[(70*8) + 4] = 8'h16; font_rom[(70*8) + 5] = 8'h06; font_rom[(70*8) + 6] = 8'h0F; font_rom[(70*8) + 7] = 8'h00;
        //ASCII 'G' (U+0047, dec 71)
        font_rom[(71*8) + 0] = 8'h3C; font_rom[(71*8) + 1] = 8'h66; font_rom[(71*8) + 2] = 8'h03; font_rom[(71*8) + 3] = 8'h03;
        font_rom[(71*8) + 4] = 8'h73; font_rom[(71*8) + 5] = 8'h66; font_rom[(71*8) + 6] = 8'h7C; font_rom[(71*8) + 7] = 8'h00;
        //ASCII 'H' (U+0048, dec 72)
        font_rom[(72*8) + 0] = 8'h33; font_rom[(72*8) + 1] = 8'h33; font_rom[(72*8) + 2] = 8'h33; font_rom[(72*8) + 3] = 8'h3F;
        font_rom[(72*8) + 4] = 8'h33; font_rom[(72*8) + 5] = 8'h33; font_rom[(72*8) + 6] = 8'h33; font_rom[(72*8) + 7] = 8'h00;
        //ASCII 'I' (U+0049, dec 73)
        font_rom[(73*8) + 0] = 8'h1E; font_rom[(73*8) + 1] = 8'h0C; font_rom[(73*8) + 2] = 8'h0C; font_rom[(73*8) + 3] = 8'h0C;
        font_rom[(73*8) + 4] = 8'h0C; font_rom[(73*8) + 5] = 8'h0C; font_rom[(73*8) + 6] = 8'h1E; font_rom[(73*8) + 7] = 8'h00;
        //ASCII 'J' (U+004A, dec 74)
        font_rom[(74*8) + 0] = 8'h78; font_rom[(74*8) + 1] = 8'h30; font_rom[(74*8) + 2] = 8'h30; font_rom[(74*8) + 3] = 8'h30;
        font_rom[(74*8) + 4] = 8'h33; font_rom[(74*8) + 5] = 8'h33; font_rom[(74*8) + 6] = 8'h1E; font_rom[(74*8) + 7] = 8'h00;
        //ASCII 'K' (U+004B, dec 75)
        font_rom[(75*8) + 0] = 8'h67; font_rom[(75*8) + 1] = 8'h66; font_rom[(75*8) + 2] = 8'h36; font_rom[(75*8) + 3] = 8'h1E;
        font_rom[(75*8) + 4] = 8'h36; font_rom[(75*8) + 5] = 8'h66; font_rom[(75*8) + 6] = 8'h67; font_rom[(75*8) + 7] = 8'h00;
        //ASCII 'L' (U+004C, dec 76)
        font_rom[(76*8) + 0] = 8'h0F; font_rom[(76*8) + 1] = 8'h06; font_rom[(76*8) + 2] = 8'h06; font_rom[(76*8) + 3] = 8'h06;
        font_rom[(76*8) + 4] = 8'h46; font_rom[(76*8) + 5] = 8'h66; font_rom[(76*8) + 6] = 8'h7F; font_rom[(76*8) + 7] = 8'h00;
        //ASCII 'M' (U+004D, dec 77)
        font_rom[(77*8) + 0] = 8'h63; font_rom[(77*8) + 1] = 8'h77; font_rom[(77*8) + 2] = 8'h7F; font_rom[(77*8) + 3] = 8'h7F;
        font_rom[(77*8) + 4] = 8'h6B; font_rom[(77*8) + 5] = 8'h63; font_rom[(77*8) + 6] = 8'h63; font_rom[(77*8) + 7] = 8'h00;
        //ASCII 'N' (U+004E, dec 78)
        font_rom[(78*8) + 0] = 8'h63; font_rom[(78*8) + 1] = 8'h67; font_rom[(78*8) + 2] = 8'h6F; font_rom[(78*8) + 3] = 8'h7B;
        font_rom[(78*8) + 4] = 8'h73; font_rom[(78*8) + 5] = 8'h63; font_rom[(78*8) + 6] = 8'h63; font_rom[(78*8) + 7] = 8'h00;
        //ASCII 'O' (U+004F, dec 79)
        font_rom[(79*8) + 0] = 8'h1C; font_rom[(79*8) + 1] = 8'h36; font_rom[(79*8) + 2] = 8'h63; font_rom[(79*8) + 3] = 8'h63;
        font_rom[(79*8) + 4] = 8'h63; font_rom[(79*8) + 5] = 8'h36; font_rom[(79*8) + 6] = 8'h1C; font_rom[(79*8) + 7] = 8'h00;
        //ASCII 'P' (U+0050, dec 80)
        font_rom[(80*8) + 0] = 8'h3F; font_rom[(80*8) + 1] = 8'h66; font_rom[(80*8) + 2] = 8'h66; font_rom[(80*8) + 3] = 8'h3E;
        font_rom[(80*8) + 4] = 8'h06; font_rom[(80*8) + 5] = 8'h06; font_rom[(80*8) + 6] = 8'h0F; font_rom[(80*8) + 7] = 8'h00;
        //ASCII 'Q' (U+0051, dec 81)
        font_rom[(81*8) + 0] = 8'h1E; font_rom[(81*8) + 1] = 8'h33; font_rom[(81*8) + 2] = 8'h33; font_rom[(81*8) + 3] = 8'h33;
        font_rom[(81*8) + 4] = 8'h3B; font_rom[(81*8) + 5] = 8'h1E; font_rom[(81*8) + 6] = 8'h38; font_rom[(81*8) + 7] = 8'h00;
        //ASCII 'R' (U+0052, dec 82)
        font_rom[(82*8) + 0] = 8'h3F; font_rom[(82*8) + 1] = 8'h66; font_rom[(82*8) + 2] = 8'h66; font_rom[(82*8) + 3] = 8'h3E;
        font_rom[(82*8) + 4] = 8'h36; font_rom[(82*8) + 5] = 8'h66; font_rom[(82*8) + 6] = 8'h67; font_rom[(82*8) + 7] = 8'h00;
        //ASCII 'S' (U+0053, dec 83)
        font_rom[(83*8) + 0] = 8'h1E; font_rom[(83*8) + 1] = 8'h33; font_rom[(83*8) + 2] = 8'h07; font_rom[(83*8) + 3] = 8'h0E;
        font_rom[(83*8) + 4] = 8'h38; font_rom[(83*8) + 5] = 8'h33; font_rom[(83*8) + 6] = 8'h1E; font_rom[(83*8) + 7] = 8'h00;
        //ASCII 'T' (U+0054, dec 84)
        font_rom[(84*8) + 0] = 8'h3F; font_rom[(84*8) + 1] = 8'h2D; font_rom[(84*8) + 2] = 8'h0C; font_rom[(84*8) + 3] = 8'h0C;
        font_rom[(84*8) + 4] = 8'h0C; font_rom[(84*8) + 5] = 8'h0C; font_rom[(84*8) + 6] = 8'h1E; font_rom[(84*8) + 7] = 8'h00;
        //ASCII 'U' (U+0055, dec 85)
        font_rom[(85*8) + 0] = 8'h33; font_rom[(85*8) + 1] = 8'h33; font_rom[(85*8) + 2] = 8'h33; font_rom[(85*8) + 3] = 8'h33;
        font_rom[(85*8) + 4] = 8'h33; font_rom[(85*8) + 5] = 8'h33; font_rom[(85*8) + 6] = 8'h3F; font_rom[(85*8) + 7] = 8'h00;
        //ASCII 'V' (U+0056, dec 86)
        font_rom[(86*8) + 0] = 8'h33; font_rom[(86*8) + 1] = 8'h33; font_rom[(86*8) + 2] = 8'h33; font_rom[(86*8) + 3] = 8'h33;
        font_rom[(86*8) + 4] = 8'h33; font_rom[(86*8) + 5] = 8'h1E; font_rom[(86*8) + 6] = 8'h0C; font_rom[(86*8) + 7] = 8'h00;
        //ASCII 'W' (U+0057, dec 87)
        font_rom[(87*8) + 0] = 8'h63; font_rom[(87*8) + 1] = 8'h63; font_rom[(87*8) + 2] = 8'h63; font_rom[(87*8) + 3] = 8'h6B;
        font_rom[(87*8) + 4] = 8'h7F; font_rom[(87*8) + 5] = 8'h77; font_rom[(87*8) + 6] = 8'h63; font_rom[(87*8) + 7] = 8'h00;
        //ASCII 'X' (U+0058, dec 88)
        font_rom[(88*8) + 0] = 8'h63; font_rom[(88*8) + 1] = 8'h63; font_rom[(88*8) + 2] = 8'h36; font_rom[(88*8) + 3] = 8'h1C;
        font_rom[(88*8) + 4] = 8'h1C; font_rom[(88*8) + 5] = 8'h36; font_rom[(88*8) + 6] = 8'h63; font_rom[(88*8) + 7] = 8'h00;
        //ASCII 'Y' (U+0059, dec 89)
        font_rom[(89*8) + 0] = 8'h33; font_rom[(89*8) + 1] = 8'h33; font_rom[(89*8) + 2] = 8'h33; font_rom[(89*8) + 3] = 8'h1E;
        font_rom[(89*8) + 4] = 8'h0C; font_rom[(89*8) + 5] = 8'h0C; font_rom[(89*8) + 6] = 8'h1E; font_rom[(89*8) + 7] = 8'h00;
        //ASCII 'Z' (U+005A, dec 90)
        font_rom[(90*8) + 0] = 8'h7F; font_rom[(90*8) + 1] = 8'h63; font_rom[(90*8) + 2] = 8'h31; font_rom[(90*8) + 3] = 8'h18;
        font_rom[(90*8) + 4] = 8'h4C; font_rom[(90*8) + 5] = 8'h66; font_rom[(90*8) + 6] = 8'h7F; font_rom[(90*8) + 7] = 8'h00;

    end

    //Pixel Generation
    //Pipeline stage 1 (VGA Clock Domain): Read from Character Framebuffer
    reg [7:0] char_ascii_code_r; //Registered ASCII code from framebuffer
            reg [($clog2(SCREEN_CHAR_COLS))-1:0] char_col_idx;
            reg [($clog2(SCREEN_CHAR_ROWS))-1:0] char_row_idx;
            reg [FRAMEBUFFER_ADDR_BITS-1:0] current_fb_read_addr_comb;
    
    
    
    
    
    always @(posedge i_vga_clk) begin
        if (i_rst) begin
            char_ascii_code_r <= 8'h20; //Default to space
        end else begin
            //Calculate current character cell's address in framebuffer
             char_col_idx = (i_pixel_col < H_ACTIVE_PIXELS) ? (i_pixel_col / CHAR_WIDTH_PIXELS) : 0;
             char_row_idx = (i_pixel_row < V_ACTIVE_PIXELS) ? (i_pixel_row / CHAR_HEIGHT_PIXELS) : 0;
             current_fb_read_addr_comb = (char_row_idx * SCREEN_CHAR_COLS) + char_col_idx;
             
            if (i_video_on && current_fb_read_addr_comb < FRAMEBUFFER_SIZE) begin
                char_ascii_code_r <= char_framebuffer[current_fb_read_addr_comb];
            end else begin
                char_ascii_code_r <= 8'h20; //Output spaces during blanking or if addr out of bounds
            end
        end
    end

    //Pipeline stage 2 (VGA Clock Domain): Calculate Font ROM address and read from Font ROM.
    reg [7:0] font_pixel_data_r; //Registered pixel data from font ROM
            reg [($clog2(CHAR_HEIGHT_PIXELS))-1:0] char_pixel_y_offset_comb; //Y offset within the 8x8 char (0-7)
            reg [FONT_ROM_ADDR_BITS-1:0] current_font_read_addr_comb;
    
    always @(posedge i_vga_clk) begin
        if (i_rst) begin
            font_pixel_data_r <= 8'h00;
        end else begin
             char_pixel_y_offset_comb = i_pixel_row % CHAR_HEIGHT_PIXELS;
             current_font_read_addr_comb = (char_ascii_code_r < FONT_NUM_CHARS) ?
                                            (char_ascii_code_r * FONT_BYTES_PER_CHAR) + char_pixel_y_offset_comb :
                                            (32 * FONT_BYTES_PER_CHAR) + char_pixel_y_offset_comb; //Default to space font

            if (i_video_on && current_font_read_addr_comb < FONT_ROM_SIZE_BYTES) begin
                font_pixel_data_r <= font_rom[current_font_read_addr_comb];
            end else begin
                font_pixel_data_r <= 8'h00; //Blank if address out of bounds
            end
        end
    end

    //Pipeline stage 3 (VGA Clock Domain): Determine if current pixel is foreground
           reg [($clog2(CHAR_WIDTH_PIXELS))-1:0] char_pixel_x_offset_comb; //X offset within the 8-pixel wide char (0-7)
    always @(posedge i_vga_clk) begin
        if (i_rst) begin
            outputPixel_is_foreground <= 1'b0;
        end else begin
            if (i_video_on) begin

                char_pixel_x_offset_comb = i_pixel_col % CHAR_WIDTH_PIXELS;
                outputPixel_is_foreground <= (font_pixel_data_r >> (CHAR_WIDTH_PIXELS - 1 - char_pixel_x_offset_comb)) & 1'b1;
            end else begin
                outputPixel_is_foreground <= 1'b0;
            end
        end
    end


    //Wishbone Slave Logic for Framebuffer Write (System Clock Domain)
    wire [FRAMEBUFFER_ADDR_BITS-1:0] effective_wb_fb_write_addr; //uses only the 6 bits from i_wb_fb_adr
    assign effective_wb_fb_write_addr = i_wb_fb_adr; //Only uses lower 6 bits.

    always @(posedge i_sys_clk or posedge i_rst) begin
        if (i_rst) begin
            o_wb_fb_ack <= 1'b0;
        end else begin
            if (o_wb_fb_ack) begin
                o_wb_fb_ack <= 1'b0;
            end
            if (i_wb_fb_cyc && i_wb_fb_stb && !o_wb_fb_ack) begin
                o_wb_fb_ack <= 1'b1;
                if (i_wb_fb_we) begin
                    if (effective_wb_fb_write_addr < FRAMEBUFFER_SIZE) begin //Check against full FB size
                        //For simplicity, assume CPU writes character to LSB of i_wb_fb_dat_w
                        if (i_wb_fb_sel[0]) begin
                            char_framebuffer[effective_wb_fb_write_addr] <= i_wb_fb_dat_w[7:0];
                        end
                        //Add other byte lanes if needed:
                        //if (i_wb_fb_sel[1] && (effective_wb_fb_write_addr + 1 < FRAMEBUFFER_SIZE))
                        //   char_framebuffer[effective_wb_fb_write_addr + 1] <= i_wb_fb_dat_w[15:8];
                    end
                end
            end
        end
    end

endmodule
