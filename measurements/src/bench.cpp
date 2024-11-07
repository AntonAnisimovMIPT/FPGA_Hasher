#include <iostream>
#include <iomanip>
#include <sstream>
#include <fstream>
#include <string>
#include <vector>
#include <boost/asio.hpp>
#include <boost/program_options.hpp>
#include <openssl/evp.h>
#include <openssl/err.h>

namespace po = boost::program_options;
namespace asio = boost::asio;

std::string sha256_hash(const std::string& data) {
    unsigned char hash[EVP_MAX_MD_SIZE];  // Максимальный размер хеша
    unsigned int hash_length = 0;          // Переменная для хранения длины хеша
    EVP_MD_CTX* mdctx = EVP_MD_CTX_new();

    if (mdctx == nullptr) {
        throw std::runtime_error("Failed to create EVP_MD_CTX");
    }

    // Инициализация контекста для хеширования
    if (EVP_DigestInit_ex(mdctx, EVP_sha256(), nullptr) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw std::runtime_error("Failed to initialize digest context");
    }

    // Обновление контекста с данными
    if (EVP_DigestUpdate(mdctx, data.c_str(), data.size()) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw std::runtime_error("Failed to update digest");
    }

    // Финализация хеширования
    if (EVP_DigestFinal_ex(mdctx, hash, &hash_length) != 1) {
        EVP_MD_CTX_free(mdctx);
        throw std::runtime_error("Failed to finalize digest");
    }

    // Освобождение контекста
    EVP_MD_CTX_free(mdctx);

    // Преобразование хеша в строку
    std::stringstream ss;
    for (unsigned int i = 0; i < hash_length; ++i) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
    }
    return ss.str();
}

std::vector<std::string> read_strings_from_file(const std::string& filename) {
    std::vector<std::string> strings;
    std::ifstream file(filename);
    std::string line;

    if (!file.is_open()) {
        throw std::runtime_error("Could not open the file: " + filename);
    }

    while (std::getline(file, line)) {
        strings.push_back(line);
    }

    file.close();
    return strings;
}

int main(int argc, char* argv[]) {

    po::options_description desc("Allowed options");
    desc.add_options()
        ("help", "Display help message")
        ("file", po::value<std::string>(), "Input file containing strings")
        ("port", po::value<std::string>()->default_value("COM3"), "COM port to use (default: COM3)");

    po::variables_map vm;
    po::store(boost::program_options::parse_command_line(argc, argv, desc), vm);
    po::notify(vm);

    if (vm.count("help") || !vm.count("file")) {
        std::cout << desc << std::endl;
        return 1;
    }

    auto filename = vm["file"].as<std::string>();
    auto port = vm["port"].as<std::string>();

    asio::io_service io;
    asio::serial_port serial(io, port);  

    serial.set_option(asio::serial_port_base::baud_rate(115200));
    serial.set_option(asio::serial_port_base::character_size(8));
    serial.set_option(asio::serial_port_base::stop_bits(asio::serial_port_base::stop_bits::one));
    serial.set_option(asio::serial_port_base::parity(asio::serial_port_base::parity::none));
    serial.set_option(asio::serial_port_base::flow_control(asio::serial_port_base::flow_control::hardware));

    std::vector<std::string> tests_strings;
    try {
        tests_strings = read_strings_from_file(filename);
    } catch (const std::runtime_error& e) {
        std::cerr << "Error reading messages: " << e.what() << std::endl;
        return 1;
    }

    // todo: добавить таймер для бэнчмаркинга
    for (const auto& unit_data : tests_strings) {

        std::cout << "Calculating the Hash value for a string: " << unit_data << std::endl;

        // Вычисление SHA-256 на стороне C++
        auto expected_hash = sha256_hash(unit_data);
        std::cout << "Expected Hash (C++): " << expected_hash << std::endl;

        // Отправка сообщения на FPGA
        asio::write(serial, asio::buffer(unit_data + "\n"));

        // Чтение хеша от FPGA
        char received_data[128] = {0};
        asio::read(serial, asio::buffer(received_data, 128));

        std::string received_hash(received_data);
        std::cout << "Received Hash (FPGA): " << received_hash << std::endl;

        if (received_hash == expected_hash) {
            std::cout << "Hashes match. FPGA SHA-256 implementation is correct." << std::endl;
        } else {
            std::cout << "Hash mismatch! FPGA SHA-256 implementation needs verification." << std::endl;
        }
        std::cout << "----------------------------------------" << std::endl;
    }

    return 0;
}