package com.hamxanadeem.wigglewars.ui

/** A map's look: sky, land layers and water. Picked from the match seed. */
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
) {
    companion object {
        val all = listOf(
            MapTheme("Grassland", 0xFF5EC4FF.toInt(), 0xFFD8F1FF.toInt(), 0xFF8BD653.toInt(), 0xFF4E9A2E.toInt(), 0xFF96612F.toInt(), 0xFF5E3A1A.toInt(), 0xFF9E9E9E.toInt(), 0xFF9CC3E0.toInt(), 0xFF2E7BD6.toInt()),
            MapTheme("Desert", 0xFFFF9E57.toInt(), 0xFFFFE3B3.toInt(), 0xFFF2CF7A.toInt(), 0xFFD9A647.toInt(), 0xFFD48C45.toInt(), 0xFF8C4F22.toInt(), 0xFFB08968.toInt(), 0xFFE8B98A.toInt(), 0xFF2A9D8F.toInt()),
            MapTheme("Snowy Peaks", 0xFF7FA8D9.toInt(), 0xFFE6F0FA.toInt(), 0xFFFFFFFF.toInt(), 0xFFCFE3F2.toInt(), 0xFF7D8FA3.toInt(), 0xFF46566B.toInt(), 0xFFB0BEC5.toInt(), 0xFFC5D5E8.toInt(), 0xFF3A6EA5.toInt()),
            MapTheme("Candy Land", 0xFFFFA6D5.toInt(), 0xFFFFE4F2.toInt(), 0xFFFF7EB9.toInt(), 0xFFE0559A.toInt(), 0xFF8D5A3B.toInt(), 0xFF5A3420.toInt(), 0xFFFFF59D.toInt(), 0xFFF8BBD9.toInt(), 0xFF7E57C2.toInt()),
        )

        fun forSeed(seed: Long) = all[(seed.mod(all.size.toLong())).toInt()]
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
