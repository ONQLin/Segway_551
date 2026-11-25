module SegwayMath #(
    parameter signed [12:0] MIN_DUTY = 13'h0A8,
    parameter [6:0] LOW_TORQUE_BAND = 7'h2A,
    parameter signed [3:0] GAIN_MULT = 4'h4,
    parameter PIPELINED = 1
) (
    input  logic               clk,
    input  logic signed [11:0] PID_cntrl,
    input  logic [7:0]         ss_tmr,
    input  logic [11:0]        steer_pot,
    input  logic               en_steer, pwr_up,
    output logic signed [11:0] lft_spd, rght_spd,
    output logic               too_fast
);
    logic signed [19:0] product;
    logic [11:0] clipped_pot;
    logic signed [11:0] centered_pot;
    logic signed [13:0] triple_pot;
    logic signed [12:0] steer_offset, PID_ss, steer;
    logic signed [12:0] lft_torque, rght_torque;

    assign product = PID_cntrl * $signed({1'b0, ss_tmr});
    assign clipped_pot = (steer_pot < 12'h200) ? 12'h200 :
                         (steer_pot > 12'hE00) ? 12'hE00 : steer_pot;
    assign centered_pot = clipped_pot - 12'h7ff;
    assign triple_pot = centered_pot * 3;
    assign steer_offset = en_steer ? (triple_pot >>> 4) : 13'sd0;

    if (PIPELINED) begin
        always_ff @(posedge clk) begin
            PID_ss <= $signed(product[19:8]);
            steer <= steer_offset;
            lft_torque <= PID_ss + steer;
            rght_torque <= PID_ss - steer;
        end
    end else begin
        assign PID_ss = $signed(product[19:8]);
        assign steer = steer_offset;
        assign lft_torque = PID_ss + steer;
        assign rght_torque = PID_ss - steer;
    end

    function automatic logic signed [11:0] shape(input logic signed [12:0] torque);
        logic [12:0] magnitude;
        logic signed [12:0] shaped;
        magnitude = (torque < 0) ? -torque : torque;
        if (magnitude < LOW_TORQUE_BAND)
            shaped = torque * GAIN_MULT;
        else
            shaped = (torque < 0) ? torque - MIN_DUTY : torque + MIN_DUTY;
        return (shaped > 2047) ? 12'sh7ff : (shaped < -2048) ? 12'sh800 : shaped[11:0];
    endfunction

    // Gate the output immediately even while an earlier torque is in flight.
    wire signed [11:0] lft_shaped_sat = pwr_up ? shape(lft_torque) : 12'sd0;
    wire signed [11:0] rght_shaped_sat = pwr_up ? shape(rght_torque) : 12'sd0;
    assign lft_spd = lft_shaped_sat;
    assign rght_spd = rght_shaped_sat;
    assign too_fast = (lft_spd > 12'sd1536) || (rght_spd > 12'sd1536);
endmodule
