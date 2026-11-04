module shift_reg_4bit (
    input        clk,
    input        rst,         // reset sinkron, aktif high
    input        load,        // 1 = muat data paralel (d) ke register
    input        shift_en,    // 1 = geser satu bit per clock
    input        serial_in,   // bit serial yang masuk
    input  [3:0] d,           // data paralel masuk
    output reg [3:0] q,       // data paralel keluar
    output       serial_out   // data serial keluar (MSB)
);

    assign serial_out = q[3];

    always @(posedge clk) begin
        if (rst)
            q <= 4'b0000;
        else if (load)
            q <= d;                          // parallel load
        else if (shift_en)
            q <= {q[2:0], serial_in};        // geser ke kiri
    end

endmodule