module PWM11 (
    input  logic        clk, rst_n,
    input  logic [10:0] duty,
    output logic        PWM1, PWM2, PWM_synch, ovr_I_blank
);
    localparam logic [10:0] NONOVERLAP = 11'h040;
    localparam logic [11:0] BLANK_CLKS = 12'd128;

    logic [10:0] cnt;
    // Keep the carry so a late second pulse cannot wrap to the start of the period.
    wire [11:0] second_start = {1'b0, duty} + {1'b0, NONOVERLAP};

    assign PWM_synch = (cnt == 0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
            PWM1 <= 1'b0;
            PWM2 <= 1'b0;
            ovr_I_blank <= 1'b0;
        end else begin
            cnt <= cnt + 1'b1;
            PWM1 <= (cnt >= NONOVERLAP) && (cnt < duty);
            PWM2 <= ({1'b0, cnt} >= second_start);
            ovr_I_blank <= ((cnt >= NONOVERLAP) && (cnt < NONOVERLAP + BLANK_CLKS))
                        || ((cnt >= second_start) && (cnt < second_start + BLANK_CLKS));
        end
    end
endmodule
