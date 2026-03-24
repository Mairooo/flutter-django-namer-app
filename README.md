# Namer App

Application fullstack de génération de paires de mots aléatoires avec gestion de favoris, construite avec **Flutter** (frontend) et **Django REST Framework** (backend).

## Architecture

```
flutter-django-namer-app/
├── flutter_application_1/   # Application mobile/web Flutter
└── namer_backend/           # API REST Django
```

## Frontend — Flutter

### Fonctionnalités

- Génération aléatoire de paires de mots anglais
- Ajout/suppression de favoris avec persistance locale (`SharedPreferences`)
- Navigation par onglets (Accueil / Favoris)
- Bouton retour pour récupérer le dernier mot passé
- Géolocalisation (enregistrement de la position GPS)
- Thème sombre personnalisé (style Sigma, couleurs rose/bleu nuit)

### Dépendances principales

| Package              | Usage                          |
|----------------------|--------------------------------|
| `english_words`      | Génération de paires de mots   |
| `provider`           | Gestion d'état                 |
| `http`               | Requêtes HTTP vers le backend  |
| `shared_preferences` | Stockage local des favoris     |
| `geolocator`         | Accès à la localisation GPS    |
| `url_launcher`       | Ouverture de liens externes    |
| `flutter_svg`        | Affichage de logos SVG         |

### Lancement

```bash
cd flutter_application_1
flutter pub get
flutter run
```

## Backend — Django REST Framework

### Fonctionnalités

- API REST pour la gestion des favoris (CRUD)
- Modèle `Favorite` (mot unique + date de création)
- Modèle `Notification` (suivi des actions like/unlike)
- Base de données PostgreSQL

### Endpoints

| Méthode  | URL                          | Description              |
|----------|------------------------------|--------------------------|
| `GET`    | `/api/favorites/`            | Lister tous les favoris  |
| `POST`   | `/api/favorites/`            | Ajouter un favori        |
| `GET`    | `/api/favorites/{word}/`     | Détail d'un favori       |
| `DELETE` | `/api/favorites/{word}/`     | Supprimer un favori      |

### Prérequis

- Python 3.10+
- PostgreSQL avec une base `namer_db`

### Installation et lancement

```bash
cd namer_backend

# Créer un environnement virtuel
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# Installer les dépendances
pip install -r requirements.txt

# Appliquer les migrations
python manage.py migrate

# Lancer le serveur
python manage.py runserver
```

Le serveur sera accessible sur `http://localhost:8000`.

## Stack technique

| Composant  | Technologie                  |
|------------|------------------------------|
| Frontend   | Flutter (Dart)               |
| Backend    | Django 6.0 + DRF             |
| Base de données | PostgreSQL              |
| État (frontend) | Provider               |
| Stockage local  | SharedPreferences      |
