interface Seg_ports();          // external interaction with Segway 
      logic [7:0] cmd;				// command host is sending to DUT
      logic send_cmd;				// asserted to initiate sending of command
      logic signed [15:0] rider_lean;
      logic [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
      logic OVR_I_lft, OVR_I_rght;
      //check the output
      logic cmd_sent;
endinterface
// !!! Because package would be compiled in the module part. Then this
// real interface would be conflexed with the Vif defined in the class
// if it is local def. So set this interface as a global one.


module Segway_tb();

import tb_tasks::*;
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM1_rght, PWM2_rght, PWM1_lft, PWM2_lft;
wire piezo,piezo_n;
wire rst_n;					// synchronized global reset


////// Stimulus is declared as type reg ///////

reg clk, RST_n;

///// Internal registers for testing purposes??? /////////
Seg_ports Seg_intf();     // use Vif-->IF to bridge between Seg_drv class and DUT

////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM1_lft(PWM1_lft),
				  .PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
				  .PWM2_rght(PWM2_rght),.rider_lean(Seg_intf.rider_lean));				  

/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
ADC128S_FC iA2D(.clk(clk),.rst_n(RST_n),.SS_n(A2D_SS_n),.SCLK(A2D_SCLK),
             .MISO(A2D_MISO),.MOSI(A2D_MOSI),.ld_cell_lft(Seg_intf.ld_cell_lft),.ld_cell_rght(Seg_intf.ld_cell_rght),
			 .steerPot(Seg_intf.steerPot),.batt(Seg_intf.batt));			
	 
////// Instantiate DUT ////////
Segway #(.fast_sim(1)) iDUT(.clk(clk),.RST_n(RST_n),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.INERT_INT(INT),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.PWM1_lft(PWM1_lft),.PWM2_lft(PWM2_lft),.PWM1_rght(PWM1_rght),
			.PWM2_rght(PWM2_rght),.OVR_I_lft(Seg_intf.OVR_I_lft),.OVR_I_rght(Seg_intf.OVR_I_rght),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
uart_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(Seg_intf.send_cmd),.tx_data(Seg_intf.cmd),.tx_done(Seg_intf.cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

initial begin
  Seg_drv seg_drv;
  seg_drv = new(Seg_intf);
  seg_drv.init();
  /// Your magic goes here ///
  clk = 0;
  RST_n = 0;
  repeat(3) @(negedge clk);
  RST_n = 1;
  repeat(3) @(negedge clk);
  // send "g" to segway
  seg_drv.uart_tx_case(.clk(clk), .tx_in(8'h67));
  seg_drv.rider_config(12'd400, 12'd300, 12'd200, 12'h8FF);

  wait(iDUT.pwr_up == 1);
  $display("the Segway has powered up");
  repeat(300000) @(posedge clk);
  seg_drv.vif.rider_lean = 16'h0;
  repeat(800000) @(posedge clk);
  seg_drv.vif.rider_lean = 16'd0;
  repeat(800000) @(posedge clk);
  $stop();
end

always
  #10 clk = ~clk;

endmodule	