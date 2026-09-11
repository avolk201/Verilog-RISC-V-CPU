// hello_uart.c - transmit a string over UART0 from C, verifying via loopback.
// Exercises: string literals, char* indexing, pointer casts to MMIO, while
// loops, and bitwise ops. Returns 0 on success (testbench reports PASS and
// echoes the transmitted text to the console).

int main(void) {
    int uart = 0x10000000;
    char *s = "Hello from C on the RV32 SoC!\r\n";

    // Program the UART: DLAB=1, divisor=8, then 8N1.
    *(int*)(uart + 0x0C) = 0x80;   // LCR: DLAB
    *(int*)(uart + 0x00) = 8;      // DLL
    *(int*)(uart + 0x04) = 0;      // DLM
    *(int*)(uart + 0x0C) = 0x03;   // LCR: 8N1, DLAB=0

    int i = 0;
    while (s[i] != 0) {
        int c = s[i];
        while ((*(int*)(uart + 0x14) & 0x20) == 0) { }   // wait THRE
        *(int*)(uart + 0x00) = c;                        // transmit
        while ((*(int*)(uart + 0x14) & 0x01) == 0) { }   // wait DR (loopback)
        int r = *(int*)(uart + 0x00);                    // read back
        if (r != c) return 1;                            // mismatch -> FAIL
        i = i + 1;
    }
    return 0;                                            // PASS
}
