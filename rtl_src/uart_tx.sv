module uart_tx #(
	parameter baud_rate = 19200,
	parameter clk_rate = 50_000_000,
	parameter div_num = clk_rate/baud_rate
)
(
	input 		clk,    	// Clock
	input 		rst_n,  	// Asynchronous reset active low
	input 		trmt,	  	// Asserted for 1 clock to initiate transmission
	input[7:0] 	tx_data,	// Byte to transmit

	output		TX,			// Serial data out
	output reg	tx_done		// Asserted when byte is done transmitting. Stays high till next byte transmitted. 
);

	typedef enum reg[1:0] {IDLE, WAITING, TRANSMIT} state_t;

	state_t [1:0] cstate, next_state;

	reg[8:0]	tx_shift_reg;
	reg[3:0]	bit_cnt;
	reg[11:0]	baud_cnt;	//actually I want to use $log2(div_num)

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			cstate <= IDLE;
		end else begin
			cstate <= next_state;
		end
	end

	///////////////////////////////////////////////////////////////
  	//TX SM: comb part. waiting is for baud cnt, transmit is for shift and 1bit done. 
  	//Because I init the shift reg at beginning, I set WAITING<-->TRANSMIT pair to relieve controling shift.
  	///////////////////////////////////////////////////////////////
	always_comb begin
			next_state = cstate;
			case (cstate)
				IDLE: begin			// when IDLE, TX set high, wating for data, 
					if(trmt) begin
						next_state = WAITING;
					end
				end

				TRANSMIT: begin		// when to transmit(1 cycle), the shift reg will shift, bit_cnt++, up tp 10(8+start+end) times.
					next_state = (bit_cnt != 9) ? WAITING : IDLE;
				end

				WAITING: begin		// waiting for baud_cnt then goto transmit. minus 1 for state transition, cannot quit until it is done
					if(baud_cnt == div_num - 2) begin
						next_state = TRANSMIT;
					end
				end

				default: begin 
					next_state = IDLE;
				end 
			endcase
	end

	///////////////////////////////////////////////////////////////
  	//tx shift reg: preset,1 >>, up to 10 baud transmit
  	///////////////////////////////////////////////////////////////
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			tx_shift_reg <= 9'h1ff;
		end else if(trmt == 1'b1) begin 	// load shift reg, 1'b1 is stop, 1'b0 is start
			tx_shift_reg <= {tx_data, 1'b0};
		end else if(cstate == TRANSMIT) begin      			// when waiting stop, shift.
			tx_shift_reg <= {1'b1,tx_shift_reg[8:1]};		// shift default 1 to save bit for stop
		end
	end

	///////////////////////////////////////////////////////////////
  	//bit_cnt: init by trmt, add up when shift
  	///////////////////////////////////////////////////////////////
	always_ff @(posedge clk or negedge rst_n) begin 	//bit_cnt counts 8bit transfer
		if(~rst_n) begin
			bit_cnt <= 4'h0;
		end else if(trmt == 1'b1) begin 				//reset the bit_cnt when new data come
			bit_cnt <= 4'h0;
		end else if(cstate == TRANSMIT) begin
			bit_cnt <= bit_cnt + 1;
		end
	end

	//////////////////////////////////////////////////////////////
  	//baud_cnt: only add up when in waiting for baud length, otherwise it always sleep in '0
  	///////////////////////////////////////////////////////////////
	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			baud_cnt <= 12'h000; 
		end else if(cstate == WAITING)begin 			
			baud_cnt <= baud_cnt + 1;
		end else begin   						// only when in wating state, start counting
			baud_cnt <= 12'h000;
		end
	end

	//////////////////////////////////////////////////////////////
  	//ff for tx_done out
  	///////////////////////////////////////////////////////////////
	always_ff @(posedge clk or negedge rst_n) begin 
		if(~rst_n) begin
			tx_done <= 1'b0;
		end else if(trmt) begin
			tx_done <= 1'b0;
		end else if(bit_cnt == 10) begin
			tx_done <= 1'b1;
		end
	end

	assign TX = tx_shift_reg[0]; 		 // tx = 1 until trmt comes

endmodule
