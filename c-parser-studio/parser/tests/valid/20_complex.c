/* valid/20_complex.c - Multiple features combined */
#include <stdio.h>

int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

int main() {
    int i;
    for (i = 0; i < 5; i++) {
        int f = factorial(i);
        printf("%d! = %d\n", i, f);
    }
    return 0;
}

