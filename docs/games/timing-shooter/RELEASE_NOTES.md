# Timing Shooter - 2026-10-16

- Remastered Stage 1 transition art and shared gold HOLD YOUR FIRE caption. Left-stair transition shows the male officer only.
- Three randomized normal enemy builds, with character-specific Great/Perfect knockdown sequences.
- Return to mission briefing after abandoning or clearing a stage, retaining stage selection and playing selection music.
- Larger briefing stage labels and weapon corner tags on choice, inventory and active-effect slots.
- Item guide after the eight tutorial lessons, before the OPEN FIRE introduction.
- Stage 2 room totals: 16, 20, 21. The third room spawns three enemies per batch. Its boss summons three guards every two turns and has a 975ms dodge with one midpoint color switch.
- Muzzle flashes follow camera dodges, including VS effects. Shotgun plays one sound per shot.
- VS round counts include both players' attacks. Recent successful network traffic suppresses redundant 10s heartbeats; 30s absence detection requires the updated multiplayer Apps Script.
- Public stage rankings have independent weekly/all-time boards. Existing records migrate to stage1; stage2 starts empty.

## Apps Script Deployment Required

GitHub source updates do not deploy Google Apps Script. Redeploy both the public-ranking and multiplayer projects using their included `Code.gs` files.

The live ranking JSON is deliberately kept unchanged while the online ranking server is still v1. The stage-v2 snapshot is included with the ranking server source. After deploying the new ranking script, run `migrateStageRankings` once: it reads and migrates the latest GitHub revision, preserving any new player records. Do not replace the live file with an old snapshot.

The public ranking implementation is separate from the native AST app's authenticated score service.
