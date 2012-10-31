#include <blkid.h>
#include "local.h"

static struct format **targets = 0;

static inline void free_target(struct format *p)
{
  free(p->devicepath);
  
  free(p->size);
  
  free(p->filesystem);
  
  free(p->newfilesystem);
  
  free(p->options);
  
  free(p->mountpath);

  free(p);
}

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

  target->filesystem = strdup(filesystem);

  if(probe != 0)
    blkid_free_probe(probe);
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
      
      size_to_string(buf,PATH_MAX,device_get_size(device),false);
    
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
        
        size_to_string(buf,PATH_MAX,disk_partition_get_size(disk,i),false);
        
        target->size = strdup(buf);
        
        probe_filesystem(target);
      }
    }
    
    device_close(device);
  }

  add_target(0,&n,&size);

  free(devices);

  targets = realloc(targets,n * sizeof(struct format *));

  return true;
}

static void format_filter_devices(void)
{
  size_t i = 0;
  size_t j = 0;

  for( ; targets[i] != 0 ; ++i )
  {
    struct format *p = targets[i];
    
    if(p->newfilesystem == 0 && p->options == 0 && p->mountpath == 0)
    {
      free_target(p);
      continue;
    }
    
    targets[j++] = p;
  }

  targets[j++] = 0;
  
  targets = realloc(targets,j * sizeof(struct format *));
}

static bool format_sort_devices(void)
{
  struct format **p = targets;
  struct format *t = 0;
  
  for( ; *p != 0 ; ++p )
  {
    struct format *target = *p;
    
    if(strcmp(target->newfilesystem,"swap") != 0 && strcmp(target->mountpath,"/") == 0)
      break;
  }
  
  if(*p == 0)
  {
    errno = EINVAL;
    error(strerror(errno));
    return false;
  }
  
  t = targets[0];
  
  targets[0] = *p;
  
  *p = t;
  
  return true;
}

static bool format_process_devices(void)
{
  int i = 0;
  int j = 0;
  int padding = 0;
  char text[256] = {0};
  int percent = 0;
  const char *program = 0;
  char command[_POSIX_ARG_MAX] = {0};
  char path[PATH_MAX] = {0};
  
  for( ; targets[j] != 0 ; ++j )
    ;

  if(j < 10)
    padding = 1;
  else if(j < 100)
    padding = 2;
  else if(j < 1000)
    padding = 3;
  else if(j < 10000)
    padding = 4;

  for( ; i < j ; ++i )
  {
    struct format *target = targets[i];
    
    snprintf(text,256,"(%*d/%d) - %-8s - %-8s",padding,i+1,j,target->devicepath,target->newfilesystem);
    
    percent = (float) (i+1) / j * 100;
    
    ui_dialog_progress(_("Formatting"),text,percent);
    
    if(target->format)
    {
      if(strcmp(target->newfilesystem,"ext2") == 0)
        program = "mkfs.ext2";
      else if(strcmp(target->newfilesystem,"ext3") == 0)
        program = "mkfs.ext3";
      else if(strcmp(target->newfilesystem,"ext4") == 0)
        program = "mkfs.ext4";
      else if(strcmp(target->newfilesystem,"reiserfs") == 0)
        program = "mkfs.reiserfs -q";
      else if(strcmp(target->newfilesystem,"jfs") == 0)
        program = "mkfs.jfs -q";
      else if(strcmp(target->newfilesystem,"xfs") == 0)
        program = "mkfs.xfs -f";
      else if(strcmp(target->newfilesystem,"btrfs") == 0)
        program = "mkfs.btrfs";
      else if(strcmp(target->newfilesystem,"swap") == 0)
        program = "mkswap";
        
      snprintf(command,_POSIX_ARG_MAX,"%s %s %s",program,target->options,target->devicepath);
      
      if(!execute(command,"/",0))
      {
        ui_dialog_progress(0,0,-1);
        return false;
      }
    }
    
    if(strcmp(target->newfilesystem,"swap") == 0)
    {
      snprintf(command,_POSIX_ARG_MAX,"swapon %s",target->devicepath);
      
      if(!execute(command,"/",0))
      {
        ui_dialog_progress(0,0,-1);
        return false;
      }
    }
    else
    {
      snprintf(path,PATH_MAX,"%s%s",INSTALL_ROOT,target->mountpath);
   
      if(!mkdir_recurse(path))
      {
        ui_dialog_progress(0,0,-1);
        return false;
      }
      
      if(mount(target->devicepath,path,target->newfilesystem,0,0) == -1)
      {
        error(strerror(errno));
        ui_dialog_progress(0,0,-1);
        return false;
      }
    }
  }
  
  ui_dialog_progress(0,0,-1);
  
  return true;
}

static bool format_run(void)
{
  if(!format_setup())
    return false;

  if(!ui_window_format(targets))
    return false;

  format_filter_devices();

  if(!format_sort_devices())
    return false;

  if(!format_process_devices())
    return false;

  return true;
}

static void format_reset(void)
{
  struct format **p = 0;

  if(targets != 0)
  {
    for( p = targets ; *p != 0 ; ++p )
    {
      free_target(*p);
    }
    
    free(targets);
    
    targets = 0;
  }
}

struct module format_module =
{
  format_run,
  format_reset,
  __FILE__
};