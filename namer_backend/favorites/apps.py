from django.apps import AppConfig


class FavoritesConfig(AppConfig):
    name = 'favorites'

    def ready(self):
        # Importer les signals pour qu'ils soient enregistrés
        import favorites.signals
