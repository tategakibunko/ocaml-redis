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
	ocamlfind install ocaml-redis redis.cma redis.cmxa redis.a redis.cmi redis.o META

uninstall:
	ocamlfind remove ocaml-redis

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
