module uart_tx #(
    parameter CLKS_PER_BIT = 16      // clock per satu bit (clock / baud)
)(
    input        clk,
    input        rst,                // reset sinkron, aktif high
    input        start,              // pulsa 1 clock: mulai kirim
    input  [7:0] data,               // byte yang dikirim
    output reg   tx,                 // jalur serial keluar
    output       busy                // 1 selama pengiriman berlangsung
);

    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;              // penghitung waktu satu bit
    reg [2:0]  bit_idx;              // bit data ke-berapa (0..7)
    reg [7:0]  data_reg;             // salinan data yang sedang dikirim

    always @(posedge clk) begin
        if (rst) begin
            state    <= IDLE;
            tx       <= 1'b1;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx      <= 1'b1;
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (start) begin
                        data_reg <= data;
                        state    <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;                          // start bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= DATA;
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end

                DATA: begin
                    tx <= data_reg[bit_idx];             // kirim bit ke-bit_idx
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        if (bit_idx == 3'd7) begin
                            bit_idx <= 3'd0;
                            state   <= STOP;
                        end else
                            bit_idx <= bit_idx + 3'd1;
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end

                STOP: begin
                    tx <= 1'b1;                          // stop bit
                    if (clk_cnt == CLKS_PER_BIT - 1) begin
                        clk_cnt <= 16'd0;
                        state   <= IDLE;
                    end else
                        clk_cnt <= clk_cnt + 16'd1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    assign busy = (state != IDLE);

endmodule