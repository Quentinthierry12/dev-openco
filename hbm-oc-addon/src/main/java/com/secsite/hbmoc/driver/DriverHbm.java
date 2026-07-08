package com.secsite.hbmoc.driver;

import com.secsite.hbmoc.HbmMapping;

import li.cil.oc.api.driver.DriverBlock;
import li.cil.oc.api.network.ManagedEnvironment;
import net.minecraft.tileentity.TileEntity;
import net.minecraft.util.EnumFacing;
import net.minecraft.util.math.BlockPos;
import net.minecraft.world.World;

/**
 * Driver de bloc OpenComputers reconnaissant les TileEntity HBM.
 * En jeu, un bloc Adapter OpenComputers adjacent à un bloc HBM déclenche ce driver,
 * qui crée l'Environment adapté (porte/silo/radar/réacteur/générique).
 */
public class DriverHbm implements DriverBlock {

    @Override
    public boolean worksWith(World world, BlockPos pos, EnumFacing side) {
        TileEntity te = world.getTileEntity(pos);
        return HbmMapping.isHbm(te);
    }

    @Override
    public ManagedEnvironment createEnvironment(World world, BlockPos pos, EnumFacing side) {
        TileEntity te = world.getTileEntity(pos);
        if (!HbmMapping.isHbm(te)) return null;
        return HbmMapping.createFor(te);
    }
}
