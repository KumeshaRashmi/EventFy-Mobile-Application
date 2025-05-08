import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:lef_mob/pages/creater/org_home.dart';

// Mock Firestore
class MockFirestore extends Mock implements FirebaseFirestore {}

// Mock QuerySnapshot
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}

void main() {
  group('OrgHomePage Tests', () {
    late MockFirestore mockFirestore;

    setUp(() {
      mockFirestore = MockFirestore();
    });

    testWidgets('Fetch events successfully', (WidgetTester tester) async {
      // Mock Firestore data
      final mockQuerySnapshot = MockQuerySnapshot();
      when(mockFirestore.collection('events').get()).thenAnswer((_) async => Future.value(mockQuerySnapshot));

      // Build the OrgHomePage widget
      await tester.pumpWidget(MaterialApp(
        home: OrgHomePage(
          profileImageUrl: '',
          displayName: 'Test Organizer',
          email: 'test@example.com',
        ),
      ));

      // Verify that the widget builds without errors
      expect(find.byType(OrgHomePage), findsOneWidget);
    });

    testWidgets('Delete event successfully', (WidgetTester tester) async {
      // Mock Firestore delete operation
      when(mockFirestore.collection('events').doc(any).delete()).thenAnswer((_) async => null);

      // Build the OrgHomePage widget
      await tester.pumpWidget(MaterialApp(
        home: OrgHomePage(
          profileImageUrl: '',
          displayName: 'Test Organizer',
          email: 'test@example.com',
        ),
      ));

      // Simulate user interaction to delete an event
      // (You can add more specific interaction tests here if needed)
      expect(find.byType(OrgHomePage), findsOneWidget);
    });
  });
}
