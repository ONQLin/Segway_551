package tb_tasks;
      // https://stackoverflow.com/questions/67922669/what-causes-interface-resolution-compilation-error-when-working-with-classes-a
      class Seg_drv;

            virtual Seg_ports vif; // virtual interface link to segway
            reg uclk;
            reg piezo_check, platform_check;

            function new( virtual Seg_ports s);
                  vif = s; // initialize the virtual interface 
                  uclk = 0;
                  {piezo_check, platform_check} = {1'b0,1'b0};
            endfunction

            task init();   //init the stimulus
                  {vif.OVR_I_lft, vif.OVR_I_rght} = {1'b0, 1'b0};
                  rider_config(0,0,0);
                  vif.cmd = '0;
                  vif.send_cmd = '0;
                  vif.rider_lean = '0;
            endtask

            ////////////////////////////////////////
            // Seq 1 is similar to ex23 featured  //
            // with rider normally stand on seg   //
            // and exert some step lean to check  //
            // whether balance is controled or not//
            ////////////////////////////////////////
            task automatic seg_test_seq1(ref clk);
                  {piezo_check, platform_check} = {1'b1,1'b1};

                  ////// Stage 1: Testing Auth with rider off/on | cover iAuth A2D iBUZZ iSTR... ///////
                  fork
                        begin                         // testor meanwhile check some states                                          
                              // send "g" to power on the device
                              uart_tx_case(.clk(clk), .tx_in(8'h67));
                              if(vif.pwr_up == 1'b1) begin
                                    $display("------Step1: rider off pwr on pass!------"); 
                              end else begin
                                    $error("without rider, it should also pwr");      
                                    $stop;
                              end
                              // waiting for lft rght data received
                              repeat(4) @(posedge vif.a2d_vld);
                              // send "s"
                              uart_tx_case(.clk(clk), .tx_in(8'h73));
                              if(vif.pwr_up == 1'b0) begin
                                    $display("------Step2: rider off pwr off pass!------");
                              end else begin
                                    $error("one should pwr off with rider off");
                                    $stop;
                              end
                              {piezo_check, platform_check} = {1'b0,1'b0};
                        end      
                        quiet_piezo_ck();             //scoreboard check for piezo                                 
                        plain_platform_ck(15'd10);    //scoreboard check for platform                     
                  join
                  // rider on and start steer
                  rider_config(12'd400, 12'd300, 12'd200);
                  repeat(4) @(posedge vif.a2d_vld);
                  uart_tx_case(.clk(clk), .tx_in(8'h67));
                  if(vif.pwr_up == 1'b0) begin
                        $error("one should power up");
                        $stop;
                  end
                  uart_tx_case(.clk(clk), .tx_in(8'h73));
                  if(vif.pwr_up == 1'b0) begin
                        $error("one should power up");
                        $stop;
                  end else begin
                        $display("------Step3: rider on pwr on pass!------");
                  end
                  ////// Stage 2: Testing rider on with some step lean and watch the balance control ///////
                  ////// cover  iBAL iDRV iBuzz iNemo...//////
                  piezo_check = 1;
                  fork
                        begin
                              repeat(300000) @(posedge clk);
                              vif.rider_lean = 16'h0fff;
                              repeat(800000) @(posedge clk);
                              vif.rider_lean = 16'd0;
                              repeat(800000) @(posedge clk);
                              piezo_check = 0;
                        end
                        steer_piezo_ck();
                  join
                  $display("------Step4: watch rider on seg with lean passes!------");
            endtask : seg_test_seq1

            ////////////////////////////////////////
            // Seq 2 applies random rider lean    //
            // and different states of steer      //
            // and exert some step lean to check  //
            // whether balance is controled or not//
            ////////////////////////////////////////
            task seg_test_seq2(ref clk);
                  uart_tx_case(.clk(clk), .tx_in(8'h67));
                  rider_config(12'd300, 12'd400, 12'd200);              //rider on and steer en      
                  repeat(4) @(posedge vif.a2d_vld);
                  piezo_check = 1;
                  fork
                        begin
                              for(int i = 0; i < 4; i=i+1) begin 
                                    random_leaning(16'h0, 16'h0fff);
                                    repeat(600000) @(posedge clk);
                              end
                              piezo_check = 0;
                        end
                        steer_piezo_ck();             //scoreboard check for piezo steer
                  join
                  $display("------Step1: watch steer en with lean!------");
                  rider_config(12'd1000, 12'd10, 12'd200);              //rider on and steer off      
                  repeat(4) @(posedge vif.a2d_vld);                     //piezo should be off in this case
                  piezo_check = 1;
                  fork
                        begin
                              for(int i = 0; i < 4; i=i+1) begin 
                                    random_leaning(16'h0, 16'h0fff);
                                    repeat(600000) @(posedge clk);
                              end      
                              piezo_check = 0;
                        end
                        quiet_piezo_ck();             //scoreboard check for piezo quiet
                  join
                  $display("------Step2: watch steer off with lean!------");
                  rider_config(12'd20, 12'd20, 12'd200, 12'd100);       //all off but batt low 
                  repeat(4) @(posedge vif.a2d_vld);
                  piezo_check = 1;
                  fork                          
                        begin
                              for(int i = 0; i < 4; i=i+1) begin 
                                    random_leaning(16'h0, 16'h0fff);
                                    repeat(600000) @(posedge clk);
                              end      
                              piezo_check = 0;
                        end
                        batt_piezo_ck();             //scoreboard check for piezo batt
                  join
                  $display("------Step3: watch rider off batt low with lean!------");
            endtask : seg_test_seq2


            ////// Testor func or tasks: some can integrated to interfaces but not ///////
            task automatic uart_tx_case(input[7:0] tx_in, ref clk);
                  @(negedge clk);
                  vif.send_cmd = 1;
                  vif.cmd = tx_in;
                  @(negedge clk);
                  vif.send_cmd = 0;		// 1clk trmt, to capture and set txdata;
                  wait(vif.cmd_sent == 1'b1); 	// serial data done, otherwise uart_tx is not sent
                  $display("tx data, %h, is sent",tx_in);
                  wait_bauds(12);   
            endtask

            function void rider_config(input[11:0] lcl, input[11:0] lcr, input[11:0] sp, input[11:0] bt=12'h8FF);
                 {vif.ld_cell_lft, vif.ld_cell_rght, vif.steerPot, vif.batt} = 
                 {lcl, lcr, sp, bt}; 
            endfunction

            function void random_leaning(input[15:0] Lowl, input[15:0] Highl);
                  vif.rider_lean = $urandom_range(Lowl, Highl);
            endfunction

            task wait_bauds(input[15:0] len);
                  repeat(len*2) #30000 uclk = ~uclk;
            endtask


            ////// Scoreboard tasks: checking simple components ///////
            task steer_piezo_ck();
                  reg[8:0] piezo_cnt;
                  reg[1:0] wait_cnt = 2'b00;
                  int i, j;
                  fork
                        while(piezo_check == 1'b1) begin : piezo_counter
                              @(posedge vif.piezo);
                              wait_cnt = 2'b00;
                              piezo_cnt = piezo_cnt + 1;
                              if(piezo_cnt > 360) begin
                                    $error("steer piezo goes wrong : %d, round %d!!!", piezo_cnt, i);
                                    $stop;
                              end
                              i++;
                        end : piezo_counter
                        while(piezo_check == 1'b1) begin : waiting_piezo
                              #20_000;
                              if(wait_cnt==2'b01) begin
                                    if((piezo_cnt <350) || (piezo_cnt > 370)) begin
                                          $error("steer piezo goes wrong : %d round %d!!!!!!", piezo_cnt, j);
                                          $stop;
                                    end
                                    piezo_cnt = 0;
                                    wait_cnt[1] = 1; // only reset once when it hits waiting
                              end
                              wait_cnt[0] = 1;
                              j++;
                        end : waiting_piezo
                  join_any
                  disable piezo_counter;
                  $display("steer_piezo_ck passes!!!");
            endtask

            task plain_platform_ck(input[14:0] limit);
                  while(1) begin
                        #100;
                        if($signed(vif.theta_platform) > $signed(limit) || ($signed(vif.theta_platform) < $signed(~limit))) begin
                              $error("no state changes now!!!");
                              $stop;
                        end
                        if(platform_check == 0)
                              break;
                  end
                  $display("pltf_ck_proc 1 pass"); 
            endtask : plain_platform_ck

            task quiet_piezo_ck();
                  while(1) begin
                        #40;
                        if(vif.piezo == 1'b1) begin
                              $error("no state changes now!!!");
                              $stop;
                        end
                        if(piezo_check == 0)
                              break;
                  end
                  $display("quiet_piezo_ck pass!");
            endtask : quiet_piezo_ck

            task batt_piezo_ck();
                  reg[2:0] wait_cnt = 0;
                  int i;
                  fork
                        while(piezo_check == 1'b1) begin : piezo_trig
                              @(posedge vif.piezo);
                              wait_cnt = 0;
                        end : piezo_trig
                        while(piezo_check == 1'b1) begin
                              #20_000;
                              wait_cnt = wait_cnt + 1;
                              if(&wait_cnt) begin
                                    $display("it is not batt or fast mode!!! round %d", i);
                                    $stop;
                              end
                              i++;
                        end
                  join_any
                  disable piezo_trig;
                  $display("batt_piezo_ck passes!!!");
            endtask : batt_piezo_ck

      endclass

endpackage : tb_tasks













