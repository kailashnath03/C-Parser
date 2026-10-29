%{
/*
 * lexer.l - Flex lexer for C Parser Studio
 *
 * Recognises a practical subset of C tokens.
 * Uses win_flex (Flex 2.6.4) on Windows.
 *
 * Token values are defined by Bison in parser.tab.h.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "parser.tab.h"

/* ------------------------------------------------------------------ */
/*  Source-position tracking                                            */
/* ------------------------------------------------------------------ */
int yycolumn = 1;

/* Called by Flex before each token action */
#define YY_USER_ACTION                          \
    yylloc.first_line   = yylineno;             \
    yylloc.first_column = yycolumn;             \
    yylloc.last_line    = yylineno;             \
    yylloc.last_column  = yycolumn + (int)yyleng - 1; \
    yycolumn           += (int)yyleng;

/* Token-debug mode: set by main() when --tokens flag is used */
int g_token_mode = 0;

/* Forward declaration */
static void print_token(const char *type, const char *lexeme);

%}

/* ------------------------------------------------------------------ */
/*  Flex options                                                        */
/* ------------------------------------------------------------------ */
%option noyywrap
%option yylineno
%option nounput
%option noinput

/* ------------------------------------------------------------------ */
/*  Exclusive start conditions                                          */
/* ------------------------------------------------------------------ */
%x BLOCK_COMMENT
%x STRING_LIT
%x CHAR_LIT

/* ------------------------------------------------------------------ */
/*  Helper definitions                                                  */
/* ------------------------------------------------------------------ */
DIGIT       [0-9]
HEXDIGIT    [0-9a-fA-F]
OCTDIGIT    [0-7]
LETTER      [a-zA-Z_]
ALNUM       [a-zA-Z_0-9]

INT_SUFFIX  ([uU][lL]?|[lL][uU]?|[lL][lL][uU]?|[uU][lL][lL])?
FLT_SUFFIX  [fFlL]?

DECINT      {DIGIT}+{INT_SUFFIX}
HEXINT      0[xX]{HEXDIGIT}+{INT_SUFFIX}
OCTINT      0{OCTDIGIT}+{INT_SUFFIX}

FLOAT1      {DIGIT}+\.{DIGIT}*([eE][+-]?{DIGIT}+)?{FLT_SUFFIX}
FLOAT2      \.{DIGIT}+([eE][+-]?{DIGIT}+)?{FLT_SUFFIX}
FLOAT3      {DIGIT}+[eE][+-]?{DIGIT}+{FLT_SUFFIX}

%%

 /* ----------------------------------------------------------------- */
 /*  Whitespace and newlines                                            */
 /* ----------------------------------------------------------------- */
[ \t\r]+        { /* skip; column already advanced by YY_USER_ACTION */ }
\n              { yycolumn = 1; }

 /* ----------------------------------------------------------------- */
 /*  Preprocessor directives: skip entire line                         */
 /* ----------------------------------------------------------------- */
^[ \t]*#[^\n]*  { /* skip preprocessor line */ }

 /* ----------------------------------------------------------------- */
 /*  Block comments (slash-star ... star-slash)                        */
 /* ----------------------------------------------------------------- */
"/*"            { BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>{
    [^*\n]+     { /* consume */ }
    "*"+[^*/\n] { /* consume */ }
    \n          { yycolumn = 1; }
    "*"+"/"     { BEGIN(INITIAL); }
    <<EOF>>     {
        fprintf(stderr, "error: unterminated block comment\n");
        return YYerror;
    }
}

 /* ----------------------------------------------------------------- */
 /*  Single-line comments                                               */
 /* ----------------------------------------------------------------- */
"//"[^\n]*      { /* skip */ }

 /* ----------------------------------------------------------------- */
 /*  String literals                                                    */
 /* ----------------------------------------------------------------- */
\"              {
    /* start collecting string */
    BEGIN(STRING_LIT);
    /* reset buffer */
    extern char g_str_buf[];
    extern int  g_str_len;
    g_str_buf[0] = '"';
    g_str_len    = 1;
}
<STRING_LIT>{
    \"          {
        extern char g_str_buf[];
        extern int  g_str_len;
        g_str_buf[g_str_len++] = '"';
        g_str_buf[g_str_len]   = '\0';
        BEGIN(INITIAL);
        yylval.str_val = strdup(g_str_buf);
        print_token("STRING_LITERAL", g_str_buf);
        return TOK_STRING_LITERAL;
    }
    \\[nrtbfv\\'\"0] {
        extern char g_str_buf[];
        extern int  g_str_len;
        g_str_buf[g_str_len++] = yytext[0];
        g_str_buf[g_str_len++] = yytext[1];
    }
    \n          {
        fprintf(stderr, "error:%d: unterminated string literal\n", yylineno);
        yycolumn = 1;
        BEGIN(INITIAL);
        return YYerror;
    }
    <<EOF>>     {
        fprintf(stderr, "error: unterminated string literal at EOF\n");
        return YYerror;
    }
    .           {
        extern char g_str_buf[];
        extern int  g_str_len;
        g_str_buf[g_str_len++] = yytext[0];
    }
}

 /* ----------------------------------------------------------------- */
 /*  Character literals                                                 */
 /* ----------------------------------------------------------------- */
\'              {
    extern char g_char_buf[];
    extern int  g_char_len;
    BEGIN(CHAR_LIT);
    g_char_buf[0] = '\'';
    g_char_len    = 1;
}
<CHAR_LIT>{
    \'          {
        extern char g_char_buf[];
        extern int  g_char_len;
        g_char_buf[g_char_len++] = '\'';
        g_char_buf[g_char_len]   = '\0';
        BEGIN(INITIAL);
        yylval.str_val = strdup(g_char_buf);
        print_token("CHAR_LITERAL", g_char_buf);
        return TOK_CHAR_LITERAL;
    }
    \\[nrtbfv\\'\"0] {
        extern char g_char_buf[];
        extern int  g_char_len;
        g_char_buf[g_char_len++] = yytext[0];
        g_char_buf[g_char_len++] = yytext[1];
    }
    \n          {
        fprintf(stderr, "error:%d: unterminated character literal\n", yylineno);
        yycolumn = 1;
        BEGIN(INITIAL);
        return YYerror;
    }
    <<EOF>>     {
        fprintf(stderr, "error: unterminated character literal at EOF\n");
        return YYerror;
    }
    .           {
        extern char g_char_buf[];
        extern int  g_char_len;
        g_char_buf[g_char_len++] = yytext[0];
    }
}

 /* ----------------------------------------------------------------- */
 /*  Floating-point literals (must come before integer rules)          */
 /* ----------------------------------------------------------------- */
{FLOAT1}|{FLOAT2}|{FLOAT3} {
    yylval.str_val = strdup(yytext);
    print_token("FLOAT_LITERAL", yytext);
    return TOK_FLOAT_LITERAL;
}

 /* ----------------------------------------------------------------- */
 /*  Integer literals                                                   */
 /* ----------------------------------------------------------------- */
{HEXINT}        {
    yylval.str_val = strdup(yytext);
    print_token("INT_LITERAL", yytext);
    return TOK_INT_LITERAL;
}
{OCTINT}        {
    yylval.str_val = strdup(yytext);
    print_token("INT_LITERAL", yytext);
    return TOK_INT_LITERAL;
}
{DECINT}        {
    yylval.str_val = strdup(yytext);
    print_token("INT_LITERAL", yytext);
    return TOK_INT_LITERAL;
}

 /* ----------------------------------------------------------------- */
 /*  Keywords (must come before IDENTIFIER rule)                       */
 /* ----------------------------------------------------------------- */
"auto"          { print_token("AUTO",       yytext); return TOK_AUTO;     }
"break"         { print_token("BREAK",      yytext); return TOK_BREAK;    }
"case"          { print_token("CASE",       yytext); return TOK_CASE;     }
"char"          { print_token("CHAR",       yytext); return TOK_CHAR;     }
"const"         { print_token("CONST",      yytext); return TOK_CONST;    }
"continue"      { print_token("CONTINUE",   yytext); return TOK_CONTINUE; }
"default"       { print_token("DEFAULT",    yytext); return TOK_DEFAULT;  }
"do"            { print_token("DO",         yytext); return TOK_DO;       }
"double"        { print_token("DOUBLE",     yytext); return TOK_DOUBLE;   }
"else"          { print_token("ELSE",       yytext); return TOK_ELSE;     }
"enum"          { print_token("ENUM",       yytext); return TOK_ENUM;     }
"extern"        { print_token("EXTERN",     yytext); return TOK_EXTERN;   }
"float"         { print_token("FLOAT",      yytext); return TOK_FLOAT;    }
"for"           { print_token("FOR",        yytext); return TOK_FOR;      }
"goto"          { print_token("GOTO",       yytext); return TOK_GOTO;     }
"if"            { print_token("IF",         yytext); return TOK_IF;       }
"inline"        { print_token("INLINE",     yytext); return TOK_INLINE;   }
"int"           { print_token("INT",        yytext); return TOK_INT;      }
"long"          { print_token("LONG",       yytext); return TOK_LONG;     }
"register"      { print_token("REGISTER",   yytext); return TOK_REGISTER; }
"restrict"      { print_token("RESTRICT",   yytext); return TOK_RESTRICT; }
"return"        { print_token("RETURN",     yytext); return TOK_RETURN;   }
"short"         { print_token("SHORT",      yytext); return TOK_SHORT;    }
"signed"        { print_token("SIGNED",     yytext); return TOK_SIGNED;   }
"sizeof"        { print_token("SIZEOF",     yytext); return TOK_SIZEOF;   }
"static"        { print_token("STATIC",     yytext); return TOK_STATIC;   }
"struct"        { print_token("STRUCT",     yytext); return TOK_STRUCT;   }
"switch"        { print_token("SWITCH",     yytext); return TOK_SWITCH;   }
"typedef"       { print_token("TYPEDEF",    yytext); return TOK_TYPEDEF;  }
"union"         { print_token("UNION",      yytext); return TOK_UNION;    }
"unsigned"      { print_token("UNSIGNED",   yytext); return TOK_UNSIGNED; }
"void"          { print_token("VOID",       yytext); return TOK_VOID;     }
"volatile"      { print_token("VOLATILE",   yytext); return TOK_VOLATILE; }
"while"         { print_token("WHILE",      yytext); return TOK_WHILE;    }

 /* ----------------------------------------------------------------- */
 /*  Identifiers                                                        */
 /* ----------------------------------------------------------------- */
{LETTER}{ALNUM}* {
    yylval.str_val = strdup(yytext);
    print_token("IDENTIFIER", yytext);
    return TOK_IDENTIFIER;
}

 /* ----------------------------------------------------------------- */
 /*  Multi-character operators (longest match first)                   */
 /* ----------------------------------------------------------------- */
"<<="           { print_token("LSHIFT_ASSIGN", yytext); return TOK_LSHIFT_ASSIGN; }
">>="           { print_token("RSHIFT_ASSIGN", yytext); return TOK_RSHIFT_ASSIGN; }
"..."           { print_token("ELLIPSIS",      yytext); return TOK_ELLIPSIS;      }
"&&"            { print_token("AND_AND",       yytext); return TOK_AND_AND;       }
"||"            { print_token("OR_OR",         yytext); return TOK_OR_OR;         }
"++"            { print_token("PLUS_PLUS",     yytext); return TOK_PLUS_PLUS;     }
"--"            { print_token("MINUS_MINUS",   yytext); return TOK_MINUS_MINUS;   }
"->"            { print_token("ARROW",         yytext); return TOK_ARROW;         }
"<<"            { print_token("LSHIFT",        yytext); return TOK_LSHIFT;        }
">>"            { print_token("RSHIFT",        yytext); return TOK_RSHIFT;        }
"<="            { print_token("LE",            yytext); return TOK_LE;            }
">="            { print_token("GE",            yytext); return TOK_GE;            }
"=="            { print_token("EQ",            yytext); return TOK_EQ;            }
"!="            { print_token("NE",            yytext); return TOK_NE;            }
"+="            { print_token("PLUS_ASSIGN",   yytext); return TOK_PLUS_ASSIGN;   }
"-="            { print_token("MINUS_ASSIGN",  yytext); return TOK_MINUS_ASSIGN;  }
"*="            { print_token("STAR_ASSIGN",   yytext); return TOK_STAR_ASSIGN;   }
"/="            { print_token("DIV_ASSIGN",    yytext); return TOK_DIV_ASSIGN;    }
"%="            { print_token("MOD_ASSIGN",    yytext); return TOK_MOD_ASSIGN;    }
"&="            { print_token("AND_ASSIGN",    yytext); return TOK_AND_ASSIGN;    }
"|="            { print_token("OR_ASSIGN",     yytext); return TOK_OR_ASSIGN;     }
"^="            { print_token("XOR_ASSIGN",    yytext); return TOK_XOR_ASSIGN;    }

 /* ----------------------------------------------------------------- */
 /*  Single-character operators and punctuation                        */
 /* ----------------------------------------------------------------- */
"+"             { print_token("PLUS",      yytext); return '+'; }
"-"             { print_token("MINUS",     yytext); return '-'; }
"*"             { print_token("STAR",      yytext); return '*'; }
"/"             { print_token("SLASH",     yytext); return '/'; }
"%"             { print_token("PERCENT",   yytext); return '%'; }
"&"             { print_token("AMP",       yytext); return '&'; }
"|"             { print_token("PIPE",      yytext); return '|'; }
"^"             { print_token("CARET",     yytext); return '^'; }
"~"             { print_token("TILDE",     yytext); return '~'; }
"!"             { print_token("BANG",      yytext); return '!'; }
"<"             { print_token("LT",        yytext); return '<'; }
">"             { print_token("GT",        yytext); return '>'; }
"="             { print_token("ASSIGN",    yytext); return '='; }
"?"             { print_token("QUESTION",  yytext); return '?'; }
":"             { print_token("COLON",     yytext); return ':'; }
";"             { print_token("SEMI",      yytext); return ';'; }
","             { print_token("COMMA",     yytext); return ','; }
"."             { print_token("DOT",       yytext); return '.'; }
"("             { print_token("LPAREN",    yytext); return '('; }
")"             { print_token("RPAREN",    yytext); return ')'; }
"["             { print_token("LBRACKET",  yytext); return '['; }
"]"             { print_token("RBRACKET",  yytext); return ']'; }
"{"             { print_token("LBRACE",    yytext); return '{'; }
"}"             { print_token("RBRACE",    yytext); return '}'; }

 /* ----------------------------------------------------------------- */
 /*  Invalid characters                                                 */
 /* ----------------------------------------------------------------- */
.               {
    fprintf(stderr, "error:%d:%d: invalid character '%s'\n",
            yylineno, yycolumn - 1, yytext);
    return YYerror;
}

%%

/* ------------------------------------------------------------------ */
/*  String / char accumulation buffers (referenced from actions above) */
/* ------------------------------------------------------------------ */
char g_str_buf[65536];
int  g_str_len = 0;

char g_char_buf[64];
int  g_char_len = 0;

/* ------------------------------------------------------------------ */
/*  Token debug output                                                  */
/* ------------------------------------------------------------------ */
static void print_token(const char *type, const char *lexeme)
{
    if (!g_token_mode) return;
    printf("%-20s %-30s %4d    %4d\n",
           type, lexeme, yylineno, yycolumn - (int)yyleng);
}
