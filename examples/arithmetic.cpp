// C linkage keeps function names readable in the IR report.
extern "C" int arithmetic(int x, int y) {
  int sum = x + y;
  int scaled = sum * 3;
  return scaled - 1;
}

extern "C" int choose(int x) {
  if (x > 0)
    return x + 1;
  return x - 1;
}
