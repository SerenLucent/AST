import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const transitLiveUrl = 'https://serenlucent.github.io/TransitLive/';

/// Isolate the other Pages app from AST's same-origin login storage.
/// JSONP, fonts and images work without allow-same-origin or any AST bridge.
void configureTransitFrame(web.HTMLIFrameElement frame) {
  frame
    ..title = 'Transit Live'
    ..referrerPolicy = 'no-referrer'
    ..setAttribute(
      'sandbox',
      'allow-scripts allow-popups allow-popups-to-escape-sandbox',
    );
  frame.style
    ..border = '0'
    ..width = '100%'
    ..height = '100%';
  frame.src = transitLiveUrl;
}

class TransitLiveScreen extends StatefulWidget {
  const TransitLiveScreen({super.key});

  @override
  State<TransitLiveScreen> createState() => _TransitLiveScreenState();
}

class _TransitLiveScreenState extends State<TransitLiveScreen> {
  web.HTMLIFrameElement? _frame;
  JSFunction? _onLoad;
  Timer? _timer;
  bool _loading = true;
  bool _slow = false;
  int _revision = 0;

  void _created(Object element) {
    if (!mounted) return;
    final frame = element as web.HTMLIFrameElement;
    _frame = frame;
    _onLoad =
        ((web.Event event) {
          if (!mounted || _frame != frame) return;
          _timer?.cancel();
          setState(() {
            _loading = false;
            _slow = false;
          });
        }).toJS;
    frame.addEventListener('load', _onLoad);
    configureTransitFrame(frame);
    _timer = Timer(const Duration(seconds: 25), () {
      if (mounted && _loading) setState(() => _slow = true);
    });
  }

  void _clear() {
    _timer?.cancel();
    final frame = _frame;
    if (frame != null) {
      frame.removeEventListener('load', _onLoad);
      // Stop the child app's polling immediately when leaving or reloading.
      frame.src = 'about:blank';
      frame.remove();
    }
    _frame = null;
    _onLoad = null;
  }

  void _reload() {
    _clear();
    setState(() {
      _revision++;
      _loading = true;
      _slow = false;
    });
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Transit Live'),
      actions: [
        IconButton(
          tooltip: '새로고침',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_slow)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('연결이 지연되고 있어요. 인터넷 연결을 확인해 주세요.'),
                  TextButton(onPressed: _reload, child: const Text('다시 시도')),
                ],
              ),
            ),
          Expanded(
            child: HtmlElementView.fromTagName(
              key: ValueKey(_revision),
              tagName: 'iframe',
              onElementCreated: _created,
            ),
          ),
        ],
      ),
    ),
  );
}
