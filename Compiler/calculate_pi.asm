// Functional opcodes: ADD, SUB, XOR, LDI (load data immediate), JMP (jump/goto), BEQZ (branch if equals zero), HALT, STR (store), AND, LOAD, MOV (move), JAL, JR, MUL
// Registers:

        // ---------- compute pi in Q8.8 ----------
        // R0 = N_terms
        LDI   R0, #20          // sum 20 terms
        LDI   R1, #0           // n = 0
        LDI   R2, #0           // sum = 0 (Q8.8)

loop_n:
        // denom = 2*n + 1 → R3
        MOV   R3, R1
        ADD   R3, R3, R1      // R3 = 2*n
        LDI   R4, #1
        ADD   R3, R3, R4      // R3 = 2*n + 1

        // term = 256 / denom → R4
        LDI   R5, #256        // dividend
        JAL   R6, div         // R6←return, R4←quotient
        JR    R6

        // apply sign: if n odd, term = –term
        MOV   R5, R1
        AND   R5, R5, #1
        BEQZ  R5, skip_neg
        SUB   R4, R0, R4      // R0 is 0 so this negates R4
skip_neg:

        // sum += term
        ADD   R2, R2, R4

        // n++
        LDI   R4, #1
        ADD   R1, R1, R4

        // if n < N_terms loop
        MOV   R4, R0
        SUB   R4, R4, R1
        BEQZ  R4, compute_done
        JMP   loop_n

compute_done:
        // pi = sum * 4
        LDI   R4, #4
        MUL   R2, R2, R4

        // extract integer part (pi >> 8) → R7
        JAL   R6, shr8
        JR    R6
        STR   R7, #0            // M[0] = 3

        // extract each decimal digit 1…10
        // repeat:
        //   frac = frac * 10
        //   digit = frac >> 8
        //   frac = frac & 0xFF
        //   STR digit, #addr

        LDI   R5, #10           // multiplier
        LDI   R8, #1            // digit index
        MOV   R3, R2            // frac = R2

digit_loop:
        MUL   R3, R3, R5        // frac *= 10
        JAL   R6, shr8
        JR    R6                // R7 = top‐8 bits = digit
        STR   R7, R8            // store at M[R8]
        // frac = frac & 0xFF
        LDI   R4, #0xFF
        AND   R3, R3, R4

        // idx++
        LDI   R4, #1
        ADD   R8, R8, R4
        // stop after 10 digits
        LDI   R4, #11
        SUB   R4, R4, R8
        BEQZ  R4, done_store
        JMP   digit_loop

done_store:
        HALT

// ----------------- subroutines -----------------

div:    // R5=dividend, R3=divisor → R4=quotient, R3=remainder
        DIV   R4, R5, R3

shr8:   // R3=Q8.8 value → R7=R3>>8
        // …implement shift‐right‐8 here…
        //JR    R6