module uart_rx (
    input wire clk,
    input wire reset_n,
    input wire rx,
    output reg [7:0] data_out,
    output reg data_valid
);
    // UART RX Parameters
    parameter BAUD_RATE = 9600;
    parameter CLOCK_FREQ = 50000000;  // FPGA clock frequency
    localparam TICKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;
    
    reg [15:0] tick_counter = 0;
    reg [3:0] bit_index = 0;
    reg receiving = 0;
    reg [7:0] rx_buffer;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            data_valid <= 0;
            tick_counter <= 0;
            bit_index <= 0;
            receiving <= 0;
        end else begin
            if (!receiving && !rx) begin
                // Start bit detected
                receiving <= 1;
                tick_counter <= TICKS_PER_BIT / 2;
                bit_index <= 0;
            end else if (receiving) begin
                if (tick_counter == TICKS_PER_BIT) begin
                    tick_counter <= 0;
                    if (bit_index < 8) begin
                        // Receiving data bits
                        rx_buffer[bit_index] <= rx;
                        bit_index <= bit_index + 1;
                    end else begin
                        // Stop bit received
                        receiving <= 0;
                        data_out <= rx_buffer;
                        data_valid <= 1;
                    end
                end else begin
                    tick_counter <= tick_counter + 1;
                    data_valid <= 0;
                end
            end else begin
                data_valid <= 0;
            end
        end
    end
endmodule
