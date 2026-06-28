import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/top_bar.dart';
import 'setup_screen.dart';

class RemoteScreen extends StatefulWidget {
  final String serverUrl;
  final String? authToken;

  const RemoteScreen({
    super.key,
    required this.serverUrl,
    this.authToken,
  });

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  int _loadingProgress = 0;

  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    _loadDeviceId().then((_) {
      _initWebView();
    });
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var devId = prefs.getString('device_id');
    if (devId == null || devId.isEmpty) {
      devId = 'remote_${DateTime.now().millisecondsSinceEpoch}_${(100 + DateTime.now().microsecond % 900)}';
      await prefs.setString('device_id', devId);
    }
    if (mounted) {
      setState(() {
        _deviceId = devId!;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _remoteUrl {
    final base = widget.serverUrl;
    final token = widget.authToken;
    final List<String> params = [];
    if (token != null && token.isNotEmpty) {
      params.add('token=$token');
    }
    if (_deviceId.isNotEmpty) {
      params.add('deviceId=$_deviceId');
    }
    if (params.isNotEmpty) {
      return '$base/remote/?${params.join('&')}';
    }
    return '$base/remote/';
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0D0D14))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _loadingProgress = 0;
            });
          },
          onProgress: (p) => setState(() => _loadingProgress = p),
          onPageFinished: (_) {
            setState(() => _isLoading = false);
            _injectVibration();
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame ?? false) {
              _goToSettings();
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterVibrate',
        onMessageReceived: (_) => _vibrate(),
      )
      ..loadRequest(Uri.parse(_remoteUrl));
  }

  Future<void> _vibrate() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator) Vibration.vibrate(duration: 30);
  }

  /// Injects a small bridge so the web UI can call window.FlutterVibrate.postMessage('')
  void _injectVibration() {
    _webViewController.runJavaScript('''
      (function() {
        window.kVibrate = function() {
          try { FlutterVibrate.postMessage(''); } catch(e) {}
        };
        // Patch every button to vibrate on tap
        document.addEventListener('click', function(e) {
          var t = e.target;
          if (t && (t.tagName === 'BUTTON' || t.closest('button') || t.closest('[role="button"]'))) {
            window.kVibrate();
          }
        }, true);
      })();
    ''');
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _webViewController.reload();
  }

  void _goToSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_url');
    await prefs.remove('auth_token');
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SetupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Kalyx Remote',
              subtitle: 'Player Remote',
              onReload: _reload,
            ),
            Expanded(
              child: Stack(
                children: [
                  // WebView
                  WebViewWidget(controller: _webViewController),

                  // Top loading bar
                  if (_isLoading && _loadingProgress < 100)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _loadingProgress / 100,
                        backgroundColor: Colors.transparent,
                        color: const Color(0xFF40C8FB),
                        minHeight: 3,
                      ),
                    ),

                  // Error / offline banner
                  if (_hasError) _buildOfflineBanner(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xDD0D0D14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                color: Color(0xFF40C8FB), size: 64),
            const SizedBox(height: 20),
            const Text('Cannot reach AIVue',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              widget.serverUrl,
              style: const TextStyle(color: Color(0xFF8888AA), fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text('Make sure AIVue is running and on the same Wi-Fi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF80DCFF),
                    side: const BorderSide(color: Color(0xFF40C8FB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _goToSettings,
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Change Server'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF80DCFF),
                    side: const BorderSide(color: Color(0xFF40C8FB)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
