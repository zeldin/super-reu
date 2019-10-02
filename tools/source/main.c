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

#if USE_THREADS
#include <pthread.h>
#endif

struct frame {
  uint8_t pixels[200][320][3];
  uint8_t bitmap[25][40][8];
  uint8_t screen[25][40];
  uint8_t color[25][40];
  uint8_t mc;
  uint8_t bg;
#if USE_THREADS
  struct frame *next;
  int ready;
#endif
};

static void convert_frame(struct frame *f, int mc, int player)
{
  f->mc = mc;

  img_convert(&f->pixels, &f->bitmap, &f->screen,
	      (mc? &f->color : NULL), (mc? &f->bg : NULL));

  if (player) {
    img_convert_rev(&f->pixels, &f->bitmap, &f->screen,
		    (mc? &f->color : NULL), f->bg);
  }
}

static int read_frame(struct frame *f, FILE *vframes)
{
  return fread(&f->pixels, sizeof(f->pixels), 1, vframes);
}

#if USE_THREADS

static struct thread_context {
  pthread_mutex_t mutex;
  pthread_cond_t cond;
  FILE *vframes;
  int mc;
  int ntsc;
  int player;
  int eof;
  struct frame *free_queue;
  struct frame *submit_queue;
  struct frame *work_queue;
  struct frame *last_submit;
  int num_threads;
  pthread_t *threads;
} context = {
  PTHREAD_MUTEX_INITIALIZER,
  PTHREAD_COND_INITIALIZER
};

static void *reader_thread(void *arg)
{
  (void) pthread_mutex_lock(&context.mutex);
  for(;;) {
    struct frame *f;
    FILE *vf;
    int rc;
    while ((f = context.free_queue) == NULL)
      (void) pthread_cond_wait(&context.cond, &context.mutex);
    context.free_queue = f->next;
    f->next = NULL;
    f->ready = 0;
    vf = context.vframes;

    (void) pthread_mutex_unlock(&context.mutex);
    rc = read_frame(f, vf);
    (void) pthread_mutex_lock(&context.mutex);

    if (rc != 1) {
      context.eof = 1;
      f->next = context.free_queue;
      context.free_queue = f;
      (void) pthread_cond_broadcast(&context.cond);
      break;
    }

    if (!context.submit_queue)
      context.submit_queue = f;
    else
      context.last_submit->next = f;
    context.last_submit = f;
    if (!context.work_queue) {
      context.work_queue = f;
      (void) pthread_cond_broadcast(&context.cond);
    }
  }
  (void) pthread_mutex_unlock(&context.mutex);
}

static void *worker_thread(void *arg)
{
  (void) pthread_mutex_lock(&context.mutex);
  for(;;) {
    struct frame *f = NULL;
    while (context.work_queue == NULL && !context.eof)
      (void) pthread_cond_wait(&context.cond, &context.mutex);
    if ((f = context.work_queue))
      context.work_queue = f->next;
    if (!f)
      break;

    (void) pthread_mutex_unlock(&context.mutex);
    convert_frame(f, context.mc, context.player);
    (void) pthread_mutex_lock(&context.mutex);

    f->ready = 1;
    (void) pthread_cond_broadcast(&context.cond);
  }
  (void) pthread_mutex_unlock(&context.mutex);
}

static void prepare_convert(FILE *vframes, int mc, int ntsc, int player, int workers)
{
  struct frame *f;
  int i;

  (void) pthread_mutex_lock(&context.mutex);
  context.vframes = vframes;
  context.mc = mc;
  context.ntsc = ntsc;
  context.player = player;
  context.eof = 0;
  context.free_queue = NULL;
  context.submit_queue = NULL;
  context.work_queue = NULL;
  context.last_submit = NULL;
  for (i=0; i<2*workers; i++) {
    f = calloc(1, sizeof(struct frame));
    if (f) {
      f->next = context.free_queue;
      context.free_queue = f;
    }
  }
  f = context.free_queue;
  (void) pthread_mutex_unlock(&context.mutex);
  context.num_threads = workers + 1;
  if (!(context.threads = calloc(context.num_threads, sizeof(pthread_t))) ||
      f == NULL) {
    fprintf(stderr, "Out of memory!\n");
    abort();
  }
  (void) pthread_create(&context.threads[0], NULL, reader_thread, NULL);
  for (i=0; i<workers; i++)
    (void) pthread_create(&context.threads[i+1], NULL, worker_thread, NULL);
}

static struct frame *get_converted_frame(void)
{
  struct frame *f = NULL;
  (void) pthread_mutex_lock(&context.mutex);
  while (context.submit_queue == NULL?
	 !context.eof : !context.submit_queue->ready)
    (void) pthread_cond_wait(&context.cond, &context.mutex);
  if (context.submit_queue && context.submit_queue->ready) {
    f = context.submit_queue;
    if ((context.submit_queue = f->next) == NULL)
      context.last_submit = NULL;
  }
  (void) pthread_mutex_unlock(&context.mutex);
  return f;
}

static void release_frame(struct frame *f)
{
  (void) pthread_mutex_lock(&context.mutex);
  f->next = context.free_queue;
  context.free_queue = f;
  (void) pthread_cond_broadcast(&context.cond);
  (void) pthread_mutex_unlock(&context.mutex);
}

static void cleanup_convert(void)
{
  int i, ok;
  struct frame *f;
  (void) pthread_mutex_lock(&context.mutex);
  ok = (context.eof && context.submit_queue == NULL &&
	context.work_queue == NULL && context.last_submit == NULL);
  while ((f = context.free_queue)) {
    context.free_queue = f->next;
    free(f);
  }
  (void) pthread_mutex_unlock(&context.mutex);
  if (!ok) {
    fprintf(stderr, "Invalid context at cleanup\n");
    abort();
  }
  for(i=0; i<context.num_threads; i++)
    (void) pthread_join(context.threads[i], NULL);
  free(context.threads);
  context.threads = NULL;
  context.num_threads = 0;
}

#else

static struct frame *read_and_convert_frame(struct frame *f, FILE *vframes,
					    int mc, int ntsc, int player)
{
  if (read_frame(f, vframes) != 1)
    return NULL;
  convert_frame(f, mc, player);
  return f;
}

#endif

static void convert(FILE *vframes, FILE *aframes, FILE *player, int mc
#if USE_THREADS
		    , int parallel
#endif
		    )
{
  uint8_t ntsc = 0;
  struct frame *f = NULL;
  uint8_t f_mc = 0;
  uint8_t f_bg = 0;

#if USE_THREADS
  prepare_convert(vframes, mc, ntsc, !!player, parallel);
#else
  struct frame frame;
  memset(&frame, 0, sizeof(frame));
#endif

  for (;;) {

    uint8_t hdr_and_sound[1024];
    uint8_t data[8192+1024+1024];

    memset(hdr_and_sound, 0, sizeof(hdr_and_sound));
    hdr_and_sound[0] = 0xaa;
    hdr_and_sound[1] = 0x4d;
    hdr_and_sound[2] = 1;

    if (f == NULL) {
#if USE_THREADS
      f = get_converted_frame();
#else
      f = read_and_convert_frame(&frame, vframes, mc, ntsc, !!player);
#endif
    }

    uint16_t samples = 320;
    if (aframes) {
      int n;
      samples = fread(hdr_and_sound + 16, 1,
		      (samples > sizeof(hdr_and_sound)-16?
		       sizeof(hdr_and_sound)-16 : samples), aframes);
      for (n=0; n<samples; n++)
	hdr_and_sound[16+n] = 0xf0 | (hdr_and_sound[16+n]>>4);
    } else
      samples = 0;
    if (samples > 0) {
      hdr_and_sound[2] = (samples + 16 + 255) >> 8;
      hdr_and_sound[4] |= 4;
      hdr_and_sound[5] = samples & 0xff;
      hdr_and_sound[6] = samples >> 8;
      hdr_and_sound[8] = 16000 & 0xff;
      hdr_and_sound[9] = 16000 >> 8;
      hdr_and_sound[10] = 61;
      hdr_and_sound[11] = 108;
      hdr_and_sound[12] = 53;
      hdr_and_sound[13] = 108;
    }
    hdr_and_sound[3] = hdr_and_sound[2];

    if (f != NULL) {
      f_mc = f->mc;
      f_bg = f->bg;

      if (player) {
	fwrite(f->pixels, sizeof(f->pixels), 1, player);
      }

      memset(data, 0, sizeof(data));
      memcpy(data+0, f->bitmap, sizeof(f->bitmap));
      memcpy(data+8192, f->screen, sizeof(f->screen));
      if (f_mc)
	memcpy(data+8192+1024, f->color, sizeof(f->color));
#if USE_THREADS
      release_frame(f);
#endif
      f = NULL;
      hdr_and_sound[2] += (f_mc? 32+4+4 : 32+4);
      hdr_and_sound[4] |= (f_mc? 3 : 1);
    } else if(!samples)
      break;

    hdr_and_sound[7] = (ntsc? 60 : 50);
    hdr_and_sound[14] = (f_mc? 0x18 : 0x08);
    hdr_and_sound[15] = (f_mc? f_bg : 0);

    write(1, hdr_and_sound, hdr_and_sound[3]<<8);
    if (hdr_and_sound[2] > hdr_and_sound[3])
      write(1, data, (hdr_and_sound[2] - hdr_and_sound[3]) << 8);
  }
#if USE_THREADS
  cleanup_convert();
#endif
}

static void usage(const char *pname)
{
  fprintf(stderr, "Usage: %s [-f fps] [-m] [-p]\n"
	  "  -f fps      Set video fps\n"
	  "  -m          Enable multicolor\n"
	  "  -p          Display preview while encoding\n"
#if USE_THREADS
	  "  -j number   Set number of video encoder threads\n"
#endif
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
#if USE_THREADS
  int parallel = 1;
#endif

  FILE *vframes = NULL;
  FILE *aframes = NULL;
  FILE *player = NULL;

  while ((opt = getopt(argc, argv,
		       "f:mp"
#if USE_THREADS
		       "j:"
#endif
		       )) != -1) {
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
#if USE_THREADS
    case 'j':
      parallel = strtol(optarg, &endp, 10);
      if (!*optarg || *endp) {
	fprintf(stderr, "Invalid number: %s\n", optarg);
	return 1;
      }
      break;
#endif
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

  convert(vframes, aframes, player, mc
#if USE_THREADS
	  , parallel
#endif
	  );

  if (aframes)
    fclose(aframes);
  fclose(vframes);
  if (player)
    fclose(player);

  return 0;
}
