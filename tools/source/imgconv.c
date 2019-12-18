#include <stdint.h>
#include <stddef.h>
#include <string.h>

static uint8_t palette[16][3] = {
  { 0, 0, 0 },        // Black
  { 255, 255, 255 },  // White
  { 136, 0, 0 },      // Red
  { 170, 255, 238 },  // Cyan
  { 204, 68, 204 },   // Purple
  { 0, 204, 85 },     // Green
  { 0, 0, 170 },      // Blue
  { 238, 238, 119 },  // Yellow
  { 221, 136, 85 },   // Orange
  { 102, 68, 0 },     // Brown
  { 255, 119, 119 },  // Light red
  { 51, 51, 51 },     // Grey 1
  { 119, 119, 119 },  // Grey 2
  { 170, 255, 102 },  // Light green
  { 0, 136, 255 },    // Light blue
  { 187, 187, 187 },  // Grey 3
};

#define SET_PALETTE(I, RGB, N) do {		\
    (I) = (N);					\
    (RGB)[0] = palette[(N)][0];			\
    (RGB)[1] = palette[(N)][1];			\
    (RGB)[2] = palette[(N)][2];			\
} while(0)

static const int8_t dither_kernel[8][8] = {
  {    -25,      0,    -18,      6,    -23,      1,    -17,      8 },
  {     13,    -12,     19,     -5,     14,    -10,     21,     -4 },
  {    -15,      9,    -21,      3,    -13,     11,    -20,      5 },
  {     22,     -2,     16,     -9,     24,     -1,     17,     -7 },
  {    -22,      2,    -16,      9,    -24,      1,    -17,      7 },
  {     15,     -9,     21,     -3,     13,    -11,     20,     -5 },
  {    -13,     12,    -19,      5,    -14,     10,    -21,      4 },
  {     25,      0,     18,     -6,     23,     -1,     17,     -8 },
};

static void encode_indices(uint8_t *dst, const uint8_t *indices, int cnt, int w)
{
  while(cnt > 0) {
    uint8_t n = 0;
    int i;
    for (i=0; i<8; i+=w) {
      n = (n<<w) | *indices++;
      --cnt;
    }
    *dst++ = n;
  }
}

static uint32_t distance(const uint8_t (*a)[3], const uint8_t (*b)[3])
{
  int i;
  uint32_t dist = 0;
  for (i=0; i<3; i++) {
    int d = ((int)(*a)[i]) - ((int)(*b)[i]);
    dist += d*d;
  }
  return dist;
}

static uint8_t find_best_index(const uint8_t (*palrgb)[3], int cnt, const uint8_t (*target)[3])
{
  int i;
  int best = 0;
  uint32_t best_dist = (cnt? distance(&palrgb[0], target) : 0);
  for (i=1; i<cnt; i++) {
    uint32_t dist = distance(&palrgb[i], target);
    if (dist < best_dist) {
      best = i;
      best_dist = dist;
    }
  }
  return best;
}

static void to_indices(const uint8_t (*rgb)[3], int npixels, uint8_t *indices,
		       const uint8_t (*palrgb)[3], int palsize)
{
  int i;
  for (i=0; i<npixels; i++)
    indices[i] = find_best_index(palrgb, palsize, &rgb[i]);
}

static int to_colors(const uint8_t (*rgb)[3], int npixels, const uint8_t *indices,
		     uint8_t *pal_index, uint8_t (*palrgb)[3], int total, int locked)
{
  int i, j;
  for (i=locked; i<total; i++) {
    uint32_t r=0, g=0, b=0;
    uint32_t cnt=0;
    for (j=0; j<npixels; j++)
      if (indices[j] == i) {
	cnt++;
	r += rgb[j][0];
	g += rgb[j][1];
	b += rgb[j][2];
      }
    if (cnt > 0) {
      uint8_t avg[3] = { r/cnt, g/cnt, b/cnt };
      uint8_t idx = find_best_index(&palette[0], 16, &avg);
      for (j=0; j<locked; j++)
	if (pal_index[j] == idx)
	  break;
      if (j>=locked) {
	SET_PALETTE(pal_index[locked], palrgb[locked], idx);
	locked++;
      }
    }
  }
  return locked;
}

static void fill_palette(const uint8_t (*rgb)[3], int npixels,
			 uint8_t *pal_index, uint8_t (*palrgb)[3], int cnt, int total)
{
  int i;

  uint8_t indices[npixels];

  to_indices(rgb, npixels, indices, &palette[0], 16);

  uint32_t popularity[16];
  for (i=0; i<16; i++)
    popularity[i] = 0;

  for (i=0; i<npixels; i++)
    popularity[indices[i]] ++;

  for (i=0; i<cnt; i++)
    popularity[pal_index[i]] = 0;

  while (cnt < total) {
    uint32_t maxpop = 0;
    uint8_t idx = 0;

    for (i=0; i<16; i++)
      if (popularity[i] > maxpop) {
	maxpop = popularity[i];
	idx = i;
      }

    popularity[idx] = 0;

    SET_PALETTE(pal_index[cnt], palrgb[cnt], idx);
    cnt++;
  }
}

static void iterate(const uint8_t (*rgb)[3], int npixels, uint8_t *pal_index,
		    uint8_t (*palrgb)[3], int cnt, int total)
{
  int locked = cnt;
  int iters = 0;
  uint8_t old_pal_index[total];
  uint8_t indices[npixels];

  for (;;) {

    fill_palette(rgb, npixels, pal_index, palrgb, cnt, total);

    ++ iters;
    if (iters > 100 ||
	(iters > 1 && !memcmp(old_pal_index, pal_index, total)))
      break;

    memcpy(old_pal_index, pal_index, total);

    to_indices(rgb, npixels, indices, palrgb, total);

    cnt = to_colors(rgb, npixels, indices, pal_index, palrgb, total, locked);

  }
}

static void average2(uint8_t (*dst)[3], const uint8_t (*src)[3])
{
  (*dst)[0] = (src[0][0] + src[1][0]) / 2;
  (*dst)[1] = (src[0][1] + src[1][1]) / 2;
  (*dst)[2] = (src[0][2] + src[1][2]) / 2;
}

static void convert_sub(const uint8_t (*pixels)[64][3],
			uint8_t (*bitmap)[8], uint8_t *screen, uint8_t *color,
			int bg, uint16_t *histo)
{
  int total = (color == NULL? 2 : (bg < 0? 3 : 4));
  int cnt = 0;
  uint8_t pal_index[4];
  uint8_t palrgb[4][3];

  uint8_t pixels_int[64][3];
  int npixels = (color == NULL? 64 : 32);

  if (npixels == 64)
    memcpy(pixels_int, pixels, sizeof(pixels_int));
  else {
    const uint8_t (*pixsrc)[3] = &(*pixels)[0];
    int n;
    for (n=0; n<32; n++) {
      average2(&pixels_int[n], pixsrc);
      pixsrc+=2;
    }
  }

  if (total == 4) {
    SET_PALETTE(pal_index[0], palrgb[0], bg);
    cnt++;
  }

  iterate(&pixels_int[0], npixels, pal_index, palrgb, cnt, total);

  uint8_t indices[64];

  to_indices(&pixels_int[0], npixels, indices, palrgb, total);

  if (histo != NULL) {
    uint8_t used[4];
    int i, unused = 0;
    for (i=0; i<total; i++)
      used[i] = 0;
    for (i=0; i<npixels; i++)
      used[indices[i]] = 1;
    for (i=0; i<total; i++)
      if (!used[i])
	unused ++;
    if (!unused)
      for (i=0; i<total; i++)
	histo[pal_index[i]]++;
  }

  if (total == 2) {
    *screen = pal_index[0] | (pal_index[1] << 4);
    encode_indices(&(*bitmap)[0], indices, 64, 1);
  } else {
    const uint8_t *result = pal_index;
    if (total == 4) {
      result++;
    } else {
      int i;
      for (i=0; i<32; i++)
	indices[i]++;
    }
    *screen = result[1] | (result[0] << 4);
    *color = result[2] | 0xf0;
    encode_indices(&(*bitmap)[0], indices, 32, 2);
  }
}

static void low_convert(const uint8_t (*pixels)[200][320][3],
			uint8_t (*bitmap)[25][40][8],
			uint8_t (*screen)[25][40],
			uint8_t (*color)[25][40],
			int bg, uint16_t *histo, uint8_t dither)
{
  int r, c, rsub, csub, comp;
  for (r=0; r<25; r++)
    for (c=0; c<40; c++) {
      uint8_t subpixels[64][3];
      for (rsub=0; rsub<8; rsub++)
	for (csub=0; csub<8; csub++)
	  for (comp=0; comp<3; comp++)
	    if (dither) {
	      int16_t v = (*pixels)[(r<<3)|rsub][(c<<3)|csub][comp];
	      v += dither_kernel[(((r<<3)|rsub)/dither)&7][(((c<<3)|csub)/dither)&7];
	      subpixels[(rsub<<3)|csub][comp] =
		(v < 0? 0 : (v > 255? 255 : v));
	    } else
	      subpixels[(rsub<<3)|csub][comp] =
		(*pixels)[(r<<3)|rsub][(c<<3)|csub][comp];
      convert_sub(&subpixels, &(*bitmap)[r][c], &(*screen)[r][c],
		  (color == NULL? NULL : &(*color)[r][c]), bg, histo);
    }
}

void img_convert(const uint8_t (*pixels)[200][320][3],
		 uint8_t (*bitmap)[25][40][8],
		 uint8_t (*screen)[25][40],
		 uint8_t (*color)[25][40],
		 uint8_t *bg, uint8_t dither)
{
  int r, c, i;
  uint16_t histo[16];
  for (i=0; i<16; i++)
    histo[i] = 0;
  low_convert(pixels, bitmap, screen, color, -1, histo, dither);
  if (color != NULL && bg != NULL) {
    int n=0;
    for (i=1; i<16; i++)
      if (histo[i] > histo[n])
	n = i;
    *bg = n;
    low_convert(pixels, bitmap, screen, color, n, NULL, dither);
  }
}

static void convert_rev_sub(uint8_t (*pixels)[3],
			    const uint8_t (*bitmap)[8],
			    const uint8_t *screen, const uint8_t *color,
			    uint8_t bg)
{
  int x, y;
  uint8_t pali[4];
  uint8_t pal[4][3];
  if (color == NULL) {
    pali[0] = (*screen) & 0xf;
    pali[1] = (*screen) >> 4;
    pali[2] = 0;
    pali[3] = 0;
  } else {
    pali[0] = bg;
    pali[1] = (*screen) >> 4;
    pali[2] = (*screen) & 0xf;
    pali[3] = (*color) & 0xf;
  }
  for (x = 0; x < 4; x++)
    for (y = 0; y < 3; y++)
      pal[x][y] = palette[pali[x]][y];
  for (y = 0; y < 8; y++) {
    uint8_t b = (*bitmap)[y];
    uint8_t i;
    for (x = 0; x < 8; x++) {
      if (!(x&1)) {
	if (color == NULL)
	  i = ((b>>5)&4) | ((b>>6)&1);
	else
	  i = ((b>>6)&3) | ((b>>4)&0xc);
	b <<= 2;
      }
      (*pixels)[0] = pal[(i>>2)&3][0];
      (*pixels)[1] = pal[(i>>2)&3][1];
      (*pixels)[2] = pal[(i>>2)&3][2];
      i <<= 2;
      pixels++;
    }
  }
}

extern void hexdump(const uint8_t *p, int len);

void img_convert_rev(uint8_t (*pixels)[200][320][3],
		     const uint8_t (*bitmap)[25][40][8],
		     const uint8_t (*screen)[25][40],
		     const uint8_t (*color)[25][40],
		     const uint8_t bg)
{
  int r, c, rsub, csub;
  for (r=0; r<25; r++)
    for (c=0; c<40; c++) {
      uint8_t subpixels[64][3];
      convert_rev_sub(&subpixels[0], &(*bitmap)[r][c], &(*screen)[r][c],
		      (color == NULL? NULL : &(*color)[r][c]), bg);
      for (rsub=0; rsub<8; rsub++)
	for (csub=0; csub<8; csub++) {
	  (*pixels)[(r<<3)|rsub][(c<<3)|csub][0] = subpixels[(rsub<<3)|csub][0];
	  (*pixels)[(r<<3)|rsub][(c<<3)|csub][1] = subpixels[(rsub<<3)|csub][1];
	  (*pixels)[(r<<3)|rsub][(c<<3)|csub][2] = subpixels[(rsub<<3)|csub][2];
	}
    }
}
