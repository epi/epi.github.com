copy: plot cppdmeta.tar.gz
	mkdir -p ../../img/cppdmeta
	rm -f ../../img/cppdmeta/*
	cp hana.svg d.svg dmap.svg ../../img/cppdmeta
	mkdir -p ../../files/
	cp cppdmeta.tar.gz ../../files/
.PHONY: copy

cppdmeta.tar.gz: map.d es.d hana.cpp runtime.cpp
	mkdir -p cppdmeta
	rm -f cppdmeta/*
	cp $^ cppdmeta/
	tar zcvf $@ cppdmeta/

plot: plot.d hana.dat d.dat dmap.dat
	./$< $(shell cat hana.dat d.dat dmap.dat)
.PHONY: plot

%.dat: %
	./$< >$@

hana: hana.cpp
	clang++-3.9 -DBENCHMARK -flto -O3 -std=c++14 -g $< -o $@

d: es.d
	/opt/ldc2-1.1.0-linux-x86_64/bin/ldc2 -d-version=Benchmark -flto=full -O3 $< -of$@

dmap: map.d
	/opt/ldc2-1.1.0-linux-x86_64/bin/ldc2 -d-version=Benchmark -flto=full -O3 $< -of$@

clean:
	rm -f hana.svg d.svg dmap.svg hana.dat d.dat dmap.dat hana d dmap cppdmeta.tar.gz *.o
	rm -rf cppdmeta
.PHONY: clean

