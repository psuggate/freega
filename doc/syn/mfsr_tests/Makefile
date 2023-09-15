all: mfsrs
	./trad_tests.py
	./mfsr_tests.py
	./pctrad_tests.py
	./pcmfsr_tests.py
	./hybrid_tests.py

mfsrs:
	cd mfsrs && make

clean:
	./trad_tests.py --clean
	./mfsr_tests.py --clean
	./pctrad_tests.py --clean
	./pcmfsr_tests.py --clean
	./hybrid_tests.py --clean
	cd mfsrs && make clean
