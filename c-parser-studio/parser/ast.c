/* ast.c - AST node implementation for C Parser Studio */

#include "ast.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

/* ------------------------------------------------------------------ */
/*  Node type name table                                                */
/* ------------------------------------------------------------------ */
static const char *NODE_NAMES[NODE_COUNT] = {
    "TranslationUnit",
    "VarDecl",
    "FuncDecl",
    "FuncDef",
    "Param",
    "ParamList",
    "Declarator",
    "DeclList",
    "TypeSpec",
    "CompoundStmt",
    "ExprStmt",
    "IfStmt",
    "WhileStmt",
    "DoWhileStmt",
    "ForStmt",
    "ReturnStmt",
    "BreakStmt",
    "ContinueStmt",
    "EmptyStmt",
    "SwitchStmt",
    "CaseLabel",
    "DefaultLabel",
    "BinaryExpr",
    "UnaryExpr",
    "PostfixExpr",
    "AssignExpr",
    "FuncCall",
    "ArrayIndex",
    "ArgList",
    "TernaryExpr",
    "Identifier",
    "IntLiteral",
    "FloatLiteral",
    "CharLiteral",
    "StringLiteral",
};

const char *ast_node_type_name(NodeType t)
{
    if (t >= 0 && t < NODE_COUNT)
        return NODE_NAMES[t];
    return "Unknown";
}

/* ------------------------------------------------------------------ */
/*  Construction                                                        */
/* ------------------------------------------------------------------ */
ASTNode *ast_node_new(NodeType type, const char *label, int line, int col)
{
    ASTNode *n = (ASTNode *)calloc(1, sizeof(ASTNode));
    if (!n) { perror("ast_node_new: calloc"); exit(EXIT_FAILURE); }
    n->type  = type;
    n->label = label ? strdup(label) : NULL;
    n->line  = line;
    n->col   = col;
    return n;
}

void ast_add_child(ASTNode *parent, ASTNode *child)
{
    if (!parent || !child) return;
    if (parent->child_count >= parent->child_capacity) {
        int new_cap = parent->child_capacity ? parent->child_capacity * 2 : 4;
        parent->children = (ASTNode **)realloc(
            parent->children, (size_t)new_cap * sizeof(ASTNode *));
        if (!parent->children) { perror("ast_add_child: realloc"); exit(EXIT_FAILURE); }
        parent->child_capacity = new_cap;
    }
    parent->children[parent->child_count++] = child;
}

/* ------------------------------------------------------------------ */
/*  Convenience constructors                                            */
/* ------------------------------------------------------------------ */
ASTNode *ast_int_literal(const char *value, int line, int col)
    { return ast_node_new(NODE_INT_LITERAL, value, line, col); }

ASTNode *ast_float_literal(const char *value, int line, int col)
    { return ast_node_new(NODE_FLOAT_LITERAL, value, line, col); }

ASTNode *ast_char_literal(const char *value, int line, int col)
    { return ast_node_new(NODE_CHAR_LITERAL, value, line, col); }

ASTNode *ast_string_literal(const char *value, int line, int col)
    { return ast_node_new(NODE_STRING_LITERAL, value, line, col); }

ASTNode *ast_identifier(const char *name, int line, int col)
    { return ast_node_new(NODE_IDENTIFIER, name, line, col); }

ASTNode *ast_type_spec(const char *type, int line, int col)
    { return ast_node_new(NODE_TYPE_SPEC, type, line, col); }

ASTNode *ast_binary_expr(const char *op, ASTNode *left, ASTNode *right,
                          int line, int col)
{
    ASTNode *n = ast_node_new(NODE_BINARY_EXPR, op, line, col);
    ast_add_child(n, left);
    ast_add_child(n, right);
    return n;
}

ASTNode *ast_unary_expr(const char *op, ASTNode *operand, int line, int col)
{
    ASTNode *n = ast_node_new(NODE_UNARY_EXPR, op, line, col);
    ast_add_child(n, operand);
    return n;
}

ASTNode *ast_postfix_expr(const char *op, ASTNode *operand, int line, int col)
{
    ASTNode *n = ast_node_new(NODE_POSTFIX_EXPR, op, line, col);
    ast_add_child(n, operand);
    return n;
}

ASTNode *ast_assign_expr(const char *op, ASTNode *left, ASTNode *right,
                          int line, int col)
{
    ASTNode *n = ast_node_new(NODE_ASSIGN_EXPR, op, line, col);
    ast_add_child(n, left);
    ast_add_child(n, right);
    return n;
}

/* ------------------------------------------------------------------ */
/*  Printing - human-readable tree                                      */
/* ------------------------------------------------------------------ */
static void print_indent(int indent)
{
    for (int i = 0; i < indent; i++)
        fputs(i % 4 == 0 && i > 0 ? "|   " : "    ", stdout);
}

void ast_print(const ASTNode *node, int indent)
{
    if (!node) return;

    /* prefix for child connectors */
    if (indent > 0) {
        for (int i = 0; i < indent - 1; i++)
            fputs("    ", stdout);
        fputs("+-- ", stdout);
    }

    /* Node type name */
    printf("%s", ast_node_type_name(node->type));

    /* Optional label */
    if (node->label && node->label[0])
        printf(": %s", node->label);

    /* Source position */
    if (node->line > 0)
        printf("  [line %d, col %d]", node->line, node->col);

    putchar('\n');

    /* Recurse into children */
    for (int i = 0; i < node->child_count; i++)
        ast_print(node->children[i], indent + 1);
}

/* ------------------------------------------------------------------ */
/*  JSON serialization                                                  */
/* ------------------------------------------------------------------ */
static void json_indent(FILE *fp, int indent)
{
    for (int i = 0; i < indent * 2; i++) fputc(' ', fp);
}

/* Write a JSON-safe escaped string */
static void json_str(FILE *fp, const char *s)
{
    fputc('"', fp);
    if (s) {
        for (const char *p = s; *p; p++) {
            switch (*p) {
            case '"':  fputs("\\\"", fp); break;
            case '\\': fputs("\\\\", fp); break;
            case '\n': fputs("\\n",  fp); break;
            case '\r': fputs("\\r",  fp); break;
            case '\t': fputs("\\t",  fp); break;
            default:
                if ((unsigned char)*p < 0x20)
                    fprintf(fp, "\\u%04x", (unsigned char)*p);
                else
                    fputc(*p, fp);
            }
        }
    }
    fputc('"', fp);
}

void ast_print_json(const ASTNode *node, FILE *fp, int indent)
{
    if (!node) { fputs("null", fp); return; }

    json_indent(fp, indent);
    fputs("{\n", fp);

    json_indent(fp, indent + 1);
    fputs("\"type\": ", fp);
    json_str(fp, ast_node_type_name(node->type));
    fputs(",\n", fp);

    if (node->label) {
        json_indent(fp, indent + 1);
        fputs("\"label\": ", fp);
        json_str(fp, node->label);
        fputs(",\n", fp);
    }

    if (node->line > 0) {
        json_indent(fp, indent + 1);
        fprintf(fp, "\"line\": %d,\n", node->line);
        json_indent(fp, indent + 1);
        fprintf(fp, "\"col\": %d,\n", node->col);
    }

    json_indent(fp, indent + 1);
    fputs("\"children\": [\n", fp);
    for (int i = 0; i < node->child_count; i++) {
        ast_print_json(node->children[i], fp, indent + 2);
        if (i < node->child_count - 1) fputc(',', fp);
        fputc('\n', fp);
    }
    json_indent(fp, indent + 1);
    fputs("]\n", fp);

    json_indent(fp, indent);
    fputc('}', fp);
}

/* ------------------------------------------------------------------ */
/*  Memory cleanup                                                      */
/* ------------------------------------------------------------------ */
void ast_free(ASTNode *node)
{
    if (!node) return;
    for (int i = 0; i < node->child_count; i++)
        ast_free(node->children[i]);
    free(node->children);
    free(node->label);
    free(node);
}

