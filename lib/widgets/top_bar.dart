import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onReload;
  final VoidCallback? onSettings;
  final bool showButtons;

  const TopBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.onReload,
    this.onSettings,
    this.showButtons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF40C8FB).withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SvgPicture.asset('assets/logo1.svg', width: 42, height: 42),
            ),
          ),
          const SizedBox(width: 14),
          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8888AA),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Action Buttons
          if (showButtons) ...[
            if (onReload != null)
              _topButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Reload',
                onTap: onReload,
              ),
            if (onSettings != null) ...[
              if (onReload != null) const SizedBox(width: 10),
              _topButton(
                icon: Icons.settings_rounded,
                tooltip: 'Settings',
                onTap: onSettings,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF40C8FB).withValues(alpha: 0.25),
              ),
            ),
            child: Icon(icon, color: const Color(0xFF80DCFF), size: 20),
          ),
        ),
      ),
    );
  }
}
