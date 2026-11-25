module Auth_blk (
    input  logic clk, rst_n, rider_off, RX,
    output logic pwr_up
);
    logic rx_rdy;
    logic [7:0] rx_data;
    UART_rx urx_inst(
        .clk(clk), .rst_n(rst_n), .RX(RX),
        .rx_data(rx_data), .rdy(rx_rdy), .clr_rdy(rx_rdy)
    );

    typedef enum logic [1:0] {OFF, AUTHORIZED, STOP_PENDING} state_t;
    state_t cstate;
    wire go_cmd = rx_rdy && (rx_data == "G");
    wire stop_cmd = rx_rdy && (rx_data == "S");

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cstate <= OFF;
        else begin
            case (cstate)
                OFF: if (go_cmd)
                    cstate <= AUTHORIZED;
                AUTHORIZED: if (stop_cmd) begin
                    if (rider_off) cstate <= OFF;
                    else cstate <= STOP_PENDING;
                end
                STOP_PENDING:
                    if (go_cmd) cstate <= AUTHORIZED;
                    else if (rider_off) cstate <= OFF;
                default: cstate <= OFF;
            endcase
        end
    end

    assign pwr_up = (cstate != OFF) && !rider_off;
endmodule
