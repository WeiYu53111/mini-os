#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "stdint.h"
#include "thread.h"

void k_thread_a(void*);
void k_thread_b(void*);

int main(void) {
    //asm volatile("xchg %bx,%bx");
    put_str("I am kernel\n");

    init_all();                  // 初始化中断描述符
    //asm volatile("xchg %bx,%bx");

    thread_start("k_thread_a", 31, k_thread_a, "argA ");
    thread_start("k_thread_b", 5, k_thread_b, "argB ");

    //asm volatile("xchg %bx,%bx");
    intr_enable();	// 打开中断,使时钟中断起作用
    while(1) {
        put_str("Main ");
    };
    return 0;
}


/* 在线程中运行的函数 */
void k_thread_a(void* arg) {
/* 用void*来通用表示参数,被调用的函数知道自己需要什么类型的参数,自己转换再用 */
    char* para = arg;
    while(1) {
        put_str(para);
    }
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {
/* 用void*来通用表示参数,被调用的函数知道自己需要什么类型的参数,自己转换再用 */
    char* para = arg;
    while(1) {
        put_str(para);
    }
}