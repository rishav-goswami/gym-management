import { describe, expect, it } from "vitest";

import {
  legacySupportInboxId,
  legacySupportThreadId,
} from "../../migrations/005_unified_support_hub.mjs";

describe("legacy support migration identifiers", () => {
  it("uses deterministic thread ids across retries", () => {
    expect(legacySupportThreadId("conversation-a")).toBe(
      legacySupportThreadId("conversation-a"),
    );
    expect(legacySupportThreadId("conversation-a")).toBe(
      "legacy_conversation-a",
    );
  });

  it("uses a tenant and thread scoped inbox id", () => {
    const threadId = legacySupportThreadId("conversation-a");
    expect(legacySupportInboxId("gym-a", threadId)).toBe(
      "gym_gym-a_legacy_conversation-a",
    );
    expect(legacySupportInboxId("gym-b", threadId)).not.toBe(
      legacySupportInboxId("gym-a", threadId),
    );
  });
});
