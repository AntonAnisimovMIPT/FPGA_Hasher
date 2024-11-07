module FPGA_Hasher (
    input wire clk,              // Clock signal
    input wire reset_n,          // Asynchronous reset, active low
    input wire rx,               // UART receive line
    output wire tx               // UART transmit line
);

    // Параметры
    localparam IDLE         = 2'b00;
    localparam RECEIVING    = 2'b01;
    localparam HASHING      = 2'b10;
    localparam SENDING      = 2'b11;
    
    // Состояния FSM
    reg [1:0] state, next_state;

    // UART Signals
    wire [7:0] rx_data;
    wire rx_data_valid;
    reg [7:0] tx_data;
    reg send_data;
    wire tx_ready;

    // SHA256 Signals
    reg sha_cs;
    reg sha_we;
    reg [7:0] sha_address;
    reg [31:0] sha_write_data;
    wire [31:0] sha_read_data;
    wire sha_error;

    // Входной буфер для данных
    reg [31:0] input_buffer [0:15];
    reg [3:0] input_word_count;
    
    // Выходной буфер для хэша
    reg [255:0] hash_output;
    reg [3:0] hash_word_count;

    // Модули UART RX и TX
    uart_rx uart_rx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .rx(rx),
        .data_out(rx_data),
        .data_valid(rx_data_valid)
    );

    uart_tx uart_tx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .data_in(tx_data),
        .send(send_data),
        .tx(tx),
        .tx_ready(tx_ready)
    );

    // SHA-256 module instance
    sha256 sha_inst (
        .clk(clk),
        .reset_n(reset_n),
        .cs(sha_cs),
        .we(sha_we),
        .address(sha_address),
        .write_data(sha_write_data),
        .read_data(sha_read_data),
        .error(sha_error)
    );

    // Основная FSM
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            input_word_count <= 0;
            hash_word_count <= 0;
            send_data <= 0;
            sha_cs <= 0;
            sha_we <= 0;
        end else begin
            state <= next_state;
            
            // Обработка данных в зависимости от состояния
            case (state)
                IDLE: begin
                    if (rx_data_valid) begin
                        input_buffer[input_word_count] <= {input_buffer[input_word_count][23:0], rx_data};
                        input_word_count <= input_word_count + 1;
                        if (input_word_count == 15) begin
                            next_state <= HASHING;
                            sha_cs <= 1;
                            sha_we <= 1;
                            sha_address <= 8'h10;  // Начинаем с ADDR_BLOCK0
                        end else begin
                            next_state <= RECEIVING;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                RECEIVING: begin
                    // Сборка данных из UART
                    if (rx_data_valid) begin
                        input_buffer[input_word_count] <= {input_buffer[input_word_count][23:0], rx_data};
                        input_word_count <= input_word_count + 1;
                        if (input_word_count == 15) begin
                            next_state <= HASHING;
                            sha_cs <= 1;
                            sha_we <= 1;
                            sha_address <= 8'h10;  // Начинаем с ADDR_BLOCK0
                        end else begin
                            next_state <= RECEIVING;
                        end
                    end
                end

                HASHING: begin
                    // Передача блока в SHA-256
                    if (sha_ready) begin
                        sha_write_data <= input_buffer[sha_address[3:0]];
                        sha_address <= sha_address + 1;
                        if (sha_address == 8'h1f) begin
                            sha_we <= 0;
                            sha_cs <= 0;
                            next_state <= SENDING;
                        end
                    end
                end

                SENDING: begin
                    // Передача хэша через UART
                    if (sha_digest_valid) begin
                        hash_output <= sha_read_data;
                        tx_data <= hash_output[255:248];
                        send_data <= 1;
                        hash_output <= {hash_output[247:0], 8'h00};
                        if (tx_ready) begin
                            send_data <= 0;
                            hash_word_count <= hash_word_count + 1;
                            if (hash_word_count == 31) begin
                                next_state <= IDLE;
                                input_word_count <= 0;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
