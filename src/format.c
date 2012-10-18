#include <blkid.h>
#include "local.h"

static struct format **targets = 0;

static inline void add_target(struct format *p,int *n,int *size)
{
  if(*n == *size)
  {
    *size *= 2;
    targets = realloc(targets,*size * sizeof(struct format *));
  }
  
  targets[*n] = p;
  
  *n += 1;
}

static inline void probe_filesystem(struct format *target)
{
  blkid_probe probe = 0;
  static char *filesystems[] =
  {
    "ext2",
    "ext3",
    "ext4",
    "reiserfs",
    "jfs",
    "xfs",
    "btrfs",
    "swap",
    0
  };
  const char *filesystem = "unknown";
  const char *result = 0;
  
  if((probe = blkid_new_probe_from_filename(target->devicepath)) == 0)
    goto bail;
    
  if(blkid_probe_enable_superblocks(probe,true) == -1)
    goto bail;

  if(blkid_probe_filter_superblocks_type(probe,BLKID_FLTR_ONLYIN,filesystems) == -1)
    goto bail;

  if(blkid_probe_set_superblocks_flags(probe,BLKID_SUBLKS_TYPE) == -1)
    goto bail;

  if(blkid_do_probe(probe) == -1)
    goto bail;

  if(blkid_probe_lookup_value(probe,"TYPE",&result,0) == -1)
    goto bail;

  filesystem = result;

bail:

  if(probe != 0)
    blkid_free_probe(probe);

  target->filesystem = strdup(filesystem);
}

static bool format_setup(void)
{
  struct device **devices = 0;
  struct device **p = 0;
  int n = 0;
  int size = 128;
  int i = 0;
  int j = 0;

  if((devices = device_probe_all(true)) == 0)
    return false;

  targets = malloc0(size * sizeof(struct format *));

  for( p = devices ; *p != 0 ; ++p )
  {
    struct device *device = *p;
    struct disk *disk = disk_open(device);
    struct format *target = 0;
    char buf[PATH_MAX] = {0};
 
    if(disk == 0)
    {
      target = malloc0(sizeof(struct format));
    
      add_target(target,&n,&size);
    
      target->devicepath = strdup(device_get_path(device));
      
      size_to_string(buf,PATH_MAX,device_get_size(device),true);
    
      target->size = strdup(buf);
    
      probe_filesystem(target);
    }
    else
    {
      for( i = 0, j = disk_partition_get_count(disk) ; i < j ; ++i )
      {
        const char *purpose = disk_partition_get_purpose(disk,i);
      
        if(
          strcmp(purpose,"data") != 0 && 
          strcmp(purpose,"swap") != 0 && 
          strcmp(purpose,"efi")  != 0
        )
          continue;
        
        target = malloc0(sizeof(struct format));
      
        add_target(target,&n,&size);
      
        snprintf(buf,PATH_MAX,"%s%d",device_get_path(device),disk_partition_get_number(disk,i));
        
        target->devicepath = strdup(buf);
        
        size_to_string(buf,PATH_MAX,disk_partition_get_size(disk,i),true);
        
        target->size = strdup(buf);
        
        probe_filesystem(target);
      }
    }
    
    device_close(device);
  }

  free(devices);

  targets = realloc(targets,(n + 1) * sizeof(struct format *));

  return true;
}

static bool format_run(void)
{
  if(!format_setup())
    return false;

  return true;
}

static void format_reset(void)
{
}

struct module format_module =
{
  format_run,
  format_reset,
  __FILE__
};
