module counter_4bit (
    input        clk,    // clock
    input        rst,    // reset (sinkron, aktif high)
    input        en,     // enable: counter hanya naik saat en = 1
    output reg [3:0] count
);

    always @(posedge clk) begin
        if (rst)
            count <= 4'b0000;
        else if (en)
            count <= count + 4'b0001;
    end

endmodule