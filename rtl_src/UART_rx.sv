module UART_rx #(
    parameter baud_rate = 9600,
    parameter clk_rate = 50_000_000,
    parameter div_num = clk_rate / baud_rate
) (
    input  logic       clk, rst_n, clr_rdy, RX,
    output logic [7:0] rx_data,
    output logic       rdy
);
    logic rx_meta, rx_sync;
    logic [8:0] shift_reg;
    logic [3:0] bit_cnt;
    logic [$clog2(div_num)-1:0] baud_cnt;
    typedef enum logic {IDLE, RECEIVE} state_t;
    state_t state;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= RX;
            rx_sync <= rx_meta;
        end
    end

    assign rx_data = shift_reg[7:0];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            baud_cnt <= '0;
            bit_cnt <= '0;
            shift_reg <= '0;
            rdy <= 1'b0;
        end else begin
            if (clr_rdy)
                rdy <= 1'b0;
            case (state)
                IDLE: if (!rx_sync) begin
                    baud_cnt <= div_num / 2 - 1;
                    bit_cnt <= '0;
                    rdy <= 1'b0;
                    state <= RECEIVE;
                end
                RECEIVE: if (baud_cnt == 0) begin
                    // Sample the start, eight data bits and stop at their centers.
                    shift_reg <= {rx_sync, shift_reg[8:1]};
                    baud_cnt <= div_num - 1;
                    bit_cnt <= bit_cnt + 1'b1;
                    if (bit_cnt == 0 && rx_sync)
                        state <= IDLE;
                    else if (bit_cnt == 9) begin
                        rdy <= rx_sync;
                        state <= IDLE;
                    end
                end else begin
                    baud_cnt <= baud_cnt - 1'b1;
                end
            endcase
        end
    end
endmodule
