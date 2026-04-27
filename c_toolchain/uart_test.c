#include "util.h"
void c_trap_handler(unsigned int cause) {}
int main() { for(int i=0;i<500000;i++); print_string("Hello World!\r\n"); while(1); return 0; }
