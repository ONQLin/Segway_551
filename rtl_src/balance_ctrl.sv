module balance_ctrl #(
		parameter fast_sim = 1
	)
	(
	input 			clk,    	// 50m Clock
	input 			rst_n,  	// Asynchronous reset active low
	input 			vld, 		// High whenever new inertial sensor reading (ptch) is read
	input[15:0] 	ptch,   	// Pitch of Segway from inertial_intf
	input[15:0] 	ptch_rt,	// pitch rate (degrees/sec). Used for D_term of PID
	input			rider_off,  // Asserted when no rider detected. Zeros out integrator
	input[11:0]		steer_pot,  // From A2D_intf (converted from steering potentiometer)
	input			en_steer,   // enables steering control
	input			pwr_up,

	output[11:0] 	lft_spd,    // 12-bit signed speed of left motor
	output[11:0] 	rght_spd,   // 12-bit signed speed of rght motor
	output			too_fast    // Rider approaching point of minimal control margin
);

	wire[11:0] PID_cntrl;
	wire[7:0] ss_tmr;


	PID #(.fast_sim(fast_sim))PID_inst
		(.clk(clk),.rst_n(rst_n),.vld(vld),.ptch(ptch),.ptch_rt(ptch_rt),
		 .pwr_up(pwr_up),.rider_off(rider_off),.PID_cntrl(PID_cntrl),
		 .ss_tmr(ss_tmr));

	SegwayMath seg_inst(
		.PID_cntrl	(PID_cntrl),
		.ss_tmr		(ss_tmr),
		.steer_pot	(steer_pot),
		.en_steer	(en_steer),
		.pwr_up		(pwr_up),
		.lft_spd	(lft_spd),
		.rght_spd	(rght_spd),
		.too_fast	(too_fast)
	);
endmodule : balance_ctrl