module vgaModule
 (
    //Creating the inputs that will be needed for the VGA connection
  input wire VGA_CLK, //VGA clock
  input  wire VGA_RST, //VGA reset if needed - can be deleted if not needed
  output wire [3:0] VGA_R_LED,  //Red LED
  output  wire [3:0] VGA_G_LED,
  output wire [3:0] VGA_B_LED,
  output wire VGA_VSYNC, //Vertical Sync
  output wire VGA_HSYNC, //Horizontal Sync
  
	//Adding the WB Interface connections
  input     wire        wb_clk_i,	// Clock
  input      wire       wb_rst_i,	// Reset
  input        wire     wb_cyc_i,	// cycle valid input
  input  wire [31:0]	wb_adr_i,	// address bus inputs
  input  wire [31:0]	wb_dat_i,	// input data bus
  input	 wire [3:0]     wb_sel_i,	// byte select inputs
  input  wire           wb_we_i,	// indicates write transfer
  input  wire           wb_stb_i,	// strobe input
  output wire [31:0]  wb_dat_o,	// output data bus
  output wire           wb_ack_o,	// normal termination
  output wire           wb_err_o);	// termination with error
  

    // === VGA Timing ===
    wire [11:0] pixel_row, pixel_column;
    wire [31:0] pix_num;
    wire video_on;

    dtg vga_timing (
        .clock(VGA_CLK),
        .rst(VGA_RST),
        .horiz_sync(VGA_HSYNC),
        .vert_sync(VGA_VSYNC),
        .video_on(video_on),
        .pixel_row(pixel_row),
        .pixel_column(pixel_column),
        .pix_num(pix_num));

    // === Simple Wishbone Registers ===
    reg [3:0] reg_r = 4'hF;
    reg [3:0] reg_g = 4'h0;
    reg [3:0] reg_b = 4'h0;
    reg       ack = 0;

    assign wb_ack_o = ack;
    assign wb_err_o = 0;
    assign wb_dat_o = {24'd0, reg_r, reg_g, reg_b};  // Packed RGB readback

    always @(posedge wb_clk_i) begin
        if (wb_rst_i) begin
            ack   <= 0;
            reg_r <= 4'hF;
            reg_g <= 4'h0;
            reg_b <= 4'h0;
        end else begin
            ack <= 0;
            if (wb_stb_i && wb_cyc_i && !ack) begin
                ack <= 1;
                if (wb_we_i) begin
                    if (wb_sel_i[0]) reg_b <= wb_dat_i[3:0];
                    if (wb_sel_i[1]) reg_g <= wb_dat_i[11:8];
                    if (wb_sel_i[2]) reg_r <= wb_dat_i[19:16];
                end
            end
        end
    end

    // === Color output ===
    assign VGA_R_LED = video_on ? reg_r : 4'h0;
    assign VGA_G_LED = video_on ? reg_g : 4'h0;
    assign VGA_B_LED = video_on ? reg_b : 4'h0;


endmodule 
