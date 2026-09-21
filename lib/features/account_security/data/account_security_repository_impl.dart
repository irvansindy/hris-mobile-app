import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:hrm_app/core/network/api_envelope.dart';
import 'package:hrm_app/core/network/api_error_mapper.dart';
import 'package:hrm_app/core/network/api_exception.dart';
import 'package:hrm_app/core/network/request_context.dart';
import 'package:hrm_app/features/account_security/domain/entities/account_security.dart';
import 'package:hrm_app/features/account_security/domain/repositories/account_security_repository.dart';

class DioAccountSecurityRepository implements AccountSecurityRepository {
  const DioAccountSecurityRepository(this._dio, this.context);

  final Dio _dio;
  final RequestContext context;

  @override
  Future<MfaSetup> setupMfa() async {
    final data = (await _request(
      'POST',
      '/auth/mfa/setup',
    )).requireObjectData();
    final secret = _requiredText(data['secret'], 'Secret MFA tidak valid.');
    final qrDataUrl = _requiredText(
      data['qrDataUrl'],
      'Kode QR MFA tidak valid.',
    );
    _validateQrDataUrl(qrDataUrl);
    return MfaSetup(secret: secret, qrDataUrl: qrDataUrl);
  }

  @override
  Future<MfaEnableResult> enableMfa(String code) async {
    final normalized = _validateCode(code);
    final data = (await _request(
      'POST',
      '/auth/mfa/enable',
      data: {'code': normalized},
    )).requireObjectData();
    final rawCodes = data['recoveryCodes'];
    if (rawCodes is! List || rawCodes.isEmpty) {
      throw const FormatException('Kode pemulihan MFA tidak tersedia.');
    }
    final unique = <String>{};
    for (final value in rawCodes) {
      if (value is! String ||
          value.trim().isEmpty ||
          !unique.add(value.trim())) {
        throw const FormatException('Kode pemulihan MFA tidak valid.');
      }
    }
    return MfaEnableResult(recoveryCodes: List.unmodifiable(unique));
  }

  @override
  Future<void> disableMfa(String code) async {
    final normalized = _validateCode(code);
    await _requireSuccess(
      'POST',
      '/auth/mfa/disable',
      data: {'code': normalized},
    );
  }

  @override
  Future<List<AccountSession>> loadSessions() async {
    final raw = (await _request('GET', '/auth/sessions')).requireListData();
    final ids = <String>{};
    return List.unmodifiable(
      raw.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Data sesi aktif tidak valid.');
        }
        final id = _requiredText(value['id'], 'ID sesi tidak valid.');
        final createdAt = _requiredDate(value['createdAt']);
        final expiresAt = _requiredDate(value['expiresAt']);
        final current = value['current'] ?? value['isCurrent'];
        if (!ids.add(id) ||
            !expiresAt.isAfter(createdAt) ||
            (current != null && current is! bool)) {
          throw const FormatException('Data sesi aktif tidak valid.');
        }
        return AccountSession(
          id: id,
          userAgent: _optionalText(value['userAgent']),
          ipAddress: _optionalText(value['ipAddress']),
          createdAt: createdAt.toLocal(),
          expiresAt: expiresAt.toLocal(),
          isCurrent: current as bool?,
        );
      }),
    );
  }

  @override
  Future<void> revokeSession(String id) async {
    final normalized = id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(normalized)) {
      throw ArgumentError('ID sesi tidak valid.');
    }
    await _requireSuccess(
      'DELETE',
      '/auth/sessions/${Uri.encodeComponent(normalized)}',
    );
  }

  Future<void> _requireSuccess(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    await _request(method, path, data: data);
  }

  Future<ApiEnvelope> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (context.userId == null) {
      throw const ApiException('Sesi akun belum tersedia.');
    }
    try {
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(method: method),
      );
      final envelope = ApiEnvelope.fromJson(response.data ?? const {});
      if (!envelope.success) {
        throw FormatException(
          envelope.message.isEmpty
              ? 'Respons server tidak valid.'
              : envelope.message,
        );
      }
      return envelope;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}

String _validateCode(String value) {
  final code = value.trim();
  if (code.length < 6 || code.length > 20) {
    throw ArgumentError('Kode autentikator harus 6 sampai 20 karakter.');
  }
  return code;
}

String _requiredText(Object? value, String message) {
  final text = _optionalText(value);
  if (text == null) throw FormatException(message);
  return text;
}

String? _optionalText(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

DateTime _requiredDate(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw const FormatException('Waktu sesi aktif tidak valid.');
  }
  return parsed;
}

void _validateQrDataUrl(String value) {
  const prefix = 'data:image/png;base64,';
  if (!value.startsWith(prefix)) {
    throw const FormatException('Format kode QR MFA tidak didukung.');
  }
  try {
    final bytes = base64Decode(value.substring(prefix.length));
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    final validSignature =
        bytes.length >= pngSignature.length &&
        Iterable<int>.generate(
          pngSignature.length,
        ).every((index) => bytes[index] == pngSignature[index]);
    if (!validSignature || bytes.length > 2 * 1024 * 1024) {
      throw const FormatException('Kode QR MFA tidak valid.');
    }
  } on FormatException {
    throw const FormatException('Kode QR MFA tidak valid.');
  }
}
