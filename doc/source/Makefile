FILES=tta16_memcpy.tex tta16_set_leds.tex r16_memcpy.tex tta16_excerpt.tex

%.tex: %.S
	cat $< | ./tab2space.py > $*.tex

%.tex: %.xml
	cat $< | ./tab2space.py > $*.tex

all: ${FILES}

clean:
	rm -f ${FILES}
