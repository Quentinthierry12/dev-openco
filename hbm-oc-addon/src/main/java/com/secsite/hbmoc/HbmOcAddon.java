package com.secsite.hbmoc;

import com.secsite.hbmoc.driver.DriverHbm;

import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.common.event.FMLInitializationEvent;

/**
 * Point d'entrée du mod addon. Dépend d'OpenComputers (requis) et de HBM CE (les blocs à exposer).
 * On enregistre UN driver de bloc qui reconnaît les TileEntity HBM et les transforme en composants
 * OpenComputers via un bloc Adapter — sans modifier HBM.
 */
@Mod(modid = HbmOcAddon.MODID, name = "HBM OpenComputers Addon", version = "0.1.0",
     dependencies = "required-after:opencomputers;after:hbm")
public class HbmOcAddon {

    public static final String MODID = "hbmocaddon";

    @Mod.EventHandler
    public void init(FMLInitializationEvent event) {
        // Enregistre le driver de bloc auprès d'OpenComputers.
        li.cil.oc.api.Driver.add(new DriverHbm());
    }
}
