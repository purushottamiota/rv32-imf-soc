#include "util.h"
void c_trap_handler(unsigned int cause) {}

int main() {
    while(1) {
        print_char('A');
        print_char('B');
        print_char('C');
        for (volatile int i = 0; i < 500000; i++); 
    }
    return 0;
}
