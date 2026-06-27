import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'remote_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _urlController = TextEditingController(text: 'http://');
  final _tokenController = TextEditingController();
  bool _showToken = false;
  bool _isConnecting = false;
  String? _errorMessage;
  bool _scannerActive = false;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1) _requestCameraPermission();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) {
      setState(() => _scannerActive = status.isGranted);
    }
  }

  /// Validates and normalises the raw URL (strips trailing slash, ensures scheme).
  String _normalise(String raw) {
    raw = raw.trim();
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    return raw.replaceAll(RegExp(r'/+$'), ''); // strip trailing slashes
  }

  Future<void> _connect(String rawUrl) async {
    final url = _normalise(rawUrl);
    final token = _tokenController.text.trim();

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      // Try to reach the server's status endpoint
      final headers = <String, String>{};
      if (token.isNotEmpty) headers['X-Auth-Token'] = token;

      final response = await http
          .get(Uri.parse('$url/api/status'), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 401) {
        // 200 = open, 401 = server reachable but auth needed
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_url', url);
        if (token.isNotEmpty) await prefs.setString('auth_token', token);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RemoteScreen(serverUrl: url, authToken: token.isEmpty ? null : token),
          ),
        );
      } else {
        setState(() => _errorMessage = 'Server responded with ${response.statusCode}. Check the address.');
      }
    } on TimeoutException {
      setState(() => _errorMessage = 'Connection timed out. Is the PC on the same Wi-Fi?');
    } catch (e) {
      setState(() => _errorMessage = 'Could not reach server. Check the IP and port.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final value = barcode.rawValue ?? '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      _scanned = true;
      HapticFeedback.mediumImpact();
      _connect(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.6),
            radius: 1.2,
            colors: [Color(0xFF1A1030), Color(0xFF0D0D14)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 32),
              // Header
              const Icon(Icons.cast_connected_rounded,
                  color: Color(0xFF7C3AED), size: 44),
              const SizedBox(height: 14),
              const Text('Connect to AIVue',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              const Text('Enter your PC\'s address or scan the QR code',
                  style: TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
              const SizedBox(height: 28),

              // Tab bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF8888AA),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: const [
                    Tab(text: 'Manual'),
                    Tab(text: 'Scan QR'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildManualTab(),
                    _buildQrTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Server address field
          _label('Server Address'),
          const SizedBox(height: 8),
          _inputField(
            controller: _urlController,
            hint: 'http://192.168.1.x:8088',
            keyboardType: TextInputType.url,
            prefix: const Icon(Icons.computer_rounded,
                color: Color(0xFF7C3AED), size: 20),
          ),
          const SizedBox(height: 6),
          const Text(
            'Find the address in AIVue → Settings → Remote Control',
            style: TextStyle(color: Color(0xFF666680), fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Optional auth token
          GestureDetector(
            onTap: () => setState(() => _showToken = !_showToken),
            child: Row(
              children: [
                Icon(
                  _showToken ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF7C3AED), size: 20,
                ),
                const SizedBox(width: 6),
                const Text('Auth Token (optional)',
                    style: TextStyle(
                        color: Color(0xFF9D77F5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (_showToken) ...[
            const SizedBox(height: 10),
            _inputField(
              controller: _tokenController,
              hint: 'Leave blank if no token is set',
              prefix: const Icon(Icons.key_rounded,
                  color: Color(0xFF7C3AED), size: 20),
              obscure: true,
            ),
          ],
          const SizedBox(height: 28),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Connect button
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isConnecting
                  ? null
                  : () => _connect(_urlController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF3A2070),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isConnecting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_tethering_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('Connect',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    if (!_scannerActive) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF7C3AED), size: 56),
              const SizedBox(height: 16),
              const Text('Camera Permission Required',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text('Grant camera access to scan the QR code shown in AIVue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF8888AA), fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _requestCameraPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: MobileScanner(
            onDetect: _onQrDetected,
          ),
        ),
        // Scanning overlay
        Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF7C3AED), width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Point camera at the QR code in AIVue → Settings → Remote',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
        if (_isConnecting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF7C3AED)),
                  SizedBox(height: 16),
                  Text('Connecting…',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            color: Color(0xFFCCCCDD),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    Widget? prefix,
    TextInputType? keyboardType,
    bool obscure = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF555570), fontSize: 14),
          prefixIcon: prefix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onSubmitted: (_) => _connect(controller.text),
      ),
    );
  }
}
