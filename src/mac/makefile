# Default simulator
SIM ?= icarus

# Bahasa Toplevel
TOPLEVEL_LANG ?= verilog

# Konfigurasi agar Icarus membaca SystemVerilog
COMPILE_ARGS += -g2012

# Lokasi file RTL
VERILOG_SOURCES += $(PWD)/mac.sv

# Nama modul toplevel di SystemVerilog
TOPLEVEL = mac

# Nama file python testbench (tanpa .py)
MODULE = tb_mac

# Include cocotb makefile
include $(shell cocotb-config --makefiles)/Makefile.sim