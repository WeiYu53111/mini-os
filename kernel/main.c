#include "print.h"
#include "init.h"
int main(void) {
    put_str("I am kernel\n");
    init_all();                  // 初始化中断描述符
    asm volatile("sti");	     // 为演示中断处理,在此临时开中断
    while(1);
}
