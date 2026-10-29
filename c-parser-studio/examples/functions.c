/* functions.c - Function definitions and calls */
#include <stdio.h>

int add(int a, int b) {
    return a + b;
}

int factorial(int n) {
    if (n <= 1) {
        return 1;
    }
    return n * factorial(n - 1);
}

int main() {
    int result = add(5, 7);
    int fact   = factorial(5);
    printf("5 + 7 = %d\n", result);
    printf("5!    = %d\n", fact);
    return 0;
}

