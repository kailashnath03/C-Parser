# C Parser Studio

> **Educational C parser built with Flex and GNU Bison — Compiler Design Laboratory Project**

A complete, working command-line tool that performs **lexical analysis** and **syntax analysis** on C source code, constructing an **Abstract Syntax Tree (AST)** and reporting diagnostics with line and column information.

---

## Table of Contents

1. [Project Objective](#1-project-objective)  
2. [Scope and Limitations](#2-scope-and-limitations)  
3. [Architecture](#3-architecture)  
4. [Lexical Analysis — Flex](#4-lexical-analysis--flex)  
5. [Syntax Analysis — GNU Bison](#5-syntax-analysis--gnu-bison)  
6. [Abstract Syntax Tree](#6-abstract-syntax-tree)  
7. [Directory Structure](#7-directory-structure)  
8. [Supported C Grammar](#8-supported-c-grammar)  
9. [Required Software](#9-required-software)  
10. [Build Instructions](#10-build-instructions)  
11. [Command-Line Usage](#11-command-line-usage)  
12. [Token Output Example](#12-token-output-example)  
13. [AST Output Example](#13-ast-output-example)  
14. [JSON Output Example](#14-json-output-example)  
15. [Automated Tests](#15-automated-tests)  
16. [Error Reporting](#16-error-reporting)  
17. [Known Limitations](#17-known-limitations)  
18. [Troubleshooting](#18-troubleshooting)  
19. [College Demonstration Workflow](#19-college-demonstration-workflow)  

---

## 1. Project Objective

C Parser Studio is an **educational parser** for a clearly defined subset of the C programming language. It demonstrates the complete compiler front-end pipeline:

```
C Source Code
      │
      ▼  (Flex lexer.l)
  Token Stream
      │
      ▼  (GNU Bison parser.y)
  Abstract Syntax Tree
      │
      ▼  (ast.c / ast.h)
  Tree output (text / JSON)
```

**This project does NOT:**
- Execute the submitted C code
- Perform type checking or semantic analysis
- Replace a full C compiler

---

## 2. Scope and Limitations

### Supported

| Feature | Status |
|---------|--------|
| Data types: `int`, `char`, `float`, `double`, `void`, `short`, `long`, `signed`, `unsigned` | ✅ |
| Type combinations: `unsigned int`, `long int`, `long long` | ✅ |
| Storage/qualifier specifiers: `static`, `extern`, `const`, `volatile`, `inline`, `register` | ✅ (recognised, not checked semantically) |
| Variable declarations with and without initializers | ✅ |
| Multiple declarators: `int a = 1, b = 2, c;` | ✅ |
| Pointer declarators: `int *p;` | ✅ (syntax only) |
| Array declarators: `int arr[10];` | ✅ (syntax only) |
| Function prototypes | ✅ |
| Function definitions with parameter lists | ✅ |
| Function calls | ✅ |
| Expressions with full operator precedence/associativity | ✅ |
| Unary, postfix, binary, assignment, conditional (ternary) operators | ✅ |
| `if` / `if-else` (dangling-else resolved correctly) | ✅ |
| `while`, `do-while`, `for` loops | ✅ |
| C99 `for`-init declarations | ✅ |
| `switch` / `case` / `default` | ✅ |
| `return`, `break`, `continue`, `goto` | ✅ |
| Compound statements, nested blocks | ✅ |
| Single-line (`//`) and block (`/* */`) comments | ✅ |
| `#include`, `#define` and other preprocessor lines | ✅ (skipped lexically) |
| String and character literals | ✅ |
| Hex, octal, and decimal integer literals | ✅ |
| Floating-point literals | ✅ |

### Not Supported (Documented Limitations)

- `struct`, `union`, `enum` definitions
- `typedef`
- Function pointers
- Complex nested declarators (e.g., `int (*fp)(int)`)
- Full type checking / semantic analysis
- Symbol table construction
- Complete C preprocessor (directives are skipped, not expanded)

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     cparser.exe                             │
│                                                             │
│  main.c                                                     │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  CLI arg parsing → file open → yyparse() → AST output │ │
│  └────────────────────────────────────────────────────────┘ │
│              │                          │                   │
│         lex.yy.c                  parser.tab.c              │
│    ┌──────────────────┐      ┌────────────────────────┐     │
│    │  Flex lexer       │      │  Bison LALR(1) parser  │     │
│    │  (from lexer.l)  │─────▶│  (from parser.y)       │     │
│    │                  │      │                        │     │
│    │  Token stream    │      │  Grammar reductions    │     │
│    │  Line/col track  │      │  AST construction      │     │
│    └──────────────────┘      └────────────────────────┘     │
│                                        │                   │
│                                   ast.c / ast.h            │
│                              ┌─────────────────────┐       │
│                              │  ASTNode structures  │       │
│                              │  Tree print (text)   │       │
│                              │  JSON serialization  │       │
│                              │  Memory cleanup      │       │
│                              └─────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Lexical Analysis — Flex

**File:** `parser/lexer.l`  
**Generated:** `parser/lex.yy.c` (by `win_flex`)

The Flex lexer recognises:

- **Keywords** — all standard C keywords (`int`, `return`, `while`, etc.)
- **Identifiers** — `[a-zA-Z_][a-zA-Z0-9_]*`
- **Integer literals** — decimal, hex (`0x…`), octal (`0…`)
- **Floating-point literals** — `1.5`, `.5f`, `1e10`
- **Character literals** — `'a'`, `'\n'`
- **String literals** — `"hello\n"`
- **All C operators** — including compound-assignment (`+=`, `-=`, etc.) and increment/decrement
- **Preprocessor lines** — skipped (entire line)
- **Comments** — both `//` and `/* */` (including multi-line, with correct line tracking)
- **Invalid characters** — reported as lexical errors

Token values are shared with the Bison parser through the generated `parser.tab.h` header.

---

## 5. Syntax Analysis — GNU Bison

**File:** `parser/parser.y`  
**Generated:** `parser/parser.tab.c`, `parser/parser.tab.h` (by `win_bison`)

The grammar is an LALR(1) grammar with:

- **0 shift/reduce conflicts** (verified with `win_bison -d`)
- **0 reduce/reduce conflicts**
- Dangling-else resolved with `%prec LOWER_THAN_ELSE`
- Operator precedence handled by grammar stratification (not `%left`/`%right` — the expression hierarchy is explicit)
- Full location tracking for error messages

Grammar non-terminals include:
`translation_unit` → `ext_decl_list` → `func_def` | `func_proto` | `declaration`  
→ Statements → Expressions → Literals

---

## 6. Abstract Syntax Tree

**Files:** `parser/ast.h`, `parser/ast.c`

Each AST node has:
- A **type** (enum: `NODE_FUNC_DEF`, `NODE_VAR_DECL`, `NODE_BINARY_EXPR`, …)
- An optional **label** (operator, identifier name, literal value, type name)
- A dynamic **children** array
- **Source position** (line, column)

Node types (35 total):

```
TranslationUnit, FuncDef, FuncDecl, Param, ParamList,
VarDecl, DeclList, Declarator, TypeSpec,
CompoundStmt, ExprStmt, EmptyStmt,
IfStmt, WhileStmt, DoWhileStmt, ForStmt,
SwitchStmt, CaseLabel, DefaultLabel,
ReturnStmt, BreakStmt, ContinueStmt,
BinaryExpr, UnaryExpr, PostfixExpr, AssignExpr,
TernaryExpr, FuncCall, ArrayIndex, ArgList,
Identifier, IntLiteral, FloatLiteral, CharLiteral, StringLiteral
```

---

## 7. Directory Structure

```
c-parser-studio/
├── parser/                  # Core Compiler Design Lab Engine (Flex + Bison + C)
│   ├── lexer.l              # Flex lexer source
│   ├── parser.y             # GNU Bison grammar (LALR(1), 0 conflicts)
│   ├── ast.h                # AST node type definitions
│   ├── ast.c                # AST construction, printing, JSON, cleanup
│   ├── main.c               # CLI driver (--tokens, --ast, --json)
│   ├── Makefile             # Clean build system
│   └── tests/
│       ├── valid/           # 20 valid C programs (should parse: exit 0)
│       ├── invalid/         # 12 invalid C programs (should fail: exit 1)
│       ├── run_tests.ps1    # PowerShell test runner (Windows)
│       └── run_tests.sh     # Bash test runner (Linux / WSL)
├── backend/                 # REST API Service (Node.js)
│   ├── server.js            # Express/HTTP server (/api/parse, /api/health, /api/examples)
│   └── package.json         # Backend metadata & scripts
├── frontend/                # Dark Developer Studio Web Workbench
│   ├── index.html           # Main UI matching Kotlin Parser Studio design
│   ├── style.css            # Exact design system (--bg-dark, --primary-glow, etc.)
│   └── app.js               # Reactive workbench controller & AST visualizer
├── examples/
│   ├── hello.c              # Hello World
│   ├── arithmetic.c         # Arithmetic and precedence
│   ├── functions.c          # Function definitions and calls
│   ├── conditionals.c       # if / if-else chains
│   └── loops.c              # while, do-while, for
├── README.md
└── .gitignore
```

---

## 8. Supported C Grammar (EBNF summary)

```ebnf
program        ::= { function_def | function_proto | declaration }

function_def   ::= type_spec_list IDENTIFIER '(' params ')' compound_stmt
function_proto ::= type_spec_list IDENTIFIER '(' params ')' ';'

params         ::= empty | 'void' | param { ',' param } [ ',' '...' ]
param          ::= type_spec_list [ declarator ]

declaration    ::= type_spec_list declarator_list ';'
declarator     ::= ['*'] IDENTIFIER { '[' expr ']' }
init_decl      ::= declarator [ '=' assign_expr ]

compound_stmt  ::= '{' { declaration | statement } '}'

statement      ::= compound_stmt
                 | expr ';'
                 | ';'
                 | 'if' '(' expr ')' stmt [ 'else' stmt ]
                 | 'while' '(' expr ')' stmt
                 | 'do' stmt 'while' '(' expr ')' ';'
                 | 'for' '(' [expr|decl] ';' [expr] ';' [expr] ')' stmt
                 | 'switch' '(' expr ')' compound_stmt
                 | 'case' expr ':' | 'default' ':'
                 | 'return' [expr] ';'
                 | 'break' ';' | 'continue' ';' | 'goto' IDENTIFIER ';'

expr           ::= assign_expr { ',' assign_expr }
assign_expr    ::= cond_expr | unary_expr assign_op assign_expr
cond_expr      ::= or_expr [ '?' expr ':' cond_expr ]
or_expr        ::= and_expr  { '||' and_expr }
and_expr       ::= bitor_expr { '&&' bitor_expr }
  ... (full operator precedence hierarchy)
unary_expr     ::= postfix_expr | '++' unary_expr | '--' unary_expr
                 | unary_op cast_expr | 'sizeof' ...
postfix_expr   ::= primary_expr { '[' expr ']' | '(' [args] ')' 
                                 | '.' ID | '->' ID | '++' | '--' }
primary_expr   ::= IDENTIFIER | INT_LIT | FLOAT_LIT | CHAR_LIT
                 | STRING_LIT | '(' expr ')'
```

---

## 9. Required Software

### Windows (native, no WSL needed)

| Tool | Install command (winget) | Purpose |
|------|--------------------------|---------|
| LLVM/Clang | `winget install MartinStorsjo.LLVM-MinGW.UCRT` | C compiler |
| WinFlexBison | `winget install WinFlexBison.win_flex_bison` | Flex + Bison for Windows |
| GNU Make | included with WinFlexBison package | Build automation |

### Linux / WSL (Ubuntu)

```bash
sudo apt update
sudo apt install build-essential flex bison make
```

### macOS

```bash
brew install flex bison
```

---

## 10. Build Instructions

### Windows (PowerShell)

```powershell
# Set the Bison data directory (required for win_bison via WinGet symlink)
$env:BISON_PKGDATADIR = "C:\Users\<YourName>\AppData\Local\Microsoft\WinGet\Packages\WinFlexBison.win_flex_bison_Microsoft.Winget.Source_8wekyb3d8bbwe\data"

cd "e:\C LANGUAGE\c-parser-studio\parser"

# Clean build
make clean
make
```

### Linux / WSL / macOS

```bash
cd c-parser-studio/parser
make clean
make
```

### What make does

1. `win_bison -d parser.y` → `parser.tab.c`, `parser.tab.h`  
2. `win_flex --wincompat -o lex.yy.c lexer.l` → `lex.yy.c`  
3. `clang -c ast.c main.c parser.tab.c lex.yy.c` → object files  
4. `clang -o cparser.exe ...` → executable  

---

## 11. Command-Line Usage

```
Usage: cparser [options] [file.c]

Options:
  --tokens    Lex the input and print the token stream, then exit
  --ast       Parse and print the AST (default)
  --json      Parse and print the AST as JSON (to stdout)
  --help      Show this message

If no file is given, reads from standard input.

Exit codes:
  0  success
  1  syntax / lexical error
  2  I/O or internal error
```

---

## 12. Token Output Example

```
cparser --tokens examples/hello.c
```

```
TOKEN_TYPE           LEXEME                         LINE     COL
----------           ------                         ----     ---
INT                  int                               4       1
IDENTIFIER           main                              4       5
LPAREN               (                                 4       9
RPAREN               )                                 4      10
LBRACE               {                                 4      12
IDENTIFIER           printf                            5       5
LPAREN               (                                 5      11
STRING_LITERAL       "Hello, World!\n"                 5      28
RPAREN               )                                 5      29
SEMI                 ;                                 5      30
RETURN               return                            6       5
INT_LITERAL          0                                 6      12
SEMI                 ;                                 6      13
RBRACE               }                                 7       1
```

---

## 13. AST Output Example

Input (`examples/arithmetic.c`, excerpt):
```c
int result = 2 + 3 * 4;
```

Output (`--ast`):
```
VarDecl  [line 5, col 5]
+-- TypeSpec: int  [line 5, col 5]
+-- DeclList  [line 5, col 9]
    +-- Declarator: result  [line 5, col 9]
        +-- Declarator: =  [line 5, col 16]
            +-- BinaryExpr: +  [line 5, col 18]
                +-- IntLiteral: 2  [line 5, col 18]
                +-- BinaryExpr: *  [line 5, col 22]
                    +-- IntLiteral: 3  [line 5, col 22]
                    +-- IntLiteral: 4  [line 5, col 26]
```

Operator precedence is correctly reflected: `*` binds tighter than `+`.

---

## 14. JSON Output Example

```
cparser --json examples/hello.c
```

```json
{
  "type": "TranslationUnit",
  "line": 4,
  "col": 1,
  "children": [
    {
      "type": "FuncDef",
      "label": "main",
      "line": 4,
      "col": 1,
      "children": [
        { "type": "TypeSpec", "label": "int", "line": 4, "col": 1, "children": [] },
        { "type": "ParamList", "label": "empty", "line": 4, "col": 9, "children": [] },
        {
          "type": "CompoundStmt",
          "line": 5,
          "col": 5,
          "children": [ ... ]
        }
      ]
    }
  ]
}
```

---

## 15. Automated Tests

### Running the test suite

**Windows (PowerShell):**

```powershell
cd "e:\C LANGUAGE\c-parser-studio\parser"
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 .\cparser.exe
```

**Linux / WSL:**

```bash
cd c-parser-studio/parser
make test
```

### Test categories

**Valid programs** (20 tests — parser must exit 0):

| File | Tests |
|------|-------|
| `01_empty_main.c` | Basic main function |
| `02_var_decl.c` | Variable declarations |
| `03_init_var.c` | Initialized variables |
| `04_multi_declarator.c` | Multiple declarators |
| `05_arithmetic.c` | Arithmetic expressions |
| `06_precedence.c` | Operator precedence |
| `07_func_prototype.c` | Function prototypes |
| `08_func_def.c` | Function definitions |
| `09_func_call.c` | Function calls |
| `10_if_stmt.c` | If statements |
| `11_if_else.c` | If-else |
| `12_nested_if.c` | Dangling-else |
| `13_while.c` | While loop |
| `14_do_while.c` | Do-while loop |
| `15_for_loop.c` | For loop (C99) |
| `16_nested_blocks.c` | Nested compound statements |
| `17_return_stmt.c` | Return statements |
| `18_comments.c` | Comments and whitespace |
| `19_break_continue.c` | break / continue |
| `20_complex.c` | Factorial function |

**Invalid programs** (12 tests — parser must exit 1):

| File | Error |
|------|-------|
| `01_missing_semi.c` | Missing semicolon |
| `02_missing_brace.c` | Missing `}` |
| `03_missing_paren.c` | Missing `)` |
| `04_missing_expr.c` | Missing expression after `=` |
| `05_bad_func.c` | Malformed function header |
| `06_bad_operator.c` | Trailing operator with no operand |
| `07_unexpected_token.c` | Unexpected `}` |
| `08_unterminated_string.c` | Unterminated string literal |
| `09_invalid_char.c` | Invalid character `@` |
| `10_bad_for.c` | Missing `;` in `for` header |
| `11_bad_decl.c` | `int = 10;` (no declarator) |
| `12_double_operator.c` | `5 ++ 3` (invalid postfix use) |

### Current results: **32/32 PASS**

---

## 16. Error Reporting

Lexical errors (reported to `stderr`):

```
error:5:17: invalid character '@'
error:7: unterminated string literal
error: unterminated block comment
```

Syntax errors (reported to `stderr`):

```
syntax error at line 3, column 11: syntax error, unexpected TOK_RETURN, expecting ';' or ','
syntax error at line 6, column 1: syntax error, unexpected end of file
```

A nonzero exit code always accompanies an error message.

---

## 17. Known Limitations

1. **Preprocessor**: `#include`, `#define` and other preprocessor directives are **skipped lexically** (entire line ignored). Macro-generated tokens are not parsed.
2. **struct/union/enum**: Not supported. Programs using them will produce a syntax error.
3. **typedef**: Not supported.
4. **Function pointers**: `int (*fp)(int)` declarators will fail.
5. **Semantic analysis**: No type checking, no symbol table, no scope resolution.
6. **`f(void)` parameter**: Parsed as one abstract void-typed parameter (equivalent in effect).
7. **Very large files**: String/char literal accumulation buffer is fixed at 64 KB.

---

## 18. Troubleshooting

### `win_bison: cannot open m4sugar.m4`

Set the data directory before running make:

```powershell
$env:BISON_PKGDATADIR = "C:\Users\<YourName>\AppData\Local\Microsoft\WinGet\Packages\WinFlexBison.win_flex_bison_Microsoft.Winget.Source_8wekyb3d8bbwe\data"
```

### `clang: command not found`

Install LLVM-MinGW:

```powershell
winget install MartinStorsjo.LLVM-MinGW.UCRT
```

### `parser.tab.h: No such file or directory`

The Flex step ran before Bison. Run `make clean && make`.

### PowerShell exits 1 even though build succeeded

PowerShell treats any stderr output (including Bison warnings) as an error. Check whether `cparser.exe` was actually created:

```powershell
Test-Path ".\cparser.exe"
```

### Parser accepts obviously wrong code

Run with `--ast` to inspect what the parser actually built. If a test is unexpectedly accepted, check whether the code is actually valid C according to the documented grammar subset.

---

## 19. College Demonstration Workflow

```powershell
# Step 0: Set environment (Windows only)
$env:BISON_PKGDATADIR = "C:\Users\<name>\AppData\Local\Microsoft\WinGet\Packages\WinFlexBison.win_flex_bison_Microsoft.Winget.Source_8wekyb3d8bbwe\data"
cd "e:\C LANGUAGE\c-parser-studio\parser"

# Step 1: Clean build
make clean
make

# Step 2: Show token stream
.\cparser.exe --tokens examples\hello.c

# Step 3: Show AST for a simple program
.\cparser.exe --ast examples\hello.c

# Step 4: Demonstrate operator precedence in AST
.\cparser.exe --ast examples\arithmetic.c

# Step 5: Show AST for functions and conditionals
.\cparser.exe --ast examples\functions.c
.\cparser.exe --ast examples\conditionals.c

# Step 6: Show JSON output (machine-readable)
.\cparser.exe --json examples\hello.c

# Step 7: Show error handling
.\cparser.exe --ast tests\invalid\01_missing_semi.c
.\cparser.exe --ast tests\invalid\08_unterminated_string.c

# Step 8: Run automated test suite
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 .\cparser.exe
```

---

*C Parser Studio — Educational use only. Not a production C compiler.*

