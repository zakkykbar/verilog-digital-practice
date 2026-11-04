module regfile_8x8 (
    input        clk,
    input        rst,        // reset sinkron, aktif high
    input        we,         // write enable
    input  [2:0] waddr,      // alamat tulis
    input  [7:0] wdata,      // data tulis
    input  [2:0] raddr1,     // alamat baca port 1
    input  [2:0] raddr2,     // alamat baca port 2
    output [7:0] rdata1,     // data baca port 1
    output [7:0] rdata2      // data baca port 2
);

    reg [7:0] regs [0:7];    // 8 register, masing-masing 8 bit
    integer i;

    // Tulis: sinkron. Register 0 tidak pernah ditulis.
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1)
                regs[i] <= 8'd0;
        end else if (we && (waddr != 3'd0)) begin
            regs[waddr] <= wdata;
        end
    end

    // Baca: kombinasional. Register 0 selalu terbaca 0.
    assign rdata1 = (raddr1 == 3'd0) ? 8'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 3'd0) ? 8'd0 : regs[raddr2];

endmodule