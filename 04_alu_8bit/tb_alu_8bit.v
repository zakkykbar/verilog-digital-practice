`timescale 1ns/1ps

module tb_alu_8bit;
    reg  [7:0] a, b;
    reg  [2:0] op;
    wire [7:0] result;
    wire       zero, negative, carry, overflow;

    alu_8bit dut (.a(a), .b(b), .op(op), .result(result),
                  .zero(zero), .negative(negative),
                  .carry(carry), .overflow(overflow));

    integer ai, bi, oi;
    integer sa, sb, sres, full;
    integer errors = 0;
    reg [7:0] exp_res;
    reg       exp_c, exp_v, exp_z, exp_n;

    // Tampilkan satu kasus agar mudah dibaca
    task show(input [7:0] x, input [7:0] y, input [2:0] o);
        begin
            a = x; b = y; op = o;
            #10;
            $display("op=%0d a=%0d b=%0d -> result=%0d zero=%b neg=%b carry=%b ovf=%b",
                     op, a, b, result, zero, negative, carry, overflow);
        end
    endtask

    initial begin
        $dumpfile("alu_8bit.vcd");
        $dumpvars(0, tb_alu_8bit);

        // --- Contoh terarah (masuk ke file gelombang) ---
        show(8'd100, 8'd100, 3'b000);  // ADD: 200, overflow bertanda
        show(8'd200, 8'd100, 3'b000);  // ADD: 44, carry
        show(8'd5,   8'd10,  3'b001);  // SUB: 251, borrow, negatif
        show(8'h80,  8'h01,  3'b001);  // SUB: 127, overflow bertanda
        show(8'hF0,  8'h3C,  3'b010);  // AND
        show(8'hF0,  8'h3C,  3'b011);  // OR
        show(8'hF0,  8'h3C,  3'b100);  // XOR
        show(8'h0F,  8'd2,   3'b101);  // SLL 2
        show(8'hF0,  8'd2,   3'b110);  // SRL 2
        show(8'hFF,  8'h01,  3'b111);  // SLT: -1 < 1 -> 1
        #10;
        $dumpoff;   // jangan simpan gelombang untuk uji menyeluruh

        // --- Uji menyeluruh: semua kombinasi ---
        for (oi = 0; oi < 8; oi = oi + 1)
            for (ai = 0; ai < 256; ai = ai + 1)
                for (bi = 0; bi < 256; bi = bi + 1) begin
                    a = ai; b = bi; op = oi;
                    #1;

                    sa = (ai > 127) ? ai - 256 : ai;
                    sb = (bi > 127) ? bi - 256 : bi;
                    exp_c = 0; exp_v = 0;

                    case (oi)
                        0: begin
                            full    = ai + bi;
                            exp_res = full & 255;
                            exp_c   = (full > 255);
                            sres    = sa + sb;
                            exp_v   = (sres > 127) || (sres < -128);
                        end
                        1: begin
                            full    = ai - bi;
                            exp_res = full & 255;
                            exp_c   = (ai < bi);
                            sres    = sa - sb;
                            exp_v   = (sres > 127) || (sres < -128);
                        end
                        2: exp_res = ai & bi;
                        3: exp_res = ai | bi;
                        4: exp_res = ai ^ bi;
                        5: exp_res = (ai << (bi & 7)) & 255;
                        6: exp_res = ai >> (bi & 7);
                        7: exp_res = (sa < sb) ? 1 : 0;
                    endcase
                    exp_z = (exp_res == 0);
                    exp_n = exp_res[7];

                    if (result !== exp_res || carry !== exp_c || overflow !== exp_v ||
                        zero !== exp_z || negative !== exp_n) begin
                        errors = errors + 1;
                        if (errors <= 10)
                            $display("ERROR op=%0d a=%0d b=%0d: res=%0d(exp %0d) c=%b(%b) v=%b(%b)",
                                     oi, ai, bi, result, exp_res, carry, exp_c, overflow, exp_v);
                    end
                end

        if (errors == 0) $display("PASS: 524288 kombinasi sesuai");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule