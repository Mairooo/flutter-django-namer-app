from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import action
from .models import Favorite
from .serializers import FavoriteSerializer


class FavoriteViewSet(viewsets.ModelViewSet):
    queryset = Favorite.objects.all()
    serializer_class = FavoriteSerializer
    lookup_field = 'word'

    def create(self, request, *args, **kwargs):
        word = request.data.get('word')
        if not word:
            return Response(
                {'error': 'Le champ word est requis'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        favorite, created = Favorite.objects.get_or_create(word=word)
        serializer = self.get_serializer(favorite)
        
        if created:
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def destroy(self, request, *args, **kwargs):
        word = kwargs.get('word')
        try:
            favorite = Favorite.objects.get(word=word)
            favorite.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Favorite.DoesNotExist:
            return Response(
                {'error': 'Favori non trouvé'},
                status=status.HTTP_404_NOT_FOUND
            )
