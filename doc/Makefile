.PHONY:	all content doc clean gloss latex
all:	doc

LaTeX	:= pdflatex

content:
	cd source && make
	cd diagrams && make

doc:	content
	+$(LaTeX) document
	-bibtex document
	makeindex -s document.ist -t document.glg -o document.gls document.glo
	+$(LaTeX) document
	+$(LaTeX) document

#	dvips document.dvi
#	ps2pdf14 document.ps thesis2.pdf

clean:
	-rm document.dvi

gloss:
	+$(LaTeX) document.tex
	makeindex -s document.ist -t document.glg -o document.gls document.glo
	+$(LaTeX) document.tex

latex:	clean all
	+$(LaTeX) document
	-bibtex document
	makeindex -s document.ist -t document.glg -o document.gls document.glo
	+$(LaTeX) document
	+$(LaTeX) document

#	dvips document.dvi
#	ps2pdf14 document.ps thesis2.pdf
