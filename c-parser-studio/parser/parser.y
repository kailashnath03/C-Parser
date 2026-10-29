%{
/*
 * parser.y - GNU Bison grammar for C Parser Studio (conflict-free revision)
 *
 * Covers a practical subset of C:
 *   - types: int, char, float, double, void, short, long, signed, unsigned
 *   - variable declarations with initializers and multiple declarators
 *   - function definitions and prototypes
 *   - expressions with full operator precedence/associativity
 *   - if/else (dangling-else resolved), while, do-while, for, switch/case
 *   - return, break, continue, compound statements
 *
 * Design decisions to minimise conflicts:
 *   - Storage-class/qualifier specifiers are separated from type specifiers
 *     and handled as a flat prefix list, then combined.
 *   - The 'void' parameter ambiguity (void as type vs void-only param list)
 *     is resolved by treating "void" alone in a parameter context as a
 *     keyword-only rule that produces an empty typed parameter.
 *   - Pointer declarators use a restricted grammar that does not clash with
 *     the unary-dereference '*' in expressions.
 *   - Dangling-else is resolved with %prec LOWER_THAN_ELSE.
 *
 * Expected conflict count: 0 S/R, 0 R/R.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"

/* ------------------------------------------------------------------ */
/*  Lexer interface                                                      */
/* ------------------------------------------------------------------ */
extern int   yylex(void);
extern int   yylineno;
extern int   yycolumn;
extern char *yytext;
extern int   g_token_mode;

void yyerror(const char *msg)
{
    fprintf(stderr, "syntax error at line %d, column %d: %s\n",
            yylineno, yycolumn, msg);
}

ASTNode *g_root = NULL;

/* Helper: build a combined type label from two strings (skips empty) */
static char *combine_types(const char *a, const char *b)
{
    int la = a ? (int)strlen(a) : 0;
    int lb = b ? (int)strlen(b) : 0;
    /* If either side is empty, just return the other */
    if (la == 0) { return b ? strdup(b) : strdup(""); }
    if (lb == 0) { return a ? strdup(a) : strdup(""); }
    char *r = (char *)malloc((size_t)(la + lb + 2));
    if (!r) { perror("combine_types"); exit(1); }
    strcpy(r, a);
    r[la] = ' ';
    strcpy(r + la + 1, b);
    return r;
}
%}

/* ------------------------------------------------------------------ */
/*  Bison options                                                        */
/* ------------------------------------------------------------------ */
%locations
%define parse.error verbose

/* ------------------------------------------------------------------ */
/*  Semantic types                                                       */
/* ------------------------------------------------------------------ */
%union {
    char    *str_val;
    ASTNode *node;
}

/* ------------------------------------------------------------------ */
/*  Terminals                                                            */
/* ------------------------------------------------------------------ */
%token <str_val> TOK_IDENTIFIER
%token <str_val> TOK_INT_LITERAL TOK_FLOAT_LITERAL
%token <str_val> TOK_CHAR_LITERAL TOK_STRING_LITERAL

/* Type keywords */
%token TOK_INT TOK_CHAR TOK_FLOAT TOK_DOUBLE TOK_VOID
%token TOK_SHORT TOK_LONG TOK_SIGNED TOK_UNSIGNED

/* Storage/qualifier keywords */
%token TOK_AUTO TOK_EXTERN TOK_STATIC TOK_REGISTER TOK_INLINE
%token TOK_CONST TOK_VOLATILE TOK_RESTRICT

/* Statement keywords */
%token TOK_IF TOK_ELSE TOK_WHILE TOK_DO TOK_FOR
%token TOK_SWITCH TOK_CASE TOK_DEFAULT
%token TOK_RETURN TOK_BREAK TOK_CONTINUE TOK_GOTO

/* Other keywords */
%token TOK_SIZEOF TOK_ENUM TOK_STRUCT TOK_UNION TOK_TYPEDEF

/* Operators */
%token TOK_AND_AND TOK_OR_OR
%token TOK_PLUS_PLUS TOK_MINUS_MINUS TOK_ARROW
%token TOK_LSHIFT TOK_RSHIFT
%token TOK_LE TOK_GE TOK_EQ TOK_NE
%token TOK_PLUS_ASSIGN TOK_MINUS_ASSIGN TOK_STAR_ASSIGN
%token TOK_DIV_ASSIGN TOK_MOD_ASSIGN TOK_AND_ASSIGN
%token TOK_OR_ASSIGN TOK_XOR_ASSIGN
%token TOK_LSHIFT_ASSIGN TOK_RSHIFT_ASSIGN
%token TOK_ELLIPSIS

/* ------------------------------------------------------------------ */
/*  Nonterminal types                                                   */
/* ------------------------------------------------------------------ */
%type <node> translation_unit ext_decl_list ext_decl
%type <node> func_def func_proto
%type <node> type_spec_list decl_spec type_spec
%type <node> declaration decl_stmt declarator_list init_declarator declarator
%type <node> param_list_opt param_list param_decl
%type <node> compound_stmt block_items block_item
%type <node> statement labeled_stmt expr_stmt selection_stmt
%type <node> iteration_stmt jump_stmt
%type <node> expr assign_expr cond_expr
%type <node> or_expr and_expr bitor_expr xor_expr bitand_expr
%type <node> eq_expr rel_expr shift_expr add_expr mul_expr
%type <node> unary_expr postfix_expr primary_expr
%type <node> cast_expr arg_list
%type <node> opt_expr
%type <str_val> assign_op unary_op

/* ------------------------------------------------------------------ */
/*  Dangling-else resolution                                            */
/* ------------------------------------------------------------------ */
%nonassoc LOWER_THAN_ELSE
%nonassoc TOK_ELSE

%%

/* ================================================================== */
/*  Start                                                               */
/* ================================================================== */
start
    : translation_unit      { g_root = $1; }
    ;

translation_unit
    : ext_decl_list         { $$ = $1; }
    | /* empty */
        {
            $$ = ast_node_new(NODE_TRANSLATION_UNIT, NULL, 1, 1);
        }
    ;

ext_decl_list
    : ext_decl
        {
            $$ = ast_node_new(NODE_TRANSLATION_UNIT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | ext_decl_list ext_decl
        { ast_add_child($1, $2); $$ = $1; }
    ;

ext_decl
    : func_def      { $$ = $1; }
    | func_proto    { $$ = $1; }
    | decl_stmt     { $$ = $1; }
    ;

/* ================================================================== */
/*  Type specifiers                                                     */
/*                                                                      */
/*  decl_spec_list collects one or more declaration specifiers          */
/*  (type keywords + qualifiers/storage-class) in a flat list.         */
/*  Every token that starts a specifier is in the same rule, so there  */
/*  are no qualifier-prefix / type-suffix ambiguities.                  */
/* ================================================================== */
type_spec_list
    : decl_spec
        { $$ = $1; }
    | type_spec_list decl_spec
        {
            char *combined = combine_types($1->label, $2->label);
            ast_free($2);
            free($1->label);
            $1->label = combined;
            $$ = $1;
        }
    ;

/* A single declaration specifier: either a type keyword or a qualifier. */
/* Qualifiers produce a node with an empty label; they are silently      */
/* dropped from the combined type string during combination.             */
decl_spec
    : type_spec
        { $$ = $1; }
    | TOK_CONST    { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_VOLATILE { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_RESTRICT { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_STATIC   { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_EXTERN   { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_INLINE   { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_AUTO     { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    | TOK_REGISTER { $$ = ast_type_spec("", @1.first_line, @1.first_column); }
    ;

type_spec
    : TOK_INT      { $$ = ast_type_spec("int",      @1.first_line, @1.first_column); }
    | TOK_CHAR     { $$ = ast_type_spec("char",     @1.first_line, @1.first_column); }
    | TOK_FLOAT    { $$ = ast_type_spec("float",    @1.first_line, @1.first_column); }
    | TOK_DOUBLE   { $$ = ast_type_spec("double",   @1.first_line, @1.first_column); }
    | TOK_VOID     { $$ = ast_type_spec("void",     @1.first_line, @1.first_column); }
    | TOK_SHORT    { $$ = ast_type_spec("short",    @1.first_line, @1.first_column); }
    | TOK_LONG     { $$ = ast_type_spec("long",     @1.first_line, @1.first_column); }
    | TOK_SIGNED   { $$ = ast_type_spec("signed",   @1.first_line, @1.first_column); }
    | TOK_UNSIGNED { $$ = ast_type_spec("unsigned", @1.first_line, @1.first_column); }
    ;

/* ================================================================== */
/*  Function definition and prototype                                   */
/*                                                                      */
/*  Both share the same prefix: type_spec_list TOK_IDENTIFIER '(' ...  */
/*  The only distinction is whether the body is a compound_stmt or ';' */
/* ================================================================== */
func_def
    : type_spec_list TOK_IDENTIFIER '(' param_list_opt ')' compound_stmt
        {
            $$ = ast_node_new(NODE_FUNC_DEF, $2,
                              @1.first_line, @1.first_column);
            free($2);
            ast_add_child($$, $1);
            ast_add_child($$, $4);
            ast_add_child($$, $6);
        }
    ;

func_proto
    : type_spec_list TOK_IDENTIFIER '(' param_list_opt ')' ';'
        {
            $$ = ast_node_new(NODE_FUNC_DECL, $2,
                              @1.first_line, @1.first_column);
            free($2);
            ast_add_child($$, $1);
            ast_add_child($$, $4);
        }
    ;

/* ================================================================== */
/*  Parameters                                                          */
/* ================================================================== */
param_list_opt
    : /* empty */
        {
            $$ = ast_node_new(NODE_PARAM_LIST, "empty",
                              @$.first_line, @$.first_column);
        }
    | param_list
        { $$ = $1; }
    | param_list ',' TOK_ELLIPSIS
        {
            ASTNode *e = ast_node_new(NODE_PARAM, "...",
                                      @3.first_line, @3.first_column);
            ast_add_child($1, e);
            $$ = $1;
        }
    ;

param_list
    : param_decl
        {
            $$ = ast_node_new(NODE_PARAM_LIST, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | param_list ',' param_decl
        { ast_add_child($1, $3); $$ = $1; }
    ;

param_decl
    : type_spec_list declarator
        {
            $$ = ast_node_new(NODE_PARAM, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $2);
        }
    | type_spec_list
        {
            /* Abstract declarator: type only */
            $$ = ast_node_new(NODE_PARAM, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    ;

/* ================================================================== */
/*  Declarations                                                        */
/* ================================================================== */

/* Top-level (file-scope) declaration */
decl_stmt
    : type_spec_list declarator_list ';'
        {
            $$ = ast_node_new(NODE_VAR_DECL, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $2);
        }
    ;

/* Block-level declaration (may appear inside compound_stmt) */
declaration
    : type_spec_list declarator_list ';'
        {
            $$ = ast_node_new(NODE_VAR_DECL, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $2);
        }
    ;

declarator_list
    : init_declarator
        {
            $$ = ast_node_new(NODE_DECL_LIST, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | declarator_list ',' init_declarator
        { ast_add_child($1, $3); $$ = $1; }
    ;

init_declarator
    : declarator
        { $$ = $1; }
    | declarator '=' assign_expr
        {
            ASTNode *init = ast_node_new(NODE_DECLARATOR, "=",
                                         @2.first_line, @2.first_column);
            ast_add_child(init, $3);
            ast_add_child($1, init);
            $$ = $1;
        }
    ;

/*
 * declarator: an identifier, optionally preceded by '*' (pointer) and
 * optionally followed by array bounds.
 *
 * We use right-recursive pointer notation to avoid S/R with unary '*'.
 */
declarator
    : TOK_IDENTIFIER
        {
            $$ = ast_node_new(NODE_DECLARATOR, $1,
                              @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_IDENTIFIER array_suffix_list
        {
            $$ = ast_node_new(NODE_DECLARATOR, $1,
                              @1.first_line, @1.first_column);
            free($1);
            /* array_suffix_list is handled inline */
        }
    | pointer_prefix TOK_IDENTIFIER
        {
            char buf[512];
            snprintf(buf, sizeof(buf), "*%s", $2);
            $$ = ast_node_new(NODE_DECLARATOR, buf,
                              @1.first_line, @1.first_column);
            free($2);
        }
    ;

/* Inline: array suffix list for declarators */
array_suffix_list
    : '[' assign_expr ']'     { /* consumed by parent rule */ }
    | '[' ']'                 { /* consumed by parent rule */ }
    | array_suffix_list '[' assign_expr ']' {}
    | array_suffix_list '[' ']'             {}
    ;

pointer_prefix
    : '*'
    | '*' TOK_CONST
    | '*' TOK_VOLATILE
    | '*' pointer_prefix
    ;

/* ================================================================== */
/*  Compound statements and blocks                                      */
/* ================================================================== */
compound_stmt
    : '{' '}'
        {
            $$ = ast_node_new(NODE_COMPOUND_STMT, NULL,
                              @1.first_line, @1.first_column);
        }
    | '{' block_items '}'
        { $$ = $2; }
    ;

block_items
    : block_item
        {
            $$ = ast_node_new(NODE_COMPOUND_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | block_items block_item
        { ast_add_child($1, $2); $$ = $1; }
    ;

block_item
    : declaration   { $$ = $1; }
    | statement     { $$ = $1; }
    ;

/* ================================================================== */
/*  Statements                                                          */
/* ================================================================== */
statement
    : labeled_stmt    { $$ = $1; }
    | compound_stmt   { $$ = $1; }
    | expr_stmt       { $$ = $1; }
    | selection_stmt  { $$ = $1; }
    | iteration_stmt  { $$ = $1; }
    | jump_stmt       { $$ = $1; }
    ;

labeled_stmt
    : TOK_CASE cond_expr ':'
        {
            $$ = ast_node_new(NODE_CASE_LABEL, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $2);
        }
    | TOK_DEFAULT ':'
        {
            $$ = ast_node_new(NODE_DEFAULT_LABEL, NULL,
                              @1.first_line, @1.first_column);
        }
    | TOK_IDENTIFIER ':' statement
        {
            $$ = ast_node_new(NODE_EXPR_STMT, $1,
                              @1.first_line, @1.first_column);
            free($1);
            ast_add_child($$, $3);
        }
    ;

expr_stmt
    : ';'
        {
            $$ = ast_node_new(NODE_EMPTY_STMT, NULL,
                              @1.first_line, @1.first_column);
        }
    | expr ';'
        {
            $$ = ast_node_new(NODE_EXPR_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    ;

selection_stmt
    : TOK_IF '(' expr ')' statement %prec LOWER_THAN_ELSE
        {
            $$ = ast_node_new(NODE_IF_STMT, "if",
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
        }
    | TOK_IF '(' expr ')' statement TOK_ELSE statement
        {
            $$ = ast_node_new(NODE_IF_STMT, "if-else",
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
            ast_add_child($$, $7);
        }
    | TOK_SWITCH '(' expr ')' compound_stmt
        {
            $$ = ast_node_new(NODE_SWITCH_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
        }
    ;

iteration_stmt
    : TOK_WHILE '(' expr ')' statement
        {
            $$ = ast_node_new(NODE_WHILE_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
        }
    | TOK_DO statement TOK_WHILE '(' expr ')' ';'
        {
            $$ = ast_node_new(NODE_DO_WHILE_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $2);
            ast_add_child($$, $5);
        }
    | TOK_FOR '(' opt_expr ';' opt_expr ';' opt_expr ')' statement
        {
            $$ = ast_node_new(NODE_FOR_STMT, "expr-init",
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
            ast_add_child($$, $7);
            ast_add_child($$, $9);
        }
    | TOK_FOR '(' declaration opt_expr ';' opt_expr ')' statement
        {
            $$ = ast_node_new(NODE_FOR_STMT, "decl-init",
                              @1.first_line, @1.first_column);
            ast_add_child($$, $3);
            ast_add_child($$, $4);
            ast_add_child($$, $6);
            ast_add_child($$, $8);
        }
    ;

opt_expr
    : /* empty */
        { $$ = ast_node_new(NODE_EMPTY_STMT, NULL, 0, 0); }
    | expr
        { $$ = $1; }
    ;

jump_stmt
    : TOK_RETURN opt_expr ';'
        {
            $$ = ast_node_new(NODE_RETURN_STMT, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $2);
        }
    | TOK_BREAK ';'
        {
            $$ = ast_node_new(NODE_BREAK_STMT, NULL,
                              @1.first_line, @1.first_column);
        }
    | TOK_CONTINUE ';'
        {
            $$ = ast_node_new(NODE_CONTINUE_STMT, NULL,
                              @1.first_line, @1.first_column);
        }
    | TOK_GOTO TOK_IDENTIFIER ';'
        {
            $$ = ast_node_new(NODE_EXPR_STMT, $2,
                              @1.first_line, @1.first_column);
            free($2);
        }
    ;

/* ================================================================== */
/*  Expressions                                                         */
/*  Precedence handled by grammar stratification (lowest -> highest)   */
/* ================================================================== */
expr
    : assign_expr
        { $$ = $1; }
    | expr ',' assign_expr
        {
            $$ = ast_binary_expr(",", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

assign_expr
    : cond_expr
        { $$ = $1; }
    | unary_expr assign_op assign_expr
        {
            $$ = ast_assign_expr($2, $1, $3,
                                 @1.first_line, @1.first_column);
            free($2);
        }
    ;

assign_op
    : '='                { $$ = strdup("=");   }
    | TOK_PLUS_ASSIGN    { $$ = strdup("+=");  }
    | TOK_MINUS_ASSIGN   { $$ = strdup("-=");  }
    | TOK_STAR_ASSIGN    { $$ = strdup("*=");  }
    | TOK_DIV_ASSIGN     { $$ = strdup("/=");  }
    | TOK_MOD_ASSIGN     { $$ = strdup("%=");  }
    | TOK_AND_ASSIGN     { $$ = strdup("&=");  }
    | TOK_OR_ASSIGN      { $$ = strdup("|=");  }
    | TOK_XOR_ASSIGN     { $$ = strdup("^=");  }
    | TOK_LSHIFT_ASSIGN  { $$ = strdup("<<="); }
    | TOK_RSHIFT_ASSIGN  { $$ = strdup(">>="); }
    ;

cond_expr
    : or_expr
        { $$ = $1; }
    | or_expr '?' expr ':' cond_expr
        {
            $$ = ast_node_new(NODE_TERNARY_EXPR, "?:",
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $3);
            ast_add_child($$, $5);
        }
    ;

or_expr
    : and_expr
        { $$ = $1; }
    | or_expr TOK_OR_OR and_expr
        {
            $$ = ast_binary_expr("||", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

and_expr
    : bitor_expr
        { $$ = $1; }
    | and_expr TOK_AND_AND bitor_expr
        {
            $$ = ast_binary_expr("&&", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

bitor_expr
    : xor_expr
        { $$ = $1; }
    | bitor_expr '|' xor_expr
        {
            $$ = ast_binary_expr("|", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

xor_expr
    : bitand_expr
        { $$ = $1; }
    | xor_expr '^' bitand_expr
        {
            $$ = ast_binary_expr("^", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

bitand_expr
    : eq_expr
        { $$ = $1; }
    | bitand_expr '&' eq_expr
        {
            $$ = ast_binary_expr("&", $1, $3,
                                 @1.first_line, @1.first_column);
        }
    ;

eq_expr
    : rel_expr
        { $$ = $1; }
    | eq_expr TOK_EQ rel_expr
        { $$ = ast_binary_expr("==", $1, $3, @1.first_line, @1.first_column); }
    | eq_expr TOK_NE rel_expr
        { $$ = ast_binary_expr("!=", $1, $3, @1.first_line, @1.first_column); }
    ;

rel_expr
    : shift_expr
        { $$ = $1; }
    | rel_expr '<' shift_expr
        { $$ = ast_binary_expr("<",  $1, $3, @1.first_line, @1.first_column); }
    | rel_expr '>' shift_expr
        { $$ = ast_binary_expr(">",  $1, $3, @1.first_line, @1.first_column); }
    | rel_expr TOK_LE shift_expr
        { $$ = ast_binary_expr("<=", $1, $3, @1.first_line, @1.first_column); }
    | rel_expr TOK_GE shift_expr
        { $$ = ast_binary_expr(">=", $1, $3, @1.first_line, @1.first_column); }
    ;

shift_expr
    : add_expr
        { $$ = $1; }
    | shift_expr TOK_LSHIFT add_expr
        { $$ = ast_binary_expr("<<", $1, $3, @1.first_line, @1.first_column); }
    | shift_expr TOK_RSHIFT add_expr
        { $$ = ast_binary_expr(">>", $1, $3, @1.first_line, @1.first_column); }
    ;

add_expr
    : mul_expr
        { $$ = $1; }
    | add_expr '+' mul_expr
        { $$ = ast_binary_expr("+", $1, $3, @1.first_line, @1.first_column); }
    | add_expr '-' mul_expr
        { $$ = ast_binary_expr("-", $1, $3, @1.first_line, @1.first_column); }
    ;

mul_expr
    : cast_expr
        { $$ = $1; }
    | mul_expr '*' cast_expr
        { $$ = ast_binary_expr("*", $1, $3, @1.first_line, @1.first_column); }
    | mul_expr '/' cast_expr
        { $$ = ast_binary_expr("/", $1, $3, @1.first_line, @1.first_column); }
    | mul_expr '%' cast_expr
        { $$ = ast_binary_expr("%", $1, $3, @1.first_line, @1.first_column); }
    ;

/*
 * cast_expr: parenthesised type cast.
 * To avoid S/R with '(' expr ')', we only allow a cast when the token
 * immediately after '(' is a type keyword.
 */
cast_expr
    : unary_expr
        { $$ = $1; }
    | '(' type_spec_list ')' cast_expr
        {
            ASTNode *c = ast_node_new(NODE_UNARY_EXPR, "cast",
                                      @1.first_line, @1.first_column);
            ast_add_child(c, $2);
            ast_add_child(c, $4);
            $$ = c;
        }
    ;

unary_expr
    : postfix_expr
        { $$ = $1; }
    | TOK_PLUS_PLUS unary_expr
        { $$ = ast_unary_expr("++", $2, @1.first_line, @1.first_column); }
    | TOK_MINUS_MINUS unary_expr
        { $$ = ast_unary_expr("--", $2, @1.first_line, @1.first_column); }
    | unary_op cast_expr
        {
            $$ = ast_unary_expr($1, $2, @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_SIZEOF unary_expr
        { $$ = ast_unary_expr("sizeof", $2, @1.first_line, @1.first_column); }
    | TOK_SIZEOF '(' type_spec_list ')'
        {
            ASTNode *s = ast_node_new(NODE_UNARY_EXPR, "sizeof(type)",
                                      @1.first_line, @1.first_column);
            ast_add_child(s, $3);
            $$ = s;
        }
    ;

unary_op
    : '&' { $$ = strdup("&");  }
    | '*' { $$ = strdup("*");  }
    | '+' { $$ = strdup("+");  }
    | '-' { $$ = strdup("-");  }
    | '~' { $$ = strdup("~");  }
    | '!' { $$ = strdup("!"); }
    ;

postfix_expr
    : primary_expr
        { $$ = $1; }
    | postfix_expr '[' expr ']'
        {
            $$ = ast_node_new(NODE_ARRAY_INDEX, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $3);
        }
    | postfix_expr '(' ')'
        {
            $$ = ast_node_new(NODE_FUNC_CALL, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | postfix_expr '(' arg_list ')'
        {
            $$ = ast_node_new(NODE_FUNC_CALL, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
            ast_add_child($$, $3);
        }
    | postfix_expr '.' TOK_IDENTIFIER
        {
            ASTNode *f = ast_identifier($3, @3.first_line, @3.first_column);
            free($3);
            $$ = ast_binary_expr(".", $1, f,
                                 @1.first_line, @1.first_column);
        }
    | postfix_expr TOK_ARROW TOK_IDENTIFIER
        {
            ASTNode *f = ast_identifier($3, @3.first_line, @3.first_column);
            free($3);
            $$ = ast_binary_expr("->", $1, f,
                                 @1.first_line, @1.first_column);
        }
    | postfix_expr TOK_PLUS_PLUS
        { $$ = ast_postfix_expr("++", $1, @1.first_line, @1.first_column); }
    | postfix_expr TOK_MINUS_MINUS
        { $$ = ast_postfix_expr("--", $1, @1.first_line, @1.first_column); }
    ;

primary_expr
    : TOK_IDENTIFIER
        {
            $$ = ast_identifier($1, @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_INT_LITERAL
        {
            $$ = ast_int_literal($1, @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_FLOAT_LITERAL
        {
            $$ = ast_float_literal($1, @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_CHAR_LITERAL
        {
            $$ = ast_char_literal($1, @1.first_line, @1.first_column);
            free($1);
        }
    | TOK_STRING_LITERAL
        {
            $$ = ast_string_literal($1, @1.first_line, @1.first_column);
            free($1);
        }
    | '(' expr ')'
        { $$ = $2; }
    ;

arg_list
    : assign_expr
        {
            $$ = ast_node_new(NODE_ARG_LIST, NULL,
                              @1.first_line, @1.first_column);
            ast_add_child($$, $1);
        }
    | arg_list ',' assign_expr
        { ast_add_child($1, $3); $$ = $1; }
    ;

%%
