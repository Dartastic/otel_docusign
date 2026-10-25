// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_docusign/otel_docusign.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_docusign-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('envelopes.create records recipient_count + template + seat', () async {
    await tracedDocusign<String>(
      operation: 'envelopes.create',
      accountId: 'acc-1',
      invoke: () async => const DocusignCallResult(
        value: 'ok',
        result: DocusignResult(
          envelopeId: 'env-1',
          envelopeStatus: 'sent',
          recipientCount: 3,
          templateUsed: true,
          consumesSeat: true,
          region: 'na2',
          statusCode: 201,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('docusign envelopes.create')!);
    expect(a['docusign.account.id'], 'acc-1');
    expect(a['docusign.envelope.id'], 'env-1');
    expect(a['docusign.recipient_count'], 3);
    expect(a['docusign.template.used'], true);
    expect(a['docusign.consumes_seat'], true);
    expect(a['docusign.region'], 'na2');
  });

  test('declined envelope sets span error', () async {
    await tracedDocusign<String>(
      operation: 'envelopes.get',
      invoke: () async => const DocusignCallResult(
        value: 'ok',
        result: DocusignResult(envelopeStatus: 'declined'),
      ),
    );
    expect(
      spans.findSpanByName('docusign envelopes.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutDocusignInstrumentationAsync(() async {
      await tracedDocusign<String>(
        operation: 'envelopes.list',
        invoke: () async => const DocusignCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('docusign '), isEmpty);
  });
}
