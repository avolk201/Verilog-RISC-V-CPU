# ---------------------------------------------------------------------------
# multicore_lock.S - SMP shared-memory demonstration
#
# All NCORES harts run this same image concurrently. Each performs ITER
# read-modify-write increments of a shared `counter`, guarded by a spinlock
# built from AMOSWAP.W (atomic test-and-set). Because the interconnect grants
# one master at a time and AMOs are single-beat read-modify-writes, the lock
# provides true mutual exclusion across cores.
#
# If the lock worked, counter == NCORES*ITER exactly (no lost updates). The last
# hart to finish verifies this and writes PASS/FAIL to `tohost`.
#
# Assemble/run with NUM_CORES matching NCORES below.
# ---------------------------------------------------------------------------
    .equ NCORES,     4
    .equ ITER,       50
    .equ LOCK,       0x80010000
    .equ COUNTER,    0x80010004
    .equ CORES_DONE, 0x80010008
    .equ tohost,     0x8001FFF0
    .equ PASS_CODE,  0x600D600D

    .text
    .globl _start
_start:
    li   a0, LOCK              # a0 = &lock
    li   t2, ITER              # per-core iteration counter

outer:
    # ---- acquire spinlock: test-and-set via AMOSWAP ----
    li   t0, 1
acquire:
    amoswap.w t1, t0, (a0)     # t1 = old lock; lock = 1 (atomic)
    bnez t1, acquire           # already held -> spin

    # ---- critical section: counter = counter + 1 ----
    li   t3, COUNTER
    lw   t4, 0(t3)
    addi t4, t4, 1
    sw   t4, 0(t3)

    # ---- release lock ----
    sw   zero, 0(a0)

    addi t2, t2, -1
    bnez t2, outer

    # ---- announce completion atomically ----
    li   t3, CORES_DONE
    li   t4, 1
    amoadd.w t5, t4, (t3)      # t5 = previous cores_done
    li   t6, NCORES-1
    bne  t5, t6, done_spin     # not the last hart -> park

    # ---- last hart verifies the shared counter ----
    li   t3, COUNTER
    lw   t4, 0(t3)
    li   t5, NCORES*ITER
    li   a0, tohost
    beq  t4, t5, pass

    li   t6, 0xBAD00000        # fail: include observed count for debugging
    or   t6, t6, t4
    sw   t6, 0(a0)
    j    done_spin
pass:
    li   t6, PASS_CODE
    sw   t6, 0(a0)
done_spin:
    j    done_spin
