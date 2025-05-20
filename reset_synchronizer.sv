// reset_synchronizer.v
// Description: Synchronizes an asynchronous reset to a specific clock domain.
//              Outputs a synchronous active-high reset.

module reset_synchronizer (
    input clk_i,          // Target clock domain
    input async_reset_n_i, // Asynchronous reset input, active-low
    output logic sync_reset_o // Synchronous reset output, active-high
);

    logic r1_reg, r2_reg;

    always_ff @(posedge clk_i or negedge async_reset_n_i) begin
        if (!async_reset_n_i) begin
            r1_reg <= 1'b1;
            r2_reg <= 1'b1;
        end else begin
            r1_reg <= 1'b0; // De-assert reset
            r2_reg <= r1_reg;
        end
    end

    assign sync_reset_o = r2_reg;

endmodule
