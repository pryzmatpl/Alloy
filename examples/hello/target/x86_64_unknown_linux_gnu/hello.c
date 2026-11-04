#include <stdio.h>
#include <stdlib.h>
int main(void) {
    if (printf("Hello, world!\n") < 0) return 1;
    return 0;
}
