# Functional opcodes: ADD, SUB, XOR, LDI (load data immediate), JMP (jump/goto), BEQZ (branch if equals zero), HALT, STR (store), AND, LOAD, MOV (move), JAL, JR, MUL
# Registers:
#   R0 = F[n-1]
#   R1 = F[n]
#   R2 = F[n+1] (temporary next value)
#   R3 = 0       (constant zero)
#   R4 = memory address pointer
#   R5 = loop counter (how many more fibs to do)
#   R6 = 1

.alias FN1 R0      // F[n-1]
.alias FN  R1      // F[n]
.alias FN2 R2      // F[n+1] (temp)
.alias ZERO R3     // constant zero
.alias ADDR R4     // memory address pointer
.alias COUNT R5    // loop counter
.alias ONE R6      // constant one
.alias MEM R8      // memory base pointer
.alias TMP R9      // temp register

# Load initial values
LDI FN1, 0      # F[0] = 0
LDI FN, 1       # F[1] = 1

LDI FN2, 0      # temp
LDI ZERO, 0     # zero constant
LDI ADDR, 1     # memory address pointer
LDI COUNT, 25   # number of loops to do
LDI ONE, 1      # decrement amount
ADD TMP, TMP, ONE

LOOP:

STR FN1, MEM              # store current F[n-1] to memory at address MEM
ADD FN2, FN1, FN          # compute next = FN1 + FN
ADD ADDR, ADDR, ONE       # increment address pointer
MOV FN1, FN               # FN1 ← old FN
MOV FN, FN2               # FN ← new FN2
SUB COUNT, COUNT, ONE     # decrement loop counter
BNE LOOP                  # branch if not zero
HALT