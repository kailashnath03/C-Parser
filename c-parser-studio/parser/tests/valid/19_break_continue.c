/* valid/19_break_continue.c - Break and continue */
int main() {
    int i = 0;
    while (1) {
        if (i >= 5) break;
        i++;
        if (i == 3) continue;
    }
    return 0;
}

