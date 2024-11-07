module uart_top (
    input wire clk,              
    input wire rst,              
    input wire rx,               
    input wire [7:0] data_in,    
    input wire send,             
    output wire tx,              
    output wire [7:0] data_out,   
    output wire data_ready      
);
    wire busy_tx;                
    wire busy_rx;                

    uart_tx transmitter (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .send(send),
        .tx(tx),
        .busy(busy_tx)
    );

    uart_rx receiver (
        .clk(clk),
        .rst(rst),
        .rx(rx),
        .data_out(data_out),
        .data_ready(data_ready)
    );
endmodule
