module uart_rx (
    input wire clk,             
    input wire rst,              
    input wire rx,               
    output reg [7:0] data_out,   
    output reg data_ready        
);
    
    parameter CLK_FREQ = 50000000;  
    parameter BAUD_RATE = 115200;    
    parameter BAUD_TICK_COUNT = CLK_FREQ / BAUD_RATE; 

    reg [3:0] bit_index;             
    reg [15:0] tick_count;           
    reg [9:0] rx_shift;              
    reg busy;                        

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data_out <= 0;         
            data_ready <= 0;        
            bit_index <= 0;        
            tick_count <= 0;        
            busy <= 0;              
        end else begin
            if (!busy && !rx) begin  
                busy <= 1;          
                tick_count <= 0;     
                bit_index <= 0;      
            end else if (busy) begin
                if (tick_count < BAUD_TICK_COUNT - 1) begin
                    tick_count <= tick_count + 1; 
                end else begin
                    tick_count <= 0;
                    
                    if (bit_index < 10) begin
                        rx_shift <= {rx, rx_shift[9:1]}; // Сдвигаем биты вправо
                        bit_index <= bit_index + 1; 
                    end else begin
                        data_out <= rx_shift[8:1]; // Извлекаем принятые данные
                        data_ready <= 1;        
                        busy <= 0;              
                    end
                end
            end else begin
                data_ready <= 0; 
            end
        end
    end
endmodule
