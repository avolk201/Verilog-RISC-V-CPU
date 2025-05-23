// Functional opcodes: ADD, SUB, XOR, LDI, JMP, BEQZ, HALT, STR, AND, LOAD


LDI R0, #5   // Load value into R0
LDI R1, #15    // Load value into R1
STR R1, R0
READ R2, R1  // Read value from memory address stored in R1 into R2


MOV R4, R2
HALT