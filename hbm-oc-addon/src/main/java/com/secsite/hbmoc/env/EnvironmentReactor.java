package com.secsite.hbmoc.env;

import com.secsite.hbmoc.util.Reflect;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import net.minecraft.tileentity.TileEntity;

/**
 * Réacteur HBM (component "hbm_reactor") : supervision température/combustible/puissance + SCRAM.
 * Champs à confirmer dans les sources CE.
 */
public class EnvironmentReactor extends EnvironmentBase {

    public EnvironmentReactor(TileEntity te) {
        super(te, "hbm_reactor");
    }

    private Double num(String... names) {
        Object v = Reflect.field(te, names);
        return (v instanceof Number) ? ((Number) v).doubleValue() : null;
    }

    @Callback(doc = "function():number -- température")
    public Object[] getTemp(Context context, Arguments args) {
        return new Object[] { num("heat", "temperature", "temp") };
    }

    @Callback(doc = "function():number -- combustible restant")
    public Object[] getFuel(Context context, Arguments args) {
        return new Object[] { num("fuel", "fuelLevel") };
    }

    @Callback(doc = "function():number -- puissance produite")
    public Object[] getPower(Context context, Arguments args) {
        return new Object[] { num("power", "output", "production") };
    }

    @Callback(doc = "function() -- arrêt d'urgence (SCRAM)")
    public Object[] scram(Context context, Arguments args) {
        if (Reflect.invoke(te, "scram") == null) {
            Reflect.setField(te, true, "scram", "shutdown");
        }
        te.markDirty();
        return new Object[] { true };
    }
}
