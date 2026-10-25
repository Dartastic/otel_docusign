// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_docusign/otel_docusign.dart';

/// Traces DocuSign eSignature calls with OpenTelemetry.
///
/// `otel_docusign` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each DocuSign eSignature call in
/// [tracedDocusign]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'docusign-example');

  // Wraps a DocuSign eSignature REST v2.1 call in a CLIENT span.
  final docusignId = await tracedDocusign<String>(
    operation: 'envelopes.create',
    accountId: 'account_8f3a2c',
    invoke: () async {
      // Make the DocuSign eSignature call here, then report what it returned.
      const id = 'docusign_8f3a2c';
      return const DocusignCallResult(
          value: id,
          result: DocusignResult(
              itemCount: 3,
              totalSetSize: 512,
              envelopeId: 'envelope_8f3a2c',
              envelopeStatus: 'created',
              recipientCount: 3,
              templateUsed: true,
              bulkSendBatchId: 'bulksendbatch_8f3a2c',
              consumesSeat: true,
              region: 'na1',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedDocusign envelopes.create returned $docusignId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutDocusignInstrumentationAsync.
  await runWithoutDocusignInstrumentationAsync(
    () => tracedDocusign<String>(
      operation: 'envelopes.create',
      accountId: 'account_8f3a2c',
      invoke: () async {
        const id = 'docusign_8f3a2c';
        return const DocusignCallResult(
            value: id,
            result: DocusignResult(
                itemCount: 3,
                totalSetSize: 512,
                envelopeId: 'envelope_8f3a2c',
                envelopeStatus: 'created',
                recipientCount: 3,
                templateUsed: true,
                bulkSendBatchId: 'bulksendbatch_8f3a2c',
                consumesSeat: true,
                region: 'na1',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
