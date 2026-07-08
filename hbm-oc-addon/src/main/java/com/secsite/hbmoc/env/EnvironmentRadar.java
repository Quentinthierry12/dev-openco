package com.secsite.hbmoc.env;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import li.cil.oc.api.machine.Arguments;
import li.cil.oc.api.machine.Callback;
import li.cil.oc.api.machine.Context;
import net.minecraft.tileentity.TileEntity;

/**
 * Radar HBM (component "hbm_radar") : liste des contacts missiles + niveau de menace.
 * C'est le composant que server/adapters/radar_source.lua utilise en priorité (sinon repli redstone).
 *
 * ⚠️ getContacts() doit être rempli depuis la liste de blips déjà suivie par le radar HBM
 * (à repérer dans la TileEntity radar de CE). Forme d'un contact : { x, y, z, distance, velocity }.
 */
public class EnvironmentRadar extends EnvironmentBase {

    public EnvironmentRadar(TileEntity te) {
        super(te, "hbm_radar");
    }

    @Callback(direct = true, doc = "function():table -- contacts missiles suivis")
    public Object[] getContacts(Context context, Arguments args) {
        List<Map<String, Object>> contacts = new ArrayList<Map<String, Object>>();
        // TODO: itérer la liste interne de blips du radar HBM et remplir 'contacts'.
        // for (Object blip : trackedBlips) {
        //     Map<String,Object> c = new HashMap<String,Object>();
        //     c.put("x", ...); c.put("y", ...); c.put("z", ...);
        //     c.put("distance", ...); c.put("velocity", ...);
        //     contacts.add(c);
        // }
        return new Object[] { contacts };
    }

    @Callback(direct = true, doc = "function():number -- 1 (imminent) .. 5 (calme)")
    public Object[] getThreatLevel(Context context, Arguments args) {
        int count = 0; // TODO: = nombre de blips suivis
        int level = count <= 0 ? 5 : (count == 1 ? 2 : 1);
        return new Object[] { Integer.valueOf(level) };
    }
}
