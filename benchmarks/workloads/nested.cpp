#include <cstdint>

extern "C" std::uint32_t kernel(std::uint32_t *Data, std::uint32_t Size,
                                 std::uint32_t Repetitions, std::uint32_t A,
                                 std::uint32_t B) {
  std::uint32_t Sum = 0;
  for (std::uint32_t R = 0; R < Repetitions; ++R)
    for (std::uint32_t Row = 0; Row < Size; Row += 16)
      for (std::uint32_t Col = 0; Col < 16 && Row + Col < Size; ++Col) {
        std::uint32_t Factor = (A * B) ^ 31U;
        Data[Row + Col] += Factor + Row + Col;
        Sum = (Sum + Data[Row + Col]) ^ (Sum >> 1);
      }
  return Sum;
}
