package com.secsite.hbmoc.env;

import com.secsite.hbmoc.util.Reflect;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import net.minecraft.tileentity.TileEntity;

/**
 * Composant générique (component "hbm_machine") pour tout bloc HBM non spécialisé.
 * Expose l'énergie (via la base) + activer/désactiver + un getInfo réflexif.
 */
public class EnvironmentGeneric extends EnvironmentBase {

    public EnvironmentGeneric(TileEntity te) {
        super(te, "hbm_machine");
    }

    @Callback(doc = "function(active:boolean) -- active/désactive le bloc (si supporté)")
    public Object[] setActive(Context context, Arguments args) {
        boolean active = args.checkBoolean(0);
        Object r = Reflect.invoke(te, active ? "activate" : "deactivate");
        if (r == null) {
            Reflect.setField(te, active, "isActive", "active", "on");
        }
        te.markDirty();
        return new Object[] { true };
    }

    @Callback(doc = "function():boolean -- état actif (si connu)")
    public Object[] isActive(Context context, Arguments args) {
        Object v = Reflect.field(te, "isActive", "active", "on");
        return new Object[] { Boolean.TRUE.equals(v) };
    }
}
