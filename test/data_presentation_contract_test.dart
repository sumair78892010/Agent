import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/models/chat_message.dart';
import '../lib/services/attachment_service.dart';
import '../lib/widgets/data_summary_card.dart';

void main() {
  const summary = AttachmentDataSummary(
    format: 'CSV',
    rowCount: 3,
    columnCount: 2,
    columns: ['name', 'amount'],
    numericColumns: {
      'amount': NumericSummary(count: 3, minimum: 10, maximum: 30, average: 20),
    },
  );

  test(
    'data summaries survive ChatMessage persistence without raw content',
    () {
      final message = ChatMessage(
        role: 'user',
        content: 'Analyze this dataset',
        dataSummaries: const [summary],
      );

      final encoded = message.toJson();
      final restored = ChatMessage.fromJson(encoded);

      expect(restored.dataSummaries.single.format, 'CSV');
      expect(restored.dataSummaries.single.rowCount, 3);
      expect(
        restored.dataSummaries.single.numericColumns['amount']?.average,
        20,
      );
      expect(encoded.toString(), isNot(contains('super-secret')));
    },
  );

  testWidgets('data summary card shows bounded table and chart labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DataSummaryCard(attachmentName: 'sales.csv', summary: summary),
        ),
      ),
    );

    expect(find.text('sales.csv · CSV analysis'), findsOneWidget);
    expect(find.text('Rows 3'), findsOneWidget);
    expect(find.text('Columns 2'), findsOneWidget);
    expect(find.text('name · amount'), findsOneWidget);
    expect(find.textContaining('avg 20'), findsOneWidget);
    expect(find.textContaining('min 10'), findsOneWidget);
  });

  test(
    'presentation contract remains bounded and excludes raw attachment paths',
    () {
      final summaryJson = summary.toJson();
      expect(summaryJson['columns'], hasLength(2));
      expect(summaryJson.toString(), isNot(contains('/data/private')));
      expect(summaryJson.toString(), isNot(contains('Bearer')));
    },
  );
}
