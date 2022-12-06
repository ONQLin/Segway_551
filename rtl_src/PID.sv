module PID #(
	parameter P_COEFF = 5'h0C,
	parameter fast_sim = 0,
	parameter TMR_INC = (fast_sim) ? 256 : 1,
	parameter PIPELINED = 1
)
(
	input signed  [15:0]	ptch,			//for pterm and iterm
	input signed  [15:0] 	ptch_rt,		//for dterm
	//input signed  [17:0]	integrator,
	input					clk,
	input					rst_n,
	input					vld,			// indicate when a new inertial sensor reading is valid	
	input					pwr_up,			// Used to keep ss_tmr at zero until then
	input					rider_off,		// Asserted when no rider detected. Zeros out integrator.
	
	output signed [11:0]	PID_cntrl,
	output[7:0]			ss_tmr
);
	wire signed [9:0]	ptch_err_sat;
	wire signed [15:0]	P_term, I_term, D_term;
	logic signed [16:0]	PID_cntrl_i;
	wire signed [17:0]  ptch_err_sat_ext;
	wire				ov;
	reg signed[17:0] 	integrator;
	wire signed[17:0]   I_sum;
	reg[26:0]			ss_cnt;			//cnt for ss_tmr
	
	//saturate the incoming signed 16-bit ptch to a signed 10-bit ptch_err_sat term
	assign ptch_err_sat = (~ptch[15]) ? ((|ptch[14:9]) ? 10'h1FF : {1'b0, ptch[8:0]}) :
						((&ptch[14:9]) ? {1'b1, ptch[8:0]} : 10'h200);		

	assign ptch_err_sat_ext = {{8{ptch_err_sat[9]}}, ptch_err_sat};

	assign I_sum = integrator + ptch_err_sat_ext;

	assign ov = (integrator[17] == ptch_err_sat_ext[17]) ? ((I_sum[17] != integrator[17]) ? 1 : 0) : 0;
	
	always_ff@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			integrator <= 18'd0;
		end else if(rider_off) begin
			integrator <= 18'd0;
		end else if(vld)begin
			integrator <= (~ov)? I_sum : integrator;
		end
	end
	
	// count for ss tmr ramping
	always_ff@(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			ss_cnt <= 27'd0;
		end else if(~pwr_up) begin
			ss_cnt <= 27'd0;
		end else begin
			ss_cnt <= (~(&ss_cnt[26:8])) ? ss_cnt + TMR_INC : ss_cnt;
		end
	end
	
	assign ss_tmr = ss_cnt[26:19];	//assign the output ss tmr
	
						
	// simply multiply the coeff
	assign P_term = $signed(ptch_err_sat) * $signed(P_COEFF);
	
	// /64 and keep as 15bits then sign extension
	generate
		if(fast_sim) begin 		// sat in fast_sim
			assign I_term = (~integrator[17]) ? ((|integrator[16:15]) ? 16'h7fff : {1'b0,integrator[15:1]})  // +
												: ((&integrator[16:15]) ? {1'b1,integrator[15:1]} : 16'h8000); // -
		end else begin
			assign I_term = {{4{integrator[17]}}, integrator[17:6]};
		end
	endgenerate
	
	
	// /64 ~ and sign extension
	assign D_term = ~{{6{ptch_rt[15]}}, ptch_rt[15:6]};
	
	// add together
	generate
		if(PIPELINED) begin
			always_ff@(posedge clk) begin
				PID_cntrl_i <= P_term + I_term + D_term;
			end
		end else begin
			assign PID_cntrl_i = P_term + I_term + D_term;
		end
	endgenerate
	
	
	// 12bits sat
	assign PID_cntrl = (~PID_cntrl_i[16]) ? ((|PID_cntrl_i[15:11]) ? 12'h7FF : {1'b0, PID_cntrl_i[10:0]}) :
						((&PID_cntrl_i[15:11]) ? {1'b1, PID_cntrl_i[10:0]} : 12'h800);


endmodule : PID