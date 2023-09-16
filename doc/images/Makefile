.PHONY:	all clean

EPS	:= crt_redraw.eps cfg_space_cap.eps $(wildcard *fsr*.eps) openvga_bot.eps wishbone_bus.eps

# Extract the raw bitmap data into PPM image files
# TODO: need a way to extract the pixel widths and heights
RAW	:= crt_sim.eps freega3_pcb_art_top.eps freega3_pcb_art_bot.eps pci_to_sdram_xfer.eps wishbone_demo.eps
PPM	:= $(RAW:.eps=.ppm)

SVG	:= $(wildcard *.svg)
PDF	:= $(SVG:.svg=.pdf) $(EPS:.eps=.pdf)

all:	$(PDF)

clean:
	rm $(PDF)

%.pdf:	%.svg
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<

%.pdf:	%.eps
	+inkscape --export-area-drawing --export-text-to-path --export-pdf=$@ $<
