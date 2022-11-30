module PB_release (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input PB,
	output released
);
	reg inc_d1, inc_d2, inc_d3;		//3 flops for synchronize
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			inc_d1 <= 1'b1;
			inc_d2 <= 1'b1;
			inc_d3 <= 1'b1;
		end else begin
			inc_d1 <= PB;
			inc_d2 <= inc_d1;
			inc_d3 <= inc_d2;
		end
	end

	assign released = inc_d2 & (~inc_d3);		//sample the posedge

endmodule : PB_release