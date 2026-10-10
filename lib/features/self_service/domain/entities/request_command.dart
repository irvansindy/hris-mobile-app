import 'dart:typed_data';

import 'package:hrm_app/features/self_service/domain/entities/employee_request.dart';

class RequestAttachment {
  const RequestAttachment({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

class SubmitRequestCommand {
  const SubmitRequestCommand({
    required this.type,
    this.kind = RequestKind.leave,
    this.startDate,
    this.endDate,
    this.reason,
    this.attachment,
    this.idempotencyKey,
  });
  final String type;
  final RequestKind kind;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? reason;
  final RequestAttachment? attachment;
  final String? idempotencyKey;
}
