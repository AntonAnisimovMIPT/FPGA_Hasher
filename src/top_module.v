module top_module (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,          
    output wire uart_tx          
);

    localparam BLOCK_SIZE = 512; // Размер блока для SHA-256 (512 бит)
    localparam NUM_BYTES = BLOCK_SIZE / 8; // 64 байта для блока
    localparam DIGEST_BYTES = 32; // Размер хеша SHA-256 (256 бит = 32 байта)

    wire [7:0] uart_data;        // Данные от UART
    wire uart_data_valid;        // Данные валидны
    wire uart_tx_ready;          // UART готов к передаче
    reg send_data;               // Сигнал для отправки данных через UART
    reg [7:0] data_to_send;      // Данные для передачи через UART

    wire sha256_ready;           // SHA-256 готов
    wire [255:0] sha256_digest;  // Результат хеширования
    reg [511:0] block;           // Храним блок данных для SHA-256
    reg init_sha256;             // Сигнал для инициации хеширования
    reg next_sha256;             // Сигнал для следующего блока
    reg [5:0] byte_index;        // Индекс для передачи байтов хеша

    reg block_full;              // Флаг завершения заполнения блока


    uart_rx uart_rx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .rx(uart_rx),
        .data(uart_data),
        .data_valid(uart_data_valid)
    );


    uart_tx uart_tx_inst (
        .clk(clk),
        .reset_n(reset_n),
        .tx(uart_tx),
        .data(data_to_send),
        .data_valid(send_data),
        .tx_ready(uart_tx_ready)
    );

    sha256 sha256_inst (
        .clk(clk),
        .reset_n(reset_n),
        .cs(init_sha256),            // Начало хеширования
        .we(next_sha256),            // Следующая команда
        .address(8'h00),             // Фиксированный адрес для управления
        .write_data(block[31:0]),    // Передача 32 бит данных
        .read_data(),                // Не используем
        .error()                     // Не используем
    );


    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            init_sha256 <= 1'b0;
            next_sha256 <= 1'b0;
            block <= 512'b0;         // Инициализируем блок нулями
            byte_index <= 6'd0;      // Сброс индекса
            send_data <= 1'b0;       // Отключаем отправку данных
            block_full <= 1'b0;      // Блок не заполнен
        end else begin
            // Прием данных через UART
            if (uart_data_valid && !block_full) begin
                // Заполняем блок 8-битными данными
                block <= {block[BLOCK_SIZE-9:0], uart_data}; // Сдвигаем и добавляем новые данные
                if (&block[BLOCK_SIZE-9:0]) begin
                    block_full <= 1'b1;  // Устанавливаем флаг, когда блок заполнен
                end
            end

            // Инициация SHA-256 после заполнения блока
            if (block_full && !init_sha256) begin
                init_sha256 <= 1'b1;   // Запускаем SHA-256
            end else begin
                init_sha256 <= 1'b0;   // Отключаем сигнал после инициации
            end

            // Проверяем готовность SHA-256 и начинаем передачу результата
            if (sha256_ready && byte_index < DIGEST_BYTES) begin
                // Берём 8 бит из результата хеширования для передачи
                data_to_send <= sha256_digest[byte_index*8 +: 8]; // Выбираем 8 бит
                if (uart_tx_ready) begin
                    send_data <= 1'b1;   // Активируем сигнал отправки данных
                    byte_index <= byte_index + 1; // Переход к следующему байту
                end else begin
                    send_data <= 1'b0;   // Ожидаем, пока UART не будет готов
                end
            end else if (byte_index == DIGEST_BYTES) begin
                send_data <= 1'b0;   // Завершение передачи
                block_full <= 1'b0;  // Готовы для следующего блока данных
                byte_index <= 6'd0;  // Сбрасываем индекс для следующего блока
            end
        end
    end

endmodule
