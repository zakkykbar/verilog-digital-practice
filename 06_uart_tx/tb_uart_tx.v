`timescale 1ns/1ps

module tb_uart_tx;
    localparam CLKS = 16;

    reg        clk = 0, rst = 1, start = 0;
    reg  [7:0] data = 8'h00;
    wire       tx, busy;

    uart_tx #(.CLKS_PER_BIT(CLKS)) dut (
        .clk(clk), .rst(rst), .start(start), .data(data), .tx(tx), .busy(busy)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer n;

    // Kirim satu byte, lalu terima dan periksa dari sisi penerima
    task send_and_check(input [7:0] b);
        integer i;
        reg [7:0] rx;
        begin
            @(negedge clk); data = b; start = 1;
            @(negedge clk); start = 0;
            if (busy !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR busy tidak naik untuk byte %h", b);
            end

            @(negedge tx);                              // start bit dimulai
            repeat (CLKS/2) @(posedge clk);             // ke tengah start bit
            if (tx !== 1'b0) begin
                errors = errors + 1;
                $display("ERROR start bit bukan 0 untuk byte %h", b);
            end

            for (i = 0; i < 8; i = i + 1) begin         // 8 bit data, LSB dulu
                repeat (CLKS) @(posedge clk);
                rx[i] = tx;
            end

            repeat (CLKS) @(posedge clk);               // tengah stop bit
            if (tx !== 1'b1) begin
                errors = errors + 1;
                $display("ERROR stop bit bukan 1 untuk byte %h", b);
            end

            if (rx !== b) begin
                errors = errors + 1;
                $display("ERROR kirim %h, terima %h", b, rx);
            end else
                $display("OK    kirim %h, terima %h", b, rx);

            wait (busy === 1'b0);                       // tunggu selesai
            repeat (4) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);

        #22 rst = 0;
        repeat (4) @(posedge clk);

        // jalur harus 1 saat idle
        if (tx !== 1'b1) begin
            errors = errors + 1;
            $display("ERROR jalur idle bukan 1");
        end

        send_and_check(8'h55);   // 01010101
        send_and_check(8'hA5);   // 10100101
        send_and_check(8'h00);   // semua 0
        send_and_check(8'hFF);   // semua 1
        send_and_check(8'h48);   // 'H'
        send_and_check(8'h49);   // 'I'

        for (n = 0; n < 20; n = n + 1)
            send_and_check($random & 255);

        if (errors == 0) $display("PASS: semua byte terkirim benar");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule