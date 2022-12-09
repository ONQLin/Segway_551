////////////////////////////////////////////////////
//This test bench tests the trasition /////////////
//of Auth_blk and steer_en.///////////////////////
module Segway_check_steer_in();
			
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
		wait(iDUT.iSTR.sum_lt_min == 1'b1);
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
  //Pwr_up should not be asserted and state should still be in OFF
  if(iDUT.pwr_up !== 0) begin
	$display("Test fails: pwr_up is asserted when ld_cell are both 0");
	$stop();
  end
  if(iDUT.iAuth.cstate !== 2'b00) begin
	$display("Test fails: Segway should stay in OFF state when ld_cell are both 0");
	$stop();
  end
  //Wait for sometime and change batt, ld_cell
  repeat(5000) @(negedge clk);
  //Set the batt to be greater than threshold
  batt = 12'h900;
  //Make the difference of ld_cell greater than 1/4 of the total weight
  //in order to assert diff_gt_1_4
  ld_cell_lft = 12'h200;
  ld_cell_rght = 12'h50;
  //Use parallel compound statement to check if rider_off is deasserted
  fork
	//Error occurs when pwr_up is not set to 1
	begin: timeout2
		repeat(100000) @(negedge clk);
		$display("Test fails: rider_off is not deasserted after changing ld_cell");
		$stop();
	end: timeout2
	//If rider_off is deasserted, disable timeout2
	begin
		@(negedge iDUT.rider_off);
		disable timeout2;	//Continue testing
	end
  join
  //Wait for some time and check if pwr_up is asserted
  repeat(100) @(negedge clk);
  if(iDUT.pwr_up !== 1) begin
	$display("Test fails: pwr_up is not asserted after rider_off is deasserted");
	$stop();
  end
  //Also, check is diff_gt_1_4 is asserted and diff_gt_15_16 is not asserted
  if(iDUT.iSTR.diff_gt_1_4 !== 1) begin
	$display("Test filas: diff_gt_1_4 is not asserted when lft_ld is 0x200 and rght_ld is 0x50");
	$stop();
  end
  if(iDUT.iSTR.diff_gt_15_16 !== 0) begin
	$display("Test filas: diff_gt_1_4 is asserted when lft_ld is 0x200 and rght_ld is 0x50");
	$stop();
  end
  //Use parallel compound statement to check if en_steer is asserted when diff_gt_1_4 is 1
  fork
	//Error occurs when en_steer set to 1
	begin: timeout3
		@(posedge iDUT.en_steer);
		$display("Test fails: en_steer is asserted when diff_gt_1_4 is 1");
		$stop();
	end: timeout3
	//If en_steer not asserted, disable timeou3
	begin
		repeat(50000) @(negedge clk);
		disable timeout3;	//Continue testing
	end
  join
  //Now change ld_cell_rght to deassert diff_gt_1_4
  ld_cell_rght = 12'h200;
  //Use parallel compound statement to check if diff_gt_1_4 is deasserted
	fork
	//Error occurs when diff_gt_1_4 is not deasserted
	begin: timeout4
		repeat(100000) @(negedge clk);
		$display("Test fails: diff_gt_1_4 is not deasserted after changing ld_cell_rght");
		$stop();
	end: timeout4
	//If diff_gt_1_4 not deasserted, disable timeou4
	begin
		@(negedge iDUT.iSTR.diff_gt_1_4);
		disable timeout4;	//Continue testing
	end
  join
  //Use parallel compound statement to check if en_steer is asserted
	fork
	//Error occurs when en_steer is not asserted
	begin: timeout5
		repeat(100000) @(negedge clk);
		$display("Test fails: en_steer is not asserted after diff_gt_1_4 is deasserted");
		$stop();
	end: timeout5
	//If en_steer asserted, disable timeou5
	begin
		@(posedge iDUT.en_steer);
		disable timeout5;	//Continue testing
	end
  join
  //Now rider is stepping off, change ld_cell to assert diff_gt_15_16
  ld_cell_rght = 12'h020;
  ld_cell_lft = 12'h700;
  //Use parallel compound statement to check if diff_gt_15_16 is asserted
  fork
	//Error occurs when en_steer is not asserted
	begin: timeout6
		repeat(100000) @(negedge clk);
		$display("Test fails: diff_gt_15_16 is not asserted after changing ld_cell");
		$stop();
	end: timeout6
	//If diff_gt_15_16 asserted, disable timeout6
	begin
		@(posedge iDUT.iSTR.diff_gt_15_16);
		disable timeout6;	//Continue testing
	end
  join
  //Wait for some time
  repeat(100) @(negedge clk);
  //Check if en_steer get deasserted
  if(iDUT.en_steer !== 0) begin
	$display("Test fails: en_steer is not deasserted after diff_gt_15_15 is asserted");
	$stop();
  end
  //Check if rider_off get asserted
  if(iDUT.rider_off !== 0) begin
	$display("Test fails: rider_off is asserted after diff_gt_15_15 is asserted");
	$stop();
  end
  //Change ld_cell to 0x200 to go to en_steer
  ld_cell_rght = 12'h200;
  ld_cell_lft = 12'h200;
  //Wait for en_steer be asserted
  wait(iDUT.en_steer == 1);
  //Send signal 's' but pwr_up will still be high since rider_off is not asserted
  @(negedge clk);
  cmd = 8'h73;
  send_cmd = 1;
  //Deassert send_cmd at not negedge of clk
  @(negedge clk) send_cmd = 0;
  //Wait for some time
  repeat(30000) @(negedge clk);
  //Check if pwr_up is still asserted
  if(iDUT.pwr_up !== 1) begin
	$display("Test fails: pwr_up is deasserted when rider is still on");
	$stop();
  end
  //Now rider is knocked off, change both ld_cell to 0
  ld_cell_rght = 12'h000;
  ld_cell_lft = 12'h000;
  //Use parallel compound statement to check if rider_off is asserted
  fork
	//Error occurs when en_steer is not asserted
	begin: timeout7
		repeat(100000) @(negedge clk);
		$display("Test fails: rider_off is not asserted after rider is knocked off");
		$stop();
	end: timeout7
	//If rider_off asserted, disable timeout7
	begin
		@(posedge iDUT.rider_off);
		disable timeout7;	//Continue testing
	end
  join
  //Wait for some time
  repeat(1000) @(negedge clk);
  //Check if pwr_up is off
  if(iDUT.pwr_up !== 0) begin
	$display("Test fails: pwr_up is not deasserted when rider is still on");
	$stop();
  end
  repeat(1000) @(negedge clk);
  $stop();

end

always
  #10 clk = ~clk;

endmodule
