module A2D_intf (
	input clk,    	// Clock
	input rst_n, 	// Asynchronous reset active low
	input nxt,		// Initiates A2D conversion on next measurand

	input MISO,
	output MOSI,
	output SCLK,
	output SS_n,

	output reg[11:0] lft_ld,	// Result of last conversion on channel 0 (left load cell)
	output reg[11:0] rght_ld,   // Result of last conversion on channel 4 (right load cell)	
	output reg[11:0] steer_pot, // Result of last conversion on channel 5 (steering potentiometer)
	output reg[11:0] batt 		// Result of last conversion on channel 6 (battery voltage)
);

	typedef enum reg[1:0] {IDLE, WR, RD, RCV} state_t;
	state_t cstate, nstate;

	wire done; 		//sig of SPI transaction 
	wire[15:0] rd_data;
	reg[15:0] spi_cmd;

	reg wrt, update, load_en;

	//reg[3:0] cnt;
	reg[1:0] round_rb;

	always_ff @(posedge clk or negedge rst_n) begin
		if(~rst_n) begin
			cstate <= IDLE;
		end else begin
			cstate <= nstate;
		end
	end

	///////////////////////////////////////////////////////////////
  	// SM for the spi sig generation. Aside from 2 transactions,
  	// The RCV state is for internal between w/r 
  	///////////////////////////////////////////////////////////////
	always_comb begin
		nstate = cstate;
		wrt = 0;		// to enable spi trans
		update = 0; 	// update round_rb -- channels
		load_en = 0; 	// update the regiters for channels' value
		case (cstate)
			IDLE: begin
				if(nxt) begin
					wrt = 1;
					nstate = WR;
				end
			end

			WR: begin
				if(done) begin
					nstate = RCV;
				end
			end

			RD: begin
				if(done) begin
					load_en = 1;
					nstate = IDLE;
					update = 1;
				end
			end

			RCV: begin
				//if(&cnt) begin
					nstate = RD;
					wrt = 1;
				//end
			end

			default : begin
				nstate = IDLE;
			end
		endcase
	end

	always_ff @(posedge clk or negedge rst_n) begin : proc_
		if(~rst_n) begin
			round_rb <= 0;
		end else if(update) begin
			round_rb <= round_rb + 1;
		end
	end

	///////////////////////////////////////////////////////////////
  	// select different cmd for different channels round
  	// allowable to feed this cmd after wrt
  	///////////////////////////////////////////////////////////////
	always_comb begin
		if(cstate == WR) begin
			case (round_rb)
				2'b00: 
					spi_cmd = {{2'b00}, {3'd0}, {11'h000}};
				2'b01: 
					spi_cmd = {{2'b00}, {3'd4}, {11'h000}};
				2'b10: 
					spi_cmd = {{2'b00}, {3'd5}, {11'h000}};
				2'b11: 
					spi_cmd = {{2'b00}, {3'd6}, {11'h000}};
			endcase
		end else begin
			spi_cmd = 16'd0;
		end
	end

	///////////////////////////////////////////////////////////////
  	// After load a new value for one of 4 channels 
  	// The round_rob will change
  	///////////////////////////////////////////////////////////////
	always_ff @(posedge clk) begin
		if(load_en) begin
			case (round_rb)
				2'd0: 
					lft_ld <= rd_data[11:0];
				2'd1: 
					rght_ld <= rd_data[11:0];
				2'd2: 
					steer_pot <= rd_data[11:0];
				2'd3: 	
					batt <= rd_data[11:0];
			endcase
		end
	end

	///////////////////////////////////////////////////////////////
  	// SPI_m: can prepare the wt_data several cycles after the assertion 
  	// of the wrt. 1 done- 1 transaction
  	///////////////////////////////////////////////////////////////
	spi_mnrch SPI_M(
		.clk		(clk),    // Clock
		.rst_n		(rst_n),  // Asynchronous reset active low
		.wrt		(wrt), 	  // A high for 1 clock period would initiate a SPI transaction
		.wt_data	(spi_cmd),
		.MISO		(MISO),
		.MOSI		(MOSI),
		.SCLK		(SCLK),
		.SS_n		(SS_n),
		.done		(done),
		.rd_data	(rd_data)
	);

endmodule : A2D_intf
