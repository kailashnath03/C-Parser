/* arithmetic.c - Arithmetic and operator precedence example */
int main() {
    int a = 10;
    int b = 3;
    int sum        = a + b;
    int difference = a - b;
    int product    = a * b;
    int quotient   = a / b;
    int remainder  = a % b;
    int precedence = 2 + 3 * 4;   /* 14, not 20 */
    int grouped    = (2 + 3) * 4; /* 20          */
    return 0;
}

