module uart_tx (
    input wire clk,
    input wire reset_n,
    input wire [7:0] data_in,
    input wire send,
    output reg tx,
    output reg tx_ready
);
    parameter BAUD_RATE = 9600;
    parameter CLOCK_FREQ = 50000000;  // FPGA clock frequency
    localparam TICKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;

    reg [15:0] tick_counter = 0;
    reg [3:0] bit_index = 0;
    reg [9:0] tx_buffer;
    reg transmitting = 0;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx <= 1;
            tx_ready <= 1;
            transmitting <= 0;
            tick_counter <= 0;
        end else begin
            if (send && tx_ready) begin
                tx_ready <= 0;
                transmitting <= 1;
                tick_counter <= 0;
                bit_index <= 0;
                tx_buffer <= {1'b1, data_in, 1'b0}; // Stop bit + data + Start bit
                tx <= 0; // Start bit
            end else if (transmitting) begin
                if (tick_counter == TICKS_PER_BIT) begin
                    tick_counter <= 0;
                    bit_index <= bit_index + 1;
                    if (bit_index < 10) begin
                        tx <= tx_buffer[bit_index];
                    end else begin
                        tx_ready <= 1;
                        transmitting <= 0;
                        tx <= 1;
                    end
                end else begin
                    tick_counter <= tick_counter + 1;
                end
            end
        end
    end
endmodule
