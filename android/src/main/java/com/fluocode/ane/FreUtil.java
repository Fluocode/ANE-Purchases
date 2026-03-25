package com.fluocode.ane;

import com.adobe.fre.FREArray;
import com.adobe.fre.FREObject;

import java.util.ArrayList;
import java.util.List;

final class FreUtil {
    private FreUtil() {}

    static String getString(FREObject[] args, int index, String def) {
        if (args == null || index < 0 || index >= args.length) return def;
        try {
            FREObject o = args[index];
            if (o == null) return def;
            return o.getAsString();
        } catch (Throwable t) {
            return def;
        }
    }

    static int getInt(FREObject[] args, int index, int def) {
        if (args == null || index < 0 || index >= args.length) return def;
        try {
            FREObject o = args[index];
            if (o == null) return def;
            return o.getAsInt();
        } catch (Throwable t) {
            return def;
        }
    }

    static FREArray getArray(FREObject[] args, int index) {
        if (args == null || index < 0 || index >= args.length) return null;
        try {
            return (FREArray) args[index];
        } catch (Throwable t) {
            return null;
        }
    }

    static List<String> toStringList(FREArray arr) {
        List<String> out = new ArrayList<>();
        if (arr == null) return out;
        try {
            long n = arr.getLength();
            for (long i = 0; i < n; i++) {
                try {
                    FREObject o = arr.getObjectAt(i);
                    if (o != null) out.add(o.getAsString());
                } catch (Throwable ignored) {
                }
            }
        } catch (Throwable ignored) {
        }
        return out;
    }
}

