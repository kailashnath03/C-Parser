/* valid/16_nested_blocks.c - Nested compound statements */
int main() {
    int x = 1;
    {
        int y = 2;
        {
            int z = x + y;
        }
    }
    return 0;
}

