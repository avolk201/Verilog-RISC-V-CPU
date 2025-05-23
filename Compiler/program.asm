// Test all opcodes: LDI, ADD, SUB, XOR, JMP

//  0: load immediates into R1, R2
LDI R1, #5        // R1 ←  5
LDI R2, #-2       // R2 ← -2  (sign-extend to 6 bits)

//  2: arithmetic
ADD R3, R1, R2    // R3 ← 5 + (-2) = 3
SUB R4, R1, R2    // R4 ← 5 - (-2) = 7
XOR R5, R1, R2    // R5 ← 5 ^ (-2)

//  6: jump over the next LDI
JMP #7           // PC ← 8

//  7: this instruction should be skipped
LDI R6, #123      // (skipped)

//  8: land here and load into R7
LDI R7, #31       // R7 ← 31

// end (you could loop or halt here)