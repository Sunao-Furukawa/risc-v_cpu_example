#include "rtos.h"

static rtos_task_t g_tasks[RTOS_MAX_TASKS];
static uint32_t g_ticks;
static int g_current = -1;

void rtos_init(void) {
  for (int i = 0; i < RTOS_MAX_TASKS; i++) {
    g_tasks[i].fn = 0;
    g_tasks[i].arg = 0;
    g_tasks[i].next_run = 0;
    g_tasks[i].active = 0;
  }
  g_ticks = 0;
  g_current = -1;
}

int rtos_create_task(rtos_task_fn fn, void *arg) {
  for (int i = 0; i < RTOS_MAX_TASKS; i++) {
    if (!g_tasks[i].active) {
      g_tasks[i].fn = fn;
      g_tasks[i].arg = arg;
      g_tasks[i].next_run = 0;
      g_tasks[i].active = 1;
      return i;
    }
  }
  return -1;
}

void rtos_delay(uint32_t ticks) {
  if (g_current >= 0 && g_current < RTOS_MAX_TASKS) {
    g_tasks[g_current].next_run = g_ticks + ticks;
  }
}

uint32_t rtos_ticks(void) {
  return g_ticks;
}

void rtos_start(void) {
  for (;;) {
    for (int i = 0; i < RTOS_MAX_TASKS; i++) {
      if (!g_tasks[i].active) {
        continue;
      }
      if (g_tasks[i].next_run > g_ticks) {
        continue;
      }
      g_current = i;
      g_tasks[i].fn(g_tasks[i].arg);
    }
    g_current = -1;
    g_ticks++;
  }
}
