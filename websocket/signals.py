from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from api.models import Item
import logging

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Item)
def item_post_save(sender, instance, created, **kwargs):
    """当项目创建或更新时，发送 WebSocket 通知"""
    logger.info(f"Item {'created' if created else 'updated'}: {instance.name}")
    channel_layer = get_channel_layer()

    data = {
        'id': instance.id,
        'name': instance.name,
        'description': instance.description,
        'created_at': instance.created_at.isoformat() if instance.created_at else None,
        'updated_at': instance.updated_at.isoformat() if instance.updated_at else None,
        'action': 'created' if created else 'updated'
    }

    logger.info(f"Sending to channel layer: {data}")
    async_to_sync(channel_layer.group_send)(
        'items',
        {
            'type': 'item.update',
            'data': data
        }
    )
    logger.info("Message sent to channel layer")


@receiver(post_delete, sender=Item)
def item_post_delete(sender, instance, **kwargs):
    """当项目删除时，发送 WebSocket 通知"""
    logger.info(f"Item deleted: {instance.name}")
    channel_layer = get_channel_layer()

    data = {
        'id': instance.id,
        'action': 'deleted'
    }

    logger.info(f"Sending delete notification: {data}")
    async_to_sync(channel_layer.group_send)(
        'items',
        {
            'type': 'item.update',
            'data': data
        }
    )
    logger.info("Delete notification sent")
