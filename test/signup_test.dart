import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lef_mob/pages/signup.dart';

// Mock FirebaseAuth
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

// Mock UserCredential
class MockUserCredential extends Mock implements UserCredential {}

void main() {
  group('SignupPage Tests', () {
    late MockFirebaseAuth mockFirebaseAuth;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
    });

    testWidgets('Passwords do not match', (WidgetTester tester) async {
      // Build the SignupPage widget
      await tester.pumpWidget(MaterialApp(home: SignupPage()));

      // Enter mismatched passwords
      await tester.enterText(find.byType(TextField).at(3), 'password123'); // Password
      await tester.enterText(find.byType(TextField).at(4), 'password456'); // Confirm Password

      // Tap the Sign Up button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Password too short', (WidgetTester tester) async {
      // Build the SignupPage widget
      await tester.pumpWidget(MaterialApp(home: SignupPage()));

      // Enter a short password
      await tester.enterText(find.byType(TextField).at(3), '123'); // Password
      await tester.enterText(find.byType(TextField).at(4), '123'); // Confirm Password

      // Tap the Sign Up button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify error message is shown
      expect(find.text('Password must be at least 6 characters long'), findsOneWidget);
    });

    testWidgets('Successful registration', (WidgetTester tester) async {
      // Mock FirebaseAuth behavior
      when(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => MockUserCredential());

      // Build the SignupPage widget
      await tester.pumpWidget(MaterialApp(home: SignupPage()));

      // Enter valid details
      await tester.enterText(find.byType(TextField).at(0), 'Test User'); // Full Name
      await tester.enterText(find.byType(TextField).at(1), 'test@example.com'); // Email
      await tester.enterText(find.byType(TextField).at(2), '1234567890'); // Phone
      await tester.enterText(find.byType(TextField).at(3), 'password123'); // Password
      await tester.enterText(find.byType(TextField).at(4), 'password123'); // Confirm Password

      // Tap the Sign Up button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify FirebaseAuth method is called
      verify(mockFirebaseAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
    });
  });
}
