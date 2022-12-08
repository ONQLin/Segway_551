
// stimulus and some output/internal signals are included in intf
// make convenient to interact with func and task in package
interface Seg_ports();          // external interaction with Segway 
      logic [7:0] cmd;				// command host is sending to DUT
      logic send_cmd;				// asserted to initiate sending of command
      logic signed [15:0] rider_lean;
      logic [11:0] ld_cell_lft, ld_cell_rght,steerPot,batt;	// A2D values
      logic OVR_I_lft, OVR_I_rght;

      //check the output ports, utilized in func or tasks
      logic cmd_sent;
      logic piezo;
      logic signed[15:0] theta_platform;
      logic a2d_vld;
      logic pwr_up;
      reg[1:0] wait_cnt;
      reg[8:0] piezo_cnt;
      logic too_fast;
endinterface
// !!! Because package would be compiled in the module part. Then this
// real interface would be conflexed with the Vif defined in the class
// if it is local def. So set this interface as a global one.


module Segway_tb_seq();
`include "define.svh"
import tb_tasks::*;
//`include "tb_tasks.sv"
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
// connect internal value to check ports of intf
assign Seg_intf.theta_platform = iPHYS.theta_platform; 
assign Seg_intf.a2d_vld = iA2D.update_ch;  // a2d value update
assign Seg_intf.pwr_up = iDUT.pwr_up; 
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
			.piezo_n(piezo_n),.piezo(Seg_intf.piezo),.RX(RX_TX));

//// Instantiate UART_tx (mimics command from BLE module) //////
uart_tx iTX(.clk(clk),.rst_n(rst_n),.TX(RX_TX),.trmt(Seg_intf.send_cmd),.tx_data(Seg_intf.cmd),.tx_done(Seg_intf.cmd_sent));

/////////////////////////////////////
// Instantiate reset synchronizer //
///////////////////////////////////
rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));

initial begin

  Seg_drv seg_drv;
  seg_drv = new(Seg_intf);
  /// Your magic goes here ///
  clk = 0;
  RST_n = 0;
  seg_drv.init();
  repeat(3) @(negedge clk);
  RST_n = 1;
  repeat(3) @(negedge clk);

  `ifdef TP1
    seg_drv.init();
    seg_drv.seg_test_seq1(clk);
    $display("TEST1: watch the Analog form of theta and ptch to check the balancing");
  `endif

  `ifdef TP2
    seg_drv.init();
    seg_drv.seg_test_seq2(clk);
    $display("TEST2: watch the Analog form of theta and ptch to check the balancing");
  `endif

  `ifdef TP3
    seg_drv.init();
    fork
      seg_drv.seg_test_seq3(clk, 2'b10);
      begin                               // import is not like `include where can directly reference and force internal signals
        wait(Seg_intf.too_fast == 1'b1);
        force iDUT.iBAL.seg_inst.lft_shaped_sat = 12'd1800;
        wait(Seg_intf.too_fast == 1'b0);
        release iDUT.iBAL.seg_inst.lft_shaped_sat;
      end
    join
    
    $display("TEST3: watch the Analog form of theta and ptch to check the OVR");
  `endif

  `ifdef TP4
    seg_drv.init();
    seg_drv.seg_test_seq4(clk, 2'b01);
    $display("TEST4: watch the Analog form of theta and ptch to check the OVR shut");
  `endif


  $stop;

end

always
  #10 clk = ~clk;

endmodule	