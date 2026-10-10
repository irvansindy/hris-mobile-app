import 'package:yaml/yaml.dart';

const _httpMethods = <String>{
  'get',
  'post',
  'put',
  'patch',
  'delete',
  'head',
  'options',
  'trace',
};

final class MobileOpenApiAudit {
  MobileOpenApiAudit._({
    required this.version,
    required this.operations,
    required this.serverUrls,
    required this.operationsWithoutResponses,
    required this.duplicateOperationIds,
    required this.unresolvedReferences,
    required this.issueIds,
  });

  factory MobileOpenApiAudit.fromYaml(String source) {
    final document = loadYaml(source);
    if (document is! Map) {
      throw const FormatException('OpenAPI root must be a map.');
    }

    final operations = <String>[];
    final operationsWithoutResponses = <String>[];
    final operationIds = <String>{};
    final duplicateOperationIds = <String>{};
    final paths = _map(document['paths']);

    for (final pathEntry in paths.entries) {
      final path = pathEntry.key.toString();
      final pathItem = _map(pathEntry.value);
      for (final operationEntry in pathItem.entries) {
        final method = operationEntry.key.toString().toLowerCase();
        if (!_httpMethods.contains(method)) continue;

        final operationKey = '${method.toUpperCase()} $path';
        operations.add(operationKey);
        final operation = _map(operationEntry.value);
        if (!_map(operation['responses']).isNotEmpty) {
          operationsWithoutResponses.add(operationKey);
        }

        final operationId = operation['operationId']?.toString();
        if (operationId != null && operationId.isNotEmpty) {
          if (!operationIds.add(operationId)) {
            duplicateOperationIds.add(operationId);
          }
        }
      }
    }

    final serverUrls = <String>[
      for (final server in _list(document['servers']))
        if (_map(server)['url'] case final Object url) url.toString(),
    ];
    final references = <String>{};
    _collectReferences(document, references);
    final unresolvedReferences =
        references
            .where((reference) => !_resolves(document, reference))
            .toList()
          ..sort();

    final issueIds = <String>[];
    final schemas = _map(_map(document['components'])['schemas']);
    final errorEnvelope = _map(schemas['ErrorEnvelope']);
    final required = _list(
      errorEnvelope['required'],
    ).map((value) => value.toString()).toSet();
    final description = (errorEnvelope['description']?.toString() ?? '')
        .replaceAll('*', '');
    final describesMissingCode =
        description.contains('tidak membawa') ||
        description.toLowerCase().contains('may be absent');
    if (required.contains('code') && describesMissingCode) {
      issueIds.add('error-envelope-code-required');
    }

    return MobileOpenApiAudit._(
      version: document['openapi']?.toString(),
      operations: List.unmodifiable(operations),
      serverUrls: List.unmodifiable(serverUrls),
      operationsWithoutResponses: List.unmodifiable(operationsWithoutResponses),
      duplicateOperationIds: List.unmodifiable(
        duplicateOperationIds.toList()..sort(),
      ),
      unresolvedReferences: List.unmodifiable(unresolvedReferences),
      issueIds: List.unmodifiable(issueIds),
    );
  }

  final String? version;
  final List<String> operations;
  final List<String> serverUrls;
  final List<String> operationsWithoutResponses;
  final List<String> duplicateOperationIds;
  final List<String> unresolvedReferences;
  final List<String> issueIds;
}

final class MarkdownOperationKeys {
  const MarkdownOperationKeys({required this.values, required this.duplicates});

  final Set<String> values;
  final Set<String> duplicates;
}

MarkdownOperationKeys extractOperationKeysFromMarkdown(String source) {
  final values = <String>{};
  final duplicates = <String>{};
  final pattern = RegExp(
    r'\|\s*`((?:GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE) /[^`]+)`\s*\|',
  );
  for (final match in pattern.allMatches(source)) {
    final operation = match.group(1)!;
    if (!values.add(operation)) duplicates.add(operation);
  }
  return MarkdownOperationKeys(
    values: Set.unmodifiable(values),
    duplicates: Set.unmodifiable(duplicates),
  );
}

Map<Object?, Object?> _map(Object? value) {
  return value is Map ? value : const <Object?, Object?>{};
}

List<Object?> _list(Object? value) {
  return value is List ? value : const <Object?>[];
}

void _collectReferences(Object? value, Set<String> references) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (entry.key == r'$ref' && entry.value is String) {
        references.add(entry.value as String);
      }
      _collectReferences(entry.value, references);
    }
    return;
  }
  if (value is List) {
    for (final item in value) {
      _collectReferences(item, references);
    }
  }
}

bool _resolves(Map<Object?, Object?> document, String reference) {
  if (!reference.startsWith('#/')) return true;

  Object? current = document;
  for (final encodedPart in reference.substring(2).split('/')) {
    final part = encodedPart.replaceAll('~1', '/').replaceAll('~0', '~');
    if (current is! Map || !current.containsKey(part)) return false;
    current = current[part];
  }
  return true;
}
