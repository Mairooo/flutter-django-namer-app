from django.db import models


class Favorite(models.Model):
    word = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.word


class Notification(models.Model):
    NOTIFICATION_TYPES = (
        ('like', 'Like'),
        ('unlike', 'Unlike'),
    )
    
    notification_type = models.CharField(max_length=20, choices=NOTIFICATION_TYPES)
    word = models.CharField(max_length=100)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.notification_type}: {self.word}"
