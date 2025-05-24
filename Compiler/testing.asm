// Functional opcodes: ADD, SUB, XOR, LDI (load data immediate), JMP (jump/goto), BEQZ (branch if equals zero), HALT, STR (store), AND, LOAD, MOV (move), JAL, JR, MUL


LDI R0, #0   // Load value into R0
LDI R1, #10    // Load value into R1
ADD R1, R1, R1
JAL R15, FUNC
LDI R5, #1
MOV R1, R2 // Move value from R2 to R1
HALT

FUNC:
LDI R3, #16
MUL R2, R3, R1

JR R15
HALT