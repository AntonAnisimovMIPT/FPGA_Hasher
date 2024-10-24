module uart_tx (
    input wire clk,              
    input wire rst,              
    input wire [7:0] data_in,    
    input wire send,             
    output reg tx,               
    output reg busy             
);
    
    parameter CLK_FREQ = 50000000;  
    parameter BAUD_RATE = 115200;    
    parameter BAUD_TICK_COUNT = CLK_FREQ / BAUD_RATE; 

    reg [3:0] bit_index;             
    reg [15:0] tick_count;          
    reg [9:0] tx_shift;              
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1;                  // Логический уровень высокий (idle)
            busy <= 0;
            bit_index <= 0;
            tick_count <= 0;
        end else begin
            if (send && !busy) begin
                busy <= 1;           
                tx_shift <= {1'b1, data_in, 1'b0}; // Заполняем сдвиговый регистр (стартовый бит 0, 8 данных, стоповый бит 1)
                bit_index <= 0;       
                tick_count <= 0;      
            end else if (busy) begin
                if (tick_count < BAUD_TICK_COUNT - 1) begin
                    tick_count <= tick_count + 1; 
                end else begin
                    tick_count <= 0; 
                    tx <= tx_shift[0]; 
                    tx_shift <= {1'b1, tx_shift[9:1]}; // Сдвигаем биты влево
                    
                    if (bit_index < 9) begin
                        bit_index <= bit_index + 1; 
                    end else begin
                        busy <= 0; 
                    end
                end
            end
        end
    end
endmodule
