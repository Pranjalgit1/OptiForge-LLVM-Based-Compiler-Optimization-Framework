#include <cstdint>
#include <cstdio>

extern "C" std::uint32_t compute(std::uint32_t A, std::uint32_t B,
                                 std::uint32_t *Out);

int main() {
  const std::uint32_t Values[] = {0, 1, 2, 127, 255, 65535, 0x7fffffff,
                                0x80000000, 0xfffffffe, 0xffffffff};
  std::uint32_t Checksum = 0;
  for (std::uint32_t A : Values) {
    for (std::uint32_t B : Values) {
      std::uint32_t Out = 0;
      std::uint32_t Expected = ((A + B) * 21U) ^ 7U;
      std::uint32_t Actual = compute(A, B, &Out);
      if (Actual != Expected || Out != Expected)
        return 1;
      Checksum += Actual;
    }
  }
  std::printf("checksum: %llu\n", static_cast<unsigned long long>(Checksum));
}
