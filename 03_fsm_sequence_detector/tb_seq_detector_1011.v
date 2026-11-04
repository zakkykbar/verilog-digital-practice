`timescale 1ns/1ps

module tb_seq_detector_1011;
    reg  clk = 0, rst = 1, din = 0;
    wire detected;

    seq_detector_1011 dut (.clk(clk), .rst(rst), .din(din), .detected(detected));

    always #5 clk = ~clk;

    // Model acuan: simpan 4 bit terakhir yang dibaca (seperti shift register proyek 2)
    reg [3:0] hist;
    reg       started = 0;
    always @(posedge clk) begin
        started <= 1;
        if (rst) hist <= 4'b0000;
        else     hist <= {hist[2:0], din};
    end
    wire expected = (hist == 4'b1011);

    integer errors = 0, hits = 0, i;

    // Bandingkan di tepi turun clock
    always @(negedge clk) begin
        if (started) begin
            if (detected !== expected) begin
                errors = errors + 1;
                $display("ERROR t=%0t detected=%b expected=%b hist=%b",
                         $time, detected, expected, hist);
            end
            if (detected === 1'b1) hits = hits + 1;
        end
    end

    // Kirim satu bit: atur di tepi turun, dibaca di tepi naik berikutnya
    task send_bit(input b);
        begin
            @(negedge clk);
            din = b;
        end
    endtask

    initial begin
        $dumpfile("seq_detector_1011.vcd");
        $dumpvars(0, tb_seq_detector_1011);

        #22 rst = 0;

        // 1) Uji terarah: 1011011 -> terdeteksi 2 kali (tumpang tindih)
        send_bit(1); send_bit(0); send_bit(1); send_bit(1);
        send_bit(0); send_bit(1); send_bit(1);
        send_bit(0); send_bit(0); send_bit(0);   // beri waktu keluaran muncul
        if (hits !== 2) begin
            errors = errors + 1;
            $display("ERROR: deteksi terarah = %0d, seharusnya 2", hits);
        end

        // 2) Reset di tengah pola: 1,0,1 lalu reset, lalu 1 -> tidak boleh terdeteksi
        send_bit(1); send_bit(0); send_bit(1);
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        send_bit(1); send_bit(0); send_bit(0); send_bit(0);

        // 3) Uji acak: 200 bit, dibandingkan dengan model acuan
        for (i = 0; i < 200; i = i + 1)
            send_bit($random & 1);

        @(negedge clk); @(negedge clk);
        $display("Total deteksi: %0d", hits);
        if (errors == 0) $display("PASS: semua pengecekan sesuai");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule