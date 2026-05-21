module tb_uart_top;

    parameter SYS_CLK_FREQ = 50_000_000;
    parameter BAUD_RATE    = 9600;
    parameter WIDTH        = 8;

    localparam integer MAX_COUNT       = SYS_CLK_FREQ / (BAUD_RATE * 32);
    localparam integer SYS_CLK_HALF    = 10;
    localparam integer UART_HALF_CYC   = MAX_COUNT + 1;
    localparam integer UART_FULL_CYC   = UART_HALF_CYC * 2;
    localparam integer BIT_SYS_CLK     = 16 * UART_FULL_CYC;
    localparam integer FRAME_SYS_CLK   = 10 * BIT_SYS_CLK;
    localparam integer FRAME_WAIT_CYC  = 12 * BIT_SYS_CLK;

    reg                sys_clk;
    reg                sys_rst_l;
    reg                xmitH;
    reg  [WIDTH-1:0]   xmit_dataH;

    wire               uart_tx;
    wire               xmit_doneH;
    wire               xmit_active;
    wire [WIDTH-1:0]   rec_dataH;
    wire               rec_readyH;
    wire               rec_busy;

    reg  loopback_en;
    reg  inject_rx;
    wire uart_rx = loopback_en ? uart_tx : inject_rx;

    uart_top #(
        .SYS_CLK_FREQ (SYS_CLK_FREQ),
        .BAUD_RATE    (BAUD_RATE),
        .WIDTH        (WIDTH)
    ) dut (
        .sys_clk     (sys_clk),
        .sys_rst_l   (sys_rst_l),
        .xmitH       (xmitH),
        .xmit_dataH  (xmit_dataH),
        .uart_tx     (uart_tx),
        .xmit_doneH  (xmit_doneH),
        .xmit_active (xmit_active),
        .uart_rx     (uart_rx),
        .rec_dataH   (rec_dataH),
        .rec_readyH  (rec_readyH),
        .rec_busy    (rec_busy)
    );

    wire               ref_uart_tx;
    wire               ref_xmit_doneH;
    wire               ref_xmit_active;
    wire [WIDTH-1:0]   ref_rec_dataH;
    wire               ref_rec_readyH;
    wire               ref_rec_busy;
    wire               mm_uart_tx;
    wire               mm_xmit_doneH;
    wire               mm_xmit_active;
    wire               mm_rec_dataH;
    wire               mm_rec_readyH;
    wire               mm_rec_busy;
    wire               any_mismatch;

    uart_ref_model #(
        .SYS_CLK_FREQ  (SYS_CLK_FREQ),
        .BAUD_RATE     (BAUD_RATE),
        .WIDTH         (WIDTH)
    ) ref_model (
        .sys_clk         (sys_clk),
        .sys_rst_l       (sys_rst_l),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .uart_rx         (uart_rx),
        .ref_uart_tx     (ref_uart_tx),
        .ref_xmit_doneH  (ref_xmit_doneH),
        .ref_xmit_active (ref_xmit_active),
        .ref_rec_dataH   (ref_rec_dataH),
        .ref_rec_readyH  (ref_rec_readyH),
        .ref_rec_busy    (ref_rec_busy),
        .dut_uart_tx     (uart_tx),
        .dut_xmit_doneH  (xmit_doneH),
        .dut_xmit_active (xmit_active),
        .dut_rec_dataH   (rec_dataH),
        .dut_rec_readyH  (rec_readyH),
        .dut_rec_busy    (rec_busy),
        .mm_uart_tx      (mm_uart_tx),
        .mm_xmit_doneH   (mm_xmit_doneH),
        .mm_xmit_active  (mm_xmit_active),
        .mm_rec_dataH    (mm_rec_dataH),
        .mm_rec_readyH   (mm_rec_readyH),
        .mm_rec_busy     (mm_rec_busy),
        .any_mismatch    (any_mismatch)
    );

    initial sys_clk = 1'b0;
    always #SYS_CLK_HALF sys_clk = ~sys_clk;

    integer pass_cnt;
    integer fail_cnt;

    initial begin
        pass_cnt = 0;
        fail_cnt = 0;
    end

    always @(posedge any_mismatch) begin
        $display("[MISMATCH] @ %0t ns", $time);

        if (mm_uart_tx)
            $display("  uart_tx DUT=%b REF=%b", uart_tx, ref_uart_tx);

        if (mm_xmit_doneH)
            $display("  xmit_doneH DUT=%b REF=%b",
                     xmit_doneH, ref_xmit_doneH);

        if (mm_xmit_active)
            $display("  xmit_active DUT=%b REF=%b",
                     xmit_active, ref_xmit_active);

        if (mm_rec_dataH)
            $display("  rec_dataH DUT=0x%02X REF=0x%02X",
                     rec_dataH, ref_rec_dataH);

        if (mm_rec_readyH)
            $display("  rec_readyH DUT=%b REF=%b",
                     rec_readyH, ref_rec_readyH);

        if (mm_rec_busy)
            $display("  rec_busy DUT=%b REF=%b",
                     rec_busy, ref_rec_busy);

        fail_cnt = fail_cnt + 1;
    end

    integer frame_count;

    initial frame_count = 0;

    always @(posedge sys_clk) begin
        if (rec_readyH === 1'b1) begin
            frame_count = frame_count + 1;

            $display("[MONITOR] Frame %0d rec_dataH=0x%02X rec_busy=%b @ %0t ns",
                     frame_count, rec_dataH, rec_busy, $time);
        end
    end

    task apply_reset;
        begin
            sys_rst_l   = 1'b0;
            xmitH       = 1'b0;
            xmit_dataH  = {WIDTH{1'b0}};
            loopback_en = 1'b1;
            inject_rx   = 1'b1;

            repeat(20) @(posedge sys_clk);

            sys_rst_l = 1'b1;

            repeat(UART_HALF_CYC * 4) @(posedge sys_clk);
        end
    endtask

    task send_byte;
        input [WIDTH-1:0] data;

        begin
            xmit_dataH = data;
            xmitH      = 1'b1;

            repeat(UART_FULL_CYC * 2) @(posedge sys_clk);

            xmitH = 1'b0;
        end
    endtask

    task wait_frame;
        begin
            repeat(FRAME_WAIT_CYC) @(posedge sys_clk);
        end
    endtask

    task check;
        input [127:0] name;
        input condition;

        begin
            if (condition) begin
                $display("PASS [%s]", name);
                pass_cnt = pass_cnt + 1;
            end
            else begin
                $display("FAIL [%s]", name);
                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    task check_data;
        input [127:0] name;
        input [WIDTH-1:0] got;
        input [WIDTH-1:0] expected;

        begin
            if (got === expected) begin
                $display("PASS [%s] got=0x%02X exp=0x%02X",
                         name, got, expected);

                pass_cnt = pass_cnt + 1;
            end
            else begin
                $display("FAIL [%s] got=0x%02X exp=0x%02X",
                         name, got, expected);

                fail_cnt = fail_cnt + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_uart_top.vcd");
        $dumpvars(0, tb_uart_top);
    end

    integer i;
    reg [7:0] rand_data;

    initial begin

        $display("SYS_CLK=%0d BAUD=%0d WIDTH=%0d",
                 SYS_CLK_FREQ, BAUD_RATE, WIDTH);

        $display("MAX_COUNT=%0d UART_FULL_CYC=%0d",
                 MAX_COUNT, UART_FULL_CYC);

        $display("BIT_SYS_CLK=%0d FRAME_SYS_CLK=%0d",
                 BIT_SYS_CLK, FRAME_SYS_CLK);

       
        $display("\n--- RESET TEST ---");

        apply_reset;

        @(posedge sys_clk);

        check("uart_tx=1",      uart_tx     === 1'b1);
        check("xmit_active=0",  xmit_active === 1'b0);
        check("xmit_doneH=1",   xmit_doneH  === 1'b1);
        check("rec_busy=0",     rec_busy    === 1'b0);
        check("rec_readyH=0",   rec_readyH  === 1'b0);


        // SINGLE BYTE TEST
 

        $display("\n--- SINGLE BYTE TEST ---");

        apply_reset;

        send_byte(8'h45);

        wait_frame;

        check_data("RX 0x45", rec_dataH, 8'h45);

        // MULTIPLE PATTERN TESTS
      

        $display("\n--- MULTIPLE PATTERN TESTS ---");

        send_byte(8'h00);
        wait_frame;
        check_data("RX 0x00", rec_dataH, 8'h00);

        send_byte(8'hFF);
        wait_frame;
        check_data("RX 0xFF", rec_dataH, 8'hFF);

        send_byte(8'hAA);
        wait_frame;
        check_data("RX 0xAA", rec_dataH, 8'hAA);

        send_byte(8'h55);
        wait_frame;
        check_data("RX 0x55", rec_dataH, 8'h55);

        send_byte(8'h0F);
        wait_frame;
        check_data("RX 0x0F", rec_dataH, 8'h0F);

        send_byte(8'hF0);
        wait_frame;
        check_data("RX 0xF0", rec_dataH, 8'hF0);

        send_byte(8'h99);
        wait_frame;
        check_data("RX 0x99", rec_dataH, 8'h99);

        send_byte(8'h3C);
        wait_frame;
        check_data("RX 0x3C", rec_dataH, 8'h3C);

        send_byte(8'h7E);
        wait_frame;
        check_data("RX 0x7E", rec_dataH, 8'h7E);

        send_byte(8'h81);
        wait_frame;
        check_data("RX 0x81", rec_dataH, 8'h81);

        send_byte(8'h18);
        wait_frame;
        check_data("RX 0x18", rec_dataH, 8'h18);

        send_byte(8'h24);
        wait_frame;
        check_data("RX 0x24", rec_dataH, 8'h24);

        send_byte(8'h42);
        wait_frame;
        check_data("RX 0x42", rec_dataH, 8'h42);

        send_byte(8'hBD);
        wait_frame;
        check_data("RX 0xBD", rec_dataH, 8'hBD);

        send_byte(8'hC3);
        wait_frame;
        check_data("RX 0xC3", rec_dataH, 8'hC3);

     
        // RANDOM STRESS TEST
 

        $display("\n--- RANDOM STRESS TEST ---");

        for(i=0; i<20; i=i+1)
        begin
            rand_data = $random;

            send_byte(rand_data);

            wait_frame;

            check_data("RANDOM TEST", rec_dataH, rand_data);
        end

     

        repeat(20) @(posedge sys_clk);

        $display("\n====================================");
        $display("PASS COUNT = %0d", pass_cnt);
        $display("FAIL COUNT = %0d", fail_cnt);
        $display("====================================");

        if(fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
