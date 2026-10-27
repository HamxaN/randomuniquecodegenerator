package com.hamxanadeem.penguinslide.core

enum class Hat { NONE, BEANIE, TOP_HAT, CROWN, HEADPHONES, PARTY }

/** A penguin look. Colours are ARGB. */
data class Skin(val id: String, val name: String, val price: Int, val scarf: Long, val hat: Hat, val hatColor: Long = scarf)

object SkinCatalog {
    val all: List<Skin> = listOf(
        Skin("classic", "Classic", 0, 0xFFE53935, Hat.NONE),
        Skin("cozy", "Cozy Beanie", 150, 0xFF1E88E5, Hat.BEANIE),
        Skin("party", "Party Time", 300, 0xFFFFB300, Hat.PARTY, 0xFFEC407A),
        Skin("dj", "DJ Pengu", 600, 0xFF7E57C2, Hat.HEADPHONES, 0xFF263238),
        Skin("gent", "Gentleman", 1000, 0xFF43A047, Hat.TOP_HAT, 0xFF212121),
        Skin("royal", "Royal", 2500, 0xFF8E24AA, Hat.CROWN, 0xFFFFD54F),
    )
    val default = all.first()
    fun byId(id: String): Skin = all.firstOrNull { it.id == id } ?: default
}

/** Saved progress: fish to spend, skins, and records. */
data class Progress(
    val fish: Int = 0,
    val ownedSkins: Set<String> = setOf(SkinCatalog.default.id),
    val selectedSkin: String = SkinCatalog.default.id,
    val bestScore: Int = 0,
    val bestDistance: Int = 0,
) {
    val skin: Skin get() = SkinCatalog.byId(selectedSkin)

    /** Banks a finished run's fish and records. */
    fun afterRun(run: Run): Progress = copy(
        fish = fish + run.fishCaught,
        bestScore = maxOf(bestScore, run.score),
        bestDistance = maxOf(bestDistance, run.distance),
    )

    /** Extra fish, e.g. doubling a run's catch after a rewarded ad. */
    fun addFish(amount: Int): Progress {
        require(amount >= 0) { "Amount must not be negative" }
        return copy(fish = fish + amount)
    }

    fun buy(skin: Skin): Progress? = when {
        skin.id in ownedSkins -> null
        fish < skin.price -> null
        else -> copy(fish = fish - skin.price, ownedSkins = ownedSkins + skin.id, selectedSkin = skin.id)
    }

    fun select(skin: Skin): Progress = if (skin.id in ownedSkins) copy(selectedSkin = skin.id) else this
}
