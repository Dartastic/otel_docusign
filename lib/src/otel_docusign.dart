// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_docusign_suppression.dart';

const _tracerName = 'dartastic_otel_libs_docusign';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class DocusignResult {
  /// Creates a result.
  const DocusignResult({
    this.itemCount,
    this.totalSetSize,
    this.envelopeId,
    this.envelopeStatus,
    this.recipientCount,
    this.templateUsed,
    this.bulkSendBatchId,
    this.consumesSeat,
    this.region,
    this.requestId,
    this.statusCode,
  });

  /// `envelopes.length` for list endpoints.
  final int? itemCount;

  /// `totalSetSize`.
  final int? totalSetSize;

  /// `envelopeId` returned by creates.
  final String? envelopeId;

  /// `created` / `sent` / `delivered` / `completed` / `declined` /
  /// `voided` / `signed` / `correct`.
  final String? envelopeStatus;

  /// Recipients on the envelope — drives DocuSign's per-envelope cost
  /// (each routing order adds latency too).
  final int? recipientCount;

  /// Whether a `templateId` was used. DocuSign caches template
  /// rendering, so this is a perf dim.
  final bool? templateUsed;

  /// `batchId` for bulk send operations.
  final String? bulkSendBatchId;

  /// Whether this envelope counts against the seat-based envelope
  /// allowance (some flows are free, e.g. embedded signing).
  final bool? consumesSeat;

  /// `na1` / `na2` / `eu1` / `au1` — DocuSign account region. Affects
  /// latency + data residency routing.
  final String? region;

  /// `X-DocuSign-TraceToken`.
  final String? requestId;

  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class DocusignCallResult<T> {
  /// Creates a call result.
  const DocusignCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final DocusignResult? result;
}

/// Wraps a DocuSign eSignature REST v2.1 call in a CLIENT span.
/// [operation] is one of `envelopes.list`, `envelopes.get`,
/// `envelopes.create`, `envelopes.update`, `envelopes.send`,
/// `envelopes.void`, `envelopes.recipients.list`,
/// `envelopes.recipients.create`, `envelopes.recipients.update`,
/// `envelopes.recipients.tabs.list`, `envelopes.documents.list`,
/// `envelopes.documents.get`, `templates.list`, `templates.get`,
/// `bulk_send_lists.create`, `bulk_send_lists.send`, `connect.list`,
/// `accounts.get`, `users.list`.
Future<T> tracedDocusign<T>({
  required String operation,
  required Future<DocusignCallResult<T>> Function() invoke,
  String? accountId,
}) async {
  if (docusignInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'docusign',
    'rpc.method': operation,
    'docusign.operation': operation,
  };
  if (accountId != null) m['docusign.account.id'] = accountId;

  final span = _tracer().startSpan(
    'docusign $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTelAPI.attributeInt(
          'docusign.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.totalSetSize != null) {
        extras.add(OTelAPI.attributeInt(
          'docusign.total_set_size',
          r.result!.totalSetSize!,
        ));
      }
      if (r.result!.envelopeId != null) {
        extras.add(OTelAPI.attributeString(
          'docusign.envelope.id',
          r.result!.envelopeId!,
        ));
      }
      if (r.result!.envelopeStatus != null) {
        extras.add(OTelAPI.attributeString(
          'docusign.envelope.status',
          r.result!.envelopeStatus!,
        ));
        if (r.result!.envelopeStatus == 'declined' ||
            r.result!.envelopeStatus == 'voided') {
          span.setStatus(
            SpanStatusCode.Error,
            'DocuSign envelope ${r.result!.envelopeStatus}',
          );
        }
      }
      if (r.result!.recipientCount != null) {
        extras.add(OTelAPI.attributeInt(
          'docusign.recipient_count',
          r.result!.recipientCount!,
        ));
      }
      if (r.result!.templateUsed != null) {
        extras.add(OTelAPI.attributeBool(
          'docusign.template.used',
          r.result!.templateUsed!,
        ));
      }
      if (r.result!.bulkSendBatchId != null) {
        extras.add(OTelAPI.attributeString(
          'docusign.bulk_send.batch_id',
          r.result!.bulkSendBatchId!,
        ));
      }
      if (r.result!.consumesSeat != null) {
        extras.add(OTelAPI.attributeBool(
          'docusign.consumes_seat',
          r.result!.consumesSeat!,
        ));
      }
      if (r.result!.region != null) {
        extras.add(OTelAPI.attributeString(
          'docusign.region',
          r.result!.region!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'docusign.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'DocuSign HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
