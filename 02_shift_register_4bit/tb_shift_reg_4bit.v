`timescale 1ns/1ps

module tb_shift_reg_4bit;
    reg        clk = 0, rst = 1, load = 0, shift_en = 0, serial_in = 0;
    reg  [3:0] d = 0;
    wire [3:0] q;
    wire       serial_out;

    shift_reg_4bit dut (
        .clk(clk), .rst(rst), .load(load), .shift_en(shift_en),
        .serial_in(serial_in), .d(d), .q(q), .serial_out(serial_out)
    );

    always #5 clk = ~clk;

    integer errors = 0;
    integer i;
    reg [3:0] captured;

    task check(input [3:0] got, input [3:0] expected, input [8*8-1:0] name);
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("ERROR %0s: got=%b expected=%b", name, got, expected);
            end else
                $display("OK    %0s: %b", name, got);
        end
    endtask

    // geser satu bit: atur sinyal di tepi turun, efek terjadi di tepi naik
    task shift_in(input bit_in);
        begin
            @(negedge clk); shift_en = 1; load = 0; serial_in = bit_in;
            @(negedge clk); shift_en = 0;
        end
    endtask

    // muat data paralel
    task do_load(input [3:0] val);
        begin
            @(negedge clk); load = 1; shift_en = 0; d = val;
            @(negedge clk); load = 0;
        end
    endtask

    initial begin
        $dumpfile("shift_reg_4bit.vcd");
        $dumpvars(0, tb_shift_reg_4bit);

        #22 rst = 0;

        // SIPO: masukkan 1,0,1,1 secara serial -> q harus 1011
        shift_in(1); shift_in(0); shift_in(1); shift_in(1);
        @(negedge clk);
        check(q, 4'b1011, "SIPO");

        // PIPO: muat 0110 -> q harus 0110
        do_load(4'b0110);
        check(q, 4'b0110, "PIPO");

        // PISO: muat 1010, baca serial_out sebelum tiap geseran -> 1,0,1,0
        do_load(4'b1010);
        captured = 4'b0000;
        for (i = 0; i < 4; i = i + 1) begin
            captured = {captured[2:0], serial_out};
            shift_in(1'b0);
        end
        check(captured, 4'b1010, "PISO");

        // RESET: q harus 0000
        @(negedge clk); rst = 1;
        @(negedge clk);
        check(q, 4'b0000, "RESET");
        rst = 0;

        #20;
        if (errors == 0) $display("PASS: semua pengecekan sesuai");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule