module rst_synch (
	input clk,    // Clock
	input RST_n,  // Asynchronous reset active low
	output reg rst_n  // output global sychronized rst_n
);

	reg rst_n_d; 	//set a synch for meta problem
	always_ff @(negedge clk or negedge RST_n) begin
		if(~RST_n) begin
			rst_n_d <= 1'b0;
			rst_n <= 1'b0;
		end else begin
			rst_n_d <= 1'b1;
			rst_n <= rst_n_d;
		end
	end

endmodule : rst_synch