// c_arith.c - single-core C compiler test: functions, recursion, local arrays,
// pointer passing, for/while loops, arithmetic, comparisons, and control flow.
// Returns 0 on success (the testbench reports PASS); any non-zero return encodes
// the failing check.

int fib(int n) {
    if (n < 2) return n;
    return fib(n - 1) + fib(n - 2);
}

int gcd(int a, int b) {
    if (b == 0) return a;
    return gcd(b, a % b);
}

int sum_array(int *arr, int n) {
    int s = 0;
    int i;
    for (i = 0; i < n; i = i + 1) {
        s += arr[i];
    }
    return s;
}

void reverse_array(int *arr, int n) {
    int i;
    int tmp;
    for (i = 0; i < n / 2; i = i + 1) {
        tmp = arr[i];
        arr[i] = arr[n - 1 - i];
        arr[n - 1 - i] = tmp;
    }
}

int sum_squares(void) {
    int arr[8];
    int i;
    for (i = 0; i < 8; i = i + 1) { arr[i] = i * i; }
    return sum_array(arr, 8);   // 0+1+4+9+16+25+36+49 = 140
}

int main(void) {
    int a = 7;
    int b = 6;
    if (a * b != 42)        return 1;
    if (100 / 7 != 14)      return 2;
    if (100 % 7 != 2)       return 3;
    if (fib(10) != 55)      return 4;
    if (sum_squares() != 140) return 5;

    int x = 0;
    while (x < 10) { x = x + 1; }
    if (x != 10)            return 6;

    int acc = 0;
    int k;
    for (k = 0; k <= 5; k = k + 1) { acc += k; }
    if (acc != 15)          return 7;

    if ((5 < 3) || !(1 == 1)) return 8;
    if (((0xFF00 & 0x0FF0) >> 4) != 0x00F0) return 9;

    // Relational comparisons: <, <=, >, >=
    if (!(3 < 5) || (5 < 3) || (5 < 5)) return 10;
    if (!(5 <= 5) || !(4 <= 5) || (6 <= 5)) return 11;
    if (!(5 > 3) || (3 > 5) || (3 > 3)) return 12;
    if (!(5 >= 5) || !(6 >= 5) || (4 >= 5)) return 13;

    // Recursion: gcd
    if (gcd(48, 18) != 6) return 14;

    // Array manipulation & passing pointers
    int data[5];
    int j;
    for (j = 0; j < 5; j = j + 1) {
        data[j] = (j + 1) * 10;   // 10, 20, 30, 40, 50
    }
    if (sum_array(data, 5) != 150) return 15;

    reverse_array(data, 5);       // 50, 40, 30, 20, 10
    if (data[0] != 50 || data[1] != 40 || data[2] != 30 ||
        data[3] != 20 || data[4] != 10) return 16;

    return 0;   // PASS
}

