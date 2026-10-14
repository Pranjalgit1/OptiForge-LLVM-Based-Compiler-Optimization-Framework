#include <cstdint>

extern "C" std::uint32_t kernel(std::uint32_t *Data, std::uint32_t Size,
                                 std::uint32_t Repetitions, std::uint32_t A,
                                 std::uint32_t B) {
  std::uint32_t Sum = 0;
  for (std::uint32_t R = 0; R < Repetitions; ++R) {
    for (std::uint32_t I = 0; I < Size; ++I) {
      std::uint32_t Factor = A * B + 7U;
      Data[I] = (Data[I] + Factor) ^ (I & 31U);
      Sum += Data[I];
    }
  }
  return Sum;
}
