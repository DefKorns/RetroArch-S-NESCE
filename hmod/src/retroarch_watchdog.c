/*
 * Copyright (C) 2026 DefKorns (https://defkorns.github.io/LICENSE)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/*
 * Prints console and pad button events for retroarch-clover-child:
 *   key reset 1 | key reset 0 <ms> | key power <0|1>
 *   joy home 1  | joy home 0 <ms>  | joy any 1 | joy any 0 <ms>
 * Usage: retroarch_watchdog [--any] [--pid <pid>]
 */

#include <dirent.h>
#include <fcntl.h>
#include <linux/input.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#define MAX_DEVICES 4
#define POLL_MS 100
#define PAD_PATH "/dev/input/by-path/platform-twi.1-event-joystick"

enum device_kind { KIND_RESET, KIND_POWER, KIND_PAD };

struct device {
   int fd;
   enum device_kind kind;
   long pressed_at;
   int held[2];
   unsigned char down[KEY_CNT];
};

static long now_ms(void)
{
   struct timeval tv;
   gettimeofday(&tv, NULL);
   return tv.tv_sec * 1000L + tv.tv_usec / 1000L;
}

static int read_name(const char *node, char *name, size_t size)
{
   char path[128];
   FILE *f;

   snprintf(path, sizeof(path), "/sys/class/input/%s/device/name", node);
   if (!(f = fopen(path, "r")))
      return 0;
   if (!fgets(name, (int)size, f))
   {
      fclose(f);
      return 0;
   }
   fclose(f);
   name[strcspn(name, "\n")] = '\0';
   return 1;
}

/* A button can raise several keys at once: report the first press and the last release */
static void report(struct device *dev, int group, unsigned code,
      const char *type, const char *name, int value)
{
   if (value && !dev->down[code])
   {
      dev->down[code] = 1;
      if (++dev->held[group] != 1)
         return;
   }
   else if (!value && dev->down[code])
   {
      dev->down[code] = 0;
      if (--dev->held[group] != 0)
         return;
   }
   else
      return;

   if (value)
   {
      dev->pressed_at = now_ms();
      printf("%s %s %d\n", type, name, value);
   }
   else
      printf("%s %s %d %ld\n", type, name, value,
            dev->pressed_at ? now_ms() - dev->pressed_at : 0L);
   fflush(stdout);
}

static void handle(struct device *dev, const struct input_event *ev, int any)
{
   if (ev->type != EV_KEY || ev->value > 1 || ev->code >= KEY_CNT)
      return;

   switch (dev->kind)
   {
      case KIND_RESET:
         report(dev, 0, ev->code, "key", "reset", ev->value);
         break;
      case KIND_POWER:
         if (ev->code == KEY_POWER)
            report(dev, 0, ev->code, "key", "power", ev->value);
         break;
      case KIND_PAD:
         if (ev->code == BTN_MODE)
            report(dev, 1, ev->code, "joy", "home", ev->value);
         else if (any)
            report(dev, 0, ev->code, "joy", "any", ev->value);
         break;
   }
}

static int open_console_keys(struct device *devs, int count)
{
   DIR *dir = opendir("/sys/class/input");
   struct dirent *entry;

   if (!dir)
      return count;
   while ((entry = readdir(dir)) && count < MAX_DEVICES - 1)
   {
      char name[128], path[64];
      enum device_kind kind;
      int fd;

      if (strncmp(entry->d_name, "event", 5) != 0
            || !read_name(entry->d_name, name, sizeof(name)))
         continue;
      if (!strcmp(name, "sunxi-keyboard"))
         kind = KIND_RESET;
      else if (!strcmp(name, "sunxi-knob") || !strcmp(name, "gpio-keys"))
         kind = KIND_POWER;
      else
         continue;

      snprintf(path, sizeof(path), "/dev/input/%s", entry->d_name);
      if ((fd = open(path, O_RDONLY | O_NONBLOCK)) < 0)
         continue;
      devs[count].fd = fd;
      devs[count].kind = kind;
      devs[count].pressed_at = 0;
      count++;
   }
   closedir(dir);
   return count;
}

int main(int argc, char **argv)
{
   static struct device devs[MAX_DEVICES];
   struct pollfd fds[MAX_DEVICES];
   int count = 0, any = 0, i;
   pid_t pid = 0;

   for (i = 1; i < argc; i++)
   {
      if (!strcmp(argv[i], "--any"))
         any = 1;
      else if (!strcmp(argv[i], "--pid") && i + 1 < argc)
         pid = (pid_t)atoi(argv[++i]);
      else
      {
         fprintf(stderr, "Usage: %s [--any] [--pid <pid>]\n", argv[0]);
         return 1;
      }
   }

   count = open_console_keys(devs, count);
   if ((devs[count].fd = open(PAD_PATH, O_RDONLY | O_NONBLOCK)) >= 0)
   {
      devs[count].kind = KIND_PAD;
      devs[count].pressed_at = 0;
      count++;
   }
   if (!count)
   {
      fprintf(stderr, "Cannot open any input device\n");
      return 1;
   }

   for (i = 0; i < count; i++)
   {
      fds[i].fd = devs[i].fd;
      fds[i].events = POLLIN;
   }

   while (!pid || kill(pid, 0) == 0)
   {
      if (poll(fds, (nfds_t)count, POLL_MS) <= 0)
         continue;
      for (i = 0; i < count; i++)
      {
         struct input_event ev;

         if (!(fds[i].revents & POLLIN))
            continue;
         while (read(devs[i].fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev))
            handle(&devs[i], &ev, any);
      }
   }
   return 0;
}
