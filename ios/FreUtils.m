#import "FreUtils.h"
#import <Foundation/Foundation.h>

const char* FREGetCString(FREObject obj)
{
	if (!obj) return NULL;
	uint32_t len = 0;
	const uint8_t* str = NULL;
	if (FREGetObjectAsUTF8(obj, &len, &str) != FRE_OK || !str) return NULL;
	return (const char*)str;
}

int32_t FREGetInt32(FREObject obj, int32_t defValue)
{
	if (!obj) return defValue;
	int32_t v = defValue;
	if (FREGetObjectAsInt32(obj, &v) != FRE_OK) return defValue;
	return v;
}

uint32_t FREGetBool(FREObject obj, uint32_t defValue)
{
	if (!obj) return defValue;
	uint32_t v = defValue;
	if (FREGetObjectAsBool(obj, &v) != FRE_OK) return defValue;
	return v;
}

FREObject FRENewBool(uint32_t value)
{
	FREObject o = NULL;
	FRENewObjectFromBool(value ? 1 : 0, &o);
	return o;
}

FREObject FRENewInt(int32_t value)
{
	FREObject o = NULL;
	FRENewObjectFromInt32(value, &o);
	return o;
}

FREObject FRENewString(const char* utf8)
{
	if (!utf8) utf8 = "";
	FREObject o = NULL;
	FRENewObjectFromUTF8((uint32_t)strlen(utf8) + 1, (const uint8_t*)utf8, &o);
	return o;
}

