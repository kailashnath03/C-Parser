/* valid/12_nested_if.c - Nested if statements (dangling-else) */
int main() {
    int x = 10, y = 20;
    if (x > 0) {
        if (y > 10) {
            x = 1;
        } else {
            x = 2;
        }
    }
    return 0;
}

