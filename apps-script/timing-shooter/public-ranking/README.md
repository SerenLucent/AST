# Stage Rankings

Use `Code.gs` in the existing **public ranking** Apps Script project, not the multiplayer project.

## Deployment

1. Replace the existing ranking project's source with `Code.gs`.
2. Keep its script properties, including `GITHUB_TOKEN`, `GITHUB_OWNER`, `GITHUB_REPO`, `GITHUB_BRANCH`, and `SCORE_PATH`.
3. Deploy a new version of the existing web app. Keep the current `/exec` URL.
4. Run `migrateStageRankings` once in the editor. This reads the latest GitHub JSON under a lock and converts it without clearing any existing records. Running it again is harmless.
5. Keep the existing `resetWeeklyRankings` trigger; its handler now resets each stage's weekly board independently. All-time records are retained.

No remote data was changed by preparing these files. Do not overwrite live scores with an old packaged JSON snapshot: players may have registered new records since the snapshot.

## Storage

`rankings.json` schema version 2 contains `stages.stage1` through `stages.stage4`. Each stage owns `allTime`, `weekly`, `receipts`, `weekStart`, and `updatedAt`. Every new record/receipt contains `stageId`. Existing two-stage v2 files gain empty stage3/stage4 boards without replacing stage1/stage2 data. Run `migrateStageRankings` once after this update to persist the new boards; it is safe to rerun.

All old version-1 records become **stage1** records with names, scores, order, timestamps, and receipts preserved. Stage2 starts empty. The local legacy backup was verified against GitHub blob `a9b404bfcfa264e1d843c9f2afcf2681dd3d3756` on 2026-10-16.

`leaderboard` and `status` GET requests use `stageId=stage1`, `stage2`, `stage3`, or `stage4`. Score submissions include `result.stageId`. Missing stage IDs from old clients default to stage1; unsupported explicit stage IDs are rejected. Deduplication and TOP 10 qualification are per-stage. The browser ranking UI must also support all four stage IDs before players can submit stage3/stage4 scores.

The new client refuses to show a legacy server's stage1 response as stage2. Deploy the new ranking server before publishing the new client.

The native AST app's authenticated score service is separate; this source is for the public Games leaderboard.
