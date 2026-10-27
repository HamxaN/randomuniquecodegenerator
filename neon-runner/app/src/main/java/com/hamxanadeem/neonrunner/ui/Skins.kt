package com.hamxanadeem.neonrunner.ui

/** A runner look, bought with energy orbs. */
class Skin(val id: String, val name: String, val price: Int, val suit: Int, val glow: Int, val trail: Int)

object Skins {
    val all = listOf(
        Skin("cyan", "Cyan Volt", 0, 0xFF1B2B4F.toInt(), Neon.CYAN, Neon.CYAN),
        Skin("magenta", "Pink Pulse", 150, 0xFF3A1240.toInt(), Neon.MAGENTA, Neon.MAGENTA),
        Skin("lime", "Toxic Lime", 300, 0xFF15361F.toInt(), Neon.LIME, Neon.LIME),
        Skin("amber", "Solar Flare", 500, 0xFF3D2A0A.toInt(), Neon.AMBER, 0xFFFF6D00.toInt()),
        Skin("violet", "Void Walker", 800, 0xFF20123F.toInt(), Neon.VIOLET, 0xFFB388FF.toInt()),
        Skin("gold", "Golden Ghost", 1500, 0xFF2E2A1A.toInt(), 0xFFFFE066.toInt(), 0xFFFFFFFF.toInt()),
    )

    fun byId(id: String) = all.firstOrNull { it.id == id } ?: all.first()
}
