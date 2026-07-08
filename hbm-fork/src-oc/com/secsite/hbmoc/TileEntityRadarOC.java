package com.secsite.hbmoc;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import li.cil.oc.api.network.SimpleComponent;
import net.minecraft.tileentity.TileEntity;
import net.minecraftforge.fml.common.Optional;

/**
 * Patron d'intégration OpenComputers pour le radar HBM.
 *
 * En pratique, faire hériter la CLASSE RADAR RÉELLE de HBM CE (ex. TileEntityRadarLarge) de
 * SimpleComponent et y coller les méthodes @Callback ci-dessous, puis remplir getContacts() depuis
 * la liste de blips déjà suivie par le radar. Ici, classe autonome à titre illustratif.
 *
 * OpenComputers est une dépendance OPTIONNELLE : @Optional garantit que HBM tourne sans OC.
 */
@Optional.Interface(iface = "li.cil.oc.api.network.SimpleComponent", modid = "opencomputers")
public class TileEntityRadarOC extends TileEntity implements SimpleComponent {

    /** Nom du composant vu côté Lua : component.hbm_radar */
    @Override
    @Optional.Method(modid = "opencomputers")
    public String getComponentName() {
        return "hbm_radar";
    }

    /**
     * function():table -- renvoie la liste des contacts missiles suivis.
     * Chaque contact : { x, y, z, distance, velocity }.
     */
    @Callback(doc = "function():table -- returns tracked missile contacts", direct = true)
    @Optional.Method(modid = "opencomputers")
    public Object[] getContacts(Context context, Arguments args) {
        List<Map<String, Object>> contacts = new ArrayList<Map<String, Object>>();

        // TODO: itérer la liste interne de blips du radar HBM et remplir 'contacts'.
        // Exemple de forme attendue :
        // for (RadarBlip blip : this.trackedBlips) {
        //     Map<String, Object> c = new HashMap<String, Object>();
        //     c.put("x", blip.posX);
        //     c.put("y", blip.posY);
        //     c.put("z", blip.posZ);
        //     c.put("distance", blip.distanceTo(this));
        //     c.put("velocity", blip.speed);
        //     contacts.add(c);
        // }

        return new Object[] { contacts };
    }

    /**
     * function():number -- niveau de menace 1 (imminent) .. 5 (calme).
     * Utilisé en secours si le serveur préfère un scalaire au lieu des contacts détaillés.
     */
    @Callback(doc = "function():number -- 1 (imminent) .. 5 (clear)", direct = true)
    @Optional.Method(modid = "opencomputers")
    public Object[] getThreatLevel(Context context, Arguments args) {
        int count = 0;
        // TODO: count = this.trackedBlips.size();
        int level;
        if (count <= 0) level = 5;
        else if (count == 1) level = 2;
        else level = 1;
        return new Object[] { Integer.valueOf(level) };
    }
}
