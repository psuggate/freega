.PHONY:	all clean

EPS	:= crt_redraw.eps mfsr8.eps pci_to_sdram_xfer.eps cfg_space_cap.eps crt_sim.eps freega3_pcb_art_top.eps freega3_pcb_art_bot.eps openvga_bot.eps wishbone_bus.eps wishbone_demo.eps

SVG	:= $(wildcard *.svg)
PDF	:= $(SVG:.svg=.pdf) $(EPS:.eps=.pdf)

all:	$(PDF)

clean:
	rm $(PDF)

%.pdf:	%.svg
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<

%.pdf:	%.eps
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<
