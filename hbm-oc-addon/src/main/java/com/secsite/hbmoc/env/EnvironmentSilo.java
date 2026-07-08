package com.secsite.hbmoc.env;

import com.secsite.hbmoc.util.Reflect;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import net.minecraft.tileentity.TileEntity;

/**
 * Silo / pas de tir HBM (component "hbm_silo").
 * arm/launch/getState — À CONFIRMER dans les sources CE (méthodes/champs de ciblage et de tir).
 */
public class EnvironmentSilo extends EnvironmentBase {

    public EnvironmentSilo(TileEntity te) {
        super(te, "hbm_silo");
    }

    @Callback(doc = "function() -- arme le silo")
    public Object[] arm(Context context, Arguments args) {
        if (Reflect.invoke(te, "arm") == null) {
            Reflect.setField(te, true, "armed", "isArmed");
        }
        te.markDirty();
        return new Object[] { true };
    }

    @Callback(doc = "function(x:number, z:number) -- règle la cible et lance")
    public Object[] launch(Context context, Arguments args) {
        int x = args.checkInteger(0);
        int z = args.checkInteger(1);
        // TODO: renseigner les champs de cible réels de HBM avant le tir.
        Reflect.setField(te, x, "targetX", "tX");
        Reflect.setField(te, z, "targetZ", "tZ");
        Object r = Reflect.invoke(te, "launch");
        te.markDirty();
        return new Object[] { r != null };
    }

    @Callback(doc = "function():string -- état du silo")
    public Object[] getState(Context context, Arguments args) {
        Object armed = Reflect.field(te, "armed", "isArmed");
        return new Object[] { Boolean.TRUE.equals(armed) ? "armed" : "idle" };
    }
}
