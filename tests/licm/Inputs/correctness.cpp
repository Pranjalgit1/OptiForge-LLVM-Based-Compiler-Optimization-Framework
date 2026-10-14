#include <cstdint>
#include <cstdio>
#include <initializer_list>

extern "C" std::uint32_t loop_compute(std::int32_t N, std::uint32_t A,
                                     std::uint32_t B);
extern "C" void conditional(std::int32_t N, std::uint32_t A, bool Choose,
                            std::uint32_t *Out);

int main() {
  const std::uint32_t Values[] = {0, 1, 127, 0x80000000, 0xffffffff};
  std::uint32_t Checksum = 0;
  for (std::int32_t N : {-1, 0, 1, 2, 31}) {
    for (std::uint32_t A : Values) {
      for (std::uint32_t B : Values) {
        std::uint32_t Expected = N > 0 ? (A * B + 7U) * N : 0;
        std::uint32_t Actual = loop_compute(N, A, B);
        if (Actual != Expected)
          return 1;
        Checksum += Actual;
      }
      for (bool Choose : {false, true}) {
        std::uint32_t Out = 123;
        conditional(N, A, Choose, &Out);
        if (Out != (N > 0 && Choose ? (A ^ 7U) : 123U))
          return 2;
      }
    }
  }
  std::printf("checksum: %llu\n", static_cast<unsigned long long>(Checksum));
}
