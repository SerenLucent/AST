# AST Timing Shooter Integration

## Deployment

- The original TimingShooter workspace keeps its mode selection and WebSocket server.
- `docs/games/timing-shooter` is a separate single-player export. TAP TO START goes directly into the opening. F2/F4 are disabled.
- Run `node tools/export-ast-game.cjs` in the TimingShooter workspace to refresh the staged export.
- Publish the exported files and workflow to AST. Set repository Settings > Pages > Source to GitHub Actions.
- Expected game URL: `https://serenlucent.github.io/AST/games/timing-shooter/`.
- Pages settings and successful deployment must be verified; the source code alone does not make the URL live.

## Dedicated Score Web App

1. Create a separate Google Apps Script project and use `Code.gs` from this folder. Do not replace the existing schedule script.
2. Set Script Properties `GITHUB_TOKEN` (AST Contents read/write token) and a new random `APP_KEY`. Never commit either secret or put them in the game JavaScript.
3. Deploy as a web app executing as the owner. Choose the access setting required for the mobile app; authorize the Google permissions yourself.
4. Build Flutter with existing app settings plus `--dart-define=AST_GAME_SCORE_URL=<web-app-exec-url>` and `--dart-define=AST_GAME_SCORE_KEY=<new-app-key>`. Override `AST_GAME_URL` only if the hosting URL differs.
5. Install the new APK and test a clear. It should append/update `remote-data/games/timing-shooter-scores.json`.

## Behavior And Limits

- Game calculations happen on the device. Only completed clear results are sent via the Flutter JS channel.
- The script checks the app key, registered login ID, integer score bounds, HP conversion, and total sum. It locks writes and retries GitHub SHA conflicts.
- Retries for the same recent run ID are idempotent. Per-player best score and latest result are stored; this is not an unlimited match history.
- Nicknames come from the existing users file. Login IDs are hashed in the score file. If the repository is public, nicknames and game scores are public too.
- Client results and APK app keys can be tampered with/extracted. This is a casual team leaderboard, not secure competitive scoring.
- Each save makes a GitHub commit and consumes Apps Script/GitHub quotas. For heavy traffic use a database instead.
- The WebView only permits navigation under the configured HTTPS game path. No GitHub credentials are exposed to web content.
- A native-device WebView/audio test is required before release. No APK version bump or release upload is included automatically.
