import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hrm_app/core/face_id/face_detection_screen.dart';
import 'package:hrm_app/core/face_id/face_template_store.dart';
import 'package:hrm_app/demo/demo_repositories.dart';
import 'package:hrm_app/demo/demo_store.dart';

abstract interface class DemoFaceStorage {
  Future<bool> hasLegacyPhoto();
  Future<void> delete();
}

class SecureDemoFaceStorage implements DemoFaceStorage {
  static const _key = 'hris.demo.face.v1';
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(storageNamespace: 'hris_demo'),
  );
  @override
  Future<bool> hasLegacyPhoto() async => await _storage.read(key: _key) != null;
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class DemoToolsScreen extends StatefulWidget {
  const DemoToolsScreen({
    super.key,
    required this.store,
    required this.faceStorage,
    required this.enrollmentStore,
    required this.onChanged,
  });
  final DemoStore store;
  final DemoFaceStorage faceStorage;
  final DemoFaceEnrollmentStore enrollmentStore;
  final VoidCallback onChanged;
  @override
  State<DemoToolsScreen> createState() => _DemoToolsScreenState();
}

class _DemoToolsScreenState extends State<DemoToolsScreen> {
  bool _hasLegacyPhoto = false;
  DemoFaceEnrollment? _enrollment;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _run(() async {
      _hasLegacyPhoto = await widget.faceStorage.hasLegacyPhoto();
      _enrollment = await widget.enrollmentStore.read(
        employeeId: DemoAuth.session.employeeId!,
        companyId: DemoAuth.session.companyId!,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (_) {
      if (mounted) setState(() => _error = 'Operasi demo gagal. Coba lagi.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: const Text('Hanya memengaruhi data demo di perangkat ini.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengujian demo lokal')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            leading: const Icon(Icons.face_outlined),
            title: Text(
              _enrollment == null
                  ? 'Setup Face ID demo'
                  : 'Setup Face ID demo tersimpan',
            ),
            subtitle: Text(
              _enrollment == null
                  ? 'Pindai tengah, kiri, dan kanan secara otomatis'
                  : '3 sudut tersimpan; belum dapat mencocokkan identitas',
            ),
            onTap: () async {
              final saved = await Navigator.of(context, rootNavigator: true)
                  .push<bool>(
                    MaterialPageRoute<bool>(
                      fullscreenDialog: true,
                      builder: (_) => FaceDetectionScreen(
                        enrollmentStore: widget.enrollmentStore,
                        employeeId: DemoAuth.session.employeeId!,
                        companyId: DemoAuth.session.companyId!,
                      ),
                    ),
                  );
              if (saved == true && mounted) {
                await _run(() async {
                  _enrollment = await widget.enrollmentStore.read(
                    employeeId: DemoAuth.session.employeeId!,
                    companyId: DemoAuth.session.companyId!,
                  );
                });
              }
            },
          ),
          if (_enrollment != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await _confirm('Hapus setup Face ID demo?')) {
                        await _run(() async {
                          await widget.enrollmentStore.delete(
                            employeeId: DemoAuth.session.employeeId!,
                            companyId: DemoAuth.session.companyId!,
                          );
                          _enrollment = null;
                        });
                      }
                    },
              child: const Text('Hapus setup Face ID demo'),
            ),
          const Divider(),
          const Text('Foto wajah demo lama', style: TextStyle(fontSize: 20)),
          const Text(
            'Foto lama bukan template Face ID. Penyimpanan foto mentah baru dihentikan; hapus foto lama bila tidak diperlukan.',
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (_hasLegacyPhoto)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (await _confirm('Hapus foto wajah?')) {
                        await _run(() async {
                          await widget.faceStorage.delete();
                          _hasLegacyPhoto = false;
                        });
                      }
                    },
              child: const Text('Hapus foto wajah'),
            ),
          const Divider(),
          Text(
            'Saldo: ${widget.store.balance} hari; menunggu: ${widget.store.reserved} hari',
          ),
          const Text(
            'Persetujuan simulasi untuk menguji saldo cuti; bukan approval HR.',
          ),
          for (final row in widget.store.requests.where(
            (r) => r['status'] == 'Menunggu',
          ))
            ListTile(
              title: Text('${row['kind']} · ${row['start']}'),
              subtitle: Text(row['reason'] as String),
              trailing: TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (await _confirm('Setujui pengajuan demo?')) {
                          await _run(
                            () => widget.store.decide(
                              row['id'] as String,
                              approve: true,
                            ),
                          );
                        }
                      },
                child: const Text('Setujui'),
              ),
            ),
          const Divider(),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    if (await _confirm('Reset transaksi dan foto demo?')) {
                      await _run(() async {
                        await widget.faceStorage.delete();
                        await widget.enrollmentStore.delete(
                          employeeId: DemoAuth.session.employeeId!,
                          companyId: DemoAuth.session.companyId!,
                        );
                        _hasLegacyPhoto = false;
                        _enrollment = null;
                        await widget.store.reset();
                      });
                    }
                  },
            child: const Text('Reset data demo'),
          ),
        ],
      ),
    ),
  );
}
