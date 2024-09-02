//
// Created by W Y on 2024/8/11.
//

#ifndef MINI_OS_TSS_H
#define MINI_OS_TSS_H

#include "thread.h"
void update_tss_esp(struct task_struct* pthread);
void tss_init(void);
#endif //MINI_OS_TSS_H
