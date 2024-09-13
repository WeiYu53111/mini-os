//
// Created by W Y on 2024/9/3.
//

#ifndef MINI_OS_SYSCALL_INIT_H
#define MINI_OS_SYSCALL_INIT_H
#include "stdint.h"
void syscall_init(void);
uint32_t sys_getpid(void);
#endif //MINI_OS_SYSCALL_INIT_H
