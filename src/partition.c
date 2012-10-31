#include "local.h"

static bool partition_run(void)
{
  return true;
}

static void partition_reset(void)
{
}

struct module partition_module =
{
  partition_run,
  partition_reset,
  __FILE__
};
