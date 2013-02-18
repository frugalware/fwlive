#include "local.h"

FILE *logfile = 0;

extern int main(int argc,char **argv)
{
  int code = 0;

  if(geteuid() != 0)
  {
    printf("You must run this as root.\n");

    return EXIT_FAILURE;
  }

  if(setlocale(LC_ALL,"") == 0)
  {
    perror("main");
    
    return EXIT_FAILURE;
  }

  logfile = fopen(LOGFILE,"a");

  if(logfile == 0)
  {
    perror("main");

    return EXIT_FAILURE;
  }

  setbuf(logfile,0);

  code = ui_main(argc,argv);

  fclose(logfile);

  logfile = 0;

  return code;
}

static struct global local =
{
  .netinstall = true
};

struct global *g = &local;

struct module *modules[] =
{
  &partition_module,
  &format_module,
  &install_module,
  &postconfig_module,
  0
};
