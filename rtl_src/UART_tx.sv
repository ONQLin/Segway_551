module UART_tx #(
    parameter baud_rate = 9600,
    parameter clk_rate = 50_000_000,
    parameter div_num = clk_rate / baud_rate
) (
    input  logic       clk, rst_n, trmt,
    input  logic [7:0] tx_data,
    output logic       TX, tx_done
);
    typedef enum logic {IDLE, TRANSMIT} state_t;
    state_t state;
    logic [8:0] shift_reg;
    logic [3:0] bit_cnt;
    logic [$clog2(div_num)-1:0] baud_cnt;

    assign TX = shift_reg[0];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            shift_reg <= '1;
            bit_cnt <= '0;
            baud_cnt <= '0;
            tx_done <= 1'b0;
        end else begin
            case (state)
                IDLE: if (trmt) begin
                    shift_reg <= {tx_data, 1'b0};
                    baud_cnt <= div_num - 1;
                    bit_cnt <= '0;
                    tx_done <= 1'b0;
                    state <= TRANSMIT;
                end
                TRANSMIT: if (baud_cnt == 0) begin
                    shift_reg <= {1'b1, shift_reg[8:1]};
                    baud_cnt <= div_num - 1;
                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == 9) begin
                        tx_done <= 1'b1;
                        state <= IDLE;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1'b1;
                end
            endcase
        end
    end
endmodule
