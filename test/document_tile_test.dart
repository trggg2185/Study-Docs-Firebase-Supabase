import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_flutter/modified/models/document_model.dart';
import 'package:test_flutter/widgets/framework/document_tile.dart';

DocumentModel _document({List<String> tags = const []}) {
  final now = DateTime(2026);
  return DocumentModel(
    id: 'document-1',
    title: 'Tài liệu kiểm thử',
    type: DocumentType.lecture,
    subject: 'Lập trình',
    createdAt: now,
    updatedAt: now,
    tags: tags,
  );
}

void main() {
  Widget buildTile({List<String> tags = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: DocumentTile(document: _document(tags: tags)),
      ),
    );
  }

  testWidgets('shows at most three tag chips', (tester) async {
    await tester.pumpWidget(
      buildTile(tags: ['flutter', 'dart', 'mobile', 'extra']),
    );

    expect(find.text('flutter'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('extra'), findsNothing);
  });

  testWidgets('does not render tag chips when there are no tags', (
    tester,
  ) async {
    await tester.pumpWidget(buildTile());

    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('fits a narrow card without horizontal overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: DocumentTile(
                document: _document(tags: ['flutter', 'dart', 'responsive'])
                    .copyWith(
                      title: 'A long study document title',
                      sharedPermission: 'edit',
                    ),
                currentUserId: 'another-user',
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
