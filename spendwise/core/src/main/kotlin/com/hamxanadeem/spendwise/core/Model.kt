package com.hamxanadeem.spendwise.core

import java.time.LocalDate
import java.time.YearMonth

enum class Kind { EXPENSE, INCOME }

enum class Every(val label: String) {
    WEEKLY("Weekly"), MONTHLY("Monthly"), YEARLY("Yearly");

    /** The [n]th date of a rule starting on [start] (n = 0 is the start), keeping the day of month. */
    fun nth(start: LocalDate, n: Long): LocalDate = when (this) {
        WEEKLY -> start.plusWeeks(n)
        MONTHLY -> start.plusMonths(n)
        YEARLY -> start.plusYears(n)
    }

    /** Roughly how many times a year this repeats. */
    val perYear: Double
        get() = when (this) {
            WEEKLY -> 52.0
            MONTHLY -> 12.0
            YEARLY -> 1.0
        }
}

/**
 * A spending or income category. [budget] is a monthly limit in minor units (0 = none);
 * with [rollover], what is left (or overspent) carries into the next month.
 */
data class Category(
    val id: String,
    val name: String,
    val icon: String,
    val color: Long,
    val kind: Kind = Kind.EXPENSE,
    val budget: Long = 0,
    val rollover: Boolean = false,
    val keywords: List<String> = emptyList(),
    val archived: Boolean = false,
)

/** One transaction. [amount] is positive, in minor units (cents); [kind] says which way it went. */
data class Txn(
    val id: String,
    val amount: Long,
    val kind: Kind,
    val categoryId: String,
    val note: String,
    val date: LocalDate,
    val recurringId: String? = null,
    val createdAt: Long = 0,
)

/** A repeating transaction that is added automatically when it falls due. */
data class Recurring(
    val id: String,
    val amount: Long,
    val kind: Kind,
    val categoryId: String,
    val note: String,
    val start: LocalDate,
    val every: Every,
    val lastPosted: LocalDate? = null,
) {
    /** The dates on or before [today] that have not been posted yet. */
    fun due(today: LocalDate, limit: Int = 400): List<LocalDate> {
        val out = mutableListOf<LocalDate>()
        var n = 0L
        while (out.size < limit) {
            val d = every.nth(start, n)
            if (d.isAfter(today)) break
            if (lastPosted == null || d.isAfter(lastPosted)) out += d
            n++
        }
        return out
    }

    /** The next date this falls due after [today]. */
    fun next(today: LocalDate): LocalDate {
        var n = 0L
        while (true) {
            val d = every.nth(start, n)
            if (d.isAfter(today) && (lastPosted == null || d.isAfter(lastPosted))) return d
            n++
        }
    }
}

fun YearMonth.contains(d: LocalDate) = d.year == year && d.monthValue == monthValue

object Defaults {
    /** A sensible starting set of categories, each with words that point to it. */
    val categories: List<Category> = listOf(
        Category("food", "Food & Dining", "food", 0xFFEF6C00, keywords = listOf("restaurant", "lunch", "dinner", "breakfast", "pizza", "burger", "cafe", "coffee", "starbucks", "mcdonalds", "kfc", "subway", "sushi", "takeaway", "doordash", "ubereats", "deliveroo", "foodpanda", "snack", "tea")),
        Category("groceries", "Groceries", "cart", 0xFF2E7D32, keywords = listOf("grocery", "groceries", "supermarket", "walmart", "aldi", "lidl", "tesco", "costco", "carrefour", "milk", "bread", "eggs", "vegetables", "fruit", "market")),
        Category("transport", "Transport", "car", 0xFF1565C0, keywords = listOf("uber", "lyft", "careem", "taxi", "cab", "bus", "train", "metro", "subway fare", "fuel", "petrol", "gas", "diesel", "parking", "toll", "ticket")),
        Category("bills", "Bills & Utilities", "bolt", 0xFF6A1B9A, keywords = listOf("electricity", "electric", "water", "internet", "wifi", "phone", "mobile", "bill", "rent", "gas bill", "utility", "insurance")),
        Category("shopping", "Shopping", "bag", 0xFFC2185B, keywords = listOf("amazon", "daraz", "clothes", "shoes", "shirt", "mall", "zara", "h&m", "ikea", "electronics", "gift")),
        Category("subscriptions", "Subscriptions", "repeat", 0xFF00838F, keywords = listOf("netflix", "spotify", "youtube", "disney", "prime", "icloud", "google one", "chatgpt", "subscription", "membership", "gym")),
        Category("health", "Health", "heart", 0xFFD32F2F, keywords = listOf("doctor", "pharmacy", "medicine", "hospital", "dentist", "clinic", "vitamins", "lab test")),
        Category("fun", "Entertainment", "star", 0xFFF9A825, keywords = listOf("movie", "cinema", "concert", "game", "games", "steam", "playstation", "xbox", "bowling", "party", "tickets")),
        Category("travel", "Travel", "plane", 0xFF0277BD, keywords = listOf("flight", "hotel", "airbnb", "booking", "airline", "visa", "trip", "holiday", "vacation")),
        Category("education", "Education", "book", 0xFF4E342E, keywords = listOf("school", "tuition", "course", "books", "udemy", "coursera", "university", "fees")),
        Category("home", "Home", "home", 0xFF5D4037, keywords = listOf("furniture", "repair", "cleaning", "plumber", "hardware", "maintenance")),
        Category("other", "Other", "dots", 0xFF757575),
        Category("salary", "Salary", "wallet", 0xFF2E7D32, Kind.INCOME, keywords = listOf("salary", "paycheck", "payroll", "wage", "wages")),
        Category("freelance", "Freelance", "briefcase", 0xFF00695C, Kind.INCOME, keywords = listOf("freelance", "client", "invoice", "project", "upwork", "fiverr")),
        Category("gifts_in", "Gifts & Refunds", "gift", 0xFFAD1457, Kind.INCOME, keywords = listOf("refund", "cashback", "gift", "bonus", "reimbursement")),
        Category("other_in", "Other income", "plus", 0xFF558B2F, Kind.INCOME, keywords = listOf("interest", "dividend", "sold", "income")),
    )

    const val FALLBACK_EXPENSE = "other"
    const val FALLBACK_INCOME = "other_in"
}
