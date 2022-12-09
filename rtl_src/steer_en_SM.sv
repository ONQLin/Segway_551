module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_1_4,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY HOFFMAN...you are a moron.  sum_gt_min would simply be ~sum_lt_min. 
  // Why have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's weight is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  input diff_gt_1_4;		// asserted if load cell difference exceeds 1/4 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output logic clr_tmr;		// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;	// held high in intitial state when waiting for sum_gt_min
  
  // You fill out the rest...use good SM coding practices ///

  typedef enum reg[1:0] {INIT, WAITING, NORMAL} state_t;
  state_t state, next_state;
  
  ///////////////////////////////////////////////////////////////
  // SM 1st part: timing control, sychronize state//
  ///////////////////////////////////////////////////////////////
  always_ff @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
          state <= INIT;
      end else begin
          state <= next_state;
      end
  end

  ///////////////////////////////////////////////////////////////
  // SM 2nd part: decide next state(maybe combine some outputs)//
  ///////////////////////////////////////////////////////////////
  always_comb begin
      next_state = state;
      clr_tmr = 1'b1;   //default to avoild latch
      case (state)
        INIT: begin
            if(sum_gt_min) begin    //ensure that rider is absolutely on (higher than threshold + hysteresis), go to waiting balance
                next_state = WAITING;
                clr_tmr = 1'b0;
            end
        end
        WAITING: begin
            clr_tmr = 1'b0;
            if (sum_lt_min) begin  //rider totally step off, go back to INIT
                next_state = INIT;
            end else if(diff_gt_1_4) begin           //balance wrong, clear the counter, waiting for balance
                clr_tmr = 1'b1;
            end else if (tmr_full) begin    //1.3s for balance is up, we can enable steer
                next_state = NORMAL;
            end
        end

        NORMAL: begin
            if(~sum_gt_min) begin   //CAUSE: first check rider may get knock off the device - high priority
                next_state = INIT;
            end else if(diff_gt_15_16) begin //rider is steppingg off go to waiting for balance(clr counter)
                next_state = WAITING;
            end
        end

        default: begin
            next_state = INIT;
        end
      endcase
  end

  ///////////////////////////////////////////////////////////////
  // SM 3rd part: assign some outputs by sm&input             //
  ///////////////////////////////////////////////////////////////
  assign rider_off = (sum_lt_min) ? 1 : ((state == INIT) & (~sum_gt_min)) ? 1 : 0;
  assign en_steer = (state == NORMAL) ? 1 : 0;

  
endmodule