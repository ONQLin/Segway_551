module SegwayMath #(
	parameter MIN_DUTY = 13'h3C0,
	parameter LOW_TORQUE_BAND = 8'h3C,
	parameter GAIN_MULT = 6'h10,
	parameter PIPELINED = 1'b1
)
(
	input 					clk,
	input signed [11:0]		PID_cntrl,
	input[7:0] 		ss_tmr,
	input[11:0] 	steer_pot,
	input 			en_steer,
	input			pwr_up,
	output signed [11:0]	lft_spd,
	output signed [11:0]	rght_spd,
	output			too_fast
);

wire[19:0]	PID_ss_i;
logic signed[12:0]	PID_ss;
wire[11:0]	steer_pot_i;
wire signed[11:0] steer_pot_res1, steer_pot_res2;

wire signed [12:0] lft_torque, rght_torque;
wire signed [12:0] lft_torque_comp, lft_torque_gain;
wire[12:0]		   lft_torque_abs;
wire signed [12:0] lft_shaped_i, lft_shaped;

wire signed [12:0] rght_torque_comp, rght_torque_gain;
wire[12:0]		   rght_torque_abs;
wire signed [12:0] rght_shaped_i, rght_shaped;

assign PID_ss_i = (PID_cntrl * $signed({1'b0, ss_tmr})); 

//-------------------give ramp up steer to get torque------------------------------
assign steer_pot_i = (steer_pot < 'h200) ? 'h200 :
					 (steer_pot > 'hE00) ? 'hE00 : steer_pot; //clip
generate
	if(PIPELINED) begin
		always@(posedge clk) begin
			PID_ss <= {PID_ss_i[19] ,PID_ss_i[19:8]};	// >>>8 + ext, get final PID_ss
		end
	end else begin
		assign PID_ss = {PID_ss_i[19] ,PID_ss_i[19:8]};	// >>>8 + ext, get final PID_ss
	end
endgenerate

assign steer_pot_res1 = ($signed(steer_pot_i - 12'h7ff)) >>> 4;
assign steer_pot_res2 = $signed(steer_pot_res1 * 3);		//get final steer pot

assign lft_torque = (en_steer) ? $signed(PID_ss + steer_pot_res2) : PID_ss;
assign rght_torque = (en_steer) ? $signed(PID_ss - steer_pot_res2) : PID_ss; // get final torque
//-------------------SHAPE TORQUE-----------------------------------
assign lft_torque_comp = (lft_torque[12]) ? (lft_torque - MIN_DUTY) : (lft_torque + MIN_DUTY);	//normal zone
assign lft_torque_gain = lft_torque * $signed(GAIN_MULT);									//dead zone compensation
assign lft_torque_abs = (lft_torque[12]) ? (~lft_torque + 1'b1) : lft_torque;				//get abs to compare
assign lft_shaped_i = (lft_torque_abs > LOW_TORQUE_BAND) ? lft_torque_comp : lft_torque_gain;	//get torque after shaped
assign lft_shaped = (pwr_up) ? lft_shaped_i : 13'h0;										//get final torque
// rght torque processing is similar to lft_shape
assign rght_torque_comp = (rght_torque[12]) ? (rght_torque - MIN_DUTY) : (rght_torque + MIN_DUTY);	//normal zone
assign rght_torque_gain = rght_torque * $signed(GAIN_MULT);									//dead zone compensation
assign rght_torque_abs = (rght_torque[12]) ? (~rght_torque + 1'b1) : rght_torque;				//get abs to compare
assign rght_shaped_i = (rght_torque_abs > LOW_TORQUE_BAND) ? rght_torque_comp : rght_torque_gain;	//get torque after shaped
assign rght_shaped = (pwr_up) ? rght_shaped_i : 13'h0;										//get final torque

logic signed [11:0] lft_shaped_sat, rght_shaped_sat;
//-------------------check and get final speed-------------------------------
generate
	if(PIPELINED) begin
		always@(posedge clk) begin
			lft_shaped_sat <= (~lft_shaped[12]) ? ((|lft_shaped[12:11]) ? 12'h7FF : {{1'b0}, lft_shaped[10:0]}) :
												((&lft_shaped[12:11]) ? {{1'b1}, lft_shaped[10:0]} : 12'h800);
			rght_shaped_sat <= (~rght_shaped[12]) ? ((|rght_shaped[12:11]) ? 12'h7FF : {{1'b0}, rght_shaped[10:0]}) :
												((&rght_shaped[12:11]) ? {{1'b1}, rght_shaped[10:0]} : 12'h800);	//signed sat
		end
	end else begin
		assign lft_shaped_sat = (~lft_shaped[12]) ? ((|lft_shaped[12:11]) ? 12'h7FF : {{1'b0}, lft_shaped[10:0]}) :
													((&lft_shaped[12:11]) ? {{1'b1}, lft_shaped[10:0]} : 12'h800);
		assign rght_shaped_sat = (~rght_shaped[12]) ? ((|rght_shaped[12:11]) ? 12'h7FF : {{1'b0}, rght_shaped[10:0]}) :
													((&rght_shaped[12:11]) ? {{1'b1}, rght_shaped[10:0]} : 12'h800);	//signed sat
	end
endgenerate											
assign lft_spd = lft_shaped_sat;
assign rght_spd = rght_shaped_sat;

assign too_fast = (lft_shaped_sat > $signed(12'd1792))||(rght_shaped_sat > $signed(12'd1792));											

endmodule