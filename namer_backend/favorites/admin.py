from django.contrib import admin
from .models import Favorite, Notification


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ('word', 'created_at')
    search_fields = ('word',)
    list_filter = ('created_at',)
    ordering = ('-created_at',)


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('notification_type', 'word', 'message', 'created_at')
    list_filter = ('notification_type', 'created_at')
    search_fields = ('word', 'message')
    ordering = ('-created_at',)
