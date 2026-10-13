#include "include/CPDFium.h"
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef struct {
    FPDF_FILEWRITE interface;
    unsigned char* data;
    size_t length;
} MemoryWriter;

static int append_block(FPDF_FILEWRITE* writer, const void* data, unsigned long size) {
    MemoryWriter* output = (MemoryWriter*)writer;
    const size_t limit = 512 * 1024 * 1024;
    if (size > limit || output->length > limit - size) return 0;
    unsigned char* resized = realloc(output->data, output->length + size);
    if (!resized && size) return 0;
    output->data = resized;
    memcpy(output->data + output->length, data, size);
    output->length += size;
    return 1;
}

unsigned char* FreePDF_SaveCopy(FPDF_DOCUMENT document, size_t* length) {
    if (!document || !length) return NULL;
    MemoryWriter writer = {{1, append_block}, NULL, 0};
    if (!FPDF_SaveAsCopy(document, &writer.interface, FPDF_NO_INCREMENTAL)) {
        free(writer.data);
        return NULL;
    }
    *length = writer.length;
    return writer.data;
}
void FreePDF_FreeBuffer(void* buffer) { free(buffer); }
