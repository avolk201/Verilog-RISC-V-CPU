# ---------------------------------------------------------------------------
# Makefile - RV32 multi-core SoC: assemble, build, and run all simulations
# Requires: Icarus Verilog (iverilog/vvp), Python 3
#
#   make test    assemble all programs, build testbenches, run the regression
#   make clean   remove generated images, sim binaries and waveforms
#   make waves   run the core test and keep a VCD for inspection
# ---------------------------------------------------------------------------
IVERILOG ?= iverilog
TOOLCHAIN_DIR ?= ../rv32-toolchain
VVP      ?= vvp
PYTHON   ?= $(shell [ -x /usr/bin/python3 ] && echo /usr/bin/python3 || echo python3)
ASM      := $(PYTHON) $(TOOLCHAIN_DIR)/assembler/rv32asm.py
CC       := $(PYTHON) $(TOOLCHAIN_DIR)/compiler/rvcc.py
SRCLIST  := sim/files.f
VFLAGS   := -g2012 -I rtl/periph -s tb_soc -c $(SRCLIST)

SIMDIR   := sim
TESTDIR  := sw/tests
RTLSRCS  := $(shell find rtl -name '*.v')

# Tests as <name>:<num_cores>
TESTS_1 := core_test:1 uart_hello:1 eth_loopback:1 c_arith:1 hello_uart:1
TESTS_4 := multicore_lock:4

HEX1   := $(foreach t,$(TESTS_1),$(TESTDIR)/$(word 1,$(subst :, ,$t)).rom.hex)
HEX4   := $(foreach t,$(TESTS_4),$(TESTDIR)/$(word 1,$(subst :, ,$t)).rom.hex)
ALLHEX := $(HEX1) $(HEX4)

.PHONY: all test clean waves
all: test

# ---- testbenches (one build per core count) ----
$(SIMDIR)/tb1.vvp: $(SRCLIST) tb/tb_soc.v $(RTLSRCS)
	@mkdir -p $(SIMDIR)
	$(IVERILOG) $(VFLAGS) -P tb_soc.NUM_CORES=1 -o $@

$(SIMDIR)/tb4.vvp: $(SRCLIST) tb/tb_soc.v $(RTLSRCS)
	@mkdir -p $(SIMDIR)
	$(IVERILOG) $(VFLAGS) -P tb_soc.NUM_CORES=4 -o $@

# ---- assemble / compile programs (.S/.c -> .rom.hex + .ram.hex) ----
$(TESTDIR)/%.rom.hex: $(TESTDIR)/%.S sw/assembler/rv32asm.py
	$(ASM) $< -o $@ --ram $(@:.rom.hex=.ram.hex)

$(TESTDIR)/%.rom.hex: $(TESTDIR)/%.c sw/compiler/rvcc.py sw/assembler/rv32asm.py
	$(CC) $< --rom $@ --ram $(@:.rom.hex=.ram.hex)

# ---- run the full regression ----
test: $(SIMDIR)/tb1.vvp $(SIMDIR)/tb4.vvp $(ALLHEX)
	@echo "================ RV32 SoC regression ================"
	@fail=0; \
	for t in $(TESTS_1); do \
	  name=$${t%%:*}; \
	  $(VVP) $(SIMDIR)/tb1.vvp +ROM=$(TESTDIR)/$$name.rom.hex +RAM=$(TESTDIR)/$$name.ram.hex +TIMEOUT=200000 \
	    | grep -E "PASSED|FAILED|TIMEOUT" || fail=1; \
	done; \
	for t in $(TESTS_4); do \
	  name=$${t%%:*}; \
	  $(VVP) $(SIMDIR)/tb4.vvp +ROM=$(TESTDIR)/$$name.rom.hex +RAM=$(TESTDIR)/$$name.ram.hex +TIMEOUT=400000 \
	    | grep -E "PASSED|FAILED|TIMEOUT" || fail=1; \
	done; \
	echo "====================================================="; \
	if [ $$fail -ne 0 ]; then echo "REGRESSION FAILED"; exit 1; else echo "ALL TESTS PASSED"; fi

waves: $(SIMDIR)/tb1.vvp $(TESTDIR)/core_test.rom.hex
	$(VVP) $(SIMDIR)/tb1.vvp +ROM=$(TESTDIR)/core_test.rom.hex +RAM=$(TESTDIR)/core_test.ram.hex
	@echo "waveform written to $(SIMDIR)/dump.vcd"

clean:
	rm -f $(SIMDIR)/*.vvp $(SIMDIR)/*.vcd $(TESTDIR)/*.rom.hex $(TESTDIR)/*.ram.hex
