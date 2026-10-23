import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mobile_openapi_audit.dart';

void main() {
  group('MobileOpenApiAudit', () {
    test('extracts operations and detects the nullable-code contradiction', () {
      const source = '''
openapi: 3.1.0
servers:
  - url: "{baseUrl}/api/v1"
paths:
  /auth/login:
    post:
      operationId: login
      responses:
        "200": {description: OK}
components:
  schemas:
    ErrorEnvelope:
      type: object
      required: [success, code, message]
      description: code may be absent
      properties:
        success: {type: boolean}
        code: {type: string}
        message: {type: string}
''';

      final audit = MobileOpenApiAudit.fromYaml(source);

      expect(audit.operations, ['POST /auth/login']);
      expect(audit.serverUrls, ['{baseUrl}/api/v1']);
      expect(audit.issueIds, contains('error-envelope-code-required'));
      expect(audit.unresolvedReferences, isEmpty);
    });

    test('reports unresolved local references', () {
      const source = '''
openapi: 3.1.0
paths:
  /auth/me:
    get:
      responses:
        "200":
          description: OK
          content:
            application/json:
              schema: {\$ref: "#/components/schemas/Missing"}
components:
  schemas: {}
''';

      final audit = MobileOpenApiAudit.fromYaml(source);

      expect(audit.unresolvedReferences, ['#/components/schemas/Missing']);
    });
  });

  test('checked-in mobile OpenAPI is parseable and structurally complete', () {
    final source = File(
      'docs/api-for-mobile-apps/openapi.yaml',
    ).readAsStringSync();
    final audit = MobileOpenApiAudit.fromYaml(source);

    expect(audit.version, '3.1.0');
    expect(audit.operations, hasLength(108));
    expect(audit.operations, contains('POST /auth/login'));
    expect(audit.operations, contains('PATCH /attendance/me/check-out'));
    expect(audit.operations, contains('GET /meta/openapi.json'));
    expect(audit.operationsWithoutResponses, isEmpty);
    expect(audit.duplicateOperationIds, isEmpty);
    expect(audit.unresolvedReferences, isEmpty);

    // This preserves visibility of the backend-owned documentation defect
    // without making the client contract test permanently red.
    expect(audit.issueIds, contains('error-envelope-code-required'));
  });

  test('stage zero matrix covers every checked-in OpenAPI operation once', () {
    final openApi = File(
      'docs/api-for-mobile-apps/openapi.yaml',
    ).readAsStringSync();
    final matrix = File(
      'docs/Tahap 0 Baseline dan Matriks Kontrak API Mobile.md',
    ).readAsStringSync();

    final expected = MobileOpenApiAudit.fromYaml(openApi).operations.toSet();
    final actual = extractOperationKeysFromMarkdown(matrix);

    expect(actual.duplicates, isEmpty);
    expect(actual.values, hasLength(expected.length));
    expect(actual.values.difference(expected), isEmpty);
    expect(expected.difference(actual.values), isEmpty);
  });
}
