# Timing Shooter Multi Play

This project is separate from the ranking Apps Script. It stores temporary VS and
co-op rooms in Script Properties, not in a spreadsheet or ranking data.

## Deploy

1. Create a new Apps Script project named `Timing Shooter Multi Play`.
2. Replace the default `Code.gs` with this folder's `Code.gs`.
3. Deploy > New deployment > Web app.
4. Execute as yourself; allow Anyone to access the web app.
5. Send the `/exec` URL to connect it in `multiplayer_config.js`.

No manual function execution, spreadsheet, trigger, or extra code file is needed.
Keep the existing ranking project and its deployment unchanged.

## Transport

Writes use a simple text/plain POST. Since Google redirects ContentService and
does not provide configurable CORS response headers, the browser reads a secret
UUID receipt using JSONP. JSONP never executes a write; only authenticated polling
and possession-of-secret receipt reads are accepted through GET. Callbacks are
restricted to the client's generated names. Room/player tokens must not be shared
or logged. Only trust your own deployed endpoint.

Each attack/defense round runs locally without network delays between bullets.
Up to two bullets are active at once. They enter at least 500 ms apart; a queued
bullet uses the first free upper/lower lane. Inputs select the matching color
nearest its judgement time. Results may resolve out of order and are sorted by
original bullet index before submission, preserving attack/dodge damage pairing.
The completed round is submitted once; the server recomputes grades and damage.
Lobby turn/deathmatch edits stay local to the host. Pressing Start saves the final
settings first and only starts the match if that save succeeds; no Apps Script
update is required for this client-side batching.
The opponent receives the same colors, speed levels, and durations. Network
latency may add a pause between turns, but does not determine timing grades.

Room changes are serialized with ScriptLock. Requests have persistent per-room
deduplication; creation/join IDs survive receipt-cache eviction. Repeated rounds
cannot deduct HP twice. An independent authenticated heartbeat is sent every 10
seconds, including while choosing a roulette pattern or playing attack/defense.
A successful authenticated response for the same session within the last 10
seconds suppresses the extra heartbeat. Failed or merely queued requests do not.
Contact age uses request start time, not reply arrival, to handle slow responses.
Players expire after 30 seconds without a request; the next successful poll detects
the departure. Page exit also attempts an authenticated leave beacon. Tab switching
alone does not leave a room. Browser suspension and network loss can also cause
timeout, so this cannot distinguish every forced close from disconnection.
A round may time out after 2 minutes. There are at
most 30 rooms and each room record is bounded below the Properties size limit.
Google quotas still apply. This is a small-player-count prototype, not an
anti-cheat or high-concurrency production service. Client-reported timing is not
trusted proof of an actual key press.

One configured turn is a full pair of attack opportunities: 1P attacks, then 2P
attacks. Five turns allow ten exchanges unless HP reaches zero first. Internal
exchange IDs stay unique; the HUD displays their rounded-up half.
These turn and presence changes require replacing Code.gs in the existing Multi
Play project and deploying a new web app version, retaining the same /exec URL.

## Shared 2P API

`TimingShooterMultiplayer.create('coop')` and `join(code, 'coop')` use the same
deployment, with mode isolation from VS rooms. Authenticated `start` requires the
host and both players. `shareCoopResult({code, token}, battle, {score, hp, defeated})`
stores one result per participant. Both players can read the results via `poll`.
The host calls `coopNext` with the current battle number only after both results
arrive. The normal 2P gameplay/lobby UI is not yet connected to these APIs.

The supplied Google deployment is configured in `multiplayer_config.js`. Clearing
its endpoint switches VS back to the local Node prototype.

## Verify

Run `node tmp/verify-multiplayer-server.cjs` for the Apps Script mock tests.
Run `node tmp/verify-multiplayer-browser.cjs --live` to test the configured real
Google deployment with two anonymous Chrome pages. This verifies room creation,
joining, pattern replay, batch submissions, shared HP, and host leave. Two actual
devices on different networks should still be checked when the game is published.
