package com.hamxanadeem.wigglewars.online

import android.content.Context
import com.google.firebase.database.ChildEventListener
import com.google.firebase.database.DataSnapshot
import com.google.firebase.database.DatabaseError
import com.google.firebase.database.ServerValue
import com.google.firebase.database.ValueEventListener
import com.hamxanadeem.wigglewars.core.Codes

/** A friend in your list, with whether they have the online screen open right now. */
data class Friend(val id: String, val name: String, val online: Boolean)

/** An invitation to join a friend's room. */
data class Invite(val id: String, val fromName: String, val room: String)

/**
 * Friends, presence and invites:
 *
 * users/{playerId}        name, friend code, online, lastSeen
 * friendCodes/{code}      playerId, to look players up by code
 * friends/{me}/{friend}   name (both players get each other)
 * invites/{me}/{id}       fromName, room
 */
object Friends {

    private fun db(context: Context) = Rooms.database(context)

    /** Publishes our profile and marks us online until the app disconnects. */
    fun goOnline(context: Context, me: String, name: String, code: String) {
        val user = db(context).getReference("users").child(me)
        user.updateChildren(mapOf("name" to name, "code" to code, "online" to true, "lastSeen" to ServerValue.TIMESTAMP))
        user.child("online").onDisconnect().setValue(false)
        user.child("lastSeen").onDisconnect().setValue(ServerValue.TIMESTAMP)
        db(context).getReference("friendCodes").child(code).setValue(me)
    }

    fun goOffline(context: Context, me: String) {
        db(context).getReference("users").child(me).child("online").setValue(false)
    }

    /**
     * Makes sure our friend code isn't taken by someone else; picks a new one if it is.
     * [onReady] receives the code to use.
     */
    fun claimCode(context: Context, me: String, wanted: String, onReady: (String) -> Unit) {
        db(context).getReference("friendCodes").child(wanted).get().addOnSuccessListener { snap ->
            val owner = snap.getValue(String::class.java)
            if (owner == null || owner == me) onReady(wanted) else claimCode(context, me, Codes.friend(), onReady)
        }.addOnFailureListener { onReady(wanted) }
    }

    sealed interface AddResult {
        data class Added(val name: String) : AddResult
        data object NotFound : AddResult
        data object Yourself : AddResult
        data object Failed : AddResult
    }

    /** Adds the player with friend [code] to our list, and us to theirs. */
    fun add(context: Context, me: String, myName: String, code: String, onDone: (AddResult) -> Unit) {
        val database = db(context)
        database.getReference("friendCodes").child(code).get().addOnSuccessListener { snap ->
            val them = snap.getValue(String::class.java)
            when {
                them == null -> onDone(AddResult.NotFound)
                them == me -> onDone(AddResult.Yourself)
                else -> database.getReference("users").child(them).child("name").get().addOnSuccessListener { nameSnap ->
                    val theirName = nameSnap.getValue(String::class.java) ?: "Friend"
                    database.reference.updateChildren(
                        mapOf(
                            "friends/$me/$them/name" to theirName,
                            "friends/$them/$me/name" to myName,
                        ),
                    ).addOnCompleteListener { onDone(if (it.isSuccessful) AddResult.Added(theirName) else AddResult.Failed) }
                }.addOnFailureListener { onDone(AddResult.Failed) }
            }
        }.addOnFailureListener { onDone(AddResult.Failed) }
    }

    fun remove(context: Context, me: String, friendId: String) {
        db(context).reference.updateChildren(mapOf<String, Any?>("friends/$me/$friendId" to null, "friends/$friendId/$me" to null))
    }

    /** Watches our friends list and each friend's online status. */
    fun watch(context: Context, me: String, onChange: (List<Friend>) -> Unit): Rooms.Watch {
        val database = db(context)
        val friendsRef = database.getReference("friends").child(me)
        val names = LinkedHashMap<String, String>()
        val online = HashMap<String, Boolean>()
        val presence = HashMap<String, ValueEventListener>()

        fun publish() = onChange(
            names.map { (id, name) -> Friend(id, name, online[id] == true) }
                .sortedWith(compareBy({ !it.online }, { it.name.lowercase() })),
        )

        val listener = object : ValueEventListener {
            override fun onDataChange(snapshot: DataSnapshot) {
                val current = snapshot.children.associate { it.key!! to (it.child("name").getValue(String::class.java) ?: "Friend") }
                // Stop watching friends who were removed, start watching new ones.
                for (gone in presence.keys - current.keys) {
                    database.getReference("users").child(gone).child("online").removeEventListener(presence.remove(gone)!!)
                    online.remove(gone)
                }
                for (id in current.keys - presence.keys) {
                    val l = object : ValueEventListener {
                        override fun onDataChange(snapshot: DataSnapshot) {
                            online[id] = snapshot.getValue(Boolean::class.javaObjectType) == true
                            publish()
                        }

                        override fun onCancelled(error: DatabaseError) = Unit
                    }
                    presence[id] = l
                    database.getReference("users").child(id).child("online").addValueEventListener(l)
                }
                names.clear()
                names.putAll(current)
                publish()
            }

            override fun onCancelled(error: DatabaseError) = Unit
        }
        friendsRef.addValueEventListener(listener)
        return Rooms.Watch {
            friendsRef.removeEventListener(listener)
            for ((id, l) in presence) database.getReference("users").child(id).child("online").removeEventListener(l)
            presence.clear()
        }
    }

    fun invite(context: Context, friendId: String, myName: String, room: String) {
        db(context).getReference("invites").child(friendId).push()
            .setValue(mapOf("fromName" to myName, "room" to room, "at" to ServerValue.TIMESTAMP))
    }

    /** Calls [onInvite] for every invitation sent to us while watching. */
    fun watchInvites(context: Context, me: String, onInvite: (Invite) -> Unit): Rooms.Watch {
        val ref = db(context).getReference("invites").child(me)
        val listener = object : ChildEventListener {
            override fun onChildAdded(snapshot: DataSnapshot, previousChildName: String?) {
                val room = snapshot.child("room").getValue(String::class.java) ?: return
                val from = snapshot.child("fromName").getValue(String::class.java) ?: "A friend"
                onInvite(Invite(snapshot.key!!, from, room))
            }

            override fun onChildChanged(snapshot: DataSnapshot, previousChildName: String?) = Unit
            override fun onChildRemoved(snapshot: DataSnapshot) = Unit
            override fun onChildMoved(snapshot: DataSnapshot, previousChildName: String?) = Unit
            override fun onCancelled(error: DatabaseError) = Unit
        }
        ref.addChildEventListener(listener)
        return Rooms.Watch { ref.removeEventListener(listener) }
    }

    fun dismissInvite(context: Context, me: String, inviteId: String) {
        db(context).getReference("invites").child(me).child(inviteId).removeValue()
    }
}
