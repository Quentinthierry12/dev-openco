package com.secsite.hbmoc.env;

import com.secsite.hbmoc.util.Reflect;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import net.minecraft.tileentity.TileEntity;

/**
 * Porte / sas / trappe HBM (component "hbm_door").
 * open/close/isOpen/lock — l'intranet Lua s'y branche via door_driver kind="hbm_oc".
 *
 * ⚠️ Les noms de méthode/champ HBM (open/close/isOpen…) sont à confirmer dans les sources CE ;
 * on tente d'abord une méthode, puis on retombe sur un champ.
 */
public class EnvironmentDoor extends EnvironmentBase {

    public EnvironmentDoor(TileEntity te) {
        super(te, "hbm_door");
    }

    private void setOpen(boolean v) {
        if (Reflect.invoke(te, v ? "open" : "close") != null) {
            te.markDirty();
            return;
        }
        Reflect.setField(te, v, "isOpen", "open", "doorOpen", "state");
        te.markDirty();
    }

    @Callback(doc = "function() -- ouvre la porte")
    public Object[] open(Context context, Arguments args) {
        setOpen(true);
        return new Object[] { true };
    }

    @Callback(doc = "function() -- ferme la porte")
    public Object[] close(Context context, Arguments args) {
        setOpen(false);
        return new Object[] { true };
    }

    @Callback(doc = "function():boolean -- true si ouverte")
    public Object[] isOpen(Context context, Arguments args) {
        Object v = Reflect.field(te, "isOpen", "open", "doorOpen");
        return new Object[] { Boolean.TRUE.equals(v) };
    }

    @Callback(doc = "function(locked:boolean) -- verrouille/déverrouille la porte")
    public Object[] lock(Context context, Arguments args) {
        boolean locked = args.checkBoolean(0);
        Reflect.setField(te, locked, "locked", "isLocked");
        te.markDirty();
        return new Object[] { true };
    }
}
