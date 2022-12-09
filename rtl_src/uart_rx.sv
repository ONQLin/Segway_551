module uart_rx #(
	parameter baud_rate = 19200,
	parameter clk_rate = 50_000_000,
	parameter div_num = clk_rate/baud_rate
)
(
	input 		clk,    	// Clock
	input 		rst_n,  	// Asynchronous reset active low
	input 		clr_rdy,	// knock down the rdy when it sets
	input       RX,   		// Serial data in

	output[7:0] rx_data,	// Byte received
	output reg 	rdy 		// Asserted when received then rst by clr_rdy
);

typedef enum reg[1:0] {IDLE, WAITING, RECEIVE} state_t;

state_t cstate, next_state;

reg[8:0]	rx_shift_reg;
reg[3:0]	bit_cnt;
reg[11:0]	baud_cnt;	//actually I want to use $log2(div_num)
reg[2:0]    rx_bit;
reg		start; 	//signal the start of new batch
wire[11:0]  baud_len = ((bit_cnt == 0) || (bit_cnt == 10)) ? div_num/2 : div_num; // (default)full: 2604, half:1302

wire		start_pulse_down;	// signal the start baud

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		cstate <= IDLE;
	end else begin
		cstate <= next_state;
	end
end

///////////////////////////////////////////////////////////////
//RX SM: 9bit shift reg but totally 11 baud count because there are 2 half baud
//To capture mid bauld at first, I set WAITING<-->Receive pair and do not shift at last half.
///////////////////////////////////////////////////////////////
always_comb begin
	if(~rst_n) begin
		next_state = IDLE;
	end else begin
		next_state = cstate;
		start = 1'b0;
		case (cstate)
			IDLE: begin
				if(start_pulse_down) begin
					next_state = WAITING;
					start = 1'b1;
				end
			end

			WAITING: begin
				if(baud_cnt == 0) begin // half or full
					next_state = RECEIVE;
				end
			end

			RECEIVE: begin
				next_state = (bit_cnt != 10) ? WAITING : IDLE;
			end
			
			default : /* default */;
		endcase
	end
end

///////////////////////////////////////////////////////////////
//still use up counter copied from tx
///////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		baud_cnt <= baud_len - 1;
	end else if(cstate == WAITING)begin 			
		baud_cnt <= baud_cnt - 1;
	end else begin   							// only when in wating state, start counting
		baud_cnt <= baud_len - 1;
	end
end

///////////////////////////////////////////////////////////////
//10 baud but 2 half -->11 baud to cnt
///////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin 	//bit_cnt counts 8bit transfer
	if(~rst_n) begin
		bit_cnt <= 4'h0;
	end else if(start | clr_rdy) begin 				//reset the bit_cnt when new data come
		bit_cnt <= 4'h0;
	end else if(cstate == RECEIVE) begin
		bit_cnt <= bit_cnt + 1;
	end
end

///////////////////////////////////////////////////////////////
// stop shifting before last half baud finishes
///////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		rx_shift_reg <= 9'h000;
	end else if(clr_rdy == 1'b1) begin 
		rx_shift_reg <= 9'h000;
	end else if((cstate == RECEIVE) && (bit_cnt!=10)) begin     
		rx_shift_reg <= {RX, rx_shift_reg[8:1]};
	end
end

///////////////////////////////////////////////////////////////
// synchronizer and detector for negedge 
///////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin 	//negedge event detector
	if(~rst_n) begin
		rx_bit <= 3'b000;
	end else begin
		rx_bit[0] <= RX;
		rx_bit[1] <= rx_bit[0];
		rx_bit[2] <= rx_bit[1];	// add another 2 ff to avoid meta-stability
 	end
end

///////////////////////////////////////////////////////////////
// ff for rdy, when consumed ,it will clr
///////////////////////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		rdy <= 1'b0;
	end else if((bit_cnt == 11) && (cstate == IDLE)) begin
		rdy <= 1'b1;
	end else begin
		rdy <= 1'b0;
	end
end

assign start_pulse_down = rx_bit[2] & ~rx_bit[1]; 	// detect async --__ 

assign rx_data = rx_shift_reg[7:0];



endmodule : uart_rx