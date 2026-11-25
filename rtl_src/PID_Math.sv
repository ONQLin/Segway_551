// Combinational interface used in the PID Math exercise.
module PID_Math (
    input  logic signed [15:0] ptch, ptch_rt,
    input  logic signed [17:0] integrator,
    output logic signed [11:0] PID_cntrl
);
    PID_datapath #(.fast_sim(0), .PIPELINED(0)) math (
        .clk(1'b0), .ptch(ptch), .ptch_rt(ptch_rt), .integrator(integrator),
        .ptch_err_sat(), .PID_cntrl(PID_cntrl)
    );
endmodule

// The full controller also uses the clipped error to update its accumulator.
module PID_datapath #(
    parameter signed [4:0] P_COEFF = 5'sh09,
    parameter fast_sim = 1,
    parameter PIPELINED = 1
) (
    input  logic               clk,
    input  logic signed [15:0] ptch, ptch_rt,
    input  logic signed [17:0] integrator,
    output logic signed [9:0]  ptch_err_sat,
    output logic signed [11:0] PID_cntrl
);
    logic signed [14:0] P_term, I_term;
    logic signed [12:0] D_term;
    logic signed [15:0] sum, result;

    assign ptch_err_sat = (ptch > 511) ? 10'sd511 :
                          (ptch < -512) ? 10'sh200 : ptch[9:0];
    assign P_term = ptch_err_sat * P_COEFF;
    if (fast_sim) begin
        assign I_term = (integrator > 32767) ? 15'sh3fff :
                        (integrator < -32768) ? 15'sh4000 : integrator[15:1];
    end else begin
        assign I_term = {{3{integrator[17]}}, integrator[17:6]};
    end
    assign D_term = -$signed(ptch_rt[15:6]);
    assign sum = P_term + I_term + D_term;

    if (PIPELINED) begin
        always_ff @(posedge clk)
            result <= sum;
    end else begin
        assign result = sum;
    end

    assign PID_cntrl = (result > 2047) ? 12'sh7ff :
                       (result < -2048) ? 12'sh800 : result[11:0];
endmodule
