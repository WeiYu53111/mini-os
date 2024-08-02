#include "print.h"
#include "init.h"
#include "debug.h"
#include "memory.h"
#include "stdint.h"
#include "thread.h"
#include "console.h"

/* 临时为测试添加 */
#include "ioqueue.h"
#include "keyboard.h"
#include "interrupt.h"

void k_thread_a(void*);
void k_thread_b(void*);

int main(void) {
    //asm volatile("xchg %bx,%bx");
    put_str("I am kernel\n");

    init_all();                  // 初始化中断描述符
    //asm volatile("xchg %bx,%bx");
    thread_start("consumer_a", 31, k_thread_a, " A_");
    thread_start("consumer_b", 31, k_thread_b, " B_");

    //asm volatile("xchg %bx,%bx");
    intr_enable();	// 打开中断,使时钟中断起作用
    while(1);
   /* while(1) {
        console_put_str("Main ");
    };*/
    return 0;
}


/* 在线程中运行的函数 */
void k_thread_a(void* arg) {
    while(1) {
        enum intr_status old_status = intr_disable();
        if (!ioq_empty(&kbd_buf)) {
            console_put_str(arg);
            char byte = ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {
    while(1) {
        enum intr_status old_status = intr_disable();
        if (!ioq_empty(&kbd_buf)) {
            console_put_str(arg);
            char byte = ioq_getchar(&kbd_buf);
            console_put_char(byte);
        }
        intr_set_status(old_status);
    }
}