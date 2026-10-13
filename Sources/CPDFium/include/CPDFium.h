#ifndef FREEPDF_CPDFIUM_H
#define FREEPDF_CPDFIUM_H
#include "../../../Vendor/pdfium/include/fpdfview.h"
#include "../../../Vendor/pdfium/include/fpdf_edit.h"
#include "../../../Vendor/pdfium/include/fpdf_text.h"
#include "../../../Vendor/pdfium/include/fpdf_save.h"
#include <stddef.h>
unsigned char* FreePDF_SaveCopy(FPDF_DOCUMENT document, size_t* length);
void FreePDF_FreeBuffer(void* buffer);
#endif
