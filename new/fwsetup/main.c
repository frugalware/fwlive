// fwsetup - flexible installer for Frugalware
// Copyright (C) 2013 James Buren
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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

  seed = time(0);

  remove(LOGFILE);

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
  &locale_module,
  &layout_module,
  &partition_module,
  &format_module,
  &install_module,
  &postconfig_module,
  0
};

unsigned int seed;
