# Provide some defaults for the user settings
TOP_MODULE=$(shell echo ${XFILES} | cut -d\. -f1)
PINOUT_STEM=${TOP_MODULE}
PINOUT=${PINOUT_STEM}-$(shell echo ${TARGET} | cut -d- -f1,2).ucf
#########################################################
# User settings start here
#########################################################

# Target as part_num-package-speed_grade. USE LOWER CASE
#TARGET=xcr3128xl-vq100-10
#TARGET=xcr3064xl-pc44-10
#TARGET=xcr3064xl-vq100-10
#TARGET=xcr3128xl-tq144-10
#TARGET=xc2s30-tq144-5
#TARGET=xc2s400e-ft256-7
#TARGET=xc2v3000-ff1152-6
TARGET=xc3s200-ft256-4

# export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/Xilinx/bin/lin
# export XILINX=/usr/local/Xilinx

# List of files. The first one will be taken as the top module, unless TOP_MODULE overridden
VGA_FILES=rtl/vga.v rtl/text/text_mode.v rtl/text/text2pix.v rtl/crt/crtc640x400.v rtl/ib/ib_sram_framebuffer.v rtl/ib/ib_mda_ports.v

MEM_FILES=rtl/ram/sram/mem_mux.v rtl/ram/sram/vga_to_mem.v rtl/misc/sync_slow_to_fast.v rtl/misc/sync_fast_to_slow.v rtl/ram/sram/sram_interface_16bit.v rtl/ram/sram/mem_ctrl.v rtl/fifo/FIFO16X18.v rtl/fifo/FIFO16X4.v rtl/fifo/FIFO16X32.v rtl/fifo/FIFO16X1.v rtl/serial_flash/read_prom.v rtl/serial_flash/serial_shift_and_compare.v

PCI_FILES=rtl/pci/new_target.v rtl/pci/pci_latch.v rtl/pci/pci_transaction.v rtl/pci/pci_decoder.v rtl/pci/pci_gen_devsel_n.v rtl/pci/pci_gen_trdy_n.v rtl/pci/pci_gen_ib_write.v rtl/pci/pci_gen_ib_strobe.v rtl/pci/pci_gen_ib_address.v rtl/pci/pci_cfg_space_decoder.v rtl/pci/decode.v rtl/pci/pci_cfg_space.v

COMMON_FILES=rtl/vga_starter_kit.v ${VGA_FILES} ${PCI_FILES} ${MEM_FILES} rtl/led_display/led_display.v rtl/led_display/led_digit.v

XFILES=${COMMON_FILES}
IFILES=${COMMON_FILES} rtl/vga_test.v rtl/xilinx_sim/RAMB16_S9_S9.v rtl/xilinx_sim/RAMB16_S36.v rtl/xilinx_sim/RAMB16_S1.v rtl/xilinx_sim/LUT4.v rtl/xilinx_sim/BUFG.v rtl/xilinx_sim/DCM.v rtl/xilinx_sim/FDR.v rtl/xilinx_sim/RAM16X1D.v rtl/xilinx_sim/FDCE.v rtl/ram/sram/IS61LV25616AL.v rtl/xilinx_sim/FDE.v

# (optional) Name of top module. Defaults to name of first file with suffix removed
TOP_MODULE=vga_starter_kit
ICARUS_TOP_MODULE=vga_test
# (optional) List of modules for a show resources report (FPGA only)
#RSRC_REPORT=
RSRC_REPORT=

# (optional) Name of Contraints file. Defaults to PINOUT_STEM-PART-PACKAGE.ucf
PINOUT=ucf/vga.ucf
# (optional) Name of PINOUT_STEM. Defaults to TOP_MODULE
#PINOUT_STEM=testing
# whether to require matching of all the paramaters in the .ucf file true/false
# WARNING: if this is false, be careful of spelling errors ... they won't appear as warnings
#STRICT_UCF=false

# opt level is 1,2,3 or 4. 4 will take some time (maybe hours). 5 is just insane. Default is 1
OPT_LEVEL=4
# opt mode is one of speed or area
OPT_MODE=speed

# quiet mode - true or false.
QUIET_MODE=false

#########################################################
# Advanced user settings
#########################################################

# Both FPGA and CPLD
XST_EXTRAS=
NGDBUILD_EXTRAS=

# FPGA Only
MAP_EXTRAS= -r
PAR_EXTRAS=
BITGEN_EXTRAS=

# CPLD only
CPLDFIT_XTRAS=
HPREP6_EXTRAS=

#########################################################
# User settings end here
#########################################################

# Internal settings. Probably no need to tamper with these
X_SETTINGS = /usr/local/Xilinx/settings.sh
X_PREFIX = _xilinx_int

PART=$(shell echo ${TARGET} | cut -d- -f1)
PACKAGE=$(shell echo ${TARGET} | cut -d- -f2)
SPEED_GRADE=$(shell echo ${TARGET} | cut -d- -f3)
FFILES=${X_PREFIX}_target.v ${XFILES}

ifneq '$(filter xc9%,${PART})' ''
PART_TYPE=cpld
else
ifneq '$(filter xcr3%,${PART})' ''
PART_TYPE=cpld
else
ifneq '$(filter xc2c%,${PART})' ''
PART_TYPE=cpld
else
ifneq '$(filter xc2s%,${PART})' ''
PART_TYPE=fpga
else
ifneq '$(filter xc3s%,${PART})' ''
PART_TYPE=fpga
else
ifneq '$(filter xc2v%,${PART})' ''
PART_TYPE=fpga
else
PART_TYPE=unknown
endif
endif
endif
endif
endif
endif

ifeq '$(OPT_LEVEL)' '2'
XST_OPT_LEVEL=2
CPLD_EXHAUST=
PAR_OPT=-ol med
else
ifeq '$(OPT_LEVEL)' '3'
XST_OPT_LEVEL=2
CPLD_EXHAUST=
PAR_OPT=-ol high
else
ifeq '$(OPT_LEVEL)' '4'
XST_OPT_LEVEL=2
CPLD_EXHAUST=-exhaust
PAR_OPT=-ol high -xe n
else
ifeq '$(OPT_LEVEL)' '5'
XST_OPT_LEVEL=2
CPLD_EXHAUST=-exhaust
PAR_OPT=-ol high -xe c
else
#assume optlevel 1 (lowest)
XST_OPT_LEVEL=1
CPLD_EXHAUST=
PAR_OPT=-ol std
endif
endif
endif
endif

ifeq '${STRICT_UCF}' 'TRUE'
AUL=
else
ifeq '${STRICT_UCF}' 'true'
AUL=
else
ifeq '${STRICT_UCF}' '1'
AUL=
else
AUL=-aul
endif
endif
endif

ifeq '${QUIET_MODE}' 'true'
SILENT_INT=-intstyle silent
MAP_QUIET=-quiet
else
SILENT_INT=
MAP_QUIET=
endif

ifeq '${PART_TYPE}' 'cpld'
PROG_EXT=jed
else
PROG_EXT=bit
endif

all: build prom

prom:
	/usr/local/Xilinx/bin/lin/promgen -w -u 0 _xilinx_int.bit -p mcs
#	perl ../vgabios/perl/pc.pl -f mcs -swap off -uf vgabios.mem -pf freega.mcs
#	/usr/local/Xilinx/bin/lin/promgen -w -c -r new_freega.mcs


clean:
	@rm -rf ${X_PREFIX}_dir ${X_PREFIX}.* _* *.srp *.lso tmperr.err icarus.out
	@md5sum makefile > make.md5

clean_test:
ifneq '$(shell cat make.md5)' '$(shell md5sum makefile)'
	@echo 'Makefile changed: making clean'
	make clean
else
endif

test:
	echo ${TEST}

#########################################################

icarus: clean_test ${XFILES}
	iverilog -D__icarus -o icarus.out -s ${ICARUS_TOP_MODULE} ${IFILES}

#########################################################
# Used both for CPLD and FPGA

${X_PREFIX}.prj : 
	@echo '`define __${PART}_${PACKAGE} 1'  > ${X_PREFIX}_target.v
	@echo '`define __xilinx 1'  >>  ${X_PREFIX}_target.v
	@rm -f ${X_PREFIX}.prj
	@touch ${X_PREFIX}.prj
	@for x in $(filter %.v,${FFILES}); do echo "verilog work $$x" >> ${X_PREFIX}.prj; done
	@for x in $(filter %.vhd,${FFILES}); do echo "vhdl work $$x" >> ${X_PREFIX}.prj; done
	@mkdir -p ${X_PREFIX}_dir/xst

xst: clean_test ${FFILES} ${X_PREFIX}.ngc

${X_PREFIX}.ngc : ${X_PREFIX}.prj ${FFILES} ${PINOUT}
	@echo 'set -tmpdir ${X_PREFIX}_dir/xst -xsthdpdir ${X_PREFIX}_dir/xst'> ${X_PREFIX}.scr
	@echo 'run -ifn ${X_PREFIX}.prj -ifmt mixed -top $(TOP_MODULE) -ofn ${X_PREFIX}.ngc -p ${PART}-${PACKAGE}-${SPEED_GRADE}' >> ${X_PREFIX}.scr
	@echo '-opt_mode ${OPT_MODE} -opt_level ${XST_OPT_LEVEL}' ${XST_EXTRAS} >> ${X_PREFIX}.scr
	. ${X_SETTINGS} ; xst -ifn ${X_PREFIX}.scr

${X_PREFIX}_%.srp: ${X_PREFIX}.prj ${FFILES} ${PINOUT}
	@echo 'set -tmpdir ${X_PREFIX}_dir/xst -xsthdpdir ${X_PREFIX}_dir/xst'> ${X_PREFIX}_$(*F).scr
	@echo 'run -ifn ${X_PREFIX}.prj -ifmt mixed -top $(*F) -ofn ${X_PREFIX}_$(*F).ngc -p ${PART}-${PACKAGE}-${SPEED_GRADE}' >> ${X_PREFIX}_$(*F).scr
	@echo '-opt_mode area -opt_level ${XST_OPT_LEVEL}' ${XST_EXTRAS} >> ${X_PREFIX}_$(*F).scr
	. ${X_SETTINGS} ; xst -ifn ${X_PREFIX}_$(*F).scr

resources: $(patsubst %,${X_PREFIX}_%.srp,${RSRC_REPORT})
	@for x in ${RSRC_REPORT}; do echo MODULE: $$x ; head -$$[15+`grep -n "Device utilization summary" $(patsubst %,${X_PREFIX}_%.srp,$$x) | grep -v ")" | cut -d: -f1`] $(patsubst %,${X_PREFIX}_%.srp,$$x) | tail -15 | grep "Number of" | grep -v IOBs | grep -v GCLKs ; echo "" ; done

${X_PREFIX}.ngd : ${X_PREFIX}.ngc
	@mkdir -p ${X_PREFIX}_dir/xst
	. ${X_SETTINGS} ; ngdbuild -dd ${X_PREFIX}_dir ${AUL} ${NGDBUILD_EXTRAS} ${SILENT_INT} -uc ${PINOUT} ${X_PREFIX}.ngc

build: clean_test ${X_PREFIX}.${PROG_EXT}

program: clean_test clean_test build
	. ${X_SETTINGS} ; impact -batch impact_${PART_TYPE}.cmd

#########################################################
# CPLD only

ifeq '${OPT_MODE}' 'area'
CPLD_OPT_MODE=density
else
CPLD_OPT_MODE=speed
endif

${X_PREFIX}.vm6 : ${X_PREFIX}.ngd
	. ${X_SETTINGS} ; cpldfit -p ${PART}-${SPEED_GRADE}-${PACKAGE} -optimize ${CPLDFIT_XTRAS} ${CPLD_OPT_MODE} ${CPLD_EXHAUST} ${X_PREFIX}.ngd

${X_PREFIX}.jed : ${X_PREFIX}.vm6
	. ${X_SETTINGS} ; hprep6 -i ${X_PREFIX}.vm6 ${SILENT_INT} ${HPREP6_EXTRAS}

#########################################################
# FPGA only

map: ${X_PREFIX}0.ncd

${X_PREFIX}0.ncd : ${X_PREFIX}.ngd
	@cp ${X_PREFIX}.ngd ${X_PREFIX}0.ngd
	. ${X_SETTINGS} ; map ${MAP_QUIET} ${MAP_EXTRAS} -cm ${OPT_MODE} ${X_PREFIX}0.ngd ${X_PREFIX}0.pcf

par: ${X_PREFIX}.ncd

${X_PREFIX}.ncd :${X_PREFIX}0.ncd
	. ${X_SETTINGS} ; par -w ${PAR_OPT} ${PAR_EXTRAS} ${X_PREFIX}0.ncd ${X_PREFIX}.ncd
	. ${X_SETTINGS} ; trce -a ${SILENT_INT} ${X_PREFIX}.ncd _xilinx_int0.pcf
	tail -18 ${X_PREFIX}.twr

timing: ${X_PREFIX}.ncd
	tail -18 ${X_PREFIX}.twr

bitgen: ${X_PREFIX}.bit

${X_PREFIX}.bit : ${X_PREFIX}.ncd
	. ${X_SETTINGS} ; bitgen -w ${SILENT_INT} ${BITGEN_EXTRAS} ${X_PREFIX}.ncd
