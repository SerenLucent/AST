import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'player_localizations.dart';
import 'score_file_input.dart';

class ScoreFolderEntry {
  const ScoreFolderEntry({
    required this.id,
    required this.name,
    required this.directory,
    this.size = -1,
  });

  factory ScoreFolderEntry.fromMap(Map<Object?, Object?> value) =>
      ScoreFolderEntry(
        id: value['id'] as String,
        name: value['name'] as String,
        directory: value['directory'] == true,
        size: (value['size'] as num?)?.toInt() ?? -1,
      );

  final String id, name;
  final bool directory;
  final int size;
  bool get tooLarge => !directory && size > maxScoreFileBytes;
}

/// Android owns the persisted read-only tree grant. No storage paths or writes.
class ScoreFolderService {
  const ScoreFolderService();
  static const channel = MethodChannel('nwc/score_folders');

  Future<ScoreFolderEntry?> _folder(String method) async {
    final value = await channel.invokeMapMethod<Object?, Object?>(method);
    return value == null ? null : ScoreFolderEntry.fromMap(value);
  }

  Future<ScoreFolderEntry?> root() => _folder('root');
  Future<ScoreFolderEntry?> chooseRoot() => _folder('chooseRoot');

  Future<List<ScoreFolderEntry>> list(String id) async {
    final values = await channel.invokeListMethod<Object?>('list', {'id': id});
    final entries =
        (values ?? [])
            .map(
              (value) => ScoreFolderEntry.fromMap(
                (value as Map).cast<Object?, Object?>(),
              ),
            )
            .where(
              (entry) => entry.directory || isSupportedScoreName(entry.name),
            )
            .toList();
    entries.sort(
      (a, b) =>
          a.directory != b.directory
              ? (a.directory ? -1 : 1)
              : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  Future<PlatformFile> read(ScoreFolderEntry entry) async {
    validateScoreName(entry.name);
    if (entry.directory) {
      throw const ScoreReadException(ScoreReadError.wrongExtension);
    }
    if (entry.tooLarge) throw const ScoreReadException(ScoreReadError.tooLarge);
    try {
      final value = await channel.invokeMapMethod<Object?, Object?>('read', {
        'id': entry.id,
      });
      final name = value?['name'] as String?;
      final bytes = value?['bytes'] as Uint8List?;
      if (name == null || bytes == null) {
        throw const ScoreReadException(ScoreReadError.unreadable);
      }
      validateScoreName(name);
      validateScoreBytes(bytes);
      return PlatformFile(name: name, size: bytes.length, bytes: bytes);
    } on PlatformException catch (error) {
      switch (error.code) {
        case 'WRONG_EXTENSION':
          throw const ScoreReadException(ScoreReadError.wrongExtension);
        case 'SCORE_TOO_LARGE':
          throw const ScoreReadException(ScoreReadError.tooLarge);
        case 'INVALID_SCORE':
          throw const ScoreReadException(ScoreReadError.invalidFile);
        default:
          rethrow;
      }
    }
  }

  Future<void> cancel() async {
    try {
      await channel.invokeMethod<void>('cancel');
    } on PlatformException {
      /* Best-effort cancellation during route teardown. */
    } on MissingPluginException {
      /* No native folder bridge in desktop tests. */
    }
  }
}

Future<PlatformFile?> showScoreFolderPicker(BuildContext context) =>
    Navigator.of(context).push<PlatformFile>(
      MaterialPageRoute(builder: (_) => const ScoreFolderPage()),
    );

class ScoreFolderPage extends StatefulWidget {
  const ScoreFolderPage({
    super.key,
    this.service = const ScoreFolderService(),
    this.systemPicker = pickScoreFile,
  });
  final ScoreFolderService service;
  final Future<PlatformFile?> Function() systemPicker;

  @override
  State<ScoreFolderPage> createState() => _ScoreFolderPageState();
}

class _ScoreFolderPageState extends State<ScoreFolderPage> {
  List<ScoreFolderEntry> _path = [], _entries = [];
  bool _busy = true, _closed = false;
  Object? _error;
  int _request = 0;

  bool _current(int request) => mounted && !_closed && request == _request;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final request = ++_request;
    try {
      final root = await widget.service.root();
      if (!_current(request)) return;
      if (root != null) {
        await _load([root]);
        return;
      }
    } catch (error) {
      if (_current(request)) _error = error;
    }
    if (_current(request)) setState(() => _busy = false);
  }

  Future<void> _load(List<ScoreFolderEntry> path) async {
    final request = ++_request;
    setState(() {
      _path = path;
      _entries = [];
      _error = null;
      _busy = true;
    });
    try {
      await widget.service.cancel();
      if (!_current(request)) return;
      final entries = await widget.service.list(path.last.id);
      if (!_current(request)) return;
      // Defensive filtering also protects UI tests/custom service implementations.
      _entries =
          entries
              .where((e) => e.directory || isSupportedScoreName(e.name))
              .toList()
            ..sort(
              (a, b) =>
                  a.directory != b.directory
                      ? (a.directory ? -1 : 1)
                      : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
    } catch (error) {
      if (_current(request)) _error = error;
    } finally {
      if (_current(request)) setState(() => _busy = false);
    }
  }

  Future<void> _choose() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final root = await widget.service.chooseRoot();
      if (!_current(request)) return;
      if (root != null) await _load([root]);
    } catch (error) {
      if (_current(request)) _error = error;
    } finally {
      if (_current(request)) setState(() => _busy = false);
    }
  }

  Future<void> _open(ScoreFolderEntry? entry) async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file =
          entry == null
              ? await widget.systemPicker()
              : await widget.service.read(entry);
      if (!_current(request)) return;
      if (file != null && mounted) Navigator.of(context).pop(file);
    } catch (error) {
      if (_current(request)) _error = error;
    } finally {
      if (_current(request)) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_path.length > 1) {
      _load(_path.sublist(0, _path.length - 1));
    } else {
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    _closed = true;
    _request++;
    unawaited(widget.service.cancel());
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  String _errorText(NwcLocalizations s) {
    final error = _error;
    if (error is ScoreReadException) return error.localized(s);
    if (error is PlatformException && error.code == 'TIMEOUT') {
      return s.folderTimeout;
    }
    return s.folderAccessError;
  }

  @override
  Widget build(BuildContext context) {
    final s = playerStrings(context);
    return PopScope<PlatformFile>(
      canPop: _path.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _cancel();
        } else {
          _back();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const ValueKey('folder-back'),
            onPressed: _back,
            tooltip: s.folderBack,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(s.scoreFolder),
          actions: [
            IconButton(
              key: const ValueKey('folder-refresh'),
              tooltip: s.folderRefresh,
              onPressed:
                  _busy || _path.isEmpty ? null : () => _load([..._path]),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.folderHelp),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const ValueKey('choose-score-folder'),
                          onPressed: _busy ? null : _choose,
                          icon: const Icon(Icons.folder_open),
                          label: Text(
                            _path.isEmpty
                                ? s.chooseScoreFolder
                                : s.changeScoreFolder,
                          ),
                        ),
                        TextButton.icon(
                          key: const ValueKey('folder-system-picker'),
                          onPressed: _busy ? null : () => _open(null),
                          icon: const Icon(Icons.insert_drive_file_outlined),
                          label: Text(s.openFile),
                        ),
                      ],
                    ),
                    if (_path.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _path.map((e) => e.name).join(' / '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child:
                    _error != null
                        ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _errorText(s),
                            key: const ValueKey('folder-error'),
                          ),
                        )
                        : _path.isEmpty
                        ? SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Text(s.folderPermissionHelp),
                        )
                        : _entries.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _busy ? s.folderLoading : s.folderEmpty,
                            ),
                          ),
                        )
                        : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final entry = _entries[index];
                            return ListTile(
                              key: ValueKey('score-entry-${entry.id}'),
                              enabled: !_busy && !entry.tooLarge,
                              leading: Icon(
                                entry.directory
                                    ? Icons.folder_outlined
                                    : Icons.music_note,
                              ),
                              title: Text(
                                entry.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle:
                                  entry.tooLarge ? Text(s.scoreTooLarge) : null,
                              trailing:
                                  entry.directory
                                      ? const Icon(Icons.chevron_right)
                                      : null,
                              onTap:
                                  _busy || entry.tooLarge
                                      ? null
                                      : () =>
                                          entry.directory
                                              ? _load([..._path, entry])
                                              : _open(entry),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
