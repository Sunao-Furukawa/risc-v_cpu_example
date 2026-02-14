#include <stdint.h>
#include "rtos.h"

static volatile uint32_t *const tohost = (uint32_t *)0x00001000u;

static volatile uint32_t task_a_count = 0;
static volatile uint32_t task_b_count = 0;
static volatile uint32_t done_a = 0;
static volatile uint32_t done_b = 0;

static void task_a(void *arg) {
  (void)arg;
  task_a_count++;
  if (task_a_count >= 1000) {
    done_a = 1;
  }
  rtos_delay(1);
}

static void task_b(void *arg) {
  (void)arg;
  task_b_count++;
  if (task_b_count >= 1500) {
    done_b = 1;
  }
  rtos_delay(2);
}

static void task_monitor(void *arg) {
  (void)arg;
  if (done_a && done_b) {
    *tohost = 1;
    for (;;) {
    }
  }
  rtos_delay(1);
}

int main(void) {
  rtos_init();
  rtos_create_task(task_a, 0);
  rtos_create_task(task_b, 0);
  rtos_create_task(task_monitor, 0);
  rtos_start();
  return 0;
}
