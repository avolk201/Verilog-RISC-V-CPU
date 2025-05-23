// Functional opcodes: ADD, SUB, XOR, LDI, JMP, BEQZ, HALT
// Registers:
//   R0 = F[n-1]
//   R1 = F[n]
//   R2 = F[n+1] (temporary next value)
//   R3 = 0       (constant zero)
//   R4 = memory address pointer
//   R5 = loop counter (how many more fibs to do)
//   R6 = 1

    // Load initial values
    LDI R0, #0      // F[0] = 0
    LDI R1, #1      // F[1] = 1
    LDI R2, #0      // temp
    LDI R3, #0      // zero constant
    LDI R4, #0      // R4 = memory address pointer
    LDI R5, #31     // number of loops to do
    LDI R6, #1      // decrement amount

LOOP:
    // store current F[n] (R1) to memory at address R4
    STR  R1, R4
    // compute next = R0 + R1
    ADD  R2, R0, R1

    // increment address pointer
    ADD  R4, R4, R6

    // shift window
    ADD  R0, R1, R3  // R0 ← old R1
    ADD  R1, R2, R3  // R1 ← new R2

    // decrement & maybe finish
    SUB  R5, R5, R6
    BEQZ END
    JMP  LOOP

END:
    HALT