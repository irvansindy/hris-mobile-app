import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_app/demo/demo_design_repositories.dart';
import 'package:hrm_app/features/profile/domain/entities/employee.dart';
import 'package:hrm_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:hrm_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:hrm_app/features/profile/profile_dependencies.dart';
import 'package:hrm_app/features/profile/profile_providers.dart';

void main() {
  const sectionKeys = [
    'profile-identity',
    'profile-contact',
    'profile-employment',
    'profile-documents',
    'profile-settings',
    'profile-preferences',
    'profile-face-id',
    'profile-sign-out',
  ];

  testWidgets('demo and production keep the same Profile composition', (
    tester,
  ) async {
    final demoOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: DemoDesignProfile(),
      faceIdBuilder: (_) => const Scaffold(body: Text('Face ID demo')),
      sectionKeys: sectionKeys,
    );
    expect(find.text('Kelola Face ID'), findsOneWidget);
    expect(find.text('Siap digunakan di perangkat ini'), findsOneWidget);
    await tester.ensureVisible(find.text('Kelola Face ID'));
    await tester.tap(find.text('Kelola Face ID'));
    await tester.pumpAndSettle();
    expect(find.text('Face ID demo'), findsOneWidget);

    final productionOrder = await _pumpAndReadSectionOrder(
      tester,
      repository: const _ProductionProfileRepository(),
      sectionKeys: sectionKeys,
    );

    expect(demoOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(sectionKeys));
    expect(productionOrder, orderedEquals(demoOrder));
    expect(find.text('Kelola Face ID'), findsOneWidget);
    expect(find.text('Belum tersedia pada konfigurasi ini'), findsOneWidget);
    await tester.ensureVisible(find.text('Kelola Face ID'));
    await tester.tap(find.text('Kelola Face ID'));
    await tester.pumpAndSettle();
    expect(find.text('Face ID demo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<List<String>> _pumpAndReadSectionOrder(
  WidgetTester tester, {
  required ProfileRepository repository,
  required List<String> sectionKeys,
  WidgetBuilder? faceIdBuilder,
}) async {
  tester.view.physicalSize = const Size(400, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        profileRepositoryProvider.overrideWithValue(repository),
        profileFaceIdBuilderProvider.overrideWithValue(faceIdBuilder),
      ],
      child: MaterialApp(
        home: ProfileScreen(
          isDarkMode: false,
          onThemeToggle: () {},
          onSignOut: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final positions = {
    for (final key in sectionKeys)
      key: tester.getTopLeft(find.byKey(ValueKey(key))).dy,
  };
  final ordered = positions.entries.toList()
    ..sort((left, right) => left.value.compareTo(right.value));
  return ordered.map((entry) => entry.key).toList(growable: false);
}

class _ProductionProfileRepository implements ProfileRepository {
  const _ProductionProfileRepository();

  static const employee = Employee(
    id: 'EMP001',
    name: 'Karyawan Produksi',
    role: 'Marketing Staff',
    department: 'Marketing',
    email: 'employee@example.test',
    phone: '08123456789',
    location: 'Head Office Jakarta',
    joinDate: '15 Jan 2024',
    salary: 0,
    initials: 'KP',
    avatarColorIndex: 0,
  );

  @override
  Employee get currentEmployee => employee;

  @override
  Future<Employee> refresh() async => employee;
}
