export const id = "005_unified_support_hub";
export const description =
  "Copy legacy member-trainer conversations into the routed gym support model without deleting originals";

export function legacySupportThreadId(conversationId) {
  return `legacy_${conversationId}`;
}

export function legacySupportInboxId(gymId, threadId) {
  return `gym_${gymId}_${threadId}`;
}

export async function preview({ db }) {
  const conversations = await db.collectionGroup("conversations").count().get();
  return {
    candidateConversations: conversations.data().count,
    note: "Only gyms/<gymId>/conversations documents with one active member are copied. Legacy documents remain readable during rollout.",
  };
}

export async function apply({ db, FieldValue }) {
  const gyms = await db.collection("gyms").get();
  for (const gym of gyms.docs) {
    const conversations = await gym.ref.collection("conversations").get();
    for (const conversation of conversations.docs) {
      const participantUids = [...new Set(
        (conversation.get("participantUids") || []).map(String),
      )];
      if (participantUids.length < 2) continue;
      const memberships = await Promise.all(participantUids.map((uid) =>
        db.doc(`gym_memberships/${gym.id}_${uid}`).get()
      ));
      const member = memberships.find((item) =>
        item.exists && item.get("status") === "active" && item.get("role") === "member"
      );
      if (!member) continue;
      const trainer = memberships.find((item) =>
        item.exists && item.get("status") === "active" && item.get("role") === "trainer"
      );
      const memberUid = String(member.get("uid"));
      const trainerUid = trainer ? String(trainer.get("uid")) : null;
      const threadId = legacySupportThreadId(conversation.id);
      const threadRef = gym.ref.collection("support_threads").doc(threadId);
      const existing = await threadRef.get();
      if (!existing.exists) {
        await threadRef.create({
          gymId: gym.id,
          scopeType: "gym",
          kind: "coaching",
          category: "coaching",
          memberUid,
          requesterUid: memberUid,
          createdByUid: memberUid,
          createdByRole: "member",
          assignedUid: trainerUid,
          participantUids,
          subject: "Trainer support",
          status: "open",
          lastMessage: conversation.get("lastMessage") || "Previous trainer conversation",
          lastMessageAt: conversation.get("lastMessageAt") ||
            conversation.get("updatedAt") || conversation.get("createdAt") || FieldValue.serverTimestamp(),
          createdAt: conversation.get("createdAt") || FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          legacyConversationId: conversation.id,
          migratedAt: FieldValue.serverTimestamp(),
        });
      }
      const messages = await conversation.ref.collection("messages").get();
      const writer = db.bulkWriter();
      for (const message of messages.docs) {
        writer.set(threadRef.collection("messages").doc(message.id), {
          ...message.data(),
          gymId: gym.id,
          threadId,
          senderType: message.get("senderUid") === memberUid ? "member" : "gymStaff",
          migratedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      writer.set(db.doc(`users/${memberUid}/support_inbox/${legacySupportInboxId(gym.id, threadId)}`), {
        scopeType: "gym",
        gymId: gym.id,
        threadId,
        subject: "Trainer support",
        category: "coaching",
        status: "open",
        lastMessage: conversation.get("lastMessage") || "Previous trainer conversation",
        lastMessageAt: conversation.get("lastMessageAt") ||
          conversation.get("updatedAt") || conversation.get("createdAt") || FieldValue.serverTimestamp(),
        unread: false,
        migratedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      await writer.close();
    }
  }
}
