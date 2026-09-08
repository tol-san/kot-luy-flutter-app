import 'package:flutter/material.dart';

import 'package:kot_luy/theme.dart';

/// Card providing toggle switches for automatic silent backup and SIM/Wi-Fi selection.
class DriveSettingsCard extends StatelessWidget {
  const DriveSettingsCard({
    super.key,
    required this.automatic,
    required this.allowSim,
    required this.actionInProgress,
    required this.onToggleAutomatic,
    required this.onToggleSimData,
  });

  final bool automatic;
  final bool allowSim;
  final bool actionInProgress;
  final ValueChanged<bool> onToggleAutomatic;
  final ValueChanged<bool> onToggleSimData;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: const Text(
              'បម្រុងទុកស្វ័យប្រវត្តិ (Silent)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            subtitle: const Text(
              'បម្រុងទុកដោយស្ងាត់ៗពេលទិន្នន័យប្រែប្រួល និងរៀងរាល់ 6 ម៉ោង',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            value: automatic,
            activeThumbColor: green,
            thumbColor: _lockedSwitchThumb,
            trackColor: _lockedSwitchTrack,
            onChanged: actionInProgress ? null : onToggleAutomatic,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: const Text(
              'ប្រើ Wi-Fi ឬទិន្នន័យចល័ត (SIM)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
            subtitle: Text(
              allowSim
                  ? 'អនុញ្ញាតឱ្យបម្រុងទុកទាំងតាម SIM ទូរសព្ទ និង Wi-Fi'
                  : 'បម្រុងទុកតែតាមប្រព័ន្ធ Wi-Fi ប៉ុណ្ណោះ',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
            value: allowSim,
            activeThumbColor: green,
            thumbColor: _lockedSwitchThumb,
            trackColor: _lockedSwitchTrack,
            onChanged: actionInProgress ? null : onToggleSimData,
          ),
        ],
      ),
    );
  }

  // Disabled is an interaction state, not a change to the saved ON/OFF value.
  WidgetStateProperty<Color?> get _lockedSwitchThumb =>
      WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? const Color(0xFF52735F)
            : const Color(0xFF737873);
      });

  WidgetStateProperty<Color?> get _lockedSwitchTrack =>
      WidgetStateProperty.resolveWith((states) {
        if (!states.contains(WidgetState.disabled)) return null;
        return states.contains(WidgetState.selected)
            ? const Color(0xFFB8CDBF)
            : const Color(0xFFE0E3DE);
      });
}
