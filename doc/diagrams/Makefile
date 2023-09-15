.PHONY:	all eps clean
EPS=pci_pci_state_machine.eps pci_wb_state_machine.eps wb_sdram_state_machine.eps mem_hierarchy.eps RISC16_IFmts.eps tta16_overview.eps risc16_pipeline.eps pc_unit.eps risc16_bypass.eps ddr_primitive.eps bitwise_unit.eps tta16_henk.eps cache_sense_logic.eps bufgmux.eps synchroniser.eps afifo.eps freega_simple.eps tta16_instr.eps tta16_used_fields.eps risc16_instr.eps tta16_pipeline.eps risc16_pipeline2.eps sync2.eps

# DOT	:= $(wildcard *.dot)
BOX_RAW	:= $(wildcard *.box)
LIB	:= $(filter %_lib.box, $(BOX_RAW))
BOX	:= $(filter-out %_lib.box, $(BOX_RAW))

# EPS	:= $(BOX:.box=.eps) $(DOT:.dot=.eps)
PDF	:= $(BOX:.box=.pdf)

all: $(PDF)

eps: $(EPS)

clean:
	rm -rf ${EPS}

%.eps: %.dot
	dot -Teps -o $*.eps $<

%.pdf: %.box $(LIB)
	box -l g -I . $< -o $@

%.eps: %.box
	box -l g -I . -o $@ $<
