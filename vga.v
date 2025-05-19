module vgaModule
 (
    //Creating the inputs that will be needed for the VGA connection
  input wire VGA_CLK, //VGA clock
  input wire VGA_RST, //VGA reset if needed - can be deleted if not needed
  output wire [3:0] VGA_R_LED,  //Red LED
  output wire [3:0] VGA_G_LED,
  output wire [3:0] VGA_B_LED,
  output wire VGA_VSYNC, //Vertical Sync
  output wire VGA_HSYNC, //Horizontal Sync
  
	//Adding the WB Interface connections
  input  wire        wb_clk_i,	// Clock
  input  wire       wb_rst_i,	// Reset
  input  wire     wb_cyc_i,	// cycle valid input
  input  wire [31:0]	wb_adr_i,	// address bus inputs
  input  wire [31:0]	wb_dat_i,	// input data bus
  input	 wire [3:0]     wb_sel_i,	// byte select inputs
  input  wire           wb_we_i,	// indicates write transfer
  input  wire           wb_stb_i,	// strobe input
  output wire [31:0]  wb_dat_o,	// output data bus
  output wire           wb_ack_o,	// normal termination
  output wire           wb_err_o);// termination w/ error	
  
endmodule 
