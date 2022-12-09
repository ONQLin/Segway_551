module inertial_integrator #(				//team name: dd go out;		team member: Alvin, Jiahao, Sissi, Yeon Jae
	parameter PTCH_RT_OFFSET = 16'h0050,
	parameter AZ_OFFSET = 16'h00A0
)(
	input 				clk,    	// Clock
	input 				rst_n,  	// Asynchronous reset active low
	input				vld, 		// High for a single clock cycle when new inertial readings are valid
	input signed[15:0] 	ptch_rt,	// 16-bit signed raw pitch rate from inertial sensor
	input signed[15:0] 	AZ, 		// Will be used for sensor fusion (acceleration in Z direction)
	output signed[15:0] ptch 		// Fully compensated and “fused” 16-bit signed pitch.
);

reg signed[26:0]	ptch_int;

wire signed[15:0] ptch_rt_comp;
wire signed[15:0] AZ_comp;
wire signed[15:0] ptch_acc;
wire signed[24:0] ptch_acc_product;
//wire signed[26:0] fusion_ptch_offset;

assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;		//ptch from gyro
assign AZ_comp = AZ - AZ_OFFSET;					// acc Z to cal ptch

assign ptch_acc_product = AZ_comp * $signed(327);
assign ptch_acc = {{4{ptch_acc_product[24]}},ptch_acc_product[24:13]};		// tan^-1 ~ Az --> ptch from az
//assign fusion_ptch_offset = (ptch_acc>ptch) ? 27'd1024 : -27'd1024; 		// hysteresis given by AZ to compensate the drift

always_ff @(posedge clk or negedge rst_n) begin
 	if(~rst_n) begin
 		ptch_int <= 27'h0000000;
 	end else if(vld) begin 													// accumulate the ptch int
 		ptch_int <= (ptch_acc>ptch) ? (ptch_int - {{11{ptch_rt_comp[15]}},ptch_rt_comp} + 1024):
							(ptch_int - {{11{ptch_rt_comp[15]}},ptch_rt_comp} - 1024);
 	end
end 

assign ptch = ptch_int[26:11];

endmodule : inertial_integrator