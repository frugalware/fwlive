#include "local.h"

static struct device **devices = 0;
static struct disk **disks = 0;

static bool partition_setup(void)
{
  int i = 0;

  if((devices = device_probe_all(true)) == 0)
    return false;

  for( ; devices[i] != 0 ; ++i )
    ;

  disks = malloc0(sizeof(struct disk *) * (i + 1));

  for( i = 0 ; devices[i] != 0 ; ++i )
    disks[i] = disk_open(devices[i]);

  return true;
}

static bool partition_run(void)
{
  if(!partition_setup())
    return false;

  if(!ui_window_partition(devices,disks))
    return false;

  return true;
}

static void partition_reset(void)
{
  int i = 0;

  if(devices != 0)
  {
    if(disks != 0)
    {
      for( i = 0 ; disks[i] != 0 ; ++i )
      {
        disk_close(disks[i]);
      }
      
      free(disks);
      
      disks = 0;
    }
    
    for( i = 0 ; devices[i] != 0 ; ++i )
    {
      device_close(devices[i]);
    }
    
    free(devices);
    
    devices = 0;
  }
}

struct module partition_module =
{
  partition_run,
  partition_reset,
  __FILE__
};
