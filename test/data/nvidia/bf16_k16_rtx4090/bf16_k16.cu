#include <cuda_runtime.h>

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

struct DotInput {
    uint16_t a[16];
    uint16_t b[16];
    uint32_t c;
};

__device__ uint32_t pack_pair(const uint16_t* values) {
    return uint32_t(values[0]) | (uint32_t(values[1]) << 16);
}

// One input per warp. Store D[0,0] with A in row 0 and B in column 0.
extern "C" __global__ void bf16_k16_mma(const DotInput* inputs, uint32_t* results) {
    const unsigned lane = threadIdx.x;
    const unsigned group = lane / 4;
    const unsigned k = 2 * (lane % 4);
    const DotInput& input = inputs[blockIdx.x];

    // PTX m16n8k16 fragments. A's second and fourth registers hold row 8
    // in group 0. B's two registers hold the lower/upper K halves.
    const uint32_t a_low = group == 0 ? pack_pair(input.a + k) : 0;
    const uint32_t a_high = group == 0 ? pack_pair(input.a + k + 8) : 0;
    const uint32_t b_low = group == 0 ? pack_pair(input.b + k) : 0;
    const uint32_t b_high = group == 0 ? pack_pair(input.b + k + 8) : 0;
    const uint32_t zero = 0;
    const float c = lane == 0 ? __uint_as_float(input.c) : 0.0f;
    float d00;
    [[maybe_unused]] float d01, d80, d81;
    asm volatile(
        "mma.sync.aligned.m16n8k16.row.col.f32.bf16.bf16.f32 "
        "{%0, %1, %2, %3}, {%4, %5, %6, %7}, {%8, %9}, {%10, %11, %12, %13};"
        : "=f"(d00), "=f"(d01), "=f"(d80), "=f"(d81)
        : "r"(a_low), "r"(zero), "r"(a_high), "r"(zero), "r"(b_low), "r"(b_high),
          "f"(c), "f"(0.0f), "f"(0.0f), "f"(0.0f));
    if (lane == 0) {
        results[blockIdx.x] = __float_as_uint(d00);
    }
}

void check_cuda(cudaError_t status, const char* operation) {
    if (status != cudaSuccess) {
        std::cerr << operation << ": " << cudaGetErrorString(status) << '\n';
        std::exit(EXIT_FAILURE);
    }
}

int main() {
    // Decimal ID, then 16 A and 16 B BF16 words and one C FP32 word in hex.
    std::vector<int> ids;
    std::vector<DotInput> inputs;
    int id;
    while (std::cin >> std::dec >> id) {
        DotInput input{};
        std::cin >> std::hex;
        for (auto& element : input.a) {
            std::cin >> element;
        }
        for (auto& element : input.b) {
            std::cin >> element;
        }
        if (!(std::cin >> input.c)) {
            std::cerr << "Invalid input record " << id << '\n';
            return EXIT_FAILURE;
        }
        ids.push_back(id);
        inputs.push_back(input);
    }
    if (!std::cin.eof() || inputs.empty()) {
        std::cerr << "Expected at least one complete input record\n";
        return EXIT_FAILURE;
    }

    cudaDeviceProp device{};
    check_cuda(cudaGetDeviceProperties(&device, 0), "cudaGetDeviceProperties");
    if (device.major != 8 || device.minor != 9) {
        std::cerr << "Expected an SM 8.9 device\n";
        return EXIT_FAILURE;
    }
    int driver_version;
    int runtime_version;
    check_cuda(cudaDriverGetVersion(&driver_version), "cudaDriverGetVersion");
    check_cuda(cudaRuntimeGetVersion(&runtime_version), "cudaRuntimeGetVersion");
    std::cerr << device.name << " | sm_" << device.major << device.minor
              << " | driver_api=" << driver_version << " | runtime=" << runtime_version << '\n';

    DotInput* device_inputs;
    uint32_t* device_results;
    std::vector<uint32_t> results(inputs.size());
    const auto input_bytes = inputs.size() * sizeof(DotInput);
    const auto result_bytes = results.size() * sizeof(uint32_t);
    check_cuda(cudaMalloc(&device_inputs, input_bytes), "cudaMalloc inputs");
    check_cuda(cudaMalloc(&device_results, result_bytes), "cudaMalloc results");
    check_cuda(cudaMemcpy(device_inputs, inputs.data(), input_bytes, cudaMemcpyHostToDevice),
               "copy inputs");
    bf16_k16_mma<<<inputs.size(), 32>>>(device_inputs, device_results);
    check_cuda(cudaGetLastError(), "launch bf16_k16_mma");
    check_cuda(cudaMemcpy(results.data(), device_results, result_bytes, cudaMemcpyDeviceToHost),
               "copy results");
    check_cuda(cudaFree(device_results), "cudaFree results");
    check_cuda(cudaFree(device_inputs), "cudaFree inputs");

    for (size_t index = 0; index < ids.size(); ++index) {
        std::cout << std::dec << ids[index] << ' ' << std::hex << results[index] << '\n';
    }
}
