extern "C" int sum_array(const int *values, int count) {
  int sum = 0;
  for (int i = 0; i < count; ++i)
    sum += values[i];
  return sum;
}

extern "C" int nested_sum(int rows, int columns) {
  int sum = 0;
  for (int i = 0; i < rows; ++i)
    for (int j = 0; j < columns; ++j)
      sum += i + j;
  return sum;
}
