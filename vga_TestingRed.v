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





    //Internal signals for dtg module
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

    //Pixel generation logic


    //testing red output for bitfile write


    //R = 4'hF (max), G = 4'h0, B = 4'h0


    always @(posedge VGA_CLK or posedge wb_rst_i) begin
        if (wb_rst_i) begin
           VGA_R_LED   <= 4'h0;
           VGA_G_LED <= 4'h0;
           VGA_B_LED  <= 4'h0;

        end else begin
            if (internal_video_on) begin
                VGA_R_LED   <= 4'hF; //Full Red
                VGA_G_LED <= 4'h0;
                VGA_B_LED  <= 4'h0;

            end else begin
                VGA_R_LED   <= 4'h0;
                VGA_G_LED <= 4'h0;
                VGA_B_LED  <= 4'h0;
            end
        end
    end

    //wishbone interconnect minimal implementatio
    //For now, it only acknowledges valid cycles; no actual registers are read or written via the wb_intercon

    reg wb_ack_r;
    assign wb_dat_o = 32'h0; //No readable registers yet
    assign wb_ack_o = wb_dat_o;

    always @(posedge wb_clk_i or posedge wb_rst_i) begin


        if (wb_rst_i) begin
            wb_ack_r <= 1'b0;
            
        end else begin
            if (wb_ack_r) begin //De-assert ack after one cycle
                wb_ack_r <= 1'b0;
            end
            //Check for !wb_ack_r to prevent re-acknowledging before master sees it

            if (wb_cyc_i && wb_stb_i && !wb_ack_r) begin
                //Acknowledge the Wishbone cycle
                //register read/write module needs to be implemented for ASCI characters, just trying to get video output at this point
                wb_ack_r <= 1'b1;
            end
        end
    end

endmodule
