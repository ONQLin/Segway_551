////////////////////////////////////////////////////
//This test bench tests the trasition /////////////
//of Auth_blk and steer_en.///////////////////////
module Segway_tb_check_steer_en_SM();
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
wire cmd_sent;
wire rst_n;					// synchronized global reset

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;				// command host is sending to DUT
reg send_cmd;				// asserted to initiate sending of command
reg signed [15:0] rider_lean;
reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;

///// Internal registers for testing purposes??? /////////


////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
				  .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
				  .PWM2_rght(PWM2_rght),.rider_lean(rider_lean));				  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
             .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(ld_cell_lft),.ld_cell_rght(ld_cell_rght),
			 .steerPot(steerPot),.batt(batt));			
	 
////// Instantiate DUT ////////
Segway #(.fast_sim(1)) iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
			.PWM2_rght(PWM2_rght),.OVR_I_lft(OVR_I_lft),.OVR_I_rght(OVR_I_rght),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
uart_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

initial begin
  
  /// Your magic goes here ///
  clk = 0;
  RST_n = 0;
  repeat(3) @(negedge clk);
  RST_n = 1;
  //Set inputs to 0 first
  //pwr_up and sum_gt_min should be 0 and sum_lt_min should be 1
  send_cmd = 0;
  cmd = 8'h00;
  rider_lean = 16'h0000;
  ld_cell_lft = 12'h000;
  ld_cell_rght = 12'h0000;
  steerPot = 12'h0000;
  batt = 12'h0000;
  OVR_I_lft = 0;
  OVR_I_rght = 0;
  //Use parallel compound statement to check if sum_gt_min is 0 and sum_lt_min is 1
  fork
	//Error occurs when sum_gt_min set to 1
	begin: timeout1
		@(posedge iDUT.iSTR.sum_gt_min);
		$display("Test fails: sum_gt_min is asserted at first");
		$stop();
	end: timeout1
	//If sum_lt_min is asserted, disable timeou1
	begin
		@(posedge iDUT.iSTR.sum_lt_min);
		disable timeout1;	//Continue testing
	end
  join
  //Wait for some time
  repeat(10) @(negedge clk);
  //Check the value of lft_ld, rght_ld and pwr_up
  if(iDUT.iSTR.lft_ld !== 12'h000) begin
	$display("Test fails: lft_ld should be 0 at first");
	$stop();
  end
  if(iDUT.iSTR.rght_ld !== 12'h000) begin
	$display("Test fails: rght_ld should be 0 at first");
	$stop();
  end
  if(iDUT.iAuth.pwr_up !== 1'b0) begin
	$display("Test fails: rght_ld should be 0 at first");
	$stop();
  end

  //Send 'g' to the segway but pwr_up should not be asserted
  cmd = 8'h67;
  send_cmd = 1;
  //Deassert send_cmd after 1 clk period
  @(negedge clk) send_cmd = 0;
  repeat(100000) @(negedge clk);
  repeat(50000) @(negedge clk);
  send_cmd = 1;
  @(negedge clk) send_cmd = 0;
  //Set the batt to be greater than threshold
  batt = 12'h900;
  ld_cell_lft = 12'h200;
  ld_cell_rght = 12'h200;
  repeat(100000) @(negedge clk);
  $stop();
end

always
  #10 clk = ~clk;

endmodule
