package com.secsite.hbmoc.util;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.HashMap;
import java.util.Map;

/**
 * Accès par réflexion aux champs/méthodes des TileEntity HBM, avec cache.
 * Permet d'exposer les blocs sans dépendre de leurs classes à la compilation (résilient aux versions).
 * Les noms de champs/méthodes sont à confirmer dans les sources de HBM CE.
 */
public final class Reflect {

    private static final Map<String, Field> FIELD_CACHE = new HashMap<String, Field>();

    private Reflect() {}

    /** Lit le premier champ trouvé parmi `names` (remonte la hiérarchie de classes). */
    public static Object field(Object obj, String... names) {
        if (obj == null) return null;
        for (String name : names) {
            Field f = findField(obj.getClass(), name);
            if (f != null) {
                try { return f.get(obj); } catch (IllegalAccessException ignored) {}
            }
        }
        return null;
    }

    /** Écrit le premier champ trouvé parmi `names`. Renvoie true si écrit. */
    public static boolean setField(Object obj, Object value, String... names) {
        if (obj == null) return false;
        for (String name : names) {
            Field f = findField(obj.getClass(), name);
            if (f != null) {
                try { f.set(obj, value); return true; } catch (IllegalAccessException ignored) {}
            }
        }
        return false;
    }

    /** Invoque une méthode sans argument par nom. Renvoie le résultat, ou null. */
    public static Object invoke(Object obj, String name) {
        if (obj == null) return null;
        try {
            Method m = obj.getClass().getMethod(name);
            return m.invoke(obj);
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Field findField(Class<?> cls, String name) {
        String key = cls.getName() + "#" + name;
        if (FIELD_CACHE.containsKey(key)) return FIELD_CACHE.get(key);
        Field found = null;
        Class<?> c = cls;
        while (c != null && found == null) {
            try {
                found = c.getDeclaredField(name);
                found.setAccessible(true);
            } catch (NoSuchFieldException e) {
                c = c.getSuperclass();
            }
        }
        FIELD_CACHE.put(key, found);
        return found;
    }
}
