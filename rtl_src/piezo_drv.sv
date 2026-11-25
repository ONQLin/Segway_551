module piezo_drv #(parameter fast_sim = 1) (
    input  logic clk, rst_n, en_steer, too_fast, batt_low,
    output logic piezo, piezo_n
);
    localparam SCALE = fast_sim ? 64 : 1;
    localparam QUARTER = (1 << 23) / SCALE;
    localparam REPEAT_CLKS = 150_000_000 / SCALE;
    // Rounded clock periods for a 50 MHz clock, including fast_sim scaling.
    localparam G6 = (50_000_000 + 1568*SCALE/2) / (1568*SCALE);
    localparam C7 = (50_000_000 + 2093*SCALE/2) / (2093*SCALE);
    localparam E7 = (50_000_000 + 2637*SCALE/2) / (2637*SCALE);
    localparam G7 = (50_000_000 + 3136*SCALE/2) / (3136*SCALE);

    typedef enum logic [1:0] {IDLE, STEER, FAST, BATT} mode_t;
    mode_t cmd, requested;
    logic [2:0] note_idx;
    logic waiting;
    logic [$clog2(2*QUARTER)-1:0] note_cnt;
    logic [$clog2(2*QUARTER):0] duration;
    logic [$clog2(G6)-1:0] phase, period_clks;
    logic [$clog2(REPEAT_CLKS)-1:0] repeat_cnt;

    always_comb begin
        if (too_fast) requested = FAST;
        else if (batt_low) requested = BATT;
        else if (en_steer) requested = STEER;
        else requested = IDLE;

        case (note_idx)
            0: period_clks = G6;
            1: period_clks = C7;
            2, 4: period_clks = E7;
            default: period_clks = G7;
        endcase
        case (note_idx)
            3: duration = QUARTER + QUARTER/2;
            4: duration = QUARTER/2;
            5: duration = 2*QUARTER;
            default: duration = QUARTER;
        endcase
    end

    wire note_done = (note_cnt == duration - 1);
    wire last_note = (cmd == BATT) ? (note_idx == 0) : (note_idx == 5);
    wire restart = (cmd == IDLE) || (requested == FAST && cmd != FAST)
                || (waiting && (repeat_cnt == REPEAT_CLKS-1 || requested != cmd))
                || (cmd == FAST && note_idx == 2 && note_done);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cmd <= IDLE;
            waiting <= 1'b0;
            note_idx <= '0;
            repeat_cnt <= '0;
            note_cnt <= '0;
            phase <= '0;
        end else if (requested == IDLE || restart) begin
            cmd <= requested;
            waiting <= 1'b0;
            note_idx <= (requested == BATT) ? 3'd5 : 3'd0;
            repeat_cnt <= '0;
            note_cnt <= '0;
            phase <= '0;
        end else begin
            repeat_cnt <= repeat_cnt + 1'b1;
            if (!waiting) begin
                if (note_done) begin
                    phase <= '0;
                    note_cnt <= '0;
                    if (last_note)
                        waiting <= 1'b1;
                    else if (cmd == BATT)
                        note_idx <= note_idx - 1'b1;
                    else
                        note_idx <= note_idx + 1'b1;
                end else begin
                    note_cnt <= note_cnt + 1'b1;
                    phase <= (phase == period_clks-1) ? '0 : phase + 1'b1;
                end
            end
        end
    end

    assign piezo = (cmd != IDLE) && !waiting && (phase < (period_clks >> 1));
    assign piezo_n = ~piezo;
endmodule
