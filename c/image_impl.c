#include <stdlib.h>


void* (*zstbMallocPtr)(size_t size) = NULL;
void* (*zstbReallocPtr)(void* ptr, size_t size) = NULL;
void (*zstbFreePtr)(void* ptr) = NULL;

#define STBI_MALLOC(size) zstbMallocPtr(size)
#define STBI_REALLOC(ptr, size) zstbReallocPtr(ptr, size)
#define STBI_FREE(ptr) zstbFreePtr(ptr)

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"


#define STBIW_MALLOC(size) zstbMallocPtr(size)
#define STBIW_REALLOC(ptr, size) zstbReallocPtr(ptr, size)
#define STBIW_FREE(ptr) zstbFreePtr(ptr)

#define STB_IMAGE_WRITE_IMPLEMENTATION
#include "stb_image_write.h"


void* (*zstbirMallocPtr)(size_t size, void* context) = NULL;
void (*zstbirFreePtr)(void* ptr, void* context) = NULL;

#define STBIR_MALLOC(size, context) zstbirMallocPtr(size, context)
#define STBIR_FREE(ptr, context) zstbirFreePtr(ptr, context)

#define STB_IMAGE_RESIZE_IMPLEMENTATION
#include "stb_image_resize2.h"
