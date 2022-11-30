module steer_en_tb ();

reg clk, rst_n;
reg signed[11:0] lft_ld, rght_ld;
wire en_steer, rider_off;

steer_en DUT(
	.clk      (clk),
	.rst_n    (rst_n),
	.lft_ld   (lft_ld),
	.rght_ld  (rght_ld),
	.en_steer (en_steer),
	.rider_off(rider_off)
);

initial begin
	clk = 0;
	rst_n = 0;
	lft_ld = 0;
	rght_ld = 0;
	@(negedge clk);
	rst_n = 1;

	/////////////////////////////////////////////////////////////
	// First check no outputs occur when both differences are //
	// less than, but sum_gt_min has not yet occurred.       //
	//////////////////////////////////////////////////////////
	repeat (2) begin
	  if (en_steer) begin
	    $display("ERROR: no en_steer should not be asserted yet\n");
		$stop();
	  end	  
	  @(negedge clk);
	  if (!rider_off) begin
	    $display("ERROR: rider_off should be asserted\n");
		$stop();
	  end
	end

	/////////////////////////////////////////////////////////////
	// Just test different lft and rght ld to examine the ctrl //
	// I think the SM has been verified.	   				//
	//////////////////////////////////////////////////////////
	repeat(3) @(posedge clk);
	lft_ld = -1000;
	rght_ld = 200;
	repeat(3) @(posedge clk);
	$display("------------- new round 1-------%d-%d-----",lft_ld, rght_ld);
	$display("diff_gt_1_4 = %b", DUT.diff_gt_1_4);
	$display("diff_gt_15_16 = %b", DUT.diff_gt_15_16);
	$display("sum_lt_min = %b", DUT.sum_lt_min);
	$display("sum_gt_min = %b", DUT.sum_gt_min);
	lft_ld = -300;
	rght_ld = -600;
	repeat(3) @(posedge clk);
	$display("------------- new round 2-------%d-%d-----",lft_ld, rght_ld);
	$display("diff_gt_1_4 = %b", DUT.diff_gt_1_4);
	$display("diff_gt_15_16 = %b", DUT.diff_gt_15_16);
	$display("sum_lt_min = %b", DUT.sum_lt_min);
	$display("sum_gt_min = %b", DUT.sum_gt_min);
	lft_ld = 1000;
	rght_ld = -200;
	repeat(3) @(posedge clk);
	$display("------------- new round 3-------%d-%d-----",lft_ld, rght_ld);
	$display("diff_gt_1_4 = %b", DUT.diff_gt_1_4);
	$display("diff_gt_15_16 = %b", DUT.diff_gt_15_16);
	$display("sum_lt_min = %b", DUT.sum_lt_min);
	$display("sum_gt_min = %b", DUT.sum_gt_min);
	lft_ld = 1111;
	rght_ld = -550;
	repeat(3) @(posedge clk);
	$display("------------- new round 4-------%d-%d-----",lft_ld, rght_ld);
	$display("diff_gt_1_4 = %b", DUT.diff_gt_1_4);
	$display("diff_gt_15_16 = %b", DUT.diff_gt_15_16);
	$display("sum_lt_min = %b", DUT.sum_lt_min);
	$display("sum_gt_min = %b", DUT.sum_gt_min);
	lft_ld = 1000;
	rght_ld = 800;
	repeat(3) @(posedge clk);
	$display("------------- new round 5-------%d-%d-----",lft_ld, rght_ld);
	$display("diff_gt_1_4 = %b", DUT.diff_gt_1_4);
	$display("diff_gt_15_16 = %b", DUT.diff_gt_15_16);
	$display("sum_lt_min = %b", DUT.sum_lt_min);
	$display("sum_gt_min = %b", DUT.sum_gt_min);
	wait(DUT.SM0.state == 2);
	#100;
	$stop;
end

always begin
	#10 clk = ~clk;
end


endmodule : steer_en_tb