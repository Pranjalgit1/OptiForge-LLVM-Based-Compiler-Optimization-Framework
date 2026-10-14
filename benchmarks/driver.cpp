#include <charconv>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

extern "C" std::uint32_t kernel(std::uint32_t *, std::uint32_t, std::uint32_t,
                                 std::uint32_t, std::uint32_t);

int main(int Argc, char **Argv) {
  if (Argc != 3)
    return 2;
  std::uint32_t Size = 0, Repetitions = 0;
  auto Parse = [](const char *Text, std::uint32_t &Value) {
    const char *End = Text + std::strlen(Text);
    auto R = std::from_chars(Text, End, Value);
    return R.ec == std::errc() && R.ptr == End && Value <= (1U << 24);
  };
  if (!Parse(Argv[1], Size) || !Parse(Argv[2], Repetitions))
    return 2;
  std::vector<std::uint32_t> Data(Size);
  std::uint32_t Seed = 0x12345678;
  for (auto &Value : Data) {
    Seed ^= Seed << 13;
    Seed ^= Seed >> 17;
    Seed ^= Seed << 5;
    Value = Seed;
  }
  auto Start = std::chrono::steady_clock::now();
  std::uint32_t Result = kernel(Data.data(), Size, Repetitions, 123456789U,
                                987654321U);
  auto Stop = std::chrono::steady_clock::now();
  auto Nanoseconds =
      std::chrono::duration_cast<std::chrono::nanoseconds>(Stop - Start).count();
  // Observe the final array outside the timed interval as well as the return.
  std::uint64_t Digest = 14695981039346656037ULL;
  for (std::uint32_t Value : Data)
    Digest = (Digest ^ Value) * 1099511628211ULL;
  std::printf("{\"elapsed_ns\":%lld,\"result\":%u,\"memory_digest\":%llu}\n",
              static_cast<long long>(Nanoseconds), Result,
              static_cast<unsigned long long>(Digest));
}
