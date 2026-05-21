

module uart_ref_model #(
    parameter SYS_CLK_FREQ = 50_000_000,
    parameter BAUD_RATE    = 9600,
    parameter WIDTH        = 8
)(

    input  wire            sys_clk,
    input  wire            sys_rst_l,
    input  wire            xmitH,
    input  wire [WIDTH-1:0] xmit_dataH,
    input  wire            uart_rx,

    output reg             ref_uart_tx,
    output reg             ref_xmit_doneH,
    output reg             ref_xmit_active,
    output reg  [WIDTH-1:0] ref_rec_dataH,
    output reg             ref_rec_readyH,
    output reg             ref_rec_busy,

    input  wire            dut_uart_tx,
    input  wire            dut_xmit_doneH,
    input  wire            dut_xmit_active,
    input  wire [WIDTH-1:0] dut_rec_dataH,
    input  wire            dut_rec_readyH,
    input  wire            dut_rec_busy,

    output wire            mm_uart_tx,
    output wire            mm_xmit_doneH,
    output wire            mm_xmit_active,
    output wire            mm_rec_dataH,
    output wire            mm_rec_readyH,
    output wire            mm_rec_busy,
    output wire            any_mismatch
);

    localparam integer MAX_COUNT = SYS_CLK_FREQ / (BAUD_RATE * 32);

    reg [$clog2(MAX_COUNT):0] ref_count;
    reg                       ref_uart_clk;

    always @(posedge sys_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            ref_count    <= 0;
            ref_uart_clk <= 0;
        end else if (ref_count < MAX_COUNT) begin
            ref_count <= ref_count + 1;
        end else begin
            ref_count    <= 0;
            ref_uart_clk <= ~ref_uart_clk;
        end
    end

    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;
    localparam BIT_CLKS = 16;

    reg [1:0]          tx_state;
    reg [3:0]          tx_clk_count;
    reg [2:0]          tx_bit_index;
    reg [WIDTH-1:0]    tx_data;

    always @(posedge ref_uart_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            tx_state         <= TX_IDLE;
            tx_clk_count     <= 0;
            tx_bit_index     <= 0;
            tx_data          <= 0;
            ref_uart_tx      <= 1'b1;
            ref_xmit_doneH   <= 1'b1;
            ref_xmit_active  <= 1'b0;
        end else begin
            case (tx_state)

                TX_IDLE: begin
                    ref_uart_tx     <= 1'b1;
                    tx_bit_index    <= 0;
                    ref_xmit_active <= 1'b0;
                    tx_clk_count    <= 0;
                    ref_xmit_doneH  <= 1'b1;
                    if (xmitH) begin
                        tx_data          <= xmit_dataH;
                        ref_xmit_active  <= 1'b1;
                        ref_xmit_doneH   <= 1'b0;
                        tx_state         <= TX_START;
                    end
                end

                TX_START: begin
                    ref_uart_tx <= 1'b0;
                    if (tx_clk_count < BIT_CLKS - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        tx_state     <= TX_DATA;
                    end
                end

                TX_DATA: begin
                    ref_uart_tx <= tx_data[tx_bit_index];
                    if (tx_clk_count < BIT_CLKS - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count <= 0;
                        if (tx_bit_index < WIDTH - 1) begin
                            tx_bit_index <= tx_bit_index + 1;
                        end else begin
                            tx_bit_index <= 0;
                            tx_state     <= TX_STOP;
                        end
                    end
                end

                TX_STOP: begin
                    ref_uart_tx <= 1'b1;
                    if (tx_clk_count < BIT_CLKS - 1) begin
                        tx_clk_count <= tx_clk_count + 1;
                    end else begin
                        tx_clk_count    <= 0;
                        ref_xmit_active <= 1'b0;
                        ref_xmit_doneH  <= 1'b1;
                        if (xmitH) begin
                            tx_data          <= xmit_dataH;
                            tx_bit_index     <= 0;
                            ref_xmit_active  <= 1'b1;
                            tx_state         <= TX_START;
                        end else begin
                            tx_state <= TX_IDLE;
                        end
                    end
                end

                default: begin
                    tx_state        <= TX_IDLE;
                    ref_uart_tx     <= 1'b1;
                    tx_clk_count    <= 0;
                    tx_bit_index    <= 0;
                    ref_xmit_doneH  <= 1'b1;
                    ref_xmit_active <= 1'b0;
                end
            endcase
        end
    end

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;
    localparam MID_PT   = (BIT_CLKS / 2) - 1;

    reg        rx_sync0, rx_sync1;
    reg [1:0]  rx_state;
    reg [3:0]  rx_clk_count;
    reg [WIDTH-1:0] rx_data;
    reg [2:0]  rx_bit_index;

    always @(posedge ref_uart_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rx_sync0 <= 1'b1;
            rx_sync1 <= 1'b1;
        end else begin
            rx_sync0 <= uart_rx;
            rx_sync1 <= rx_sync0;
        end
    end

    always @(posedge ref_uart_clk or negedge sys_rst_l) begin
        if (!sys_rst_l) begin
            rx_state       <= RX_IDLE;
            rx_clk_count   <= 0;
            rx_bit_index   <= 0;
            rx_data        <= 0;
            ref_rec_dataH  <= 0;
            ref_rec_busy   <= 1'b0;
            ref_rec_readyH <= 1'b0;
        end else begin
            ref_rec_readyH <= 1'b0;

            case (rx_state)

                RX_IDLE: begin
                    rx_clk_count <= 0;
                    rx_bit_index <= 0;
                    ref_rec_busy <= 1'b0;
                    if (rx_sync1 == 1'b0) begin
                        ref_rec_busy <= 1'b1;
                        rx_state     <= RX_START;
                    end
                end

                RX_START: begin
                    if (rx_clk_count < MID_PT) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 0;
                        if (rx_sync1 == 1'b0) begin
                            rx_state <= RX_DATA;
                        end else begin
                            rx_state <= RX_IDLE;
                        end
                    end
                end

                RX_DATA: begin
                    if (rx_clk_count < BIT_CLKS - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count              <= 0;
                        rx_data[rx_bit_index]     <= rx_sync1;
                        if (rx_bit_index < WIDTH - 1) begin
                            rx_bit_index <= rx_bit_index + 1;
                        end else begin
                            rx_bit_index <= 0;
                            rx_state     <= RX_STOP;
                        end
                    end
                end

                RX_STOP: begin
                    if (rx_clk_count < BIT_CLKS - 1) begin
                        rx_clk_count <= rx_clk_count + 1;
                    end else begin
                        rx_clk_count <= 0;
                        if (rx_sync1 == 1'b1) begin
                            ref_rec_dataH  <= rx_data;
                            ref_rec_readyH <= 1'b1;
                            ref_rec_busy   <= 1'b0;
                        end
                        rx_state <= RX_IDLE;
                    end
                end

                default: begin
                    rx_state       <= RX_IDLE;
                    rx_clk_count   <= 0;
                    rx_bit_index   <= 0;
                    ref_rec_readyH <= 1'b0;
                    ref_rec_busy   <= 1'b0;
                end
            endcase
        end
    end

    assign mm_uart_tx     = (dut_uart_tx     !== ref_uart_tx);
    assign mm_xmit_doneH  = (dut_xmit_doneH  !== ref_xmit_doneH);
    assign mm_xmit_active = (dut_xmit_active  !== ref_xmit_active);
    assign mm_rec_dataH   = (dut_rec_dataH    !== ref_rec_dataH);
    assign mm_rec_readyH  = (dut_rec_readyH   !== ref_rec_readyH);
    assign mm_rec_busy    = (dut_rec_busy     !== ref_rec_busy);

    assign any_mismatch = mm_uart_tx | mm_xmit_doneH | mm_xmit_active |
                          mm_rec_dataH | mm_rec_readyH | mm_rec_busy;

endmodule
