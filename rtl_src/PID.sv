module PID #(
    parameter signed [4:0] P_COEFF = 5'sh09,
    parameter fast_sim = 1,
    parameter TMR_INC = fast_sim ? 256 : 1,
    parameter PIPELINED = 1
) (
    input  logic signed [15:0] ptch, ptch_rt,
    input  logic               clk, rst_n, vld, pwr_up, rider_off,
    output logic signed [11:0] PID_cntrl,
    output logic [7:0]         ss_tmr
);
    logic signed [9:0] ptch_err_sat;
    logic signed [17:0] integrator, I_sum;
    logic [26:0] ss_cnt;
    logic overflow;

    PID_datapath #(.P_COEFF(P_COEFF), .fast_sim(fast_sim), .PIPELINED(PIPELINED)) math (
        .clk(clk), .ptch(ptch), .ptch_rt(ptch_rt), .integrator(integrator),
        .ptch_err_sat(ptch_err_sat), .PID_cntrl(PID_cntrl)
    );

    assign I_sum = integrator + ptch_err_sat;
    assign overflow = (ptch_err_sat[9] == integrator[17]) && (I_sum[17] != integrator[17]);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            integrator <= '0;
        else if (rider_off)
            integrator <= '0;
        else if (vld && !overflow)
            integrator <= I_sum;
    end

    assign ss_tmr = ss_cnt[26:19];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ss_cnt <= '0;
        else if (!pwr_up)
            ss_cnt <= '0;
        else if (!(&ss_tmr))
            ss_cnt <= ss_cnt + TMR_INC;
    end
endmodule
