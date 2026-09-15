# ---------------------------------------------------------------------------
# Makefile for Tiny Tapeout RV32 Fork (Tiny Silicon Computer)
# ---------------------------------------------------------------------------
IVERILOG ?= iverilog
VVP      ?= vvp
PYTHON   ?= $(shell [ -x /usr/bin/python3 ] && echo /usr/bin/python3 || echo python3)

SIMDIR   := sim
RTLSRCS  := $(wildcard rtl/*.v)
TBSRCS   := tb/tb_tt_top.v
VFLAGS   := -g2012 -I rtl

.PHONY: all test clean waves doom

all: test

$(SIMDIR)/tb_tt.vvp: $(RTLSRCS) $(TBSRCS)
	@mkdir -p $(SIMDIR)
	$(IVERILOG) $(VFLAGS) -s tb_tt_top -o $@ $(RTLSRCS) $(TBSRCS)

test: $(SIMDIR)/tb_tt.vvp
	@echo "================ Running Tiny Tapeout RV32 Simulation ================"
	$(VVP) $(SIMDIR)/tb_tt.vvp
	@echo "======================================================================"

# ---- Rigorous DOOM Simulation ----
sw/flash_image.hex: sw/doom_test.S sw/make_doom_wad.py sw/make_flash_image.py ../sw/assembler/rv32asm.py
	@$(PYTHON) sw/make_doom_wad.py sw/doom1.wad
	@$(PYTHON) ../sw/assembler/rv32asm.py sw/doom_test.S -o sw/doom_test.rom.hex --ram sw/doom_test.ram.hex --text-base 0x00000000 --data-base 0x00000800
	@$(PYTHON) sw/make_flash_image.py

$(SIMDIR)/tb_doom.vvp: $(RTLSRCS) tb/tb_doom.v sw/flash_image.hex
	@mkdir -p $(SIMDIR)
	$(IVERILOG) $(VFLAGS) -s tb_doom -o $@ $(RTLSRCS) tb/tb_doom.v

doom: $(SIMDIR)/tb_doom.vvp sw/flash_image.hex
	@echo "================ Running Rigorous DOOM Simulation ================"
	$(VVP) $(SIMDIR)/tb_doom.vvp
	@echo "=================================================================="

waves: $(SIMDIR)/tb_tt.vvp
	$(VVP) $(SIMDIR)/tb_tt.vvp
	@echo "Waveform dumped to $(SIMDIR)/tt_dump.vcd"

clean:
	rm -rf $(SIMDIR)
