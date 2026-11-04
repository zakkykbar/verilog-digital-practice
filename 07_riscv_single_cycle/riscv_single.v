// ============ ALU 32 bit ============
module riscv_alu (
    input  [31:0] a,
    input  [31:0] b,
    input  [2:0]  ctrl,          // 0 add, 1 sub, 2 and, 3 or, 4 slt
    output reg [31:0] y,
    output        zero
);
    always @(*) begin
        case (ctrl)
            3'd0:    y = a + b;
            3'd1:    y = a - b;
            3'd2:    y = a & b;
            3'd3:    y = a | b;
            3'd4:    y = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: y = 32'd0;
        endcase
    end
    assign zero = (y == 32'd0);
endmodule

// ============ Register file 32 x 32 bit (x0 selalu 0) ============
module riscv_regfile (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  ra1,
    input  [4:0]  ra2,
    input  [4:0]  wa,
    input  [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);
    reg [31:0] regs [0:31];
    integer i;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && (wa != 5'd0)) begin
            regs[wa] <= wd;
        end
    end

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : regs[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : regs[ra2];
endmodule

// ============ Pembangkit immediate ============
module riscv_imm_gen (
    input  [31:0] instr,
    input  [1:0]  sel,           // 0 = I, 1 = S, 2 = B, 3 = J
    output reg [31:0] imm
);
    always @(*) begin
        case (sel)
            2'd0: imm = {{20{instr[31]}}, instr[31:20]};
            2'd1: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            2'd2: imm = {{19{instr[31]}}, instr[31], instr[7],
                         instr[30:25], instr[11:8], 1'b0};
            2'd3: imm = {{11{instr[31]}}, instr[31], instr[19:12],
                         instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end
endmodule

// ============ Control unit ============
module riscv_control (
    input  [6:0] opcode,
    input  [2:0] funct3,
    input        funct7_5,       // bit 30 instruksi (membedakan add dan sub)
    output reg       reg_write,
    output reg       alu_src,    // 0 = rs2, 1 = immediate
    output reg       mem_write,
    output reg       branch,
    output reg       jump,
    output reg [1:0] wb_sel,     // 0 = ALU, 1 = memori, 2 = PC+4
    output reg [1:0] imm_sel,
    output reg [2:0] alu_ctrl
);
    always @(*) begin
        // nilai awal (aman)
        reg_write = 1'b0;
        alu_src   = 1'b0;
        mem_write = 1'b0;
        branch    = 1'b0;
        jump      = 1'b0;
        wb_sel    = 2'd0;
        imm_sel   = 2'd0;
        alu_ctrl  = 3'd0;

        case (opcode)
            7'b0110011: begin                    // R-type
                reg_write = 1'b1;
                case (funct3)
                    3'b000:  alu_ctrl = funct7_5 ? 3'd1 : 3'd0;  // sub / add
                    3'b111:  alu_ctrl = 3'd2;                    // and
                    3'b110:  alu_ctrl = 3'd3;                    // or
                    3'b010:  alu_ctrl = 3'd4;                    // slt
                    default: alu_ctrl = 3'd0;
                endcase
            end
            7'b0010011: begin                    // addi
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 3'd0;
            end
            7'b0000011: begin                    // lw
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_ctrl  = 3'd0;
                wb_sel    = 2'd1;
            end
            7'b0100011: begin                    // sw
                alu_src   = 1'b1;
                mem_write = 1'b1;
                alu_ctrl  = 3'd0;
                imm_sel   = 2'd1;
            end
            7'b1100011: begin                    // beq
                branch    = 1'b1;
                alu_ctrl  = 3'd1;                // kurangkan, lihat flag zero
                imm_sel   = 2'd2;
            end
            7'b1101111: begin                    // jal
                reg_write = 1'b1;
                jump      = 1'b1;
                wb_sel    = 2'd2;
                imm_sel   = 2'd3;
            end
            default: ;
        endcase
    end
endmodule

// ============ Memori instruksi (64 kata) ============
module riscv_imem (
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem [0:63];
    assign instr = mem[addr[7:2]];
endmodule

// ============ Memori data (64 kata) ============
module riscv_dmem (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] wdata,
    output [31:0] rdata
);
    reg [31:0] mem [0:63];
    integer i;
    initial begin
        for (i = 0; i < 64; i = i + 1)
            mem[i] = 32'd0;
    end
    always @(posedge clk)
        if (we) mem[addr[7:2]] <= wdata;
    assign rdata = mem[addr[7:2]];
endmodule

// ============ CPU puncak ============
module riscv_single (
    input         clk,
    input         rst,
    output [31:0] pc_out
);
    reg  [31:0] pc;
    wire [31:0] instr, imm, rd1, rd2, alu_b, alu_y, dmem_rd;
    wire [31:0] pc_plus4, pc_target, pc_next, wb_data;
    wire        reg_write, alu_src, mem_write, branch, jump, zero;
    wire [1:0]  wb_sel, imm_sel;
    wire [2:0]  alu_ctrl;

    assign pc_out = pc;

    riscv_imem u_imem (.addr(pc), .instr(instr));

    riscv_control u_ctrl (
        .opcode(instr[6:0]), .funct3(instr[14:12]), .funct7_5(instr[30]),
        .reg_write(reg_write), .alu_src(alu_src), .mem_write(mem_write),
        .branch(branch), .jump(jump), .wb_sel(wb_sel),
        .imm_sel(imm_sel), .alu_ctrl(alu_ctrl)
    );

    riscv_imm_gen u_imm (.instr(instr), .sel(imm_sel), .imm(imm));

    riscv_regfile u_rf (
        .clk(clk), .rst(rst), .we(reg_write),
        .ra1(instr[19:15]), .ra2(instr[24:20]), .wa(instr[11:7]),
        .wd(wb_data), .rd1(rd1), .rd2(rd2)
    );

    assign alu_b = alu_src ? imm : rd2;

    riscv_alu u_alu (.a(rd1), .b(alu_b), .ctrl(alu_ctrl), .y(alu_y), .zero(zero));

    riscv_dmem u_dmem (
        .clk(clk), .we(mem_write), .addr(alu_y), .wdata(rd2), .rdata(dmem_rd)
    );

    assign wb_data   = (wb_sel == 2'd0) ? alu_y :
                       (wb_sel == 2'd1) ? dmem_rd : pc_plus4;

    assign pc_plus4  = pc + 32'd4;
    assign pc_target = pc + imm;
    assign pc_next   = (jump | (branch & zero)) ? pc_target : pc_plus4;

    always @(posedge clk) begin
        if (rst) pc <= 32'd0;
        else     pc <= pc_next;
    end
endmodule