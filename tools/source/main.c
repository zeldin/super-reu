/*
 *  Convert movie to m64 format
 *
 *  Example invocation:
 *
 *  m64conv -f 24 -p -m big_buck_bunny_%05d.png BigBuckBunny-stereo.flac > bunny_mc.m64
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>

#include "imgconv.h"

static void convert(FILE *vframes, FILE *aframes, FILE *player, int mc)
{
  uint8_t pixels[200][320][3];
  uint8_t bitmap[25][40][8];
  uint8_t screen[25][40];
  uint8_t color[25][40];
  uint8_t bg = 0;
  uint8_t ntsc = 0;

  while(fread(pixels, sizeof(pixels), 1, vframes) == 1) {

    img_convert(&pixels, &bitmap, &screen, (mc? &color : NULL), (mc? &bg : NULL));

    if (player) {
      img_convert_rev(&pixels, &bitmap, &screen, (mc? &color : NULL), bg);
      fwrite(pixels, sizeof(pixels), 1, player);
    }

    uint8_t hdr_and_sound[1024];
    uint8_t data[8192+1024+1024];
    memset(data, 0, sizeof(data));
    memcpy(data+0, bitmap, sizeof(bitmap));
    memcpy(data+8192, screen, sizeof(screen));
    if (mc)
      memcpy(data+8192+1024, color, sizeof(color));

    uint16_t samples = 320;
    memset(hdr_and_sound, 0, sizeof(hdr_and_sound));
    if (aframes) {
      int n;
      samples = fread(hdr_and_sound + 16, 1,
		      (samples > sizeof(hdr_and_sound)-16?
		       sizeof(hdr_and_sound)-16 : samples), aframes);
      for (n=0; n<samples; n++)
	hdr_and_sound[16+n] = 0xf0 | (hdr_and_sound[16+n]>>4);
    } else
      samples = 0;
    hdr_and_sound[0] = 0xaa;
    hdr_and_sound[1] = 0x4d;
    hdr_and_sound[3] = (samples + 16 + 255) >> 8;
    hdr_and_sound[2] = hdr_and_sound[3] + (mc? 32+4+4 : 32+4);
    hdr_and_sound[4] = (samples > 0? 4 : 0) | (mc? 3 : 1);
    hdr_and_sound[5] = samples & 0xff;
    hdr_and_sound[6] = samples >> 8;
    hdr_and_sound[7] = (ntsc? 60 : 50);
    hdr_and_sound[8] = 16000 & 0xff;
    hdr_and_sound[9] = 16000 >> 8;
    hdr_and_sound[10] = 61;
    hdr_and_sound[11] = 108;
    hdr_and_sound[12] = 53;
    hdr_and_sound[13] = 108;
    hdr_and_sound[14] = (mc? 0x18 : 0x08);
    hdr_and_sound[15] = (mc? bg : 0);

    write(1, hdr_and_sound, hdr_and_sound[3]<<8);
    write(1, data, (mc? 8192+1024+1024 : 8192+1024));
  }
}

static void usage(const char *pname)
{
  fprintf(stderr, "Usage: %s [-f fps] [-m] [-p]\n"
	  "  -f fps      Set video fps\n"
	  "  -m          Enable multicolor\n"
	  "  -p          Display preview while encoding\n"
	  , pname);
}

static char *cmdline_buffer;
static size_t cmdline_buffer_size, cmdline_buffer_len;

static void cmdline_start()
{
  cmdline_buffer = NULL;
  cmdline_buffer_size = 0;
  cmdline_buffer_len = 0;
}

static char *cmdline_finish()
{
  char *ret = cmdline_buffer;
  cmdline_start();
  return (ret == NULL? "" : ret);
}

static char *cmdline_extend(int len)
{
  size_t min_size = cmdline_buffer_len + len + 1;
  if (min_size > cmdline_buffer_size) {
    size_t new_size = cmdline_buffer_size + (cmdline_buffer_size >> 1);
    char *new = realloc(cmdline_buffer,
			cmdline_buffer_size =
			(min_size > new_size? min_size : new_size));
    if (new == NULL) {
      free(cmdline_buffer);
      fprintf(stderr, "Out of memory!\n");
      exit(1);
    }
    cmdline_buffer = new;
  }
  return cmdline_buffer + cmdline_buffer_len;
}

static void cmdline_append(const char *fmt, ...)
{
  int len, len2;
  char *dst;
  va_list va;
  va_start(va, fmt);
  len = vsnprintf(NULL, 0, fmt, va);
  va_end(va);
  dst = cmdline_extend(len + 1);
  if (cmdline_buffer_len > 0)
    *dst++ = ' ';
  va_start(va, fmt);
  len2 = vsnprintf(dst, len + 1, fmt, va);
  va_end(va);
  dst += (len2 < len? len2 : len);
  cmdline_buffer_len = dst - cmdline_buffer;
}

static void cmdline_append_quoted(const char *str)
{
  int q = 0;
  const char *p;
  char *dst;
  for (p=str; *p; p++)
    if (*p == '\'' || *p == '\\')
      q += 3;
  dst = cmdline_extend(p - str + q + 3);
  if (cmdline_buffer_len > 0)
    *dst++ = ' ';
  *dst++ = '\'';
  for (p=str; *p; p++)
    if (*p == '\'' || *p == '\\') {
      *dst++ = '\'';
      *dst++ = '\\';
      *dst++ = *p;
      *dst++ = '\'';
    } else
      *dst++ = *p;
  *dst++ = '\'';
  *dst = '\0';
  cmdline_buffer_len = dst - cmdline_buffer;
}

int main(int argc, char *argv[])
{
  int opt, mc = 0, preview = 0;
  double fps = 50;
  char *endp, *cmdline;

  FILE *vframes = NULL;
  FILE *aframes = NULL;
  FILE *player = NULL;

  while ((opt = getopt(argc, argv, "f:mp")) != -1) {
    switch (opt) {
    case 'f':
      fps = strtod(optarg, &endp);
      if (!*optarg || *endp) {
	fprintf(stderr, "Invalid number: %s\n", optarg);
	return 1;
      }
      break;
    case 'm':
      mc = 1;
      break;
    case 'p':
      preview = 1;
      break;
    case '?':
    default:
      usage(argv[0]);
      return 1;
    }
  }

  if (optind >= argc) {
    usage(argv[0]);
    return 1;
  }

  cmdline_start();
  cmdline_append("ffmpeg");
  if (strchr(argv[optind], '%'))
    cmdline_append("-framerate %.8g", fps);
  cmdline_append("-i");
  cmdline_append_quoted(argv[optind]);
  cmdline_append("-vf 'scale=w=320:h=200:force_original_aspect_ratio=decrease,pad=320:200:(ow-iw)/2:(oh-ih)/2'");
  cmdline_append("-r %.8g", fps);
  cmdline_append("-f rawvideo -pix_fmt rgb24 -");
  cmdline = cmdline_finish();

  vframes = popen(cmdline, "r");
  free(cmdline);
  if (vframes == NULL) {
    perror("popen");
    return 1;
  }

  cmdline_start();
  cmdline_append("ffmpeg -nostats -hide_banner");
  cmdline_append("-i");
  cmdline_append_quoted(argv[optind+1 >= argc? optind : optind+1]);
  cmdline_append("-f u8 -af volume=10dB,aformat=sample_fmts=u8:sample_rates=%d:channel_layouts=mono -", 16000);
  cmdline = cmdline_finish();

  aframes = popen(cmdline, "r");
  free(cmdline);
  if (aframes == NULL) {
    perror("popen");
    fclose(vframes);
    return 1;
  }

  if (preview) {
    cmdline_start();
    cmdline_append("ffplay -nostats -hide_banner -autoexit");
    cmdline_append("-f rawvideo -pixel_format rgb24");
    cmdline_append("-video_size 320x200 -framerate %.3g -", fps);
    cmdline = cmdline_finish();

    player = popen(cmdline, "w");
    free(cmdline);
    if (player == NULL) {
      perror("popen");
      if (aframes)
	fclose(aframes);
      fclose(vframes);
      return 1;
    }
  }

  convert(vframes, aframes, player, mc);

  if (aframes)
    fclose(aframes);
  fclose(vframes);
  if (player)
    fclose(player);

  return 0;
}
