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

static char **locales = 0;

static bool locale_setup(void)
{
  char command[_POSIX_ARG_MAX] = {0};
  FILE *pipe = 0;
  size_t i = 0;
  size_t size = 512;
  char line[LINE_MAX] = {0};
  
  strfcpy(command,sizeof(command),"locale --all-locales | grep '\\.utf8$' | sort --unique");

  if((pipe = popen(command,"r")) == 0)
  {
    error(strerror(errno));
    return false;
  }
  
  locales = malloc0(sizeof(char *) * size);
  
  while(fgets(line,sizeof(line),pipe) != 0)
  {
    if(strlen(line) == 0)
      continue;
  
    if(i == size)
    {
      size *= 2;
      locales = realloc(locales,sizeof(char *) * size);
    }

    locales[i++] = strdup(line);
  }

  locales[i] = 0;

  locales = realloc(locales,sizeof(char *) * (i+1));
  
  if(pclose(pipe) == -1)
  {
    error(strerror(errno));
    return false;
  }
  
  return true;
}

static bool locale_do_locale(void)
{
  const char *var = "LANG";
  char *locale = 0;
  
  if(!ui_window_locale(var,locales,&locale))
    return false;

  if(setenv(var,locale,true) == -1)
  {
    error(strerror(errno));
    return false;
  }

  return true;
}

static bool locale_run(void)
{
  if(!locale_setup())
    return false;

  if(!locale_do_locale())
    return false;

  return true;
}

static void locale_reset(void)
{
  size_t i = 0;

  if(locales != 0)
  {
    for( ; locales[i] != 0 ; ++i )
      free(locales[i]);
    
    free(locales);
    
    locales = 0;
  }
}

struct module locale_module =
{
  locale_run,
  locale_reset,
  __FILE__
};
