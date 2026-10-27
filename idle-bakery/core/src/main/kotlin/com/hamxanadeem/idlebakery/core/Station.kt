package com.hamxanadeem.idlebakery.core

/**
 * One kind of pastry the bakery makes. Buying the first level unlocks it; each
 * level adds [revenue] per batch, and each batch takes [seconds].
 */
data class Station(
    val index: Int,
    val name: String,
    val baseCost: Double,
    val costGrowth: Double,
    val revenue: Double,
    val seconds: Double,
    val managerCost: Double,
)

object Menu {
    val stations: List<Station> = listOf(
        Station(0, "Cookies", 4.0, 1.07, 1.0, 0.6, 1_000.0),
        Station(1, "Cupcakes", 60.0, 1.15, 60.0, 3.0, 15_000.0),
        Station(2, "Donuts", 720.0, 1.14, 540.0, 6.0, 100_000.0),
        Station(3, "Croissants", 8_640.0, 1.13, 4_320.0, 12.0, 500_000.0),
        Station(4, "Pies", 103_680.0, 1.12, 51_840.0, 24.0, 1_200_000.0),
        Station(5, "Layer Cakes", 1_244_160.0, 1.11, 622_080.0, 96.0, 10_000_000.0),
        Station(6, "Macarons", 14_929_920.0, 1.10, 7_464_960.0, 384.0, 111_111_111.0),
        Station(7, "Wedding Cakes", 179_159_040.0, 1.09, 89_579_520.0, 1_536.0, 555_555_555.0),
    )

    /** Every one of these levels doubles a station's revenue. */
    val milestones = listOf(25, 50, 100, 200, 300, 400, 500)
}
