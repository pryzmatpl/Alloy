extern "C" printf(fmt: *const u8, ...): i32;

function hanoi(n: i32, from: *const u8, via: *const u8, to: *const u8): void {
    if n == 0 {
        return;
    }
    hanoi(n - 1, from, to, via);
    printf("Move from %s to %s\n", from, to);
    hanoi(n - 1, via, from, to);
}

function main(): i32 {
    hanoi(4, "A", "B", "C");
    return 0;
}
