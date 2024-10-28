SUBMIT := backend.ml team.txt

HWNAME := hw03
ZIPNAME := $(HWNAME)-submit.zip

# Define the output directory
OUTPUT_DIR = _make_build

# Ensure the output directory exists
$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

all: main.native

.PHONY: test
test: main.native $(OUTPUT_DIR)
	./main.native --test

test-full: main.native $(OUTPUT_DIR)
	./main.native --full-test > $(OUTPUT_DIR)/full_test_output.txt

main.native:
	ocamlbuild -Is util,x86,ll,grading,sharedtests -libs unix,str main.native -use-menhir

main.byte:
	ocamlbuild -Is util,x86,ll,grading,sharedtests -libs unix,str main.byte -use-menhir

.PHONY: utop repl
utop: main.byte
	utop -require unix,str

repl: utop

zip: $(SUBMIT)
	zip '$(ZIPNAME)' $(SUBMIT)

.PHONY: clean
clean:
	ocamlbuild -clean
	rm -rf output a.out
	rm -rf $(OUTPUT_DIR)/*
