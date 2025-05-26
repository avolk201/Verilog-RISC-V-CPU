# Functional opcodes: ADD, SUB, XOR, LDI (load data immediate), JMP (jump/goto), BEQZ (branch if equals zero), HALT, STR (store), AND, LOAD, MOV (move), JAL, JR, MUL
# Registers:
#   R0 = F[n-1]
#   R1 = F[n]
#   R2 = F[n+1] (temporary next value)
#   R3 = 0       (constant zero)
#   R4 = memory address pointer
#   R5 = loop counter (how many more fibs to do)
#   R6 = 1

# Load initial values
LDI R0, 0      # F[0] = 0
LDI R1, 1      # F[1] = 1

LDI R2, 0      # temp
LDI R3, 0      # zero constant
LDI R4, 1      # R4 = memory address pointer
LDI R5, 25     # number of loops to do
LDI R6, 1      # decrement amount
ADD R9, R9, R6

LOOP:

STR R0, R8              # store current F[n-1] to memory at address R8
ADD R2, R0, R1          # compute next = R0 + R1
ADD R4, R4, R6          # increment address pointer
MOV R0, R1              # R0 ← old R1
MOV R1, R2              # R1 ← new R2
SUB R5, R5, R6          # decrement loop counter
BNE LOOP                # branch if not zero
HALT