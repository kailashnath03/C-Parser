/* ast.h - Abstract Syntax Tree definitions for C Parser Studio
 * 
 * Defines node types and structures for representing a subset of C.
 */

#ifndef AST_H
#define AST_H

#include <stdio.h>

/* ------------------------------------------------------------------ */
/*  Node type enumeration                                               */
/* ------------------------------------------------------------------ */
typedef enum {
    /* Top-level */
    NODE_TRANSLATION_UNIT,

    /* Declarations */
    NODE_VAR_DECL,          /* variable declaration                  */
    NODE_FUNC_DECL,         /* function prototype                    */
    NODE_FUNC_DEF,          /* function definition                   */
    NODE_PARAM,             /* a single parameter                    */
    NODE_PARAM_LIST,        /* list of parameters                    */
    NODE_DECLARATOR,        /* name + optional initializer           */
    NODE_DECL_LIST,         /* comma-separated declarators           */
    NODE_TYPE_SPEC,         /* a type specifier                      */

    /* Statements */
    NODE_COMPOUND_STMT,     /* { ... }                               */
    NODE_EXPR_STMT,         /* expression;                           */
    NODE_IF_STMT,           /* if / if-else                          */
    NODE_WHILE_STMT,        /* while                                 */
    NODE_DO_WHILE_STMT,     /* do-while                              */
    NODE_FOR_STMT,          /* for                                   */
    NODE_RETURN_STMT,       /* return                                */
    NODE_BREAK_STMT,        /* break                                 */
    NODE_CONTINUE_STMT,     /* continue                              */
    NODE_EMPTY_STMT,        /* ;                                     */
    NODE_SWITCH_STMT,       /* switch                                */
    NODE_CASE_LABEL,        /* case <expr>:                          */
    NODE_DEFAULT_LABEL,     /* default:                              */

    /* Expressions */
    NODE_BINARY_EXPR,       /* left op right                         */
    NODE_UNARY_EXPR,        /* op operand                            */
    NODE_POSTFIX_EXPR,      /* operand op  (++ / --)                 */
    NODE_ASSIGN_EXPR,       /* left = right                          */
    NODE_FUNC_CALL,         /* f(args)                               */
    NODE_ARRAY_INDEX,       /* a[i]                                  */
    NODE_ARG_LIST,          /* function-call argument list           */
    NODE_TERNARY_EXPR,      /* cond ? then : else                    */

    /* Literals / primary */
    NODE_IDENTIFIER,
    NODE_INT_LITERAL,
    NODE_FLOAT_LITERAL,
    NODE_CHAR_LITERAL,
    NODE_STRING_LITERAL,

    /* Sentinel */
    NODE_COUNT
} NodeType;

/* ------------------------------------------------------------------ */
/*  AST node structure                                                  */
/* ------------------------------------------------------------------ */
typedef struct ASTNode {
    NodeType    type;

    /* Optional label: operator string, identifier name, literal text,
       type name, etc.  Heap-allocated; may be NULL.                  */
    char       *label;

    /* Children (dynamic array) */
    struct ASTNode **children;
    int              child_count;
    int              child_capacity;

    /* Source location (best effort) */
    int line;
    int col;
} ASTNode;

/* ------------------------------------------------------------------ */
/*  Construction helpers                                                */
/* ------------------------------------------------------------------ */
ASTNode *ast_node_new(NodeType type, const char *label, int line, int col);
void     ast_add_child(ASTNode *parent, ASTNode *child);

/* Convenience wrappers */
ASTNode *ast_int_literal   (const char *value, int line, int col);
ASTNode *ast_float_literal (const char *value, int line, int col);
ASTNode *ast_char_literal  (const char *value, int line, int col);
ASTNode *ast_string_literal(const char *value, int line, int col);
ASTNode *ast_identifier    (const char *name,  int line, int col);
ASTNode *ast_type_spec     (const char *type,  int line, int col);
ASTNode *ast_binary_expr   (const char *op,    ASTNode *left, ASTNode *right, int line, int col);
ASTNode *ast_unary_expr    (const char *op,    ASTNode *operand, int line, int col);
ASTNode *ast_postfix_expr  (const char *op,    ASTNode *operand, int line, int col);
ASTNode *ast_assign_expr   (const char *op,    ASTNode *left,  ASTNode *right, int line, int col);

/* ------------------------------------------------------------------ */
/*  Output helpers                                                      */
/* ------------------------------------------------------------------ */
/* Human-readable tree print */
void ast_print(const ASTNode *node, int indent);

/* JSON serialization (written to fp) */
void ast_print_json(const ASTNode *node, FILE *fp, int indent);

/* ------------------------------------------------------------------ */
/*  Memory management                                                   */
/* ------------------------------------------------------------------ */
void ast_free(ASTNode *node);

/* Node-type name (for printing) */
const char *ast_node_type_name(NodeType t);

#endif /* AST_H */

