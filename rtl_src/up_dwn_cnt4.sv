module up_dwn_cnt4 (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input en,	  // en from PB release
	input dwn,	  // flop when cnt full
	output reg[3:0] cnt
);

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			cnt <= 0;
		end else if(en) begin 	//inc_button ---> change cnt +1/-1
			cnt <= (~dwn) ? cnt + 1 : cnt - 1;	//inc or dec by dwn
		end
	end

endmodule : up_dwn_cnt4