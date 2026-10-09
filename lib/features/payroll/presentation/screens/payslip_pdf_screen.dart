import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hrm_app/core/security/sensitive_screen.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/core/widgets/app_state_view.dart';
import 'package:pdfrx/pdfrx.dart';

class PayslipPdfScreen extends StatefulWidget {
  PayslipPdfScreen({
    super.key,
    required Uint8List bytes,
    required this.sourceName,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String sourceName;

  @override
  State<PayslipPdfScreen> createState() => _PayslipPdfScreenState();
}

class _PayslipPdfScreenState extends State<PayslipPdfScreen>
    with WidgetsBindingObserver {
  final _protection = const SensitiveScreenController();
  bool _covered = false;

  bool get _valid =>
      widget.bytes.length >= 5 &&
      widget.bytes[0] == 0x25 &&
      widget.bytes[1] == 0x50 &&
      widget.bytes[2] == 0x44 &&
      widget.bytes[3] == 0x46 &&
      widget.bytes[4] == 0x2D;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_protection.enable());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      widget.bytes.fillRange(0, widget.bytes.length, 0);
      setState(() => _covered = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.bytes.fillRange(0, widget.bytes.length, 0);
    unawaited(_protection.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PDF slip gaji'),
      leading: IconButton(
        tooltip: 'Kembali',
        onPressed: Navigator.of(context).pop,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
    ),
    body: SafeArea(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_covered)
            ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Konten slip gaji disembunyikan',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Kembali ke daftar dan masukkan PIN lagi.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_valid)
            PdfViewer.data(
              widget.bytes,
              sourceName: widget.sourceName,
              maxSizeToCacheOnMemory: 5 * 1024 * 1024,
              params: PdfViewerParams(
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Center(
                child: AppStateView(
                  kind: AppViewStateKind.error,
                  title: 'PDF slip gaji tidak valid',
                  message: 'Dokumen ditolak sebelum ditampilkan.',
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
