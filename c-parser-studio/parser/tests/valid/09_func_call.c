/* valid/09_func_call.c - Function calls */
#include <stdio.h>

int square(int n) {
    return n * n;
}

int main() {
    int x = square(5);
    printf("%d\n", x);
    return 0;
}

