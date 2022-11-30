module steer_en #(
	parameter fast_sim = 1'b1,
	parameter MIN_RIDER_WT = 12'h200,
	parameter WT_HYSTERESIS = 8'h40,
	parameter CNT_LEN = (fast_sim) ? 14 : 25
)
(
	input clk,    // Clock 50M
	input rst_n,  // Asynchronous reset active low
	input[11:0] lft_ld,
	input[11:0] rght_ld,

	output en_steer,
	output rider_off
);
	//value to SM
	wire clr_tmr;
	wire tmr_full;
	wire sum_lt_min, sum_gt_min, diff_gt_15_16, diff_gt_1_4;
	//internal value
	wire[12:0] lr_sum;
	wire signed[11:0] lr_diff;
	wire[11:0] lr_abs;
	wire[12:0] lr_sum_1_4;
	wire[12:0] lr_sum_15_16;  
	// timer size for fast_sim
	reg[CNT_LEN:0] cnt1_4;

	// the 1.34s timer
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			cnt1_4 <= 0;
		end else if(clr_tmr) begin
			cnt1_4 <= 0;
		end else begin
			cnt1_4 <= cnt1_4 + 1;
		end
	end

	assign tmr_full = &cnt1_4;

	assign lr_sum = lft_ld + rght_ld;
	assign lr_diff = lft_ld - rght_ld;
	assign lr_abs = (lr_diff[11]) ? ~lr_diff: lr_diff[10:0];
	assign lr_sum_1_4 = {{2{lr_sum[12]}},lr_sum[12:2]};	//1/4 == >>2
	assign lr_sum_15_16 = lr_sum - {{4{lr_sum[12]}},lr_sum[12:4]}; // 15/16 = 1-1/16

	// fed to SM
	assign diff_gt_1_4 = (lr_abs > lr_sum_1_4) ? 1 : 0;  //when sum < 0 ....
	assign diff_gt_15_16 = (lr_abs > lr_sum_15_16) ? 1 : 0;
	assign sum_lt_min = (lr_sum < MIN_RIDER_WT - WT_HYSTERESIS) ? 1 : 0;
	assign sum_gt_min = (lr_sum > MIN_RIDER_WT + WT_HYSTERESIS) ? 1 : 0;

	steer_en_SM SM0(
		.clk          	(clk),
		.rst_n		  	(rst_n),
		.tmr_full	  	(tmr_full),
		.sum_gt_min	  	(sum_gt_min),
		.sum_lt_min	  	(sum_lt_min),
		.diff_gt_1_4  	(diff_gt_1_4),
		.diff_gt_15_16	(diff_gt_15_16),
		.clr_tmr      	(clr_tmr),
		.en_steer     	(en_steer),
		.rider_off    	(rider_off)
	);


endmodule : steer_en