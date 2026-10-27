import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../map/presentation/controllers/map_screen_controller.dart';

/// Modal dialog allowing the user to download a 10×10 km forest square
/// for 100% hermetic offline foraging in cellular dead zones.
class DownloadAreaDialog extends ConsumerStatefulWidget {
  final LatLng center;
  final String suggestedName;

  const DownloadAreaDialog({
    super.key,
    required this.center,
    this.suggestedName = '',
  });

  static Future<void> show({
    required BuildContext context,
    required LatLng center,
    String suggestedName = '',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DownloadAreaDialog(
        center: center,
        suggestedName: suggestedName,
      ),
    );
  }

  @override
  ConsumerState<DownloadAreaDialog> createState() => _DownloadAreaDialogState();
}

class _DownloadAreaDialogState extends ConsumerState<DownloadAreaDialog> {
  late final TextEditingController _nameController;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusText = 'Gotowy do pobrania';
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    final defaultName = widget.suggestedName.isNotEmpty
        ? widget.suggestedName
        : 'Las wokół (${widget.center.latitude.toStringAsFixed(2)}, ${widget.center.longitude.toStringAsFixed(2)})';
    _nameController = TextEditingController(text: defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.05;
      _statusText = 'Inicjalizacja...';
    });

    final notifier = ref.read(mapScreenProvider.notifier);
    await notifier.downloadOfflineArea(
      name: _nameController.text.trim(),
      center: widget.center,
      radiusKm: 5.0, // 5 km radius = 10×10 km square
    );

    if (!mounted) return;
    final mapState = ref.read(mapScreenProvider);

    setState(() {
      _isDownloading = false;
      _progress = 1.0;
      _statusText = mapState.offlineDownloadStatus.isNotEmpty
          ? mapState.offlineDownloadStatus
          : 'Pobieranie zakończone sukcesem!';
      _isFinished = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldDeep.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emeraldLight.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Text('💾', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pobierz rejon offline',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kwadrat 10 × 10 km wokół wybranej pozycji',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isDownloading)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textDim, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Content
            if (!_isDownloading && !_isFinished) ...[
              const Text(
                'Nazwa pakietu leśnego:',
                style: TextStyle(
                  color: AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.card,
                  hintText: 'np. Bory Tucholskie 10×10 km',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                  prefixIcon: const Icon(Icons.forest_rounded, color: AppColors.emeraldLight, size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.emeraldLight),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Feature details container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      icon: '🌲',
                      title: 'BDL Taksonomia',
                      subtitle: 'Gatunki drzew, wiek, typ siedliskowy i wilgotność',
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _buildFeatureRow(
                      icon: '💧',
                      title: 'Opady i gleba (14 dni)',
                      subtitle: 'Suma deszczu i wilgotność podłoża dla wyliczania grzybów',
                    ),
                    const Divider(color: AppColors.border, height: 16),
                    _buildFeatureRow(
                      icon: '🎯',
                      title: 'MatchEngine offline',
                      subtitle: '100% lokalny algorytm szans — 0 kB transferu w lesie',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action button
              FilledButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Pobierz pakiet (ok. 80-120 KB)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emeraldDeep,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ] else ...[
              // Progress or Completed state
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isFinished
                        ? AppColors.emeraldLight.withValues(alpha: 0.5)
                        : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    if (_isDownloading) ...[
                      const SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.emeraldLight,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: _progress > 0 ? _progress : null,
                          backgroundColor: AppColors.card,
                          color: AppColors.emeraldLight,
                          minHeight: 6,
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.emeraldDeep.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.emeraldLight,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Pakiet zapisany pomyślnie!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _statusText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textDim,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.emeraldDeep,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Zamknij i używaj offline'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow({
    required String icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
