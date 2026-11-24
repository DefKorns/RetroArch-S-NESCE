/*
 * Copyright (C) 2026 DefKorns (https://defkorns.github.io/LICENSE)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

#ifdef HAVE_CLASSIC

#include <dlfcn.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#ifdef HAVE_THREADS
#include <pthread.h>
#endif

#include <dynamic/dylib.h>

#define XZ_USE_CRC64
#include "../../deps/xz-embedded/xz.h"

#define XZ_SHM_DIR "/dev/shm/"
#define XZ_FOOTER_SIZE 12
#define XZ_HEADER_SIZE 12
#define XZ_MAX_BLOCKS 16

struct xz_block
{
   const uint8_t *header;
   const uint8_t *data;
   uint8_t *out;
   uint64_t unpadded;
   uint64_t usize;
   int ok;
};

static const uint8_t xz_magic[6] = { 0xFD, '7', 'z', 'X', 'Z', 0x00 };

static int read_vli(const uint8_t **p, const uint8_t *end, uint64_t *value)
{
   unsigned shift = 0;

   *value = 0;
   while (*p < end && shift < 63)
   {
      uint8_t byte = *(*p)++;
      *value |= (uint64_t)(byte & 0x7F) << shift;
      if (!(byte & 0x80))
         return 1;
      shift += 7;
   }
   return 0;
}

static int index_blocks(const uint8_t *data, size_t size,
      struct xz_block *blocks, size_t *count, uint64_t *total)
{
   const uint8_t *footer, *index, *end;
   uint64_t records, unpadded, length, backward, i;

   if (size < XZ_HEADER_SIZE + XZ_FOOTER_SIZE)
      return 0;

   footer = data + size - XZ_FOOTER_SIZE;
   if (footer[10] != 'Y' || footer[11] != 'Z')
      return 0;

   backward = ((uint64_t)footer[4] | (uint64_t)footer[5] << 8
         | (uint64_t)footer[6] << 16 | (uint64_t)footer[7] << 24) + 1;
   backward *= 4;
   if (backward > size - XZ_HEADER_SIZE - XZ_FOOTER_SIZE)
      return 0;

   index = footer - backward;
   end   = footer;
   if (*index++ != 0x00 || !read_vli(&index, end, &records))
      return 0;

   *total = 0;
   for (i = 0; i < records; i++)
   {
      if (!read_vli(&index, end, &unpadded) || !read_vli(&index, end, &length))
         return 0;
      if (i < XZ_MAX_BLOCKS)
      {
         blocks[i].unpadded = unpadded;
         blocks[i].usize    = length;
      }
      *total += length;
   }
   *count = (size_t)records;
   return 1;
}

int dylib_xz_is_compressed(const char *path)
{
   uint8_t head[sizeof(xz_magic)];
   int fd = open(path, O_RDONLY | O_CLOEXEC);
   int match;

   if (fd < 0)
      return 0;
   match = pread(fd, head, sizeof(head), 0) == (ssize_t)sizeof(head)
      && !memcmp(head, xz_magic, sizeof(head));
   close(fd);
   return match;
}

static int decode(const uint8_t *in, size_t in_size, uint8_t *out, size_t out_size)
{
   struct xz_dec *dec;
   struct xz_buf buf;
   enum xz_ret ret;

   xz_crc32_init();
   xz_crc64_init();

   dec = xz_dec_init(XZ_SINGLE, 0);
   if (!dec)
      return 0;

   buf.in       = in;
   buf.in_pos   = 0;
   buf.in_size  = in_size;
   buf.out      = out;
   buf.out_pos  = 0;
   buf.out_size = out_size;
   ret          = xz_dec_run(dec, &buf);
   xz_dec_end(dec);
   return ret == XZ_STREAM_END && buf.out_pos == out_size;
}

static size_t put_vli(uint8_t *p, uint64_t value)
{
   size_t n = 0;

   while (value >= 0x80)
   {
      p[n++] = (uint8_t)(value | 0x80);
      value >>= 7;
   }
   p[n++] = (uint8_t)value;
   return n;
}

static void put_le32(uint8_t *p, uint32_t value)
{
   p[0] = (uint8_t)value;
   p[1] = (uint8_t)(value >> 8);
   p[2] = (uint8_t)(value >> 16);
   p[3] = (uint8_t)(value >> 24);
}

static void *decode_block(void *arg)
{
   struct xz_block *b = (struct xz_block*)arg;
   size_t padded = (size_t)((b->unpadded + 3) & ~(uint64_t)3);
   size_t n = 0, index_len, total;
   uint8_t index[64], footer[XZ_FOOTER_SIZE], *stream;

   index[n++] = 0x00;
   n += put_vli(index + n, 1);
   n += put_vli(index + n, b->unpadded);
   n += put_vli(index + n, b->usize);
   while (n & 3)
      index[n++] = 0;
   put_le32(index + n, xz_crc32(index, n, 0));
   index_len = n + 4;

   put_le32(footer + 4, (uint32_t)(index_len / 4 - 1));
   footer[8]  = b->header[6];
   footer[9]  = b->header[7];
   put_le32(footer, xz_crc32(footer + 4, 6, 0));
   footer[10] = 'Y';
   footer[11] = 'Z';

   total  = XZ_HEADER_SIZE + padded + index_len + XZ_FOOTER_SIZE;
   stream = (uint8_t*)malloc(total);
   b->ok  = 0;
   if (!stream)
      return NULL;

   memcpy(stream, b->header, XZ_HEADER_SIZE);
   memcpy(stream + XZ_HEADER_SIZE, b->data, padded);
   memcpy(stream + XZ_HEADER_SIZE + padded, index, index_len);
   memcpy(stream + XZ_HEADER_SIZE + padded + index_len, footer, XZ_FOOTER_SIZE);
   b->ok = decode(stream, total, b->out, (size_t)b->usize);
   free(stream);
   return NULL;
}

static int decode_blocks(struct xz_block *blocks, size_t count)
{
#ifdef HAVE_THREADS
   pthread_t threads[XZ_MAX_BLOCKS];
   int started[XZ_MAX_BLOCKS];
#endif
   size_t i;
   int ok = 1;

   xz_crc32_init();
   xz_crc64_init();

#ifdef HAVE_THREADS
   for (i = 1; i < count; i++)
      started[i] = pthread_create(&threads[i], NULL, decode_block, &blocks[i]) == 0;
   decode_block(&blocks[0]);
   for (i = 1; i < count; i++)
   {
      if (started[i])
         pthread_join(threads[i], NULL);
      else
         decode_block(&blocks[i]);
   }
#else
   for (i = 0; i < count; i++)
      decode_block(&blocks[i]);
#endif

   for (i = 0; i < count; i++)
      ok &= blocks[i].ok;
   return ok;
}

static int layout_blocks(struct xz_block *blocks, size_t count,
      const uint8_t *in, size_t in_size, uint8_t *out)
{
   uint64_t in_off = XZ_HEADER_SIZE, out_off = 0;
   size_t i;

   for (i = 0; i < count; i++)
   {
      uint64_t padded = (blocks[i].unpadded + 3) & ~(uint64_t)3;

      if (in_off + padded > in_size - XZ_FOOTER_SIZE)
         return 0;
      blocks[i].header = in;
      blocks[i].data   = in + in_off;
      blocks[i].out    = out + out_off;
      in_off          += padded;
      out_off         += blocks[i].usize;
   }
   return 1;
}

static struct
{
   char path[512];
   off_t size;
   time_t mtime;
   int fd;
} cache = { "", 0, 0, -1 };

static dylib_t open_fd(int fd)
{
   char name[40];

   snprintf(name, sizeof(name), "/proc/self/fd/%d", fd);
   return dlopen(name, RTLD_LAZY | RTLD_LOCAL);
}

static int decode_to_shm(const char *path, const struct stat *st)
{
   char tmp[256];
   uint64_t out_size = 0;
   void *in = MAP_FAILED, *out = MAP_FAILED;
   const char *name = strrchr(path, '/');
   struct xz_block blocks[XZ_MAX_BLOCKS];
   size_t count = 0;
   int in_fd, out_fd = -1, ok = 0;

   in_fd = open(path, O_RDONLY | O_CLOEXEC);
   if (in_fd < 0)
      return -1;
   in = mmap(NULL, (size_t)st->st_size, PROT_READ, MAP_PRIVATE, in_fd, 0);
   close(in_fd);
   if (in == MAP_FAILED)
      return -1;

   if (!index_blocks((const uint8_t*)in, (size_t)st->st_size, blocks, &count, &out_size) || !out_size)
      goto done;

   snprintf(tmp, sizeof(tmp), XZ_SHM_DIR "%s.XXXXXX", name ? name + 1 : path);
   out_fd = mkstemp(tmp);
   if (out_fd < 0)
      goto done;
   unlink(tmp);
   fcntl(out_fd, F_SETFD, FD_CLOEXEC);

   if (ftruncate(out_fd, (off_t)out_size) == 0)
      out = mmap(NULL, (size_t)out_size, PROT_READ | PROT_WRITE, MAP_SHARED, out_fd, 0);
   if (out != MAP_FAILED)
   {
      if (count > 1 && count <= XZ_MAX_BLOCKS)
         ok = layout_blocks(blocks, count, (const uint8_t*)in, (size_t)st->st_size, (uint8_t*)out)
            && decode_blocks(blocks, count);
      else
         ok = decode((const uint8_t*)in, (size_t)st->st_size, (uint8_t*)out, (size_t)out_size);
      munmap(out, (size_t)out_size);
   }
   if (!ok)
   {
      close(out_fd);
      out_fd = -1;
   }

done:
   munmap(in, (size_t)st->st_size);
   return out_fd;
}

dylib_t dylib_xz_load(const char *path)
{
   struct stat st;
   int fd;

   if (stat(path, &st) != 0 || st.st_size <= 0)
      return NULL;

   if (cache.fd >= 0 && cache.size == st.st_size && cache.mtime == st.st_mtime
         && !strcmp(cache.path, path))
      return open_fd(cache.fd);

   fd = decode_to_shm(path, &st);
   if (fd < 0)
      return NULL;

   if (cache.fd >= 0)
      close(cache.fd);
   strncpy(cache.path, path, sizeof(cache.path) - 1);
   cache.path[sizeof(cache.path) - 1] = '\0';
   cache.size  = st.st_size;
   cache.mtime = st.st_mtime;
   cache.fd    = fd;
   return open_fd(fd);
}

#endif
