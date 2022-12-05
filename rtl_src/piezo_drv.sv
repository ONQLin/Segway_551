module piezo_drv #(
	parameter fast_sim = 0,
	parameter div_note = (fast_sim) ? 17'h02000 : 1,	// divider for fast_sim
	parameter note_len_1 = 26'h2000000/div_note, 	// last G7 1/2 note
	parameter note_len_1_4 = 24'h800000/div_note, 	// 123 G6 C7 E7 1/4 note
	parameter note_len_1_8 = 23'h400000/div_note,	// last 2nd E7 1/8 note
	parameter note_len_3_8 = (24'h800000+23'h400000)/div_note,	//4th G7 3/8 note

	parameter div_frq = (fast_sim) ? 1000 : 1,	//divider for fast_sim	
	parameter G6_frq = 31888/div_frq, 			//divider for G6 frq
	parameter C7_frq = 23889/div_frq,			//divider for C7 frq
	parameter E7_frq = 18961/div_frq,           //divider for E7 frq
	parameter G7_frq = 15944/div_frq,			//divider for G7 frq

	parameter div_rep = (fast_sim) ? 100_00 : 1,
	parameter repeat_len = 3*50_000_000/div_rep
)
(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input en_steer,
	input too_fast,
	input batt_low,

	output reg piezo,
	output piezo_n
);

reg[25:0] note_cnt;
reg[14:0] frq_cnt;
reg[27:0] rep_cnt;

logic[14:0] H_frq;

reg[1:0] frq_sel;
reg frq_load, note_clr, note_en, rep_en, rep_clr, cmd_clr; // signals to control counters

typedef enum reg[1:0] {IDLE, STEER, FAST, BATT} cmd_t;
cmd_t cmd;

typedef enum reg[2:0] {IDLE1, NOTE1, NOTE2, NOTE3, NOTE4, NOTE5, NOTE6, WAITING} piezo_state;
piezo_state cstate, nstate;

always_comb begin
	case (frq_sel)
		2'b00: H_frq = G6_frq;
		2'b01: H_frq = C7_frq;
		2'b10: H_frq = E7_frq;
		2'b11: H_frq = G7_frq;
		default : H_frq = G6_frq;
	endcase
end

//note duration counter check with note_len in diif states
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		note_cnt <= 0;
	end else if(note_clr) begin
		note_cnt <= 0;
	end else if(note_en) begin
		note_cnt <= note_cnt + 1;
	end
end

//piezo freq counter check with diff note freq in 
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		frq_cnt <= 0;
	end else if(note_clr) begin
		frq_cnt <= 0;
	end else if(frq_load) begin
		frq_cnt <= 0;
	end else if(note_en) begin
		frq_cnt <= frq_cnt + 1;
	end
end

//3s repeat counter
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		rep_cnt <= 0;
	end else if(rep_clr) begin
		rep_cnt <= 0;
	end else if(rep_en) begin
		rep_cnt <= rep_cnt + 1;
	end
end

localparam duty_num = (fast_sim) ? 10 : 10000;
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		piezo <= 0;
		frq_load <= 0;
	end else if(frq_cnt == H_frq - duty_num) begin
		piezo <= 1;
	end else if(frq_cnt == H_frq) begin
		piezo <= 0;
		frq_load <= 1;
	end else begin
		piezo <= (note_en) ? piezo : 0;
		frq_load <= 0;
	end
end

// according to the state of cmd, the piezo sm will carry out different loops
always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		cmd <= IDLE;
	end else if(too_fast) begin
		cmd <= FAST;
	end else if(batt_low) begin
		cmd <= BATT;
	end else if(en_steer) begin
		cmd <= STEER;
	end else if(cmd_clr) begin
		cmd <= IDLE;
	end
end

always_ff @(posedge clk or negedge rst_n) begin
	if(~rst_n) begin
		cstate <= IDLE1;
	end else begin
		cstate <= nstate;
	end
end

always_comb begin
	nstate = cstate;
	note_clr = 0;
	note_en = 1;
	rep_clr = 0;
	rep_en = 1;
	cmd_clr = 0;
	case (cstate)
		IDLE1: begin
			rep_en = 0;
			note_en = 0;
			cmd_clr = 1;
			rep_clr = 1;
			if(cmd == FAST) begin
				nstate = NOTE1;	
				note_clr = 1;
			end else if(cmd == BATT) begin
				nstate = NOTE6;
				note_clr = 1;
			end else if(cmd == STEER) begin
				nstate = NOTE1;
				note_clr = 1;
			end
		end

		NOTE1: begin
			frq_sel = 2'b00;
			if(note_cnt == note_len_1_4) begin
				nstate = (cmd == BATT) ? WAITING : NOTE2;
				note_clr = 1;
			end
		end

		NOTE2: begin
			frq_sel = 2'b01;
			if(note_cnt == note_len_1_4) begin
				nstate = (cmd == BATT) ? NOTE1 : NOTE3;
				note_clr = 1;
			end
		end

		NOTE3: begin
			frq_sel = 2'b10;
			if(note_cnt == note_len_1_4) begin
				nstate = (cmd == FAST) ? IDLE1:((cmd == BATT) ? NOTE2 : NOTE4);
				note_clr = 1;
			end
		end

		NOTE4: begin
			frq_sel = 2'b11;
			if(note_cnt == note_len_3_8) begin
				nstate = (cmd == FAST) ? IDLE1:((cmd == BATT) ? NOTE3 : NOTE5);
				note_clr = 1;
			end
		end

		NOTE5: begin
			frq_sel = 2'b10;
			if(note_cnt == note_len_1_8) begin
				nstate = (cmd == FAST) ? IDLE1:((cmd == BATT) ? NOTE4 : NOTE6);
				note_clr = 1;
			end
		end

		NOTE6: begin
			frq_sel = 2'b11;
			if(note_cnt == note_len_1) begin
				nstate = (cmd == FAST) ? IDLE1:((cmd == BATT) ? NOTE5 : WAITING);
				note_clr = 1;
			end
		end

		WAITING: begin
			note_en = 0;
			cmd_clr = 1;
			if((rep_cnt == repeat_len) || (cmd != STEER)) begin
				nstate = IDLE1;
			end
		end

		default : nstate = IDLE1;
	endcase
end

assign piezo_n = ~piezo;


endmodule : piezo_drv