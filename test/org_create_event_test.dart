import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lef_mob/pages/creater/org_create_event.dart';

// Mock Firestore
class MockFirestore extends Mock implements FirebaseFirestore {}

// Mock DocumentReference
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}

void main() {
  group('OrgCreateEventPage Tests', () {
    late MockFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirestore();
    });

    testWidgets('Create event successfully', (WidgetTester tester) async {
      // Mock Firestore add operation
      when(mockFirestore.collection('events').add(any as Map<String, dynamic>)).thenAnswer((_) async => MockDocumentReference());

      // Build the OrgCreateEventPage widget
      await tester.pumpWidget(MaterialApp(
        home: OrgCreateEventPage(organizerName: 'Test Organizer'),
      ));

      // Enter event details
      await tester.enterText(find.byType(TextField).at(0), 'Test Event'); // Event Name
      await tester.enterText(find.byType(TextField).at(1), 'This is a test event description.'); // Event Description
      await tester.enterText(find.byType(TextField).at(2), '5000'); // Ticket Price

      // Simulate creating the event
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump();

      // Verify that the event was created successfully
      verify(mockFirestore.collection('events').add(any as Map<String, dynamic>)).called(1);
    });

    testWidgets('Fail to create event with missing fields', (WidgetTester tester) async {
      // Build the OrgCreateEventPage widget
      await tester.pumpWidget(MaterialApp(
        home: OrgCreateEventPage(organizerName: 'Test Organizer'),
      ));

      // Leave fields empty and try to create the event
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump();

      // Verify that no Firestore operation was called
      verifyNever(mockFirestore.collection('events').add(any as Map<String, dynamic>));
    });
  });
}
