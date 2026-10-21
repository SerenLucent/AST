import 'player_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const privacyPolicyUrl = String.fromEnvironment('NWC_PRIVACY_URL');

void registerBundledLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final entry
        in {
          'Bravura': 'assets/fonts/Bravura-LICENSE.txt',
          'Noto Sans KR': 'assets/fonts/NotoSansKR-LICENSE.txt',
          'Florestan SoundFont': 'assets/soundfonts/README.md',
        }.entries) {
      yield LicenseEntryWithLineBreaks([
        entry.key,
      ], await rootBundle.loadString(entry.value));
    }
  });
}

Future<void> showPlayerInformation(BuildContext context) => showDialog<void>(
  context: context,
  builder:
      (dialogContext) => AlertDialog(
        title: const Text('NWC Player · LUCENTY Labs'),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(playerStrings(dialogContext).privacySummary),
            const SizedBox(height: 12),
            if (privacyPolicyUrl.isNotEmpty)
              TextButton(
                onPressed: () async {
                  try {
                    await const MethodChannel(
                      'nwc/external_url',
                    ).invokeMethod<void>('open', {'url': privacyPolicyUrl});
                  } catch (_) {
                    if (dialogContext.mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            playerStrings(dialogContext).copyPrivacyUrl,
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Text(playerStrings(dialogContext).openPrivacy),
              ),
            SelectableText(
              privacyPolicyUrl.isEmpty
                  ? playerStrings(dialogContext).privacyNotConfigured
                  : privacyPolicyUrl,
            ),
            TextButton(
              onPressed:
                  () => showLicensePage(
                    context: dialogContext,
                    applicationName: 'NWC Player',
                  ),
              child: Text(playerStrings(dialogContext).openLicenses),
            ),
            const Text('© 2026 LUCENTY Labs. All rights reserved.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(playerStrings(dialogContext).close),
          ),
        ],
      ),
);
