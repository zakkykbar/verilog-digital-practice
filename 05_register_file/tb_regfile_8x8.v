`timescale 1ns/1ps

module tb_regfile_8x8;
    reg        clk = 0, rst = 1, we = 0;
    reg  [2:0] waddr = 0, raddr1 = 0, raddr2 = 0;
    reg  [7:0] wdata = 0;
    wire [7:0] rdata1, rdata2;

    regfile_8x8 dut (
        .clk(clk), .rst(rst), .we(we), .waddr(waddr), .wdata(wdata),
        .raddr1(raddr1), .raddr2(raddr2), .rdata1(rdata1), .rdata2(rdata2)
    );

    always #5 clk = ~clk;

    reg [7:0] model [0:7];     // model acuan
    integer errors = 0;
    integer n;

    // Baca semua alamat lewat kedua port dan bandingkan dengan model
    task check_all(input [8*16-1:0] name);
        integer k;
        begin
            for (k = 0; k < 8; k = k + 1) begin
                raddr1 = k;
                raddr2 = 7 - k;
                #1;
                if (rdata1 !== model[k]) begin
                    errors = errors + 1;
                    $display("ERROR %0s port1 addr=%0d got=%h exp=%h",
                             name, k, rdata1, model[k]);
                end
                if (rdata2 !== model[7-k]) begin
                    errors = errors + 1;
                    $display("ERROR %0s port2 addr=%0d got=%h exp=%h",
                             name, 7-k, rdata2, model[7-k]);
                end
            end
            $display("checked %0s", name);
        end
    endtask

    // Tulis satu register (diatur di tepi turun, masuk di tepi naik)
    task write_reg(input [2:0] addr, input [7:0] data);
        begin
            @(negedge clk); we = 1; waddr = addr; wdata = data;
            @(negedge clk); we = 0;
            if (addr != 3'd0) model[addr] = data;
        end
    endtask

    task do_reset;
        integer k;
        begin
            @(negedge clk); rst = 1;
            @(negedge clk); rst = 0;
            for (k = 0; k < 8; k = k + 1) model[k] = 8'd0;
        end
    endtask

    initial begin
        $dumpfile("regfile_8x8.vcd");
        $dumpvars(0, tb_regfile_8x8);

        // 1) Reset: semua register bernilai 0
        do_reset;
        check_all("after reset");

        // 2) Tulis nilai berbeda ke register 1..7
        write_reg(3'd1, 8'h11);
        write_reg(3'd2, 8'h22);
        write_reg(3'd3, 8'h33);
        write_reg(3'd4, 8'h44);
        write_reg(3'd5, 8'h55);
        write_reg(3'd6, 8'h66);
        write_reg(3'd7, 8'h77);
        check_all("write 1..7");

        // 3) Menulis ke register 0 harus diabaikan
        write_reg(3'd0, 8'hFF);
        check_all("write to x0");

        // 4) Baca saat menulis: nilai lama dulu, nilai baru setelah clock
        @(negedge clk);
        we = 1; waddr = 3'd3; wdata = 8'hAA; raddr1 = 3'd3;
        #1;
        if (rdata1 !== 8'h33) begin
            errors = errors + 1;
            $display("ERROR read-during-write: got=%h exp=33", rdata1);
        end else
            $display("OK read-during-write: still old value %h", rdata1);
        @(negedge clk);
        we = 0; model[3] = 8'hAA;
        #1;
        if (rdata1 !== 8'hAA) begin
            errors = errors + 1;
            $display("ERROR after clock: got=%h exp=AA", rdata1);
        end else
            $display("OK after clock: new value %h", rdata1);

        // 5) Uji acak: 200 penulisan acak, lalu bandingkan dengan model
        for (n = 0; n < 200; n = n + 1) begin
            write_reg($random & 7, $random & 255);
            check_all("random");
        end

        // 6) Reset di tengah jalan: semua kembali 0
        do_reset;
        check_all("second reset");

        if (errors == 0) $display("PASS: semua pengecekan sesuai");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule