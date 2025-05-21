//vga_controller.v
//VGA Controller for 640x480 resolution, testing for hardware implementation. outputs red background as default
//Had to use GeminiAI to make file Verilog 2001 compliant

module vga_controller (
    //System Clock and Reset
    input wire i_clk,
    input wire i_rst,
    input wire [5:0] i_wb_adr,
    input wire [31:0] i_wb_dat_w,
    input wire [3:0] i_wb_sel,
    input wire i_wb_we,
    input wire i_wb_cyc,
    input wire i_wb_stb,
    output wire [31:0] o_wb_dat_r,
    output wire o_wb_ack,
    input wire i_vga_clk,     //31.5MHz for 640x480 resolution

    //VGA Output Signals - three 4-bit outputs for RGB
    output wire o_vga_h_sync, 
    output wire o_vga_v_sync, 
    output wire o_vga_vid_en,
    output reg [3:0]  o_vga_red,
    output reg [3:0]  o_vga_green,
    output reg [3:0]  o_vga_blue
);

    //Internal signals for dtg module
    wire [11:0] pixel_row_w;
    wire [11:0] pixel_column_w;
    wire        video_on_w;
    wire        h_sync_w;
    wire        v_sync_w;

    dtg dtg_inst (
        .clock        (i_vga_clk),    
        .rst          (i_rst), 
        .horiz_sync   (h_sync_w),
        .vert_sync    (v_sync_w),
        .video_on     (video_on_w),
        .pixel_row    (pixel_row_w),
        .pixel_column (pixel_column_w),
        .pix_num      () 
    );

    //Assign VGA sync and video enable signals
    assign o_vga_h_sync = h_sync_w;
    assign o_vga_v_sync = v_sync_w;
    assign o_vga_vid_en = video_on_w;

    //Pixel generation logic
    //testing red output for bitfile write
    //R = 4'hF (max), G = 4'h0, B = 4'h0
    always @(posedge i_vga_clk or posedge i_rst) begin
        if (i_rst) begin
            o_vga_red   <= 4'h0;
            o_vga_green <= 4'h0;
            o_vga_blue  <= 4'h0;
        end else begin
            if (video_on_w) begin
                o_vga_red   <= 4'hF; //Full Red
                o_vga_green <= 4'h0;
                o_vga_blue  <= 4'h0;
            end else begin
                o_vga_red   <= 4'h0;
                o_vga_green <= 4'h0;
                o_vga_blue  <= 4'h0;
            end
        end
    end

    //wishbone interconnect minimal implementation
    //For now, it only acknowledges valid cycles; no actual registers are read or written via the wb_intercon

    reg wb_ack_r;

    assign o_wb_dat_r = 32'h0; //No readable registers yet
    assign o_wb_ack = wb_ack_r;

    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            wb_ack_r <= 1'b0;
        end else begin
            if (wb_ack_r) begin //De-assert ack after one cycle
                wb_ack_r <= 1'b0;
            end
            //Check for !wb_ack_r to prevent re-acknowledging before master sees it
            if (i_wb_cyc && i_wb_stb && !wb_ack_r) begin
                //Acknowledge the Wishbone cycle
                //register read/write module needs to be implemented for ASCI characters, just trying to get video output at this point
                wb_ack_r <= 1'b1;
            end
        end
    end

endmodule
