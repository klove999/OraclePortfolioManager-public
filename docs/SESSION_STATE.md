# Session State (Oracle Portfolio Manager)

- Owner: Kirk
- Purpose: running log of key decisions and changes from chat → repo
- Format: newest at top, UTC timestamps

## 2025-11-27
- Initialized SESSION_STATE.md

## 2025-11-28 14:44:03 UTC
- CI: applied robust migration runner in ci.yml
- Added broker scaffold files (Schwab) [planned]

## 2025-11-28 14:48:46 UTC
- Set performance protocol: move artifacts to Git, keep secrets out, optional Git LFS for big binaries.
- Established docs/SESSION_STATE.md and append procedure.
- Agreed on SHA/path referencing and git apply workflow for zero-ambiguity patches.

## 2025-11-28 16:17:46 UTC
- Defined repo hygiene: track code/SQL/docs; ignore envs/DBs/secrets; optional Git LFS for binaries.
- Clarified VS Code Source Control workflow (stage/commit/push) and untracked handling.
- Chat continuity: same thread retains context; new chat requires pasting latest SESSION_STATE.md excerpt; switching GPT version inside thread is safe.

## 2025-11-28 17:31:50 UTC
- Established one-liner bootstrap text for transferring context to a new chat.
- Confirmed that only unsaved chat text is lost; all Git-tracked and summarized work remains intact.
- Canvas cleanup procedure reviewed; feature disabled for new chats.
- Evaluated GitHub connector pros/cons - optional for repo-linked workflow.
