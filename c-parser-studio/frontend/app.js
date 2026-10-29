/**
 * app.js - C Parser Studio Frontend Application
 * Interacts with /api/parse, /api/health, /api/examples
 */

const API_BASE = window.location.origin.includes('localhost')
  ? 'http://localhost:5000/api'
  : '/api';

// State
let currentTab = 'ast';
let currentNav = 'editor';
let parserResult = null;
let examplesCache = {};
let tokenFilter = '';

// Test cases catalog
const TEST_CASES = [
  // 20 Valid
  { name: '01_empty_main.c', type: 'valid', desc: 'Basic main function return 0', code: 'int main() {\n    return 0;\n}' },
  { name: '02_var_decl.c', type: 'valid', desc: 'Multiple types variable declarations', code: 'int x;\nfloat y;\nchar c;\ndouble d;' },
  { name: '03_init_var.c', type: 'valid', desc: 'Initialized variables with literals', code: "int x = 10;\nfloat price = 12.5;\nchar grade = 'A';\nint zero = 0;" },
  { name: '04_multi_declarator.c', type: 'valid', desc: 'Comma separated declarators', code: 'int a = 2, b = 3, c;\nfloat x, y, z;' },
  { name: '05_arithmetic.c', type: 'valid', desc: 'Arithmetic expressions with operators', code: 'int main() {\n    int result = 2 + 3 * 4;\n    int diff = 10 - 2 - 1;\n    float val = 1.0 / 3.0;\n    return 0;\n}' },
  { name: '06_precedence.c', type: 'valid', desc: 'Precedence & Parenthesized grouping', code: 'int main() {\n    int a = 1 + 2 * 3;\n    int b = (1 + 2) * 3;\n    int c = 8 / 4 / 2;\n    return 0;\n}' },
  { name: '07_func_prototype.c', type: 'valid', desc: 'Function prototypes with void & params', code: 'int add(int a, int b);\nvoid print_hello(void);\nfloat compute(float x, float y);' },
  { name: '08_func_def.c', type: 'valid', desc: 'Function definitions & invocation', code: 'int add(int a, int b) {\n    return a + b;\n}\n\nint main() {\n    int result = add(3, 4);\n    return 0;\n}' },
  { name: '09_func_call.c', type: 'valid', desc: 'Function calls with arguments', code: '#include <stdio.h>\n\nint square(int n) {\n    return n * n;\n}\n\nint main() {\n    int x = square(5);\n    printf("%d\\n", x);\n    return 0;\n}' },
  { name: '10_if_stmt.c', type: 'valid', desc: 'If statement branching', code: 'int main() {\n    int x = 10;\n    if (x > 5) {\n        x = 5;\n    }\n    return 0;\n}' },
  { name: '11_if_else.c', type: 'valid', desc: 'If-else branching', code: 'int main() {\n    int x = 10;\n    if (x > 5) {\n        x = 5;\n    } else {\n        x = 0;\n    }\n    return 0;\n}' },
  { name: '12_nested_if.c', type: 'valid', desc: 'Nested conditionals (Dangling-Else)', code: 'int main() {\n    int x = 10, y = 20;\n    if (x > 0) {\n        if (y > 10) {\n            x = 1;\n        } else {\n            x = 2;\n        }\n    }\n    return 0;\n}' },
  { name: '13_while.c', type: 'valid', desc: 'While loop iteration', code: 'int main() {\n    int x = 0;\n    while (x < 10) {\n        x++;\n    }\n    return 0;\n}' },
  { name: '14_do_while.c', type: 'valid', desc: 'Do-while loop iteration', code: 'int main() {\n    int i = 0;\n    do {\n        i++;\n    } while (i < 5);\n    return 0;\n}' },
  { name: '15_for_loop.c', type: 'valid', desc: 'C99 For loop with header declaration', code: 'int main() {\n    int sum = 0;\n    for (int i = 0; i < 5; i++) {\n        sum = sum + i;\n    }\n    return 0;\n}' },
  { name: '16_nested_blocks.c', type: 'valid', desc: 'Nested compound statement blocks', code: 'int main() {\n    int x = 1;\n    {\n        int y = 2;\n        {\n            int z = x + y;\n        }\n    }\n    return 0;\n}' },
  { name: '17_return_stmt.c', type: 'valid', desc: 'Return statements with expressions & void', code: 'int zero() {\n    return 0;\n}\n\nvoid nothing() {\n    return;\n}\n\nint forty_two() {\n    return 6 * 7;\n}' },
  { name: '18_comments.c', type: 'valid', desc: 'Single-line & multi-line comments', code: '// Single-line comment\n/* Multi-line\n   comment */\nint main() {\n    int x = 10; // inline\n    /* block */ int y = x + 1;\n    return 0;\n}' },
  { name: '19_break_continue.c', type: 'valid', desc: 'Break and continue jump statements', code: 'int main() {\n    int i = 0;\n    while (1) {\n        if (i >= 5) break;\n        i++;\n        if (i == 3) continue;\n    }\n    return 0;\n}' },
  { name: '20_complex.c', type: 'valid', desc: 'Factorial function with for loop & calls', code: '#include <stdio.h>\n\nint factorial(int n) {\n    if (n <= 1) return 1;\n    return n * factorial(n - 1);\n}\n\nint main() {\n    for (int i = 0; i < 5; i++) {\n        printf("%d! = %d\\n", i, factorial(i));\n    }\n    return 0;\n}' },

  // 12 Invalid
  { name: '01_missing_semi.c', type: 'invalid', desc: 'Missing semicolon after statement', code: 'int main() {\n    int x = 10\n    return 0;\n}' },
  { name: '02_missing_brace.c', type: 'invalid', desc: 'Missing closing curly brace', code: 'int main() {\n    int x = 10;\n    return 0;' },
  { name: '03_missing_paren.c', type: 'invalid', desc: 'Missing closing parenthesis in header', code: 'int main( {\n    return 0;\n}' },
  { name: '04_missing_expr.c', type: 'invalid', desc: 'Missing expression after assignment =', code: 'int main() {\n    int x = ;\n    return 0;\n}' },
  { name: '05_bad_func.c', type: 'invalid', desc: 'Malformed function without identifier', code: 'int (int a, int b) {\n    return a + b;\n}' },
  { name: '06_bad_operator.c', type: 'invalid', desc: 'Trailing operator without right operand', code: 'int main() {\n    int x = 5 + * ;\n    return 0;\n}' },
  { name: '07_unexpected_token.c', type: 'invalid', desc: 'Extra closing brace in block', code: 'int main() {\n    int x = 10;\n    } return 0;\n}' },
  { name: '08_unterminated_string.c', type: 'invalid', desc: 'Unclosed string literal', code: 'int main() {\n    char *s = "hello world;\n    return 0;\n}' },
  { name: '09_invalid_char.c', type: 'invalid', desc: 'Unsupported illegal character @', code: 'int main() {\n    int x = 10 @ 5;\n    return 0;\n}' },
  { name: '10_bad_for.c', type: 'invalid', desc: 'Missing semicolon in for header', code: 'int main() {\n    for (int i = 0 i < 5; i++) {\n    }\n    return 0;\n}' },
  { name: '11_bad_decl.c', type: 'invalid', desc: 'Type keyword with no declarator', code: 'int main() {\n    int = 10;\n    return 0;\n}' },
  { name: '12_double_operator.c', type: 'invalid', desc: 'Invalid double binary operator usage', code: 'int main() {\n    int x = 5 ++ 3;\n    return 0;\n}' }
];

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
  setupEditorEvents();
  fetchHealth();
  fetchExamples();
  renderTestMatrix('all');

  // Load default arithmetic example
  loadPreset('arithmetic');
});

// Setup editor line numbers, tab key, keyboard shortcut
function setupEditorEvents() {
  const textarea = document.getElementById('codeTextarea');
  const lineNumbers = document.getElementById('lineNumbers');

  function updateLineNumbers() {
    const lines = textarea.value.split('\n').length;
    let nums = '';
    for (let i = 1; i <= Math.max(lines, 1); i++) {
      nums += i + '\n';
    }
    lineNumbers.textContent = nums.trimEnd();
  }

  textarea.addEventListener('input', updateLineNumbers);

  textarea.addEventListener('scroll', () => {
    lineNumbers.scrollTop = textarea.scrollTop;
  });

  textarea.addEventListener('keydown', (e) => {
    // Ctrl + Enter to run
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault();
      runParser();
      return;
    }

    // Tab key inserts 4 spaces
    if (e.key === 'Tab') {
      e.preventDefault();
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      textarea.value = textarea.value.substring(0, start) + '    ' + textarea.value.substring(end);
      textarea.selectionStart = textarea.selectionEnd = start + 4;
      updateLineNumbers();
    }
  });

  updateLineNumbers();
}

// Fetch backend health status
async function fetchHealth() {
  const dot = document.getElementById('statusDot');
  const text = document.getElementById('statusText');
  try {
    const res = await fetch(`${API_BASE}/health`);
    const data = await res.json();
    if (data.status === 'online' && data.parserAvailable) {
      dot.className = 'status-dot online';
      text.textContent = 'Flex/Bison Engine Online';
    } else {
      dot.className = 'status-dot offline';
      text.textContent = 'Engine Offline (Rebuild Required)';
    }
  } catch (err) {
    dot.className = 'status-dot offline';
    text.textContent = 'Backend Disconnected';
  }
}

// Fetch example presets
async function fetchExamples() {
  try {
    const res = await fetch(`${API_BASE}/examples`);
    const data = await res.json();
    for (const ex of data) {
      examplesCache[ex.id] = ex.code;
    }
  } catch (err) {
    console.warn('Using local presets fallback', err);
  }
}

// Load Preset
function loadPreset(id) {
  const textarea = document.getElementById('codeTextarea');
  if (examplesCache[id]) {
    textarea.value = examplesCache[id];
  } else {
    // Fallback to local test cases
    const found = TEST_CASES.find(t => t.name.includes(id));
    if (found) {
      textarea.value = found.code;
    }
  }
  document.getElementById('codeTextarea').dispatchEvent(new Event('input'));
  runParser();
}

function clearEditor() {
  document.getElementById('codeTextarea').value = '';
  document.getElementById('codeTextarea').dispatchEvent(new Event('input'));
  parserResult = null;
  renderTabContent();
}

function resetEditor() {
  loadPreset('arithmetic');
}

// Run parser via API
async function runParser() {
  const btn = document.getElementById('runBtn');
  const code = document.getElementById('codeTextarea').value;
  btn.disabled = true;
  btn.innerHTML = `<span style="display:inline-block;animation:spin 1s linear infinite;">&#x21bb;</span> Parsing...`;

  try {
    const res = await fetch(`${API_BASE}/parse`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code: code })
    });
    parserResult = await res.json();

    // Update statistics
    const stats = parserResult.statistics || {};
    document.getElementById('statTokens').textContent = stats.tokenCount || 0;
    document.getElementById('statNodes').textContent = stats.astNodeCount || 0;
    document.getElementById('statTime').textContent = `${stats.parseTimeMs || 0} ms`;
    document.getElementById('tokenCountBadge').textContent = stats.tokenCount || 0;
    document.getElementById('diagCountBadge').textContent = (parserResult.diagnostics || []).length;

    // If errors, auto-switch to diagnostics tab
    if (parserResult.diagnostics && parserResult.diagnostics.length > 0) {
      switchTab('diagnostics');
    } else {
      renderTabContent();
    }
  } catch (err) {
    parserResult = {
      success: false,
      statistics: { tokenCount: 0, astNodeCount: 0, parseTimeMs: 0 },
      tokens: [],
      ast: null,
      diagnostics: [{ severity: 'ERROR', line: 1, column: 1, message: 'Failed to connect to parser backend: ' + err.message }]
    };
    switchTab('diagnostics');
  } finally {
    btn.disabled = false;
    btn.innerHTML = `<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg> Run Parser`;
  }
}

// Navigation switcher (Editor, Grammar, Tests)
function switchNav(nav) {
  currentNav = nav;
  document.getElementById('navEditor').className = `nav-btn ${nav === 'editor' ? 'active' : ''}`;
  document.getElementById('navGrammar').className = `nav-btn ${nav === 'grammar' ? 'active' : ''}`;
  document.getElementById('navTests').className = `nav-btn ${nav === 'tests' ? 'active' : ''}`;

  document.getElementById('viewEditor').style.display = nav === 'editor' ? 'grid' : 'none';
  document.getElementById('viewGrammar').style.display = nav === 'grammar' ? 'block' : 'none';
  document.getElementById('viewTests').style.display = nav === 'tests' ? 'block' : 'none';
}

// Tab switcher (AST, Tokens, Diagnostics, JSON)
function switchTab(tab) {
  currentTab = tab;
  ['tabAst', 'tabTokens', 'tabDiagnostics', 'tabJson'].forEach(id => {
    document.getElementById(id).className = 'tab-btn';
  });
  const map = { ast: 'tabAst', tokens: 'tabTokens', diagnostics: 'tabDiagnostics', json: 'tabJson' };
  if (map[tab]) document.getElementById(map[tab]).className = 'tab-btn active';
  renderTabContent();
}

// Render active tab content
function renderTabContent() {
  const container = document.getElementById('tabContent');
  if (!parserResult) {
    container.innerHTML = `<div style="text-align:center;padding:48px;color:var(--text-muted);font-size:0.875rem;">
      Click <strong>Run Parser</strong> to execute Flex &amp; Bison and inspect the AST.
    </div>`;
    return;
  }

  if (currentTab === 'ast') {
    if (!parserResult.ast) {
      container.innerHTML = `<div style="padding:24px;color:var(--error);font-size:0.875rem;">
        No AST available due to syntax/lexical error. See <strong>Diagnostics</strong> tab.
      </div>`;
    } else {
      container.innerHTML = `<div class="ast-tree-root">${renderASTNode(parserResult.ast, true)}</div>`;
    }
  } else if (currentTab === 'tokens') {
    renderTokensTab(container);
  } else if (currentTab === 'diagnostics') {
    renderDiagnosticsTab(container);
  } else if (currentTab === 'json') {
    const jsonStr = JSON.stringify(parserResult.ast || null, null, 2);
    container.innerHTML = `<pre class="json-view">${escapeHtml(jsonStr)}</pre>`;
  }
}

// Recursive AST Node renderer
function renderASTNode(node, isRoot = false) {
  if (!node) return '';
  const typeColorMap = {
    TranslationUnit: '#818cf8',
    FuncDef: '#34d399',
    FuncDecl: '#2dd4bf',
    TypeSpec: '#c084fc',
    VarDecl: '#60a5fa',
    Declarator: '#38bdf8',
    BinaryExpr: '#f59e0b',
    UnaryExpr: '#fbbf24',
    PostfixExpr: '#fb923c',
    AssignExpr: '#ec4899',
    IntLiteral: '#22d3ee',
    FloatLiteral: '#38bdf8',
    StringLiteral: '#4ade80',
    CharLiteral: '#86efac',
    IfStmt: '#f97316',
    WhileStmt: '#fb923c',
    ForStmt: '#fb923c',
    ReturnStmt: '#f43f5e'
  };

  const typeColor = typeColorMap[node.type] || '#c084fc';
  const labelHtml = node.label ? `<span class="ast-val">: ${escapeHtml(node.label)}</span>` : '';
  const posHtml = node.line ? `<span class="ast-pos">[L: ${node.line}, C: ${node.col}]</span>` : '';
  const hasChildren = node.children && node.children.length > 0;

  let childrenHtml = '';
  if (hasChildren) {
    childrenHtml = `<div class="ast-children">
      ${node.children.map(child => renderASTNode(child, false)).join('')}
    </div>`;
  }

  return `
    <div class="ast-node ${isRoot ? 'ast-root' : ''}">
      <div class="ast-node-header" onclick="this.nextElementSibling && (this.nextElementSibling.style.display = this.nextElementSibling.style.display === 'none' ? 'block' : 'none')">
        <span class="ast-type" style="color:${typeColor}">${node.type}</span>
        ${labelHtml}
        ${posHtml}
        ${hasChildren ? '<span style="font-size:0.65rem;color:var(--text-dim);">&#x25BC;</span>' : ''}
      </div>
      ${childrenHtml}
    </div>
  `;
}

// Tokens Tab with filter
function renderTokensTab(container) {
  const tokens = parserResult.tokens || [];
  const filtered = tokenFilter
    ? tokens.filter(t => t.type.toLowerCase().includes(tokenFilter.toLowerCase()) || t.lexeme.toLowerCase().includes(tokenFilter.toLowerCase()))
    : tokens;

  let rows = filtered.map(t => `
    <tr>
      <td><span class="token-badge">${escapeHtml(t.type)}</span></td>
      <td><code class="lexeme-code">${escapeHtml(t.lexeme)}</code></td>
      <td style="font-family:var(--font-mono);color:var(--text-dim);">${t.line}</td>
      <td style="font-family:var(--font-mono);color:var(--text-dim);">${t.column}</td>
    </tr>
  `).join('');

  container.innerHTML = `
    <div style="margin-bottom: 12px; display:flex; justify-content:space-between; align-items:center;">
      <input type="text" class="select-input" style="width: 260px;" placeholder="Filter tokens (e.g. IDENTIFIER, int, +)..." 
        value="${escapeHtml(tokenFilter)}" 
        oninput="tokenFilter = this.value; renderTokensTab(document.getElementById('tabContent'));" />
      <span style="font-size:0.8rem;color:var(--text-muted);font-family:var(--font-mono);">Showing ${filtered.length} of ${tokens.length} tokens</span>
    </div>
    <table class="token-table">
      <thead>
        <tr>
          <th>Token Type</th>
          <th>Lexeme</th>
          <th>Line</th>
          <th>Column</th>
        </tr>
      </thead>
      <tbody>
        ${rows || '<tr><td colspan="4" style="text-align:center;padding:24px;color:var(--text-muted);">No tokens matched filter</td></tr>'}
      </tbody>
    </table>
  `;
}

// Diagnostics Tab
function renderDiagnosticsTab(container) {
  const diags = parserResult.diagnostics || [];
  if (diags.length === 0) {
    container.innerHTML = `
      <div class="diag-success">
        <div style="display:flex;align-items:center;gap:10px;font-weight:600;font-size:1rem;margin-bottom:6px;">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"></polyline></svg>
          Parsing Succeeded Without Errors
        </div>
        <p style="font-size:0.85rem;color:#d1fae5;">The C source code is syntactically and lexically valid according to the LALR(1) grammar subset. AST construction completed cleanly with exit code 0.</p>
      </div>
    `;
    return;
  }

  const cards = diags.map(d => `
    <div class="diag-card">
      <div class="diag-title">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
        ${d.severity}: ${escapeHtml(d.message)}
      </div>
      <div class="diag-pos">Location: Line ${d.line}, Column ${d.column}</div>
    </div>
  `).join('');

  container.innerHTML = `
    <div style="margin-bottom:12px;color:var(--error);font-weight:600;font-size:0.9rem;">
      Syntax / Lexical Diagnostics (${diags.length})
    </div>
    ${cards}
  `;
}

// Render test matrix
function renderTestMatrix(filter) {
  const grid = document.getElementById('testGrid');
  const filtered = filter === 'all'
    ? TEST_CASES
    : TEST_CASES.filter(t => t.type === filter);

  grid.innerHTML = filtered.map(t => {
    const isVal = t.type === 'valid';
    return `
      <div class="spec-card" style="padding:14px;cursor:pointer;transition:transform .15s ease;" 
        onclick="loadTestCase('${t.name}')" 
        onmouseover="this.style.borderColor='var(--primary)'" 
        onmouseout="this.style.borderColor='var(--border-color)'">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
          <span style="font-family:var(--font-mono);font-size:0.85rem;font-weight:600;color:#fff;">${t.name}</span>
          <span class="token-badge" style="background:${isVal ? '#10b98120' : '#ef444420'};color:${isVal ? '#34d399' : '#f87171'};border-color:${isVal ? '#10b98140' : '#ef444440'}">
            ${isVal ? 'PASS (0)' : 'REJECT (1)'}
          </span>
        </div>
        <p style="font-size:0.75rem;color:var(--text-muted);">${t.desc}</p>
      </div>
    `;
  }).join('');
}

function filterTests(filter) {
  renderTestMatrix(filter);
}

function loadTestCase(name) {
  const tc = TEST_CASES.find(t => t.name === name);
  if (!tc) return;
  document.getElementById('codeTextarea').value = tc.code;
  document.getElementById('codeTextarea').dispatchEvent(new Event('input'));
  switchNav('editor');
  runParser();
}

function escapeHtml(str) {
  return (str || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

