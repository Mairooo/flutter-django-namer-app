from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from .models import Favorite, Notification


@receiver(post_save, sender=Favorite)
def favorite_created(sender, instance, created, **kwargs):
    """Enregistre une notification quand un favori est ajouté"""
    if created:
        Notification.objects.create(
            notification_type='like',
            word=instance.word,
            message=f'Le mot "{instance.word}" a été ajouté aux favoris!'
        )


@receiver(post_delete, sender=Favorite)
def favorite_deleted(sender, instance, **kwargs):
    """Enregistre une notification quand un favori est supprimé"""
    Notification.objects.create(
        notification_type='unlike',
        word=instance.word,
        message=f'Le mot "{instance.word}" a été retiré des favoris.'
    )
