#pragma once

#include "FlashRuntimeExtensions.h"

#ifdef __cplusplus
extern "C" {
#endif

const char* FREGetCString(FREObject obj);
int32_t FREGetInt32(FREObject obj, int32_t defValue);
uint32_t FREGetBool(FREObject obj, uint32_t defValue);
FREObject FRENewBool(uint32_t value);
FREObject FRENewInt(int32_t value);
FREObject FRENewString(const char* utf8);

#ifdef __cplusplus
}
#endif

