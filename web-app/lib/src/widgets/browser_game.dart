import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class BrowserGame extends StatefulWidget {
  const BrowserGame({super.key, required this.kind, required this.title, required this.onRequest});
  final String kind, title;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) onRequest;
  @override State<BrowserGame> createState() => _BrowserGameState();
}
class _BrowserGameState extends State<BrowserGame> {
  static int serial = 0;
  late final String viewType;
  late final html.IFrameElement frame;
  StreamSubscription<html.MessageEvent>? subscription;
  bool loaded = false;
  @override void initState() {
    super.initState();
    viewType = 'ast-web-game-${serial++}';
    frame = html.IFrameElement()
      ..src = Uri.base.resolve('games/${widget.kind}/index.html?mode=shared').toString()
      ..style.border = '0'..style.width = '100%'..style.height = '100%'
      ..setAttribute('title', widget.title)
      ..setAttribute('allow', 'autoplay; fullscreen');
    frame.onLoad.listen((_) { if (mounted) setState(() => loaded = true); });
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => frame);
    subscription = html.window.onMessage.listen(_receive);
  }
  Future<void> _receive(html.MessageEvent event) async {
    if (event.origin != html.window.location.origin || event.source != frame.contentWindow || event.data is! String) return;
    Map<String, dynamic> message;
    try { message = jsonDecode(event.data as String) as Map<String, dynamic>; } catch (_) { return; }
    if (message['channel'] != 'ast-web-${widget.kind}') return;
    if (message['exit'] == true) { if (mounted) Navigator.of(context).pop(); return; }
    final id = message['id'];
    if (id is! String || id.length > 100 || message['payload'] is! Map) return;
    try {
      final result = await widget.onRequest(Map<String, dynamic>.from(message['payload'] as Map));
      if (mounted) frame.contentWindow?.postMessage(jsonEncode({'channel':message['channel'],'id':id,'result':result}), html.window.location.origin);
    } catch (e) {
      if (mounted) frame.contentWindow?.postMessage(jsonEncode({'channel':message['channel'],'id':id,'error':e.toString()}), html.window.location.origin);
    }
  }
  @override void dispose() { subscription?.cancel(); frame.src = 'about:blank'; frame.remove(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(child: Stack(children: [
      Positioned.fill(child: HtmlElementView(viewType: viewType)),
      if (!loaded) const LinearProgressIndicator(),
    ])),
  );
}
