/* loops.c - while, do-while, for loops */
int main() {
    /* while loop */
    int i = 0;
    while (i < 5) {
        i++;
    }

    /* do-while loop */
    int j = 0;
    do {
        j = j + 2;
    } while (j < 10);

    /* for loop */
    int sum = 0;
    for (int k = 1; k <= 100; k++) {
        sum = sum + k;
    }

    return 0;
}

