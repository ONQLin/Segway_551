module Segway_tb();

//Declare parameter
parameter fast_sim = 1;
			
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
Segway #(fast_sim) iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
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
  
  //Set all reg input to 0
  cmd = 8'h00;
  send_cmd = 1'b0;
  rider_lean = 16'h0000;
  ld_cell_lft = 12'h400;
  ld_cell_rght = 12'h400;
  steerPot = 12'h400;
  batt = 12'h8FF;
  OVR_I_lft = 1'b0;
  OVR_I_rght = 1'b0;
  
  @(negedge clk);
  RST_n = 1;
  //Wait for some time so rst_n goes high
  repeat(10) @(negedge clk);

  //Test1: Step response provided in Ex 23 file
  @(negedge clk);
  cmd = 8'h67;
  send_cmd = 1'b1;
  @(negedge clk);
  send_cmd = 1'b0;
  //Use compound parallel statement to check if pwr_up is asserted
  fork
	//Error occurs when pwr_up is never asserted
	begin: timeout1
		repeat(30000) @(posedge clk);
		$display("Timeout for waiting pwr_up");
		$stop();
	end: timeout1
	//If pwr_up is asserted, disable timeout1
	begin
		@(posedge iDUT.iAuth.pwr_up);
		disable timeout1;	//Once pwr_up is asserted, disable timeout1 and keep testing
	end
  join
  //Make rider_lean stays at 0 for some time
  repeat(800000) @(posedge clk);
  //Change ridere_lean to 0x0FFF
  rider_lean = 16'h0FFF;
  repeat(800000) @(posedge clk);
  //Change ridere_lean to 0x0000
  rider_lean = 16'h0000;
  repeat(800000) @(posedge clk);
  $stop();
end

always
  #10 clk = ~clk;

endmodule	
