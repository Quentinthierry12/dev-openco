package com.secsite.hbmoc.env;

import com.secsite.hbmoc.util.Reflect;

import li.cil.oc.api.Network;
import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import li.cil.oc.api.network.Visibility;
import li.cil.oc.api.prefab.AbstractManagedEnvironment;
import net.minecraft.tileentity.TileEntity;

/**
 * Base commune des composants HBM exposés à OpenComputers.
 * Fournit le nœud réseau + des callbacks universels (type, énergie).
 */
public abstract class EnvironmentBase extends AbstractManagedEnvironment {

    protected final TileEntity te;

    public EnvironmentBase(TileEntity te, String component) {
        this.te = te;
        setNode(Network.newNode(this, Visibility.Network).withComponent(component).create());
    }

    @Callback(doc = "function():string -- nom de classe HBM du bloc")
    public Object[] getType(Context context, Arguments args) {
        return new Object[] { te == null ? "unknown" : te.getClass().getSimpleName() };
    }

    @Callback(doc = "function():number -- énergie stockée (si le bloc en a)")
    public Object[] getEnergy(Context context, Arguments args) {
        Object v = Reflect.field(te, "power", "energy", "storedPower");
        return new Object[] { (v instanceof Number) ? ((Number) v).doubleValue() : null };
    }
}
