import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrm_app/core/services/location_gateway.dart';

final class GeolocatorLocationService implements LocationGateway {
  const GeolocatorLocationService();

  @override
  Future<GeoCoordinate> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(
        LocationIssueKind.serviceDisabled,
        'Layanan lokasi tidak aktif. Aktifkan lokasi perangkat lalu coba lagi.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(
          LocationIssueKind.permissionDenied,
          'Izin lokasi ditolak. Izin diperlukan untuk memeriksa lokasi absensi.',
        );
      case LocationPermission.deniedForever:
        throw const LocationException(
          LocationIssueKind.permissionDeniedForever,
          'Izin lokasi diblokir. Buka pengaturan aplikasi untuk mengaktifkannya.',
        );
      case LocationPermission.unableToDetermine:
        throw const LocationException(
          LocationIssueKind.restricted,
          'Izin lokasi dibatasi oleh perangkat atau kebijakan organisasi.',
        );
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        break;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return GeoCoordinate(
        position.latitude,
        position.longitude,
        accuracyMeters: position.accuracy,
        capturedAt: position.timestamp,
        isMocked: position.isMocked,
        altitudeMeters: position.altitude,
        headingDegrees: position.heading,
      );
    } on TimeoutException {
      throw const LocationException(
        LocationIssueKind.timeout,
        'Lokasi belum diperoleh dalam 20 detik. Pindah ke area terbuka lalu coba lagi.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        LocationIssueKind.serviceDisabled,
        'Layanan lokasi tidak aktif. Aktifkan lokasi perangkat lalu coba lagi.',
      );
    } catch (_) {
      throw const LocationException(
        LocationIssueKind.unavailable,
        'Lokasi perangkat tidak dapat dibaca. Periksa GPS lalu coba lagi.',
      );
    }
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

final locationServiceProvider = Provider<LocationGateway>(
  (ref) => const GeolocatorLocationService(),
);
