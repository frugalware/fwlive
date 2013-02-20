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

static bool partition_flush(void)
{
  int i = 0;
  int j = 0;
  int padding = 0;
  int percent = 0;
  char text[LINE_MAX] = {0};

  for( ; devices[j] != 0 ; ++j )
	  ;
	
  if(j < 10)
    padding = 1;
  else if(j < 100)
    padding = 2;
  else if(j < 1000)
    padding = 3;
  else if(j < 10000)
    padding = 4;

	
  for( ; devices[i] != 0 ; ++i )
  {
    struct device *device = devices[i];
    struct disk *disk = disks[i];
  
    snprintf(text,LINE_MAX,"(%*d/%d) - %s",padding,i+1,j,device_get_path(device));
    
    percent = (float) (i+1) / j * 100;
	  
    ui_dialog_progress(_("Partitioning"),text,percent);
	  
    if(disk && !disk_flush(disk))
    {
      ui_dialog_progress(0,0,-1);
      return false;
    }
  }
	
  ui_dialog_progress(0,0,-1);
	
  return true;
}

static bool partition_run(void)
{
  if(!partition_setup())
    return false;

  if(!ui_window_partition(devices,disks))
    return false;

  if(!partition_flush())
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
