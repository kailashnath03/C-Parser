/* valid/06_precedence.c - Operator precedence */
int main() {
    int a = 1 + 2 * 3;    /* = 7, not 9 */
    int b = (1 + 2) * 3;  /* = 9        */
    int c = 8 / 4 / 2;    /* = 1        */
    return 0;
}

