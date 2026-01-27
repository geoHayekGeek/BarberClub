import 'package:flutter_test/flutter_test.dart';
import 'package:barber/core/validators/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    group('validateFullName', () {
      test('returns null for valid full name', () {
        expect(AuthValidators.validateFullName('Jean Dupont'), isNull);
        expect(AuthValidators.validateFullName('Marie-Claire Martin'), isNull);
        expect(AuthValidators.validateFullName('   Jean   '), isNull); // trimmed
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validateFullName(null),
          equals('Le nom complet est requis.'),
        );
        expect(
          AuthValidators.validateFullName(''),
          equals('Le nom complet est requis.'),
        );
        expect(
          AuthValidators.validateFullName('   '),
          equals('Le nom complet est requis.'),
        );
      });

      test('returns error for too short name', () {
        expect(
          AuthValidators.validateFullName('Jo'),
          equals('Le nom complet doit contenir au moins 3 caractères.'),
        );
        expect(
          AuthValidators.validateFullName('AB'),
          equals('Le nom complet doit contenir au moins 3 caractères.'),
        );
      });
    });

    group('validateEmail', () {
      test('returns null for valid emails', () {
        expect(AuthValidators.validateEmail('test@example.com'), isNull);
        expect(AuthValidators.validateEmail('user.name@domain.co.uk'), isNull);
        expect(AuthValidators.validateEmail('test+tag@example.com'), isNull);
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validateEmail(null),
          equals('L\'adresse e-mail est requise.'),
        );
        expect(
          AuthValidators.validateEmail(''),
          equals('L\'adresse e-mail est requise.'),
        );
      });

      test('returns error for invalid email format', () {
        expect(
          AuthValidators.validateEmail('invalid'),
          equals('Veuillez saisir une adresse e-mail valide.'),
        );
        expect(
          AuthValidators.validateEmail('invalid@'),
          equals('Veuillez saisir une adresse e-mail valide.'),
        );
        expect(
          AuthValidators.validateEmail('@example.com'),
          equals('Veuillez saisir une adresse e-mail valide.'),
        );
        expect(
          AuthValidators.validateEmail('test@'),
          equals('Veuillez saisir une adresse e-mail valide.'),
        );
      });
    });

    group('validatePhoneNumber', () {
      test('returns null for valid phone numbers', () {
        expect(AuthValidators.validatePhoneNumber('+33612345678'), isNull);
        expect(AuthValidators.validatePhoneNumber('+33123456789'), isNull);
        expect(AuthValidators.validatePhoneNumber('+123456789012345'), isNull); // 15 digits
        expect(AuthValidators.validatePhoneNumber('+12345678'), isNull); // 8 digits
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validatePhoneNumber(null),
          equals('Le numéro de téléphone est requis.'),
        );
        expect(
          AuthValidators.validatePhoneNumber(''),
          equals('Le numéro de téléphone est requis.'),
        );
      });

      test('returns error if not starting with +', () {
        expect(
          AuthValidators.validatePhoneNumber('33612345678'),
          equals('Le numéro doit commencer par + (format E.164).'),
        );
        expect(
          AuthValidators.validatePhoneNumber('0612345678'),
          equals('Le numéro doit commencer par + (format E.164).'),
        );
      });

      test('returns error for invalid characters', () {
        expect(
          AuthValidators.validatePhoneNumber('+33-612-345-678'),
          equals('Le numéro ne doit contenir que des chiffres après le +.'),
        );
        expect(
          AuthValidators.validatePhoneNumber('+33 6 12 34 56 78'),
          equals('Le numéro ne doit contenir que des chiffres après le +.'),
        );
        expect(
          AuthValidators.validatePhoneNumber('+abc123'),
          equals('Le numéro ne doit contenir que des chiffres après le +.'),
        );
      });

      test('returns error for wrong length', () {
        expect(
          AuthValidators.validatePhoneNumber('+1234567'), // 7 digits
          equals('Le numéro doit contenir entre 8 et 15 chiffres après le +.'),
        );
        expect(
          AuthValidators.validatePhoneNumber('+1234567890123456'), // 16 digits
          equals('Le numéro doit contenir entre 8 et 15 chiffres après le +.'),
        );
      });
    });

    group('validatePassword', () {
      test('returns null for valid passwords', () {
        expect(AuthValidators.validatePassword('password123'), isNull);
        expect(AuthValidators.validatePassword('12345678'), isNull); // exactly 8
        expect(AuthValidators.validatePassword('verylongpassword123'), isNull);
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validatePassword(null),
          equals('Le mot de passe est requis.'),
        );
        expect(
          AuthValidators.validatePassword(''),
          equals('Le mot de passe est requis.'),
        );
      });

      test('returns error for too short password', () {
        expect(
          AuthValidators.validatePassword('short'),
          equals('Le mot de passe doit contenir au moins 8 caractères.'),
        );
        expect(
          AuthValidators.validatePassword('1234567'),
          equals('Le mot de passe doit contenir au moins 8 caractères.'),
        );
      });
    });

    group('validatePasswordConfirmation', () {
      test('returns null when passwords match', () {
        expect(
          AuthValidators.validatePasswordConfirmation('password123', 'password123'),
          isNull,
        );
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validatePasswordConfirmation(null, 'password'),
          equals('La confirmation du mot de passe est requise.'),
        );
        expect(
          AuthValidators.validatePasswordConfirmation('', 'password'),
          equals('La confirmation du mot de passe est requise.'),
        );
      });

      test('returns error when passwords do not match', () {
        expect(
          AuthValidators.validatePasswordConfirmation('password123', 'password456'),
          equals('Les mots de passe ne correspondent pas.'),
        );
        expect(
          AuthValidators.validatePasswordConfirmation('password', 'Password'),
          equals('Les mots de passe ne correspondent pas.'),
        );
      });
    });

    group('validateLoginIdentifier', () {
      test('returns null for valid email', () {
        expect(AuthValidators.validateLoginIdentifier('test@example.com'), isNull);
      });

      test('returns null for valid phone number', () {
        expect(AuthValidators.validateLoginIdentifier('+33612345678'), isNull);
      });

      test('returns error for empty or null', () {
        expect(
          AuthValidators.validateLoginIdentifier(null),
          equals('L\'e-mail ou le numéro de téléphone est requis.'),
        );
        expect(
          AuthValidators.validateLoginIdentifier(''),
          equals('L\'e-mail ou le numéro de téléphone est requis.'),
        );
      });

      test('validates email format when @ is present', () {
        expect(
          AuthValidators.validateLoginIdentifier('invalid@'),
          equals('Veuillez saisir une adresse e-mail valide.'),
        );
      });

      test('validates phone format when @ is not present', () {
        expect(
          AuthValidators.validateLoginIdentifier('33612345678'),
          equals('Le numéro doit commencer par + (format E.164).'),
        );
      });
    });
  });
}
