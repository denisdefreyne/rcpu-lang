SOURCES := $(shell find src -name '*.cr')

.PHONY: all
all: rlc

rlc: src/rlc/main.cr $(SOURCES)
	crystal build --verbose $< -o $@

.PHONY: clean
clean:
	rm -rf .crystal
	rm -f rlc
