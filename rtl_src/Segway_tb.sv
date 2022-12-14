`timescale 1ns/1ps

//  /filespace/j/jlin445/ece551/SAED32_lib
module Segway_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
wire cmd_sent;
wire rst_n;					// synchronized global reset

wire[14:0] ptch_test;

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;				// command host is sending to DUT
reg send_cmd;				// asserted to initiate sending of command
reg signed [15:0] rider_lean;
reg [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
reg OVR_I_lft, OVR_I_rght;

///// Internal registers for testing purposes??? /////////
assign ptch_test = iDUT.ptch[14:0];

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
Segway iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
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
  //input clk, RST_n, INERT_MISO, INERT_INT, A2D_MISO, OVR_I_lft, OVR_I_rght, RX;
  {ld_cell_lft, ld_cell_rght,steerPot,batt} = {12'd0, 12'd0, 12'd0, 12'h8FF};
  {OVR_I_lft, OVR_I_rght} = {1'b0,1'b0};
  force iDUT.ptch_rt = 0;

  repeat(10) @(negedge clk);
  RST_n = 1;
  send_cmd = 0;

  release iDUT.ptch_rt;

  repeat(3) @(negedge clk);
  rider_lean = 0;

  // send "g" to segway
  uart_tx_case(8'h67);
  {ld_cell_lft, ld_cell_rght,steerPot,batt} = {12'd400, 12'd300, 12'd200, 12'h8FF};
  //{ld_cell_lft, ld_cell_rght,steerPot,batt} = {12'd0, 12'd0, 12'd0, 12'h0};
  wait(iDUT.pwr_up == 1);
  $display("pwr up pass!!!!!!");
  repeat(300000) @(posedge clk);
  rider_lean = 16'h0fff;
  repeat(800000) @(posedge clk);
  rider_lean = 16'h0000;
	
  // rider off
  uart_tx_case(8'h73);
  {ld_cell_lft, ld_cell_rght,steerPot,batt} = {12'd000, 12'd000, 12'd200, 12'h8FF};
  wait(iDUT.pwr_up == 0);
  $display("power is off when the rider is off");
	
  repeat(10) @(posedge clk);
 
  // rider on but batt is low
  uart_tx_case(8'h67);	
  {ld_cell_lft, ld_cell_rght,steerPot,batt} = {12'd400, 12'd300, 12'd200, 12'h000};
  if(iDUT.pwr_up != 0) begin
	$display("if battery is low, power should be off");
	$stop();
  end
  
  // recover the batt again
  repeat(10000) @(posedge clk);
  batt = 12'h8FF;
  wait(iDUT.pwr_up == 1);
  $display("pwr is up again");

  // test on too_fast scenario
  repeat(10000) @(posedge clk);
  {ld_cell_lft, ld_cell_rght} = {12'hFFF, 12'hFFF};
  if(iDUT.pwr_up == 0) begin
	$display("power should be up at too_fast");
	$stop();
  end
  
  repeat(800000) @(posedge clk);
  $stop();

end

always
  #10 clk = ~clk;
  

task uart_tx_case(input[7:0] tx_in);
		@(negedge clk);
		send_cmd = 1;
		cmd = tx_in;
		@(negedge clk);
		send_cmd = 0;		// 1clk trmt, to capture and set txdata;
		wait(cmd_sent == 1'b1); 	// serial data done, otherwise uart_tx is not sent
		$display("tx data, %h, is sent",tx_in); 
endtask : uart_tx_case

endmodule
