# Makefile for C Parser Studio
# Works with win_flex / win_bison / clang (llvm-mingw) on Windows
# and flex / bison / gcc on Linux / macOS.

# ------------------------------------------------------------------ #
#  Detect OS                                                           #
# ------------------------------------------------------------------ #
ifeq ($(OS),Windows_NT)
    FLEX    := win_flex
    BISON   := win_bison
    CC      := clang
    EXE     := cparser.exe
    RM      := del /Q /F
    RMDIR   := rmdir /S /Q
    MKDIR   := mkdir
    PATHSEP := \\
    NULL    := nul

    # win_bison needs its data directory when invoked via WinGet symlink.
    # Auto-detect the real executable location and set BISON_PKGDATADIR.
    BISON_REAL := $(shell powershell -NoProfile -Command \
        "(Get-Item (Get-Command win_bison).Source).Target" 2>nul)
    ifneq ($(BISON_REAL),)
        BISON_DATADIR := $(dir $(BISON_REAL))data
        export BISON_PKGDATADIR := $(BISON_DATADIR)
    endif
else
    FLEX    := flex
    BISON   := bison
    CC      := gcc
    EXE     := cparser
    RM      := rm -f
    RMDIR   := rm -rf
    MKDIR   := mkdir -p
    PATHSEP := /
    NULL    := /dev/null
endif

# ------------------------------------------------------------------ #
#  Flags                                                               #
# ------------------------------------------------------------------ #
CFLAGS   := -Wall -Wextra -Wno-unused-function \
            -Wno-implicit-function-declaration \
            -I. -g

# win_flex specific: --wincompat for Windows CR/LF-friendly output
ifeq ($(OS),Windows_NT)
    FLEXFLAGS := --wincompat
else
    FLEXFLAGS :=
endif

BISONFLAGS := -d -Wcounterexamples

# ------------------------------------------------------------------ #
#  Source and object files                                             #
# ------------------------------------------------------------------ #
GENERATED_C  := parser.tab.c lex.yy.c
GENERATED_H  := parser.tab.h
SOURCES      := ast.c main.c $(GENERATED_C)
OBJECTS      := $(SOURCES:.c=.o)

# ------------------------------------------------------------------ #
#  Default target                                                      #
# ------------------------------------------------------------------ #
.PHONY: all
all: $(EXE)

# ------------------------------------------------------------------ #
#  Bison step: generate parser.tab.c and parser.tab.h                 #
# ------------------------------------------------------------------ #
parser.tab.c parser.tab.h: parser.y
	$(BISON) $(BISONFLAGS) parser.y

# ------------------------------------------------------------------ #
#  Flex step: generate lex.yy.c                                        #
#  Must depend on parser.tab.h so the token header exists first.      #
# ------------------------------------------------------------------ #
lex.yy.c: lexer.l parser.tab.h
	$(FLEX) $(FLEXFLAGS) -o lex.yy.c lexer.l

# ------------------------------------------------------------------ #
#  Compilation rules                                                   #
# ------------------------------------------------------------------ #
ast.o: ast.c ast.h
	$(CC) $(CFLAGS) -c ast.c -o ast.o

main.o: main.c ast.h parser.tab.h
	$(CC) $(CFLAGS) -c main.c -o main.o

parser.tab.o: parser.tab.c parser.tab.h ast.h
	$(CC) $(CFLAGS) -c parser.tab.c -o parser.tab.o

lex.yy.o: lex.yy.c parser.tab.h ast.h
	$(CC) $(CFLAGS) -Wno-unused-parameter -c lex.yy.c -o lex.yy.o

# ------------------------------------------------------------------ #
#  Link                                                                #
# ------------------------------------------------------------------ #
$(EXE): ast.o main.o parser.tab.o lex.yy.o
	$(CC) $(CFLAGS) -o $(EXE) ast.o main.o parser.tab.o lex.yy.o

# ------------------------------------------------------------------ #
#  Test                                                                #
# ------------------------------------------------------------------ #
.PHONY: test
test: $(EXE)
ifeq ($(OS),Windows_NT)
	@powershell -ExecutionPolicy Bypass -File tests/run_tests.ps1 $(EXE)
else
	@bash tests/run_tests.sh ./$(EXE)
endif

# ------------------------------------------------------------------ #
#  Clean                                                               #
# ------------------------------------------------------------------ #
.PHONY: clean
clean:
ifeq ($(OS),Windows_NT)
	-$(RM) $(EXE) *.o parser.tab.c parser.tab.h lex.yy.c parser.output 2>$(NULL)
else
	$(RM) $(EXE) *.o parser.tab.c parser.tab.h lex.yy.c parser.output
endif
