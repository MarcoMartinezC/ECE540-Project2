//creating the VGA module



module vgaModule
 (
    //Creating the inputs that will be needed for the VGA connection
  input wire VGA_CLK, //VGA clock - 31.5 MHz
  input  wire VGA_RST, //VGA reset if needed - can be deleted if not needed
  input wire VGA_VIDEO_ON,
  output reg [3:0] VGA_R_LED,  //Red LED
  output  reg [3:0] VGA_G_LED,
  output reg [3:0] VGA_B_LED,
  output wire VGA_VSYNC, //Vertical Sync
  output wire VGA_HSYNC, //Horizontal Sync
  
	//Adding the WB Interface connections
  input     wire        wb_clk_i,	// Clock
  input      wire       wb_rst_i,	// Reset
  input        wire     wb_cyc_i,	// cycle valid input
  input  wire [5:0]	wb_adr_i,	// address bus inputs
  input  wire [31:0]	wb_dat_i,	// input data bus
  input	 wire [3:0]     wb_sel_i,	// byte select inputs
  input  wire           wb_we_i,	// indicates write transfer
  input  wire           wb_stb_i,	// strobe input
  output wire [31:0]  wb_dat_o,	// output data bus
  output wire           wb_ack_o,	// normal termination
  output wire           wb_err_o);	// termination with error
  


    localparam RED_BG_COLOR   = {4'hF, 4'h0, 4'h0}; //R, G, B for Red Background
    localparam WHITE_FG_COLOR = {4'hF, 4'hF, 4'hF}; //R, G, B for White Foreground (text)
    localparam BLACK_BLANKING = {4'h0, 4'h0, 4'h0}; //R, G, B for Black (during blanking)


    // === VGA Timing ===
    wire [11:0] pixel_row, pixel_column;
    wire [31:0] pix_num;
    wire internal_video_on;
    wire internal_HSync, internal_VSync;
    
    assign VGA_HSYNC = internal_HSync;
    assign VGA_VSYNC = internal_VSync;
    assign VGA_VIDEO_ON = internal_video_on;

    dtg vga_timing (
        .clock(VGA_CLK),
        .rst(VGA_RST),
        .horiz_sync(internal_HSync),
        .vert_sync(internal_VSync),
        .video_on(internal_video_on),
        .pixel_row(pixel_row),
        .pixel_column(pixel_column),
        .pix_num());
        
        
        wire pixel_is_fg_from_char_buffer;
        
    character_buffer char_buf_inst (
        .i_vga_clk          (VGA_CLK),
        .i_sys_clk          (wb_clk_i),       
        .i_rst              (wb_rst_i),       
        .i_pixel_row        (pixel_row),
        .i_pixel_col        (pixel_column),
        .i_video_on         (internal_video_on),
        .i_wb_fb_adr        (wb_adr_i),   
        .i_wb_fb_dat_w      (wb_dat_i),
        .i_wb_fb_sel        (wb_sel_i),
        .i_wb_fb_we         (wb_we_i),
        .i_wb_fb_cyc        (wb_cyc_i),
        .i_wb_fb_stb        (wb_stb_i),
        .o_wb_fb_ack        (wb_ack_o),    
        .outputPixel_is_foreground      (pixel_is_fg_from_char_buffer)
    );
    
    assign wb_dat_o = 32'h0; 


    //Pixel generation logic: Combine background and foreground from character_buffer module
    always @(posedge VGA_CLK or posedge wb_rst_i) begin
        if (wb_rst_i) begin 
            VGA_R_LED   <= BLACK_BLANKING[11:8];
            VGA_G_LED <= BLACK_BLANKING[7:4];
            VGA_B_LED  <= BLACK_BLANKING[3:0];
        end else begin
            if (internal_video_on) begin
                if (pixel_is_fg_from_char_buffer) begin
                    //Foreground character pixel
                    VGA_R_LED   <= WHITE_FG_COLOR[11:8];
                    VGA_G_LED <= WHITE_FG_COLOR[7:4];
                    VGA_B_LED  <= WHITE_FG_COLOR[3:0];
                end else begin
                    //Background pixel
                    VGA_R_LED   <= RED_BG_COLOR[11:8];
                    VGA_G_LED <= RED_BG_COLOR[7:4];
                    VGA_B_LED  <= RED_BG_COLOR[3:0];
                end
            end else begin
                //Blanking interval
                VGA_R_LED   <= BLACK_BLANKING[11:8];
                VGA_G_LED <= BLACK_BLANKING[7:4];
                VGA_B_LED  <= BLACK_BLANKING[3:0];
            end
        end
    end


endmodule
