module seq_detector_1011 (
    input  clk,
    input  rst,        // reset sinkron, aktif high
    input  din,        // bit serial masuk
    output detected    // 1 selama satu clock setelah 1011 terdeteksi
);

    localparam S0 = 3'd0,
               S1 = 3'd1,
               S2 = 3'd2,
               S3 = 3'd3,
               S4 = 3'd4;

    reg [2:0] state, next_state;

    // 1) Register state
    always @(posedge clk) begin
        if (rst) state <= S0;
        else     state <= next_state;
    end

    // 2) Logika state berikutnya
    always @(*) begin
        case (state)
            S0:      next_state = din ? S1 : S0;
            S1:      next_state = din ? S1 : S2;
            S2:      next_state = din ? S3 : S0;
            S3:      next_state = din ? S4 : S2;
            S4:      next_state = din ? S1 : S2;
            default: next_state = S0;
        endcase
    end

    // 3) Output (Moore: hanya bergantung pada state)
    assign detected = (state == S4);

endmodule