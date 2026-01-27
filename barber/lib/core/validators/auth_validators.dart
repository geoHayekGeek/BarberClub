/// Authentication form validators with French error messages

class AuthValidators {
  /// Validate full name (minimum 3 characters)
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom complet est requis.';
    }
    if (value.trim().length < 3) {
      return 'Le nom complet doit contenir au moins 3 caractères.';
    }
    return null;
  }

  /// Validate email (simple RFC-ish regex)
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'adresse e-mail est requise.';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Veuillez saisir une adresse e-mail valide.';
    }
    
    return null;
  }

  /// Validate phone number (E.164 format: + and digits, 8-15 digits after +)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le numéro de téléphone est requis.';
    }
    
    final trimmed = value.trim();
    
    // Must start with +
    if (!trimmed.startsWith('+')) {
      return 'Le numéro doit commencer par + (format E.164).';
    }
    
    // Must contain only + and digits
    if (!RegExp(r'^\+[0-9]+$').hasMatch(trimmed)) {
      return 'Le numéro ne doit contenir que des chiffres après le +.';
    }
    
    // Length check: + plus 8-15 digits
    final digitsOnly = trimmed.substring(1);
    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      return 'Le numéro doit contenir entre 8 et 15 chiffres après le +.';
    }
    
    return null;
  }

  /// Validate password (minimum 8 characters)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis.';
    }
    if (value.length < 8) {
      return 'Le mot de passe doit contenir au moins 8 caractères.';
    }
    return null;
  }

  /// Validate password confirmation (must match password)
  static String? validatePasswordConfirmation(
    String? value,
    String? password,
  ) {
    if (value == null || value.isEmpty) {
      return 'La confirmation du mot de passe est requise.';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas.';
    }
    return null;
  }

  /// Validate login identifier (email or phone)
  static String? validateLoginIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'e-mail ou le numéro de téléphone est requis.';
    }
    
    final trimmed = value.trim();
    
    // Check if it's an email or phone
    if (trimmed.contains('@')) {
      return validateEmail(value);
    } else {
      return validatePhoneNumber(value);
    }
  }
}
