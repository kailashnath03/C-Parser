/*
 * main.c - Driver for C Parser Studio
 *
 * Usage:
 *   cparser [options] [file.c]
 *
 * Options:
 *   --tokens   Print token stream and exit
 *   --ast      Print AST after parsing (default when no option given)
 *   --json     Print AST as JSON
 *   --help     Print usage
 *
 * Exit codes:
 *   0  - parse succeeded
 *   1  - parse error (invalid input)
 *   2  - I/O or internal error
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

/* ------------------------------------------------------------------ */
/*  Declarations provided by the Bison / Flex generated files          */
/* ------------------------------------------------------------------ */
extern int   yyparse(void);
extern void  yyrestart(FILE *f);
extern int   yylineno;
extern int   g_token_mode;   /* defined in lexer.l */
extern ASTNode *g_root;      /* set by the start rule */
extern FILE *yyin;

/* ------------------------------------------------------------------ */
/*  Usage                                                               */
/* ------------------------------------------------------------------ */
static void usage(const char *prog)
{
    fprintf(stderr,
        "C Parser Studio - Educational C parser using Flex and GNU Bison\n"
        "\n"
        "Usage: %s [options] [file.c]\n"
        "\n"
        "Options:\n"
        "  --tokens    Lex the input and print the token stream, then exit\n"
        "  --ast       Parse and print the AST (default)\n"
        "  --json      Parse and print the AST as JSON (to stdout)\n"
        "  --help      Show this message\n"
        "\n"
        "If no file is given, reads from standard input.\n"
        "\n"
        "Exit codes:\n"
        "  0  success\n"
        "  1  syntax / lexical error\n"
        "  2  I/O or internal error\n",
        prog);
}

/* ------------------------------------------------------------------ */
/*  Main                                                                */
/* ------------------------------------------------------------------ */
int main(int argc, char *argv[])
{
    int    opt_tokens = 0;
    int    opt_ast    = 0;
    int    opt_json   = 0;
    char  *filename   = NULL;

    /* Parse arguments */
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0 || strcmp(argv[i], "-h") == 0) {
            usage(argv[0]);
            return 0;
        } else if (strcmp(argv[i], "--tokens") == 0) {
            opt_tokens = 1;
        } else if (strcmp(argv[i], "--ast") == 0) {
            opt_ast = 1;
        } else if (strcmp(argv[i], "--json") == 0) {
            opt_json = 1;
        } else if (argv[i][0] == '-') {
            fprintf(stderr, "error: unknown option '%s'\n", argv[i]);
            usage(argv[0]);
            return 2;
        } else {
            if (filename) {
                fprintf(stderr, "error: only one input file allowed\n");
                return 2;
            }
            filename = argv[i];
        }
    }

    /* Default to --ast if no display option given */
    if (!opt_tokens && !opt_json) opt_ast = 1;

    /* Open input */
    FILE *input = stdin;
    if (filename) {
        input = fopen(filename, "r");
        if (!input) {
            fprintf(stderr, "error: cannot open '%s'\n", filename);
            return 2;
        }
    }

    /* ---------------------------------------------------------------- */
    /*  Token mode                                                        */
    /* ---------------------------------------------------------------- */
    if (opt_tokens) {
        /* Print header */
        printf("%-20s %-30s %4s    %4s\n",
               "TOKEN_TYPE", "LEXEME", "LINE", "COL");
        printf("%-20s %-30s %4s    %4s\n",
               "----------", "------", "----", "---");

        g_token_mode = 1;
        yyrestart(input);

        /* Drain the lexer */
        extern int yylex(void);
        while (yylex() != 0)
            ;   /* actions inside yylex() print each token */

        if (filename) fclose(input);
        return 0;
    }

    /* ---------------------------------------------------------------- */
    /*  Parse mode                                                        */
    /* ---------------------------------------------------------------- */
    g_token_mode = 0;
    yyin = input;
    yyrestart(input);

    int parse_result = yyparse();

    if (filename) fclose(input);

    if (parse_result != 0) {
        /* yyerror() already printed a message to stderr */
        if (g_root) ast_free(g_root);
        return 1;
    }

    /* ---------------------------------------------------------------- */
    /*  Report success                                                    */
    /* ---------------------------------------------------------------- */
    fprintf(stderr, "Parsing successful.\n");

    /* ---------------------------------------------------------------- */
    /*  Print AST                                                         */
    /* ---------------------------------------------------------------- */
    if (opt_ast) {
        printf("=== Abstract Syntax Tree ===\n");
        if (g_root) {
            ast_print(g_root, 0);
        } else {
            printf("(empty translation unit)\n");
        }
    }

    if (opt_json) {
        if (g_root) {
            ast_print_json(g_root, stdout, 0);
            putchar('\n');
        } else {
            printf("null\n");
        }
    }

    if (g_root) ast_free(g_root);
    return 0;
}
