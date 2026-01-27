# Barber Club - Guide de développement

## Prérequis

- Flutter SDK 3.10.7 ou supérieur
- Dart SDK 3.10.7 ou supérieur
- Backend API en cours d'exécution (voir `../backend/README.md`)

## Installation

1. Installer les dépendances Flutter :
```bash
flutter pub get
```

2. Générer les fichiers de code (freezed, json_serializable) :
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Configuration de l'URL de l'API

L'application utilise `--dart-define` pour configurer l'URL de base de l'API.

### Android Emulator (par défaut)

L'URL par défaut est `http://10.0.2.2:3000` (qui pointe vers `localhost:3000` sur votre machine hôte).

```bash
flutter run
```

ou explicitement :

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

### iOS Simulator

Pour iOS Simulator, utilisez `http://localhost:3000` ou l'IP de votre machine sur le réseau local :

```bash
# Option 1: localhost (si backend sur même machine)
flutter run --dart-define=API_BASE_URL=http://localhost:3000

# Option 2: IP locale (si backend sur réseau)
flutter run --dart-define=API_BASE_URL=http://192.168.1.XXX:3000
```

### Appareil physique

Pour un appareil physique (Android ou iOS), utilisez l'IP de votre machine sur le réseau local :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.XXX:3000
```

**Note** : Remplacez `192.168.1.XXX` par l'IP réelle de votre machine. Vous pouvez la trouver avec :
- Windows : `ipconfig`
- macOS/Linux : `ifconfig` ou `ip addr`

## Exécution

### Mode développement

```bash
flutter run
```

### Mode release

```bash
flutter run --release
```

## Tests

Exécuter les tests unitaires :

```bash
flutter test
```

Les tests incluent :
- Validation des formulaires (email, téléphone, mot de passe)
- Validateurs avec messages d'erreur en français

## Structure du projet

```
lib/
├── core/
│   ├── config/          # Configuration (API base URL)
│   ├── network/          # Dio client avec interceptors
│   ├── storage/          # Token repository (secure storage)
│   └── validators/       # Validateurs de formulaires
├── domain/
│   ├── models/           # Modèles de domaine (User, AuthResponse, etc.)
│   └── repositories/     # Interfaces de repositories
├── data/
│   └── repositories/     # Implémentations des repositories
└── presentation/
    ├── providers/        # Providers Riverpod
    ├── screens/          # Écrans UI
    ├── routing/          # Configuration GoRouter
    └── theme/            # Thème Material 3
```

## Fonctionnalités implémentées

### Authentification

- ✅ Connexion (email ou téléphone + mot de passe)
- ✅ Inscription (nom, email, téléphone, mot de passe)
- ✅ Mot de passe oublié
- ✅ Gestion de session (bootstrap au démarrage)
- ✅ Déconnexion
- ✅ Refresh token automatique
- ✅ Stockage sécurisé des tokens

### Sécurité

- ✅ Tokens stockés dans `flutter_secure_storage`
- ✅ Refresh token automatique avec queue lock
- ✅ Gestion des erreurs 401 avec redirection vers login
- ✅ Validation côté client avant envoi API

### UI/UX

- ✅ Thème Material 3 sombre (or/beige)
- ✅ Messages d'erreur en français
- ✅ Validation en temps réel
- ✅ États de chargement
- ✅ Navigation avec GoRouter
- ✅ Accessibilité (SafeArea, text scaling)

## Dépannage

### Erreur de connexion réseau

- Vérifiez que le backend est en cours d'exécution
- Vérifiez l'URL de base de l'API avec `--dart-define`
- Pour Android Emulator : utilisez `http://10.0.2.2:3000`
- Pour iOS Simulator : utilisez `http://localhost:3000` ou l'IP locale

### Erreurs de build (freezed/json_serializable)

Si les fichiers générés sont manquants :

```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

### Erreurs de lint

Le projet utilise des règles de lint strictes. Pour voir les erreurs :

```bash
flutter analyze
```

## Prochaines étapes

Cette implémentation couvre uniquement le module d'authentification. Les modules suivants seront ajoutés séparément :

- Réservation (booking)
- Profil utilisateur
- Navigation principale (tabs)
- Intégration avec TIMIFY (si nécessaire)
