package com.hamxanadeem.wigglewars.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.edit
import com.google.firebase.database.DataSnapshot
import com.hamxanadeem.wigglewars.R
import com.hamxanadeem.wigglewars.fx.GameSounds
import com.hamxanadeem.wigglewars.fx.Sounds
import com.hamxanadeem.wigglewars.online.Rooms

/** Create or join a room with a code, wait for friends, then start together. */
class OnlineActivity : AppCompatActivity() {

    private lateinit var nameField: EditText
    private lateinit var codeField: EditText
    private lateinit var entry: View
    private lateinit var lobby: View
    private lateinit var playersText: TextView
    private lateinit var startButton: Button
    private lateinit var wormsText: TextView

    private val prefs by lazy { getSharedPreferences("online", MODE_PRIVATE) }
    private val playerId by lazy {
        prefs.getString("player_id", null) ?: Rooms.newPlayerId().also { id -> prefs.edit { putString("player_id", id) } }
    }
    private var code: String? = null
    private var isHost = false
    private var worms = 3
    private var watch: Rooms.Watch? = null
    private var launched = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_online)
        nameField = findViewById(R.id.nameField)
        codeField = findViewById(R.id.codeField)
        entry = findViewById(R.id.entryPanel)
        lobby = findViewById(R.id.lobbyPanel)
        playersText = findViewById(R.id.playersText)
        startButton = findViewById(R.id.startOnlineButton)
        wormsText = findViewById(R.id.onlineWormsText)
        nameField.setText(prefs.getString("name", ""))

        findViewById<Button>(R.id.closeButton).setOnClickListener { finish() }
        if (!Rooms.isConfigured) {
            entry.visibility = View.GONE
            findViewById<View>(R.id.notConfiguredText).visibility = View.VISIBLE
            return
        }
        findViewById<Button>(R.id.createButton).setOnClickListener { create() }
        findViewById<Button>(R.id.joinButton).setOnClickListener { join() }
        findViewById<Button>(R.id.shareButton).setOnClickListener { share() }
        findViewById<Button>(R.id.leaveButton).setOnClickListener { leave() }
        findViewById<Button>(R.id.onlineWormsMinus).setOnClickListener { worms = (worms - 1).coerceAtLeast(1); renderWorms() }
        findViewById<Button>(R.id.onlineWormsPlus).setOnClickListener { worms = (worms + 1).coerceAtMost(5); renderWorms() }
        startButton.setOnClickListener { startMatch() }
        intent?.data?.getQueryParameter("room")?.let { codeField.setText(it) }
    }

    private fun name(): String? {
        val name = nameField.text.toString().trim().take(14)
        if (name.isEmpty()) {
            Toast.makeText(this, R.string.enter_name, Toast.LENGTH_SHORT).show()
            return null
        }
        prefs.edit { putString("name", name) }
        return name
    }

    private fun create() {
        val name = name() ?: return
        Sounds.play(GameSounds.TAP)
        val newCode = Rooms.newCode()
        Rooms.create(this, newCode, playerId, name, worms) { ok ->
            if (ok) enterLobby(newCode, host = true) else Toast.makeText(this, R.string.online_failed, Toast.LENGTH_LONG).show()
        }
    }

    private fun join() {
        val name = name() ?: return
        val roomCode = codeField.text.toString().trim().uppercase()
        if (roomCode.length != 5) {
            Toast.makeText(this, R.string.enter_code, Toast.LENGTH_SHORT).show()
            return
        }
        Sounds.play(GameSounds.TAP)
        Rooms.join(this, roomCode, playerId, name) { result ->
            val message = when (result) {
                Rooms.JoinResult.Joined -> {
                    enterLobby(roomCode, host = false)
                    null
                }
                Rooms.JoinResult.NotFound -> R.string.room_not_found
                Rooms.JoinResult.AlreadyStarted -> R.string.room_started
                Rooms.JoinResult.Full -> R.string.room_full
                Rooms.JoinResult.Failed -> R.string.online_failed
            }
            message?.let { Toast.makeText(this, it, Toast.LENGTH_LONG).show() }
        }
    }

    private fun enterLobby(roomCode: String, host: Boolean) {
        code = roomCode
        isHost = host
        entry.visibility = View.GONE
        lobby.visibility = View.VISIBLE
        findViewById<TextView>(R.id.roomCodeText).text = roomCode
        findViewById<View>(R.id.hostControls).visibility = if (host) View.VISIBLE else View.GONE
        startButton.visibility = if (host) View.VISIBLE else View.GONE
        renderWorms()
        watch?.stop()
        watch = Rooms.watch(this, roomCode, ::onRoomChanged) {
            Toast.makeText(this, R.string.online_failed, Toast.LENGTH_LONG).show()
        }
    }

    private fun playersInOrder(snapshot: DataSnapshot): List<Pair<String, String>> =
        snapshot.child("players").children
            .map { Triple(it.key!!, it.child("name").getValue(String::class.java) ?: "?", it.child("joined").getValue(Long::class.javaObjectType) ?: 0L) }
            .sortedWith(compareBy({ it.third }, { it.first }))
            .map { it.first to it.second }

    private fun onRoomChanged(snapshot: DataSnapshot) {
        if (!snapshot.child("meta").exists()) return
        val players = playersInOrder(snapshot)
        playersText.text = players.mapIndexed { i, (_, n) -> "● ${TeamColors.names[i].substringBefore(' ')}: $n" }.joinToString("\n")
        startButton.isEnabled = players.size >= 2
        startButton.alpha = if (players.size >= 2) 1f else 0.5f
        if (snapshot.child("meta/status").getValue(String::class.java) == "playing" && !launched) {
            val order = snapshot.child("meta/order").children.mapNotNull { it.getValue(String::class.java) }
            val slot = order.indexOf(playerId)
            if (slot < 0) {
                Toast.makeText(this, R.string.room_started, Toast.LENGTH_LONG).show()
                return
            }
            launched = true
            val names = order.map { id -> players.firstOrNull { it.first == id }?.second ?: "Player" }
            startActivity(
                Intent(this, GameActivity::class.java)
                    .putExtra(GameActivity.EXTRA_ROOM, code)
                    .putExtra(GameActivity.EXTRA_SLOT, slot)
                    .putExtra(GameActivity.EXTRA_NAMES, names.toTypedArray())
                    .putExtra(GameActivity.EXTRA_SEED, snapshot.child("meta/seed").getValue(Long::class.javaObjectType) ?: 1L)
                    .putExtra(GameActivity.EXTRA_WORMS, snapshot.child("meta/worms").getValue(Int::class.javaObjectType) ?: 3),
            )
            finish()
        }
    }

    private fun renderWorms() {
        wormsText.text = getString(R.string.worms_format, worms)
    }

    private fun startMatch() {
        val roomCode = code ?: return
        Sounds.play(GameSounds.TAP)
        Rooms.room(this, roomCode).child("players").get().addOnSuccessListener { snap ->
            val order = snap.children
                .map { Triple(it.key!!, it.child("joined").getValue(Long::class.javaObjectType) ?: 0L, 0) }
                .sortedWith(compareBy({ it.second }, { it.first }))
                .map { it.first }
                .take(Rooms.MAX_PLAYERS)
            if (order.size >= 2) Rooms.start(this, roomCode, order, worms)
        }
    }

    private fun share() {
        val roomCode = code ?: return
        val text = getString(R.string.share_text, roomCode)
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), getString(R.string.share)))
    }

    private fun leave() {
        code?.let { Rooms.leave(this, it, playerId) }
        watch?.stop()
        watch = null
        code = null
        lobby.visibility = View.GONE
        entry.visibility = View.VISIBLE
    }

    override fun onDestroy() {
        super.onDestroy()
        watch?.stop()
        if (!launched) code?.let { Rooms.leave(this, it, playerId) }
    }
}
