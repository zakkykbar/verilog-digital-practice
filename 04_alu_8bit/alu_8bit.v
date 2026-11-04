module alu_8bit (
    input  [7:0] a,
    input  [7:0] b,
    input  [2:0] op,
    output reg [7:0] result,
    output       zero,
    output       negative,
    output reg   carry,
    output reg   overflow
);

    reg [8:0] tmp;   // 9 bit untuk menampung carry / borrow

    always @(*) begin
        tmp      = 9'd0;
        result   = 8'd0;
        carry    = 1'b0;
        overflow = 1'b0;

        case (op)
            3'b000: begin  // ADD
                tmp      = {1'b0, a} + {1'b0, b};
                result   = tmp[7:0];
                carry    = tmp[8];
                overflow = (a[7] == b[7]) && (result[7] != a[7]);
            end
            3'b001: begin  // SUB
                tmp      = {1'b0, a} - {1'b0, b};
                result   = tmp[7:0];
                carry    = tmp[8];                       // 1 = borrow (a < b)
                overflow = (a[7] != b[7]) && (result[7] != a[7]);
            end
            3'b010: result = a & b;
            3'b011: result = a | b;
            3'b100: result = a ^ b;
            3'b101: result = a << b[2:0];
            3'b110: result = a >> b[2:0];
            3'b111: result = ($signed(a) < $signed(b)) ? 8'd1 : 8'd0;
            default: result = 8'd0;
        endcase
    end

    assign zero     = (result == 8'd0);
    assign negative = result[7];

endmodule