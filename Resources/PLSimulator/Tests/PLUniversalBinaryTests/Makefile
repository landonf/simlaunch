CC=clang
CFLAGS=-dynamiclib -arch i386 -arch x86_64
BINARIES=test test-universal

.PHONY: all
all: $(BINARIES)

test-universal: test.c
	$(CC) $(CFLAGS) $< -o $@

test: test.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(BINARIES)
