/* conditionals.c - if / if-else / nested conditions */
int main() {
    int x = 15;

    if (x > 10) {
        x = x - 10;
    } else {
        x = x + 10;
    }

    int grade = 85;
    char result;
    if (grade >= 90) {
        result = 'A';
    } else if (grade >= 80) {
        result = 'B';
    } else if (grade >= 70) {
        result = 'C';
    } else {
        result = 'F';
    }

    return 0;
}

