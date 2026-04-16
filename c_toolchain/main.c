#include "util.h"
#include "workload_alu.h"

// Helper for printing unsigned variables
void print_uint(unsigned int val) {
    if (val == 0) { print_char('0'); return; }
    char buf[16];
    int idx = 0;
    while (val > 0) {
        buf[idx++] = (val % 10) + '0';
        val /= 10;
    }
    while (idx > 0) {
        print_char(buf[--idx]);
    }
}

void run_addition() {
    print_string("\r\n--- 1. Addition Workload ---\r\n");
    int a = 100;
    int b = 2;
    int c = a + b;
    print_string("Equation: 100 + 2\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 102\r\n");
}

void run_negative() {
    print_string("\r\n--- 2. Subtraction (Negative Result) ---\r\n");
    int a = 4;
    int b = 50;
    int c = a - b;
    print_string("Equation: 4 - 50\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: -46\r\n");
}

void run_sorting() {
    print_string("\r\n--- 3. Array Sorting (Bubble Sort) ---\r\n");
    int arr[] = {6, 3, 9};
    int swapped;
    int n = 3;
    
    print_string("Original Array: 6, 3, 9\r\n");
    
    do {
        swapped = 0;
        for(int j=0; j<n-1; j++) {
            if (arr[j] > arr[j+1]) {
                int temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
                swapped = 1;
            }
        }
        n = n - 1;
    } while(swapped == 1);
    
    print_string("Sorted Array: ");
    print_int(arr[0]); print_string(", ");
    print_int(arr[1]); print_string(", ");
    print_int(arr[2]); print_string("\r\n");
    print_string("Expected: 3, 6, 9\r\n");
}

void run_fibonacci() {
    print_string("\r\n--- 4. Fibonacci Series ---\r\n");
    int t1 = 0, t2 = 1;
    int nextTerm;
    print_string("Fibonacci (5 terms): ");
    for (int i = 1; i <= 5; ++i) {
        print_int(t1);
        if (i < 5) print_string(", ");
        nextTerm = t1 + t2;
        t1 = t2;
        t2 = nextTerm;
    }
    print_string("\r\nExpected: 0, 1, 1, 2, 3\r\n");
}

void run_xor() {
    print_string("\r\n--- 5. Bitwise XOR ---\r\n");
    int a = 170; // 0xAA
    int b = 85;  // 0x55
    int c = a ^ b;
    print_string("Equation: 170 ^ 85\r\n");
    print_string("Result: ");
    print_int(c);
    print_string("\r\nExpected: 255\r\n");
}

void run_signed_multiplication() {
    print_string("\r\n--- 6. Signed Multiplication Workloads ---\r\n");
    
    int a = 15;
    int b = 6;
    int c = a * b;
    print_string("Eq: 15 * 6 = "); print_int(c); print_string(" (Exp: 90)\r\n");

    int g = -8;
    int h = 9;
    int i = g * h;
    print_string("Eq: -8 * 9 = "); print_int(i); print_string(" (Exp: -72)\r\n");
    
    int j = -12;
    int k = -12;
    int l = j * k;
    print_string("Eq: -12 * -12 = "); print_int(l); print_string(" (Exp: 144)\r\n");
    
    int d = 999;
    int e = 0;
    int f = d * e;
    print_string("Eq: 999 * 0 = "); print_int(f); print_string(" (Exp: 0)\r\n");
}

void run_unsigned_multiplication() {
    print_string("\r\n--- 7. Unsigned Multiplication Workloads ---\r\n");
    
    unsigned int a = 40000U;
    unsigned int b = 50000U;
    unsigned int c = a * b; // 2,000,000,000 fits in 32-bit uint
    print_string("Eq: 40000 * 50000 = "); print_uint(c); print_string(" (Exp: 2000000000)\r\n");
    
    unsigned int d = 100U;
    unsigned int e = 200U;
    unsigned int f = d * e;
    print_string("Eq: 100 * 200 = "); print_uint(f); print_string(" (Exp: 20000)\r\n");
}

void run_signed_division() {
    print_string("\r\n--- 8. Signed Division & Edge Cases ---\r\n");
    
    int a = 144;
    int b = 12;
    int c = a / b;
    print_string("Eq: 144 / 12 = "); print_int(c); print_string(" (Exp: 12)\r\n");
    
    int g = -100;
    int h = 5;
    int i = g / h;
    print_string("Eq: -100 / 5 = "); print_int(i); print_string(" (Exp: -20)\r\n");

    volatile int d = 50;
    volatile int e = 0;
    int f = d / e;
    // Note: RISC-V hardware spec: signed div by 0 yields -1
    print_string("Eq: 50 / 0 = "); print_int(f); print_string(" (Exp: -1 limit)\r\n");
    
    // RISC-V edge case: Most negative number divided by -1
    volatile int max_neg = -2147483647 - 1; // 0x80000000
    volatile int neg_one = -1;
    int oflow = max_neg / neg_one;
    print_string("Eq: -2147483648 / -1 = "); print_int(oflow); print_string(" (Exp: -2147483648 overflow)\r\n");
}

void run_unsigned_division() {
    print_string("\r\n--- 9. Unsigned Division & Edge Cases ---\r\n");
    
    unsigned int a = 3000000000U;
    unsigned int b = 3U;
    unsigned int c = a / b;
    print_string("Eq: 3000000000 / 3 = "); print_uint(c); print_string(" (Exp: 1000000000)\r\n");
    
    volatile unsigned int d = 50U;
    volatile unsigned int e = 0U;
    unsigned int f = d / e;
    // Note: RISC-V hardware spec: unsigned div by 0 yields all 1s (max uint)
    print_string("Eq: 50U / 0U = "); print_uint(f); print_string(" (Exp: 4294967295 limit)\r\n");
}

void run_remainders() {
    print_string("\r\n--- 10. Remainders (Modulo) Workloads ---\r\n");
    
    volatile int a = 25;
    volatile int b = 7;
    int c = a % b;
    print_string("Eq: 25 % 7 = "); print_int(c); print_string(" (Exp: 4)\r\n");
    
    volatile int d = -25;
    volatile int e = 7;
    int f = d % e; 
    print_string("Eq: -25 % 7 = "); print_int(f); print_string(" (Exp: -4)\r\n");
    
    volatile int g = 50;
    volatile int h = 0;
    int i = g % h;
    // Note: RISC-V hardware spec: REM by 0 yields the dividend
    print_string("Eq: 50 % 0 = "); print_int(i); print_string(" (Exp: 50 limit)\r\n");
    
    volatile unsigned int ua = 3000000000U;
    volatile unsigned int ub = 7U;
    unsigned int uc = ua % ub;
    print_string("Eq: 3000000000U % 7U = "); print_uint(uc); print_string(" (Exp: 4)\r\n");
}

int main() {
    print_string("\r\n\r\n============================================\r\n");
    print_string("   RISC-V SOC AUTOMATED DIAGNOSTIC RUN\r\n");
    print_string("============================================\r\n");
    print_string("Execution Started!\r\n");
    
    // Core Arithmetic Workloads
    run_addition();
    run_negative();
    run_sorting();
    run_fibonacci();
    run_xor();
    
    // M-Extension (Multiplication/Division/Remainder) Diagnostic
    run_signed_multiplication();
    run_unsigned_multiplication();
    run_signed_division();
    run_unsigned_division();
    run_remainders();
    
    // Full ALU 15-edge-case test mapped from original ASM logic
    run_alu_diagnostic();
    
    print_string("\r\n============================================\r\n");
    print_string("              TEST SUITE COMPLETE\r\n");
    print_string("============================================\r\n");
    
    return 0; // Goes back to start.S and halts
}
