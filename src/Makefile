# for redis.cmxa module not working in default project
OPT:=ocamlfind ocamlopt -g -thread
CMPL:=ocamlfind ocamlc -g -thread

all:redis.cmxa redis.cma

redis.cmi:redis.mli
	$(OPT) -package unix -c $<

redis_common.cmo:redis_common.ml
	$(CMPL) -package unix -c $<

redis_common.cmx:redis_common.ml
	$(OPT) -package unix -c $<

redis.cmo:redis.ml redis.cmi
	$(CMPL) -package unix -c $<

redis.cmx:redis.ml redis.cmi
	$(OPT) -package unix -c $<

.PHONY:redis.cma
redis.cma:redis_common.cmo redis.cmi redis.cmo
	$(CMPL) -a -o $@ redis_common.cmo redis.cmo

.PHONY:redis.cmxa
redis.cmxa:redis_common.cmx redis.cmi redis.cmx
	$(OPT) -a -o $@ redis_common.cmx redis.cmx

install:
	mkdir /usr/local/lib/ocaml/site-lib/ocaml-redis
	cp -f redis.cma redis.cmxa redis.a redis.cmi redis.o META /usr/local/lib/ocaml/site-lib/ocaml-redis/

uninstall:
	rm -rf /usr/local/lib/ocaml/site-lib/ocaml-redis

reinstall:
	make uninstall
	make install

rebuild:
	make clean
	make all

clean:
	rm -f *.cm*
	rm -f *.o
	rm -f *.a
