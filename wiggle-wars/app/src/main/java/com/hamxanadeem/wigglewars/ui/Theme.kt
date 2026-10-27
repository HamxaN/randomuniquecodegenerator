package com.hamxanadeem.wigglewars.ui

import com.hamxanadeem.wigglewars.core.Arena

/** What's drawn behind the land. */
enum class Scenery { MOUNTAINS, DUNES, CASTLES, STALACTITES, NONE }

/** A map's look: sky, land layers and water. Each arena has its own. */
class MapTheme(
    val name: String,
    val skyTop: Int,
    val skyBottom: Int,
    val surface: Int,
    val surfaceDark: Int,
    val soil: Int,
    val soilDark: Int,
    val stone: Int,
    val mountains: Int,
    val water: Int,
    val scenery: Scenery = Scenery.MOUNTAINS,
    val clouds: Boolean = true,
    val stars: Boolean = false,
    /** The sea is molten: glows and throws up embers. */
    val lava: Boolean = false,
) {
    companion object {
        val grassland = MapTheme("Grassland", 0xFF5EC4FF.toInt(), 0xFFD8F1FF.toInt(), 0xFF8BD653.toInt(), 0xFF4E9A2E.toInt(), 0xFF96612F.toInt(), 0xFF5E3A1A.toInt(), 0xFF9E9E9E.toInt(), 0xFF9CC3E0.toInt(), 0xFF2E7BD6.toInt())
        val desert = MapTheme("Desert", 0xFFFF9E57.toInt(), 0xFFFFE3B3.toInt(), 0xFFF2CF7A.toInt(), 0xFFD9A647.toInt(), 0xFFD48C45.toInt(), 0xFF8C4F22.toInt(), 0xFFB08968.toInt(), 0xFFE8B98A.toInt(), 0xFF2A9D8F.toInt(), scenery = Scenery.DUNES)
        val tropical = MapTheme("Tropical", 0xFF29B6F6.toInt(), 0xFFB3F0FF.toInt(), 0xFFFFE082.toInt(), 0xFF7CB342.toInt(), 0xFF8D6E63.toInt(), 0xFF5D4037.toInt(), 0xFFBCAAA4.toInt(), 0xFF80DEEA.toInt(), 0xFF00ACC1.toInt(), scenery = Scenery.NONE)
        val castle = MapTheme("Castle", 0xFF3F51B5.toInt(), 0xFFFFCC80.toInt(), 0xFF7CB342.toInt(), 0xFF33691E.toInt(), 0xFF8D8D8D.toInt(), 0xFF5A5A5A.toInt(), 0xFFBDBDBD.toInt(), 0xFF7986CB.toInt(), 0xFF1565C0.toInt(), scenery = Scenery.CASTLES)
        val cavern = MapTheme("Cavern", 0xFF1A1033.toInt(), 0xFF3B2466.toInt(), 0xFF9575CD.toInt(), 0xFF5E35B1.toInt(), 0xFF4A3B5C.toInt(), 0xFF2B2038.toInt(), 0xFF80DEEA.toInt(), 0xFF2E1F4D.toInt(), 0xFF26C6DA.toInt(), scenery = Scenery.STALACTITES, clouds = false)
        val sky = MapTheme("Sky", 0xFF4FC3F7.toInt(), 0xFFFFF3E0.toInt(), 0xFF9CCC65.toInt(), 0xFF558B2F.toInt(), 0xFFA1887F.toInt(), 0xFF6D4C41.toInt(), 0xFFBCAAA4.toInt(), 0xFFFFFFFF.toInt(), 0xFF0288D1.toInt(), scenery = Scenery.NONE)
        val snowy = MapTheme("Snowy Peaks", 0xFF7FA8D9.toInt(), 0xFFE6F0FA.toInt(), 0xFFFFFFFF.toInt(), 0xFFCFE3F2.toInt(), 0xFF7D8FA3.toInt(), 0xFF46566B.toInt(), 0xFFB0BEC5.toInt(), 0xFFC5D5E8.toInt(), 0xFF3A6EA5.toInt())
        val volcano = MapTheme("Volcano", 0xFF3E1A1A.toInt(), 0xFFFF7043.toInt(), 0xFF5D4037.toInt(), 0xFF3E2723.toInt(), 0xFF4E342E.toInt(), 0xFF261410.toInt(), 0xFFFF7043.toInt(), 0xFF6D2E22.toInt(), 0xFFFF5722.toInt(), clouds = false, lava = true)
        val moon = MapTheme("Moon", 0xFF05060F.toInt(), 0xFF1B1F3A.toInt(), 0xFFE0E0E0.toInt(), 0xFFB0B0B0.toInt(), 0xFF8A8A8A.toInt(), 0xFF5C5C5C.toInt(), 0xFF6E6E6E.toInt(), 0xFF2A2E4A.toInt(), 0xFF3949AB.toInt(), scenery = Scenery.NONE, clouds = false, stars = true)
        val candy = MapTheme("Candy Land", 0xFFFFA6D5.toInt(), 0xFFFFE4F2.toInt(), 0xFFFF7EB9.toInt(), 0xFFE0559A.toInt(), 0xFF8D5A3B.toInt(), 0xFF5A3420.toInt(), 0xFFFFF59D.toInt(), 0xFFF8BBD9.toInt(), 0xFF7E57C2.toInt())

        fun forArena(arena: Arena): MapTheme = when (arena) {
            Arena.HILLS -> grassland
            Arena.DUNES -> desert
            Arena.ISLANDS -> tropical
            Arena.FORTRESS -> castle
            Arena.CAVERN -> cavern
            Arena.SKY -> sky
            Arena.SNOW -> snowy
            Arena.VOLCANO -> volcano
            Arena.MOON -> moon
            Arena.CANDY -> candy
        }
    }
}

object TeamColors {
    val colors = intArrayOf(0xFFE53935.toInt(), 0xFF1E88E5.toInt(), 0xFF43A047.toInt(), 0xFFFDD835.toInt())
    val names = listOf("Red Rockets", "Blue Blasters", "Green Grubs", "Yellow Yolks")
    val dark = intArrayOf(0xFF8E0000.toInt(), 0xFF0D47A1.toInt(), 0xFF1B5E20.toInt(), 0xFFF57F17.toInt())
}

/** Green to yellow to red, for the power meter. */
fun TeamColors.mixHeat(k: Float): Int = when {
    k < 0.5f -> TerrainArt.mix(0xFF69F0AE.toInt(), 0xFFFFEB3B.toInt(), k * 2)
    else -> TerrainArt.mix(0xFFFFEB3B.toInt(), 0xFFFF1744.toInt(), (k - 0.5f) * 2)
}
