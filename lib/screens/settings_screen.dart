import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a1a2e),
              Color(0xFF16213e),
              Color(0xFF0f3460),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        _buildSectionTitle('Audio'),
                        _buildToggleTile(
                          'Sound Effects',
                          Icons.volume_up,
                          settings.soundEnabled,
                          settings.toggleSound,
                        ),
                        _buildToggleTile(
                          'Music',
                          Icons.music_note,
                          settings.musicEnabled,
                          () async {
                            await settings.toggleMusic();
                            if (settings.musicEnabled) {
                              AudioService().playBGM();
                            } else {
                              AudioService().stopBGM();
                            }
                          },
                        ),
                        _buildToggleTile(
                          'Vibration',
                          Icons.vibration,
                          settings.vibrationEnabled,
                          settings.toggleVibration,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('Account'),
                        _buildActionTile(
                          'Restore Purchases',
                          Icons.restore,
                          () {
                            _showRestoreDialog(context);
                          },
                        ),
                        _buildActionTile(
                          'Reset Progress',
                          Icons.delete_forever,
                          () {
                            _showResetDialog(context);
                          },
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 20),
                        _buildSectionTitle('About'),
                        _buildInfoTile('Version', '1.0.0'),
                        _buildInfoTile('Developer', 'chAs'),
                        _buildInfoTile('Package', 'com.chastechgroup.crystalcascade'),
                      ],
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.purpleAccent.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    IconData icon,
    bool value,
    VoidCallback onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white70),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
        trailing: Switch(
          value: value,
          onChanged: (_) => onChanged(),
          activeColor: Colors.purpleAccent,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.white70,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(color: color, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white30),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Restore Purchases',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Your purchases have been restored.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        title: const Text(
          'Reset All Progress?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'This will erase all your progress, coins, and unlocked levels. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await StorageService().resetAll();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
