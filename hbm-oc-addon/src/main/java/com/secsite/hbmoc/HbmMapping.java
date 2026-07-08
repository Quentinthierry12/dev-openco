package com.secsite.hbmoc;

import com.secsite.hbmoc.env.EnvironmentDoor;
import com.secsite.hbmoc.env.EnvironmentGeneric;
import com.secsite.hbmoc.env.EnvironmentRadar;
import com.secsite.hbmoc.env.EnvironmentReactor;
import com.secsite.hbmoc.env.EnvironmentSilo;

import li.cil.oc.api.network.ManagedEnvironment;
import net.minecraft.tileentity.TileEntity;

/**
 * Choisit l'Environment OpenComputers à créer selon la TileEntity HBM rencontrée.
 * Le matching se fait sur le NOM SIMPLE de la classe (sous-chaîne) → ajustable sans recompiler tout,
 * et résilient si HBM renomme/déplace des classes. Fallback = driver générique (énergie/NBT/actif).
 *
 * ⚠️ Les sous-chaînes ci-dessous sont indicatives : à confirmer dans les sources de HBM CE
 * (ex. les portes blast, la trappe de silo, le radar, les réacteurs).
 */
public final class HbmMapping {

    private HbmMapping() {}

    /** true si la TE appartient à HBM (package com.hbm.*). */
    public static boolean isHbm(TileEntity te) {
        return te != null && te.getClass().getName().startsWith("com.hbm.");
    }

    public static ManagedEnvironment createFor(TileEntity te) {
        String n = te.getClass().getSimpleName().toLowerCase();

        if (n.contains("door") || n.contains("hatch") || n.contains("bulkhead")) {
            return new EnvironmentDoor(te);
        }
        if (n.contains("silo") || n.contains("launchpad") || n.contains("launch")) {
            return new EnvironmentSilo(te);
        }
        if (n.contains("radar")) {
            return new EnvironmentRadar(te);
        }
        if (n.contains("reactor") || n.contains("rbmk") || n.contains("fusion")) {
            return new EnvironmentReactor(te);
        }
        // Tout le reste du parc HBM : exposition générique (énergie / infos / actif).
        return new EnvironmentGeneric(te);
    }
}
