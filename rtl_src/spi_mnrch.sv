module spi_mnrch (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	
	input wrt, 	  // A high for 1 clock period would initiate a SPI transaction

	input[15:0] wt_data,

	input MISO,
	output MOSI,
	output SCLK,
	output reg SS_n,

	output reg done,
	output[15:0] rd_data

);

reg		 	sclk_en;
reg[3:0] 	bit_cnt; 	// count the sclk number
reg[3:0] 	div_cnt;   // div cnt for sclk generate
reg[15:0] 	shift_reg; // shift reg for miso and mosi
reg 		miso_smpl; 
reg         set_done, init; //-->done div_cnt and SS_n are synchronized

wire shift = (div_cnt == 4'b1111);   //sclk negedge
wire smpl = (div_cnt == 4'b0111);    //sclk posedge

typedef enum reg[1:0] {IDLE, FRONT, TRANSMIT, BACK} state_t; 

state_t cstate, next_state;

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		SS_n <= 0;
	end else begin
		SS_n <= sclk_en;
	end
end

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		done <= 0;
	end else if(set_done) begin // last bit shifted, let done high
		done <= 1;
	end else if(wrt) begin // when new transition comes, reset done
		done <= 0;
	end
end

// sclk gen
assign SCLK = div_cnt[3];
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		div_cnt <= 4'b1011; 	// load for a pad at beginning
	end else if(~sclk_en) begin 
		div_cnt <= div_cnt + 1;
	end else begin
		div_cnt <= 4'b1011;
	end
end	

// bit cnt 1-16 use sclk in ff, save power
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		bit_cnt <= 0;
	end else if(init) begin
		bit_cnt <= 0;
	end else if(shift) begin
		bit_cnt <= bit_cnt + 1;
	end 
end

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		cstate <= IDLE;
	end else begin
		cstate <= next_state;
	end
end

// sample the miso in sclk ff, save power
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		miso_smpl <= 0;
	end else if (smpl) begin
		miso_smpl <= MISO;
	end
end

always_comb begin
	next_state = cstate;
	sclk_en = 0;
	set_done = 0;
	init = 0;
	case (cstate)
		IDLE: begin
			sclk_en = 1;
			if(wrt) begin 	//when get wrt, we start sending SCLK, first stage is a front porch
				next_state = FRONT;
				sclk_en = 0;
			end
		end

		FRONT: begin
			if(smpl) begin // at the first negedge of SCLK, we dont want shift but a load, detect the first posedge and init the counter
				next_state = TRANSMIT;
				init = 1;
			end
		end

		TRANSMIT: begin
			if(&bit_cnt) begin
				next_state = BACK;
			end
		end

		BACK: begin
			if(shift) begin
				sclk_en = 1;
				next_state = IDLE;
				set_done = 1;
			end
		end
	
		default : begin
			sclk_en = 1;
			next_state = IDLE;
		end /* default */
	endcase
end

// wating for the negedge of sclk, front case need load wtdata
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		shift_reg <= 0;
	end else if(shift) begin
		shift_reg <= (cstate == FRONT) ? wt_data : {shift_reg[14:0],miso_smpl};
	end 
end

assign MOSI = shift_reg[15];
assign rd_data = shift_reg;




endmodule : spi_mnrch