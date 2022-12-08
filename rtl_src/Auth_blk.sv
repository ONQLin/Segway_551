module Auth_blk (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input rider_off,
	input RX,

	output logic pwr_up
);
	
	logic clr_rx_rdy, rx_rdy;
	logic[7:0] rx_data;
	
	uart_rx urx_inst(
		.clk(clk),  		// IN
		.rst_n(rst_n), 		// IN
		.clr_rdy(clr_rx_rdy),
		.RX(RX),   			// IN

		.rx_data(rx_data),
		.rdy    (rx_rdy)   
	);

	wire g = (rx_data == 8'h67) && (rx_rdy == 1'b1);
	wire s = (rx_data == 8'h73) && (rx_rdy == 1'b1);

	typedef enum reg[1:0] {OFF, PWR1, PWR2} state_t;

	state_t cstate, next_state;

	always_ff @(posedge clk or negedge rst_n) begin : proc_
		if(~rst_n) begin
			cstate <= OFF;
		end else begin
			cstate <= next_state;
		end
	end

	always_comb begin
		next_state = cstate;
		clr_rx_rdy = 0;
		pwr_up = 1;
		case (cstate)
			OFF: begin
				pwr_up = 0;
				if(g&~rider_off) begin
					next_state = PWR1;
					clr_rx_rdy = 1;
				end
			end

			PWR1: begin
				if(s&rider_off) begin
					next_state = OFF;
					clr_rx_rdy = 1;
				end else if(s & ~rider_off) begin
					next_state = PWR2;
					clr_rx_rdy = 1;
				end
			end

			PWR2: begin
				if(g) begin 		// if g keep pwr on even rider_off
					next_state = PWR1;
					clr_rx_rdy = 1;
				end else if(rider_off) begin
					next_state = OFF;
				end
			end

			default : begin
				next_state = OFF;
			end

		endcase
	end

endmodule : Auth_blk
