module PWM11(
	input 		clk,			//50m clk
	input 		rst_n,			//async reset
	input[10:0] duty,			//duty cycle input. Result from balance controller telling how fast to run each motor. 
	output reg	PWM_sig,		//PWM sig out. Output to the H-bridge chip controlling the DC motor.
	output		PWM_synch,		//Used to synch duty changes with PWM cycle
	output		OVR_I_blank_n	//Ignore over current detect early in PWM cycle
);

reg[10:0] cnt;

// counter for PWM
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		cnt <= 0;
	end else begin
		cnt <= cnt + 1;
	end
end

// Generate PWM out according to cnt vs duty
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		PWM_sig <= 0;
	end else if(cnt == 0) begin
		PWM_sig <= 1;
	end else if(cnt >=duty) begin
		PWM_sig <= 0;
	end
end

assign PWM_synch = &cnt;	//PWM finish when counter is full
assign OVR_I_blank_n = (cnt>255) ? 1 : 0;	//overlook detect at beginning

endmodule : PWM11