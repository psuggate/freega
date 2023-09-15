EPS=pci_pci_state_machine.eps pci_wb_state_machine.eps wb_sdram_state_machine.eps mem_hierarchy.eps RISC16_IFmts.eps tta16_overview.eps risc16_pipeline.eps pc_unit.eps risc16_bypass.eps ddr_primitive.eps bitwise_unit.eps tta16_henk.eps cache_sense_logic.eps bufgmux.eps synchroniser.eps afifo.eps freega_simple.eps tta16_instr.eps tta16_used_fields.eps risc16_instr.eps tta16_pipeline.eps risc16_pipeline2.eps sync2.eps

%.eps: %.dot
	dot -Teps -o $*.eps $<

%.eps: %.box
	box -l g -I . $<

all: ${EPS}

clean:
	rm -rf ${EPS}
