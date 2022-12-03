package tb_tasks;
      // https://stackoverflow.com/questions/67922669/what-causes-interface-resolution-compilation-error-when-working-with-classes-a
      class Seg_drv;

            virtual Seg_ports vif; // virtual interface link to segway

            function new( virtual Seg_ports s);
                  vif = s; // initialize the virtual interface 
            endfunction

            task init();   //init the stimulus
                  {vif.OVR_I_lft, vif.OVR_I_rght} = {1'b0, 1'b0};
                  {vif.ld_cell_lft, vif.ld_cell_rght,vif.steerPot,vif.batt} 
                  = {'0, '0, '0, '0};
                  vif.cmd = '0;
                  vif.send_cmd = '0;
                  vif.rider_lean = '0;
            endtask

            task automatic uart_tx_case(input[7:0] tx_in, ref clk);
                  @(negedge clk);
                  vif.send_cmd = 1;
                  vif.cmd = tx_in;
                  @(negedge clk);
                  vif.send_cmd = 0;		// 1clk trmt, to capture and set txdata;
                  wait(vif.cmd_sent == 1'b1); 	// serial data done, otherwise uart_tx is not sent
                  $display("tx data, %h, is sent",tx_in);   
            endtask

            task rider_config(input[11:0] lcl, input[11:0] lcr, input[11:0] sp, input[11:0] bt);
                 {vif.ld_cell_lft, vif.ld_cell_rght, vif.steerPot, vif.batt} = 
                 {lcl, lcr, sp, bt}; 
            endtask

            task random_leaning(input[15:0] Lowl, input[15:0] Highl);
                  vif.rider_lean = $urandom(Lowl, Highl);
            endtask

      endclass

endpackage : tb_tasks