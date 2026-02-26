# 🎤 Vocal Planning Assistant

> Assistant vocal intelligent de planning — Application Flutter complète avec IA, TTS, reconnaissance vocale et notifications avancées.

---

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Installation](#installation)
4. [Configuration des permissions](#configuration-des-permissions)
5. [Configuration de l'API IA](#configuration-de-lapi-ia)
6. [Lancement du projet](#lancement-du-projet)
7. [Fonctionnalités détaillées](#fonctionnalités-détaillées)
8. [Structure du projet](#structure-du-projet)
9. [Dépendances](#dépendances)
10. [Dépannage](#dépannage)

---

## Vue d'ensemble

Vocal Planning Assistant est une application mobile Flutter conçue pour gérer votre planning avec une interaction principalement vocale. Elle combine :

- **Gestion complète des tâches** avec récurrence (SQLite)
- **Rappels audio** : alarme sonore + lecture Text-to-Speech
- **Reconnaissance vocale** : commandes "Stop" et "Reporter"
- **Notifications interactives** : boutons d'action même sur écran verrouillé
- **Intelligence artificielle** : analyse des conflits, optimisation, questions en langage naturel

---

## Architecture

Le projet suit les principes de la **Clean Architecture** avec une séparation en 3 couches principales, chacune ayant une responsabilité unique et des dépendances unidirectionnelles (les couches internes ne connaissent jamais les couches externes).

**Couche Domain (cœur métier)** — sans aucune dépendance Flutter ou externe :
- `entities/` : les entités pures comme `Task` avec ses règles métier
- `repositories/` : les interfaces abstraites définissant les contrats de données
- `usecases/` : les cas d'usage encapsulant chaque action métier (créer, compléter, reporter une tâche...)

**Couche Data** — implémentations concrètes des repositories :
- `datasources/` : le `DatabaseHelper` qui gère SQLite directement
- `models/` : les `TaskModel` qui ajoutent la sérialisation SQLite aux entités
- `repositories/` : l'implémentation concrète de `TaskRepositoryImpl`

**Couche Presentation** — tout ce que voit l'utilisateur :
- `pages/` : les écrans principaux (`HomePage`, `TaskFormPage`, `AiChatPage`, etc.)
- `widgets/` : les composants réutilisables (`TaskCard`, `ActiveReminderOverlay`)
- `viewmodels/` : les ViewModels Riverpod qui orchestrent l'UI et les use cases

Les **Services** constituent une couche transversale (audio, notifications, speech, IA, permissions, background tasks) utilisée par les ViewModels sans traverser les couches Domain ou Data.

La **gestion d'état** repose sur **Riverpod** avec des `Notifier` et `NotifierProvider` pour un code prévisible, testable et sans boilerplate excessif.

---

## Installation

### Prérequis

Vous devez avoir installé sur votre machine :

- **Flutter SDK** ≥ 3.0.0 (vérifiez avec `flutter --version`)
- **Dart SDK** ≥ 3.0.0 (inclus avec Flutter)
- **Android Studio** ou **VS Code** avec l'extension Flutter
- Un émulateur Android (API 26+) ou un appareil physique

### Étapes d'installation

**1. Cloner ou décompresser le projet**

```bash
cd chemin/vers/vocal_planning_assistant
```

**2. Installer les dépendances**

```bash
flutter pub get
```

**3. Créer le fichier de configuration**

```bash
cp .env.example .env
```

Puis éditez `.env` pour y mettre votre clé API (voir section suivante).

**4. Créer le répertoire assets et y ajouter un fichier audio**

```bash
mkdir -p assets/sounds assets/animations
```

Ajoutez un fichier `alarm.mp3` dans `assets/sounds/`. Vous pouvez utiliser n'importe quel fichier MP3 court (2-5 secondes idéalement) comme son d'alarme. Des fichiers libres de droits sont disponibles sur [Freesound.org](https://freesound.org).

**5. Vérifier la configuration Flutter**

```bash
flutter doctor
```

Tous les éléments de la liste doivent être ✅ (sauf iOS si vous n'avez pas de Mac).

---

## Configuration des permissions

### Android

Les permissions sont déclarées dans `android/app/src/main/AndroidManifest.xml` et demandées dynamiquement au premier lancement via `PermissionService`.

Permissions requises et leur utilité :

- `POST_NOTIFICATIONS` (Android 13+) : afficher les rappels même quand l'appli est en arrière-plan
- `SCHEDULE_EXACT_ALARM` (Android 12+) : déclencher les alarmes à l'heure exacte (pas approximative)
- `RECORD_AUDIO` : reconnaissance vocale des commandes "Stop" et "Reporter"
- `RECEIVE_BOOT_COMPLETED` : relancer les notifications planifiées après un redémarrage du téléphone
- `FOREGROUND_SERVICE` : maintenir le service de surveillance des tâches actif
- `WAKE_LOCK` : réveiller l'écran pour les rappels importants

Sur **Android 12+** (API 31+), l'utilisateur peut avoir besoin d'autoriser manuellement les alarmes exactes dans Paramètres > Applications > Vocal Planning > Alarmes & rappels.

### iOS (si applicable)

Les permissions iOS sont gérées automatiquement via `DarwinInitializationSettings` dans le `NotificationService`. La première ouverture affiche une boîte de dialogue demandant l'autorisation pour les notifications et le microphone.

---

## Configuration de l'API IA

L'application supporte **OpenAI GPT** et **Google Gemini**. La configuration se fait entièrement dans le fichier `.env` à la racine du projet.

### Avec OpenAI (recommandé)

1. Créez un compte sur [platform.openai.com](https://platform.openai.com)
2. Générez une clé API dans API Keys
3. Éditez `.env` :

```env
AI_API_KEY=sk-proj-votre-clé-ici
AI_PROVIDER=openai
AI_MODEL=gpt-4o-mini
AI_BASE_URL=https://api.openai.com/v1
```

Le modèle `gpt-4o-mini` est recommandé pour son excellent rapport qualité/prix. Vous pouvez utiliser `gpt-4o` pour de meilleures analyses au détriment du coût.

### Avec Google Gemini

1. Créez une clé API sur [aistudio.google.com](https://aistudio.google.com)
2. Éditez `.env` :

```env
AI_API_KEY=votre-clé-gemini
AI_PROVIDER=gemini
AI_MODEL=gemini-1.5-flash
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
```

Google Gemini propose une API compatible OpenAI, donc le service `AiService` fonctionne sans modification.

### Sécurité des clés API

Le fichier `.env` est listé dans `.gitignore` pour ne jamais être commité par accident. En production, considérez des approches comme un backend proxy pour éviter d'exposer la clé côté client.

---

## Lancement du projet

### Démarrage standard

```bash
# Lister les appareils disponibles
flutter devices

# Lancer sur un appareil spécifique
flutter run -d nom_appareil

# Lancer en mode release (plus performant, proche du comportement final)
flutter run --release
```

### Build de l'APK pour distribution

```bash
# APK universel (compatible tous CPU)
flutter build apk --release

# APK split par ABI (fichiers plus petits)
flutter build apk --split-per-abi --release
```

Les APK se trouvent dans `build/app/outputs/flutter-apk/`.

### Mode développement avec rechargement à chaud

```bash
flutter run
# Puis appuyez sur 'r' pour hot reload, 'R' pour hot restart
```

---

## Fonctionnalités détaillées

### Gestion des tâches

Chaque tâche possède un titre, une description (lue à voix haute), une heure exacte et un type de récurrence. La récurrence "toutes les X heures" est particulièrement utile pour des rappels comme "Boire de l'eau" ou "Se lever et s'étirer".

### Séquence de rappel

Quand l'heure d'une tâche arrive, la séquence suivante se déclenche automatiquement :

1. L'alarme sonore se joue (fichier `assets/sounds/alarm.mp3`)
2. Après 2 secondes, la TTS lit "Rappel : [titre]. [description]" en français
3. La reconnaissance vocale s'active automatiquement
4. Si aucune action dans 30 secondes, le rappel se répète
5. Ce cycle dure maximum 10 minutes (20 répétitions)

### Commandes vocales

La reconnaissance vocale accepte les variantes linguistiques naturelles pour chaque commande :

- **Terminer** : "stop", "arrête", "fin", "terminer", "ok", "compris"
- **Reporter** : "reporter", "répéter", "plus tard", "snooze", "dans 10 minutes"

### Intelligence artificielle

L'assistant IA analyse votre planning en temps réel. Il reçoit en contexte la liste complète de vos tâches avec leurs dates et récurrences avant de répondre. Quelques exemples de ce que vous pouvez lui demander :

- "Que me reste-t-il à faire cet après-midi ?"
- "Réorganise mes tâches de demain en tenant compte de mon énergie"
- "Y a-t-il des tâches qui se chevauchent cette semaine ?"

---

## Structure du projet

```
lib/
├── main.dart                    # Point d'entrée, configuration
├── core/
│   └── providers.dart           # Tous les providers Riverpod
├── domain/
│   ├── entities/task.dart       # Entité métier pure
│   ├── repositories/            # Interfaces abstraites
│   └── usecases/task_usecases.dart
├── data/
│   ├── datasources/database_helper.dart
│   ├── models/task_model.dart   # Sérialisation SQLite
│   └── repositories/task_repository_impl.dart
├── services/
│   ├── notification_service.dart
│   ├── audio_service.dart       # TTS + Alarme
│   ├── speech_service.dart      # Reconnaissance vocale
│   ├── ai_service.dart          # API OpenAI/Gemini
│   ├── permission_service.dart
│   └── background_task_service.dart
└── presentation/
    ├── pages/
    │   ├── home_page.dart
    │   ├── tasks_list_page.dart
    │   ├── task_form_page.dart
    │   └── ai_chat_page.dart
    ├── viewmodels/
    │   ├── task_viewmodel.dart
    │   └── ai_chat_viewmodel.dart
    └── widgets/
        ├── task_card.dart
        └── active_reminder_overlay.dart

android/app/src/main/AndroidManifest.xml
.env.example
pubspec.yaml
```

---

## Dépendances

| Package | Version | Rôle |
|---|---|---|
| `flutter_riverpod` | ^2.4.9 | Gestion d'état |
| `sqflite` | ^2.3.0 | Base de données SQLite locale |
| `flutter_local_notifications` | ^16.3.2 | Notifications interactives |
| `flutter_tts` | ^3.8.5 | Text-to-Speech |
| `speech_to_text` | ^6.6.0 | Reconnaissance vocale |
| `workmanager` | ^0.5.2 | Tâches en arrière-plan |
| `audioplayers` | ^5.2.1 | Lecture de l'alarme sonore |
| `dio` | ^5.4.0 | Client HTTP pour l'API IA |
| `flutter_dotenv` | ^5.1.0 | Variables d'environnement |
| `permission_handler` | ^11.2.0 | Gestion des permissions |
| `intl` | ^0.18.1 | Localisation et formatage dates |

---

## Dépannage

**"SCHEDULE_EXACT_ALARM" refusée sur Android 12+** : Allez dans Paramètres > Applications > Vocal Planning > Autorisation > Alarmes & rappels et activez l'option.

**La TTS ne parle pas en français** : Vérifiez que le moteur TTS (Google Text-to-Speech) a le français installé dans Paramètres > Accessibilité > Text-to-Speech.

**Workmanager ne se déclenche pas** : Sur certains appareils (Xiaomi, Huawei, OnePlus), l'optimisation de batterie agressive bloque les tâches en arrière-plan. Désactivez l'optimisation pour cette application dans les paramètres batterie.

**Erreur "clé API invalide"** : Vérifiez que le fichier `.env` est bien présent à la racine du projet, que la clé est correcte et que l'asset est déclaré dans `pubspec.yaml`.

**Le micro ne fonctionne pas** : Vérifiez que la permission `RECORD_AUDIO` a bien été accordée dans Paramètres > Applications > Vocal Planning > Permissions > Microphone.
