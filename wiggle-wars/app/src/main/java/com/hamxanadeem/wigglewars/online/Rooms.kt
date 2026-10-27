package com.hamxanadeem.wigglewars.online

import android.content.Context
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.database.ChildEventListener
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.DatabaseReference
import com.google.firebase.database.FirebaseDatabase
import com.google.firebase.database.ServerValue
import com.google.firebase.database.ValueEventListener
import com.hamxanadeem.wigglewars.BuildConfig
import com.hamxanadeem.wigglewars.core.Codes
import com.hamxanadeem.wigglewars.core.Move
import kotlin.random.Random

/**
 * Online rooms in a Firebase Realtime Database:
 *
 * rooms/{code}/meta     host, seed, worms, status ("lobby" or "playing"), order of players
 * rooms/{code}/players  {playerId: {name, joined}}
 * rooms/{code}/moves    every input, in the order each player sent them
 */
object Rooms {

    private const val APP_NAME = "wiggle-online"
    const val MAX_PLAYERS = 4

    val isConfigured: Boolean
        get() = BuildConfig.FIREBASE_DB_URL.isNotBlank() && BuildConfig.FIREBASE_API_KEY.isNotBlank() &&
            BuildConfig.FIREBASE_APP_ID.isNotBlank() && BuildConfig.FIREBASE_PROJECT_ID.isNotBlank()

    fun database(context: Context): FirebaseDatabase {
        val app = FirebaseApp.getApps(context).firstOrNull { it.name == APP_NAME } ?: FirebaseApp.initializeApp(
            context.applicationContext,
            FirebaseOptions.Builder()
                .setApiKey(BuildConfig.FIREBASE_API_KEY)
                .setApplicationId(BuildConfig.FIREBASE_APP_ID)
                .setProjectId(BuildConfig.FIREBASE_PROJECT_ID)
                .setDatabaseUrl(BuildConfig.FIREBASE_DB_URL)
                .build(),
            APP_NAME,
        )
        return FirebaseDatabase.getInstance(app, BuildConfig.FIREBASE_DB_URL)
    }

    fun room(context: Context, code: String): DatabaseReference = database(context).getReference("rooms").child(code)

    fun newCode(): String = Codes.room()

    fun newPlayerId(): String = java.util.UUID.randomUUID().toString().take(12)

    fun create(context: Context, code: String, playerId: String, name: String, worms: Int, onDone: (Boolean) -> Unit) {
        val ref = room(context, code)
        val meta = mapOf(
            "host" to playerId,
            "seed" to Random.nextLong(),
            "worms" to worms,
            "status" to "lobby",
            "created" to ServerValue.TIMESTAMP,
        )
        ref.child("meta").setValue(meta).continueWithTask {
            ref.child("players").child(playerId).setValue(mapOf("name" to name, "joined" to ServerValue.TIMESTAMP))
        }.addOnCompleteListener { onDone(it.isSuccessful) }
    }

    sealed interface JoinResult {
        data object Joined : JoinResult
        data object NotFound : JoinResult
        data object AlreadyStarted : JoinResult
        data object Full : JoinResult
        data object Failed : JoinResult
    }

    fun join(context: Context, code: String, playerId: String, name: String, onDone: (JoinResult) -> Unit) {
        val ref = room(context, code)
        ref.get().addOnSuccessListener { snap ->
            when {
                !snap.child("meta").exists() -> onDone(JoinResult.NotFound)
                snap.child("meta/status").getValue(String::class.java) != "lobby" -> onDone(JoinResult.AlreadyStarted)
                snap.child("players").childrenCount >= MAX_PLAYERS && !snap.child("players").hasChild(playerId) -> onDone(JoinResult.Full)
                else -> ref.child("players").child(playerId)
                    .setValue(mapOf("name" to name, "joined" to ServerValue.TIMESTAMP))
                    .addOnCompleteListener { onDone(if (it.isSuccessful) JoinResult.Joined else JoinResult.Failed) }
            }
        }.addOnFailureListener { onDone(JoinResult.Failed) }
    }

    /** Host only: fixes the player order (teams) and starts the match for everyone. */
    fun start(context: Context, code: String, orderedPlayerIds: List<String>, worms: Int) {
        room(context, code).child("meta").updateChildren(
            mapOf("order" to orderedPlayerIds, "worms" to worms, "status" to "playing"),
        )
    }

    fun leave(context: Context, code: String, playerId: String) {
        room(context, code).child("players").child(playerId).removeValue()
    }

    /** Watches a room's lobby. Call [Watch.stop] when done. */
    fun watch(context: Context, code: String, onChange: (DataSnapshot) -> Unit, onError: () -> Unit): Watch {
        val ref = room(context, code)
        val listener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) = onChange(snapshot)
            override fun onCancelled(error: DatabaseError) = onError()
        }
        ref.addValueEventListener(listener)
        return Watch { ref.removeEventListener(listener) }
    }

    fun interface Watch {
        fun stop()
    }
}

/**
 * Sends and receives a match's moves. New moves arrive through [onMove]; when the
 * link starts it also replays any moves already in the room, so a phone that
 * restarts the screen catches up by itself.
 */
class MoveLink(context: Context, code: String, private val slot: Int, private val onMove: (Move) -> Unit) {

    private val moves = Rooms.room(context, code).child("moves")
    private val listener = object : ChildEventListener {
        override fun onChildAdded(snapshot: DataSnapshot, previousChildName: String?) {
            val player = snapshot.child("p").getValue(Int::class.javaObjectType) ?: return
            val text = snapshot.child("m").getValue(String::class.java) ?: return
            Move.decode(player, text)?.let(onMove)
        }

        override fun onChildChanged(snapshot: DataSnapshot, previousChildName: String?) = Unit
        override fun onChildRemoved(snapshot: DataSnapshot) = Unit
        override fun onChildMoved(snapshot: DataSnapshot, previousChildName: String?) = Unit
        override fun onCancelled(error: DatabaseError) = Unit
    }

    init {
        moves.addChildEventListener(listener)
    }

    fun send(batch: List<Move>) {
        for (move in batch) moves.push().setValue(mapOf("p" to slot, "m" to move.encode()))
    }

    fun close() = moves.removeEventListener(listener)
}
