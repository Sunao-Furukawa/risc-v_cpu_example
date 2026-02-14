#ifndef RTOS_H
#define RTOS_H

#include <stdint.h>

#define RTOS_MAX_TASKS 8

typedef void (*rtos_task_fn)(void *arg);

typedef struct {
  rtos_task_fn fn;
  void *arg;
  uint32_t next_run;
  uint8_t active;
} rtos_task_t;

void rtos_init(void);
int rtos_create_task(rtos_task_fn fn, void *arg);
void rtos_start(void);
void rtos_delay(uint32_t ticks);
uint32_t rtos_ticks(void);

#endif
