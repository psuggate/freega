all:
	cd source && make
	cd diagrams && make

clean:
	-rm document.dvi

gloss:
	latex document.tex
	makeindex -s document.ist -t document.glg -o document.gls document.glo
	latex document.tex

latex: clean all
	latex document
	-bibtex document
	makeindex -s document.ist -t document.glg -o document.gls document.glo
	latex document
	latex document
	dvips document.dvi
	ps2pdf14 document.ps thesis2.pdf
