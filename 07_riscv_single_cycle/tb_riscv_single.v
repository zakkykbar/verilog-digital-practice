`timescale 1ns/1ps

module tb_riscv_single;
    reg         clk = 0, rst = 1;
    wire [31:0] pc;

    riscv_single dut (.clk(clk), .rst(rst), .pc_out(pc));

    always #5 clk = ~clk;

    // ---- "assembler" mini: merakit instruksi dari bidang-bidangnya ----
    function [31:0] enc_r(input [6:0] f7, input [4:0] rs2, input [4:0] rs1,
                          input [2:0] f3, input [4:0] rd, input [6:0] op);
        enc_r = {f7, rs2, rs1, f3, rd, op};
    endfunction

    function [31:0] enc_i(input [11:0] imm, input [4:0] rs1,
                          input [2:0] f3, input [4:0] rd, input [6:0] op);
        enc_i = {imm, rs1, f3, rd, op};
    endfunction

    function [31:0] enc_s(input [11:0] imm, input [4:0] rs2, input [4:0] rs1,
                          input [2:0] f3, input [6:0] op);
        enc_s = {imm[11:5], rs2, rs1, f3, imm[4:0], op};
    endfunction

    function [31:0] enc_b(input [12:0] imm, input [4:0] rs2, input [4:0] rs1,
                          input [2:0] f3, input [6:0] op);
        enc_b = {imm[12], imm[10:5], rs2, rs1, f3, imm[4:1], imm[11], op};
    endfunction

    function [31:0] enc_j(input [20:0] imm, input [4:0] rd, input [6:0] op);
        enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, op};
    endfunction

    function [31:0] asm_add (input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_add = enc_r(7'b0000000, rs2, rs1, 3'b000, rd, 7'b0110011);
    endfunction
    function [31:0] asm_sub (input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_sub = enc_r(7'b0100000, rs2, rs1, 3'b000, rd, 7'b0110011);
    endfunction
    function [31:0] asm_and (input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_and = enc_r(7'b0000000, rs2, rs1, 3'b111, rd, 7'b0110011);
    endfunction
    function [31:0] asm_or  (input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_or  = enc_r(7'b0000000, rs2, rs1, 3'b110, rd, 7'b0110011);
    endfunction
    function [31:0] asm_slt (input [4:0] rd, input [4:0] rs1, input [4:0] rs2);
        asm_slt = enc_r(7'b0000000, rs2, rs1, 3'b010, rd, 7'b0110011);
    endfunction
    function [31:0] asm_addi(input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        asm_addi = enc_i(imm, rs1, 3'b000, rd, 7'b0010011);
    endfunction
    function [31:0] asm_lw  (input [4:0] rd, input [4:0] rs1, input [11:0] imm);
        asm_lw  = enc_i(imm, rs1, 3'b010, rd, 7'b0000011);
    endfunction
    function [31:0] asm_sw  (input [4:0] rs2, input [4:0] rs1, input [11:0] imm);
        asm_sw  = enc_s(imm, rs2, rs1, 3'b010, 7'b0100011);
    endfunction
    function [31:0] asm_beq (input [4:0] rs1, input [4:0] rs2, input [12:0] off);
        asm_beq = enc_b(off, rs2, rs1, 3'b000, 7'b1100011);
    endfunction
    function [31:0] asm_jal (input [4:0] rd, input [20:0] off);
        asm_jal = enc_j(off, rd, 7'b1101111);
    endfunction

    // ---- pemeriksaan ----
    integer errors = 0;
    integer i;

    task check(input [31:0] got, input [31:0] expected, input [8*8-1:0] name);
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("ERROR %0s: got=%0d (%h) expected=%0d (%h)",
                         name, got, got, expected, expected);
            end else
                $display("OK    %0s = %0d", name, got);
        end
    endtask

    // ---- jejak eksekusi ----
    always @(posedge clk)
        if (!rst) $display("pc=%0d  instr=%h", pc, dut.instr);

    initial begin
        // Program uji (alamat byte di komentar)
        dut.u_imem.mem[0]  = asm_addi(5'd1, 5'd0, 12'd5);     //  0: x1 = 5
        dut.u_imem.mem[1]  = asm_addi(5'd2, 5'd0, 12'd7);     //  4: x2 = 7
        dut.u_imem.mem[2]  = asm_add (5'd3, 5'd1, 5'd2);      //  8: x3 = 12
        dut.u_imem.mem[3]  = asm_sub (5'd4, 5'd2, 5'd1);      // 12: x4 = 2
        dut.u_imem.mem[4]  = asm_and (5'd5, 5'd1, 5'd2);      // 16: x5 = 5
        dut.u_imem.mem[5]  = asm_or  (5'd6, 5'd1, 5'd2);      // 20: x6 = 7
        dut.u_imem.mem[6]  = asm_slt (5'd7, 5'd1, 5'd2);      // 24: x7 = 1
        dut.u_imem.mem[7]  = asm_sw  (5'd3, 5'd0, 12'd0);     // 28: mem[0] = 12
        dut.u_imem.mem[8]  = asm_lw  (5'd8, 5'd0, 12'd0);     // 32: x8 = 12
        dut.u_imem.mem[9]  = asm_beq (5'd8, 5'd3, 13'd8);     // 36: x8==x3, lompat ke 44
        dut.u_imem.mem[10] = asm_addi(5'd9, 5'd0, 12'd99);    // 40: (dilewati) x9 tetap 0
        dut.u_imem.mem[11] = asm_jal (5'd10, 21'd8);          // 44: x10 = 48, lompat ke 52
        dut.u_imem.mem[12] = asm_addi(5'd11, 5'd0, 12'd77);   // 48: (dilewati) x11 tetap 0
        dut.u_imem.mem[13] = asm_addi(5'd12, 5'd0, 12'd1);    // 52: x12 = 1
        dut.u_imem.mem[14] = asm_addi(5'd13, 5'd0, 12'hFFD);  // 56: x13 = -3
        dut.u_imem.mem[15] = asm_slt (5'd14, 5'd13, 5'd1);    // 60: x14 = 1 (-3 < 5)
        dut.u_imem.mem[16] = asm_addi(5'd0, 5'd0, 12'd5);     // 64: tulis ke x0, harus diabaikan
        dut.u_imem.mem[17] = asm_beq (5'd0, 5'd0, 13'd0);     // 68: loop di tempat (berhenti)
        for (i = 18; i < 64; i = i + 1)
            dut.u_imem.mem[i] = 32'h00000013;                 // NOP (addi x0, x0, 0)

        $dumpfile("riscv_single.vcd");
        $dumpvars(0, tb_riscv_single);

        #22 rst = 0;
        repeat (30) @(posedge clk);
        #1;

        $display("---- hasil akhir ----");
        check(dut.u_rf.regs[0],  32'd0,        "x0");
        check(dut.u_rf.regs[1],  32'd5,        "x1");
        check(dut.u_rf.regs[2],  32'd7,        "x2");
        check(dut.u_rf.regs[3],  32'd12,       "x3 add");
        check(dut.u_rf.regs[4],  32'd2,        "x4 sub");
        check(dut.u_rf.regs[5],  32'd5,        "x5 and");
        check(dut.u_rf.regs[6],  32'd7,        "x6 or");
        check(dut.u_rf.regs[7],  32'd1,        "x7 slt");
        check(dut.u_rf.regs[8],  32'd12,       "x8 lw");
        check(dut.u_rf.regs[9],  32'd0,        "x9 skip");
        check(dut.u_rf.regs[10], 32'd48,       "x10 jal");
        check(dut.u_rf.regs[11], 32'd0,        "x11 skip");
        check(dut.u_rf.regs[12], 32'd1,        "x12");
        check(dut.u_rf.regs[13], 32'hFFFFFFFD, "x13 -3");
        check(dut.u_rf.regs[14], 32'd1,        "x14 slt");
        check(dut.u_dmem.mem[0], 32'd12,       "dmem[0]");
        check(pc,                32'd68,       "pc halt");

        if (errors == 0) $display("PASS: CPU menjalankan program dengan benar");
        else             $display("FAIL: %0d kesalahan", errors);
        $finish;
    end
endmodule