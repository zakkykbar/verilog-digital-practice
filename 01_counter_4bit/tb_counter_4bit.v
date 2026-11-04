`timescale 1ns/1ps

module tb_counter_4bit;
    reg        clk = 0;
    reg        rst = 1;
    reg        en  = 0;
    wire [3:0] count;

    counter_4bit dut (.clk(clk), .rst(rst), .en(en), .count(count));

    // clock 100 MHz: periode 10 ns
    always #5 clk = ~clk;

    // model acuan: hitungan yang seharusnya
    reg [3:0] expected;
    integer errors = 0;
    always @(posedge clk) begin
        if (rst)     expected <= 4'b0000;
        else if (en) expected <= expected + 4'b0001;
    end

    // bandingkan di tepi turun clock
    always @(negedge clk) begin
        if (count !== expected) begin
            errors = errors + 1;
            $display("ERROR t=%0t count=%0d expected=%0d", $time, count, expected);
        end
    end

    initial begin
        $dumpfile("counter_4bit.vcd");
        $dumpvars(0, tb_counter_4bit);

        #22  rst = 0;  en = 1;   // lepas reset, mulai hitung
        #200 en = 0;             // tahan (enable mati)
        #30  en = 1;             // lanjut hitung
        #200 rst = 1;            // reset di tengah jalan
        #20  rst = 0;
        #50;

        if (errors == 0) $display("PASS: semua pengecekan sesuai");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule