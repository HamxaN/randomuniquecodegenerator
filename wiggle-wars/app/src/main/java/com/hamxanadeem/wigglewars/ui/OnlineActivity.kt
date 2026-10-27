package com.hamxanadeem.wigglewars.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.AppCompatButton
import androidx.core.content.edit
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.google.firebase.database.DataSnapshot
import com.hamxanadeem.wigglewars.R
import com.hamxanadeem.wigglewars.fx.GameSounds
import com.hamxanadeem.wigglewars.fx.Sounds
import com.hamxanadeem.wigglewars.core.Arena
import com.hamxanadeem.wigglewars.core.Codes
import com.hamxanadeem.wigglewars.core.WeaponSet
import com.hamxanadeem.wigglewars.online.Friend
import com.hamxanadeem.wigglewars.online.Friends
import com.hamxanadeem.wigglewars.online.Invite
import com.hamxanadeem.wigglewars.online.Rooms

/**
 * Online play: create or join a room by code, wait for friends, then start
 * together. Below that, your friends list: add friends by friend code, see who's
 * online, and invite them straight into your room.
 */
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
    private var arena: Arena? = null
    private var weaponSet = WeaponSet.STANDARD
    private var watch: Rooms.Watch? = null
    private var launched = false

    private lateinit var friendList: LinearLayout
    private lateinit var friendCodeField: EditText
    private var friendsWatch: Rooms.Watch? = null
    private var invitesWatch: Rooms.Watch? = null
    private var friendCode: String? = null
    private var profileName: String? = null
    private val shownInvites = HashSet<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_online)
        Screen.immersive(this)
        Screen.padForInsets(findViewById(R.id.onlineScroll))
        nameField = findViewById(R.id.nameField)
        codeField = findViewById(R.id.codeField)
        entry = findViewById(R.id.entryPanel)
        lobby = findViewById(R.id.lobbyPanel)
        playersText = findViewById(R.id.playersText)
        startButton = findViewById(R.id.startOnlineButton)
        wormsText = findViewById(R.id.onlineWormsText)
        nameField.setText(prefs.getString("name", ""))

        friendList = findViewById(R.id.friendList)
        friendCodeField = findViewById(R.id.friendCodeField)
        findViewById<Button>(R.id.closeButton).setOnClickListener { finish() }
        if (!Rooms.isConfigured) {
            entry.visibility = View.GONE
            findViewById<View>(R.id.friendsPanel).visibility = View.GONE
            findViewById<View>(R.id.notConfiguredText).visibility = View.VISIBLE
            return
        }
        findViewById<Button>(R.id.addFriendButton).setOnClickListener { addFriend() }
        findViewById<Button>(R.id.shareFriendCodeButton).setOnClickListener { shareFriendCode() }
        // Returning players go online straight away so friends see them.
        prefs.getString("name", null)?.takeIf { it.isNotBlank() }?.let { startProfile(it) }
        findViewById<Button>(R.id.createButton).setOnClickListener { create() }
        findViewById<Button>(R.id.joinButton).setOnClickListener { join() }
        findViewById<Button>(R.id.shareButton).setOnClickListener { share() }
        findViewById<Button>(R.id.leaveButton).setOnClickListener { leave() }
        findViewById<Button>(R.id.onlineWormsMinus).setOnClickListener { worms = (worms - 1).coerceAtLeast(1); renderWorms() }
        findViewById<Button>(R.id.onlineWormsPlus).setOnClickListener { worms = (worms + 1).coerceAtMost(5); renderWorms() }
        val settings = com.hamxanadeem.wigglewars.data.Settings(this)
        arena = Arena.entries.firstOrNull { it.name == settings.arena }
        weaponSet = WeaponSet.entries.firstOrNull { it.name == settings.weaponSet } ?: WeaponSet.STANDARD
        findViewById<Button>(R.id.onlineArenaButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            val options = listOf<Arena?>(null) + Arena.entries
            arena = options[(options.indexOf(arena) + 1) % options.size]
            pushRules()
        }
        findViewById<Button>(R.id.onlineWeaponsButton).setOnClickListener {
            Sounds.play(GameSounds.TAP)
            weaponSet = WeaponSet.entries[(weaponSet.ordinal + 1) % WeaponSet.entries.size]
            pushRules()
        }
        startButton.setOnClickListener { startMatch() }
        intent?.data?.getQueryParameter("room")?.let { codeField.setText(it) }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) Screen.immersive(this)
    }

    private fun name(): String? {
        val name = nameField.text.toString().trim().take(14)
        if (name.isEmpty()) {
            Toast.makeText(this, R.string.enter_name, Toast.LENGTH_SHORT).show()
            return null
        }
        prefs.edit { putString("name", name) }
        if (name != profileName) startProfile(name)
        return name
    }

    // ---------------------------------------------------------------- friends

    /** Publishes our name and friend code, goes online, and starts watching friends and invites. */
    private fun startProfile(name: String) {
        profileName = name
        val wanted = prefs.getString("friend_code", null) ?: Codes.friend()
        Friends.claimCode(this, playerId, wanted) { code ->
            if (isFinishing) return@claimCode
            friendCode = code
            prefs.edit { putString("friend_code", code) }
            findViewById<TextView>(R.id.myFriendCodeText).text = getString(R.string.my_friend_code, Codes.pretty(code))
            Friends.goOnline(this, playerId, name, code)
        }
        friendsWatch?.stop()
        friendsWatch = Friends.watch(this, playerId, ::renderFriends)
        invitesWatch?.stop()
        invitesWatch = Friends.watchInvites(this, playerId, ::onInvite)
    }

    private fun renderFriends(friends: List<Friend>) {
        friendList.removeAllViews()
        findViewById<View>(R.id.noFriendsText).visibility = if (friends.isEmpty()) View.VISIBLE else View.GONE
        for (friend in friends) {
            val row = layoutInflater.inflate(R.layout.item_friend, friendList, false)
            row.findViewById<TextView>(R.id.friendName).text = friend.name
            row.findViewById<TextView>(R.id.friendStatus).apply {
                setText(if (friend.online) R.string.online else R.string.offline)
                setTextColor(if (friend.online) 0xFF69F0AE.toInt() else 0x99FFFFFF.toInt())
            }
            row.findViewById<View>(R.id.friendDot).setBackgroundResource(if (friend.online) R.drawable.dot_online else R.drawable.dot_offline)
            row.findViewById<AppCompatButton>(R.id.inviteButton).setOnClickListener { inviteFriend(friend) }
            row.setOnLongClickListener {
                MaterialAlertDialogBuilder(this)
                    .setMessage(getString(R.string.remove_friend_question, friend.name))
                    .setPositiveButton(R.string.remove) { _, _ -> Friends.remove(this, playerId, friend.id) }
                    .setNegativeButton(R.string.cancel, null)
                    .show()
                true
            }
            friendList.addView(row)
        }
    }

    private fun addFriend() {
        val name = name() ?: return
        val code = Codes.normalize(friendCodeField.text.toString(), Codes.FRIEND_LENGTH)
        if (code == null) {
            Toast.makeText(this, R.string.enter_friend_code, Toast.LENGTH_SHORT).show()
            return
        }
        Sounds.play(GameSounds.TAP)
        Friends.add(this, playerId, name, code) { result ->
            val message = when (result) {
                is Friends.AddResult.Added -> {
                    friendCodeField.setText("")
                    Sounds.play(GameSounds.CRATE)
                    getString(R.string.friend_added, result.name)
                }
                Friends.AddResult.NotFound -> getString(R.string.friend_not_found)
                Friends.AddResult.Yourself -> getString(R.string.friend_yourself)
                Friends.AddResult.Failed -> getString(R.string.online_failed)
            }
            Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        }
    }

    private fun shareFriendCode() {
        val code = friendCode ?: run {
            name()
            return
        }
        val text = getString(R.string.share_friend_text, Codes.pretty(code))
        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), getString(R.string.share)))
    }

    /** Invites a friend into our room, creating one first if we aren't in a lobby yet. */
    private fun inviteFriend(friend: Friend) {
        val name = name() ?: return
        Sounds.play(GameSounds.TAP)
        val room = code
        if (room != null) {
            Friends.invite(this, friend.id, name, room)
            Toast.makeText(this, getString(R.string.invite_sent, friend.name), Toast.LENGTH_SHORT).show()
            return
        }
        val newCode = Rooms.newCode()
        Rooms.create(this, newCode, playerId, name, worms, arena?.name ?: "", weaponSet.name) { ok ->
            if (!ok) {
                Toast.makeText(this, R.string.online_failed, Toast.LENGTH_LONG).show()
                return@create
            }
            enterLobby(newCode, host = true)
            Friends.invite(this, friend.id, name, newCode)
            Toast.makeText(this, getString(R.string.invite_sent, friend.name), Toast.LENGTH_SHORT).show()
        }
    }

    private fun onInvite(invite: Invite) {
        if (isFinishing || !shownInvites.add(invite.id)) return
        Sounds.play(GameSounds.TURN)
        MaterialAlertDialogBuilder(this)
            .setTitle(R.string.invite_title)
            .setMessage(getString(R.string.invite_message, invite.fromName))
            .setPositiveButton(R.string.join_room) { _, _ ->
                Friends.dismissInvite(this, playerId, invite.id)
                if (code != invite.room) {
                    if (code != null) leave()
                    codeField.setText(invite.room)
                    join()
                }
            }
            .setNegativeButton(R.string.not_now) { _, _ -> Friends.dismissInvite(this, playerId, invite.id) }
            .show()
    }

    private fun create() {
        val name = name() ?: return
        Sounds.play(GameSounds.TAP)
        val newCode = Rooms.newCode()
        Rooms.create(this, newCode, playerId, name, worms, arena?.name ?: "", weaponSet.name) { ok ->
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
        findViewById<View>(R.id.hostOptions).visibility = if (host) View.VISIBLE else View.GONE
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
        val roomArena = snapshot.child("meta/arena").getValue(String::class.java).orEmpty()
        val roomWeapons = snapshot.child("meta/weapons").getValue(String::class.java).orEmpty()
        findViewById<TextView>(R.id.rulesText).text = getString(
            R.string.rules_format,
            Arena.entries.firstOrNull { it.name == roomArena }?.displayName ?: getString(R.string.random_arena),
            (WeaponSet.entries.firstOrNull { it.name == roomWeapons } ?: WeaponSet.STANDARD).displayName,
        )
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
                    .putExtra(GameActivity.EXTRA_WORMS, snapshot.child("meta/worms").getValue(Int::class.javaObjectType) ?: 3)
                    .putExtra(GameActivity.EXTRA_ARENA, roomArena.ifEmpty { Arena.HILLS.name })
                    .putExtra(GameActivity.EXTRA_WEAPONS, roomWeapons.ifEmpty { WeaponSet.STANDARD.name }),
            )
            finish()
        }
    }

    private fun pushRules() {
        val room = code ?: return
        if (isHost) Rooms.setRules(this, room, arena?.name ?: "", weaponSet.name)
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
            // A random arena is picked once here, so every phone builds the same map.
            val chosen = arena ?: Arena.entries.random()
            if (order.size >= 2) Rooms.start(this, roomCode, order, worms, chosen.name, weaponSet.name)
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
        friendsWatch?.stop()
        invitesWatch?.stop()
        if (Rooms.isConfigured && profileName != null) Friends.goOffline(this, playerId)
        if (!launched) code?.let { Rooms.leave(this, it, playerId) }
    }
}
