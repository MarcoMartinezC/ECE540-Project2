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

    //Colors (4-bit per channel)
    localparam RED_BG_COLOR   = {4'hF, 4'h0, 4'h0}; //R, G, B for Red Background
    localparam WHITE_FG_COLOR = {4'hF, 4'hF, 4'hF}; //R, G, B for White Foreground (text)
    localparam BLACK_BLANKING = {4'h0, 4'h0, 4'h0}; //R, G, B for Black (during blanking)

    //Internal signals for dtg
    wire [11:0] pixel_row_w;
    wire [11:0] pixel_column_w;
    wire        video_on_w;
    wire        h_sync_w;
    wire        v_sync_w;

    //Signal from character_buffer
    wire pixel_is_fg_from_char_buffer;

    //Instantiate Display Timing Generator (dtg)
    dtg dtg_inst (
        .clock        (i_vga_clk),
        .rst          (i_rst), //Assuming dtg reset is synchronous to i_vga_clk if i_rst is
        .horiz_sync   (h_sync_w),
        .vert_sync    (v_sync_w),
        .video_on     (video_on_w),
        .pixel_row    (pixel_row_w),
        .pixel_column (pixel_column_w),
        .pix_num      () 
    );

    assign o_vga_h_sync = h_sync_w;
    assign o_vga_v_sync = v_sync_w;
    assign o_vga_vid_en = video_on_w;

    //character_buffer instantiation for ASCII characters
    character_buffer char_buf_inst (
        .i_vga_clk          (i_vga_clk),
        .i_sys_clk          (i_clk),       
        .i_rst              (i_rst),       
        .i_pixel_row        (pixel_row_w),
        .i_pixel_col        (pixel_column_w),
        .i_video_on         (video_on_w),
        .i_wb_fb_adr        (i_wb_adr),   
        .i_wb_fb_dat_w      (i_wb_dat_w),
        .i_wb_fb_sel        (i_wb_sel),
        .i_wb_fb_we         (i_wb_we),
        .i_wb_fb_cyc        (i_wb_cyc),
        .i_wb_fb_stb        (i_wb_stb),
        .o_wb_fb_ack        (o_wb_ack),    
        .o_pixel_is_fg      (pixel_is_fg_from_char_buffer)
    );
    
    assign o_wb_dat_r = 32'h0; 


    //Pixel generation logic: Combine background and foreground from character_buffer module
    always @(posedge i_vga_clk or posedge i_rst) begin
        if (i_rst) begin 
            o_vga_red   <= BLACK_BLANKING[11:8];
            o_vga_green <= BLACK_BLANKING[7:4];
            o_vga_blue  <= BLACK_BLANKING[3:0];
        end else begin
            if (video_on_w) begin
                if (pixel_is_fg_from_char_buffer) begin
                    //Foreground character pixel
                    o_vga_red   <= WHITE_FG_COLOR[11:8];
                    o_vga_green <= WHITE_FG_COLOR[7:4];
                    o_vga_blue  <= WHITE_FG_COLOR[3:0];
                end else begin
                    //Background pixel
                    o_vga_red   <= RED_BG_COLOR[11:8];
                    o_vga_green <= RED_BG_COLOR[7:4];
                    o_vga_blue  <= RED_BG_COLOR[3:0];
                end
            end else begin
                //Blanking interval
                o_vga_red   <= BLACK_BLANKING[11:8];
                o_vga_green <= BLACK_BLANKING[7:4];
                o_vga_blue  <= BLACK_BLANKING[3:0];
            end
        end
    end


endmodule
