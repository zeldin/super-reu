#include <stdint.h>

void img_convert(const uint8_t (*pixels)[200][320][3],
		 uint8_t (*bitmap)[25][40][8],
		 uint8_t (*screen)[25][40],
		 uint8_t (*color)[25][40],
		 uint8_t *bg);

void img_convert_rev(uint8_t (*pixels)[200][320][3],
		     const uint8_t (*bitmap)[25][40][8],
		     const uint8_t (*screen)[25][40],
		     const uint8_t (*color)[25][40],
		     const uint8_t bg);


