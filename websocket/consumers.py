import json
import asyncio
import logging
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from api.models import Item

logger = logging.getLogger(__name__)


class ItemConsumer(AsyncWebsocketConsumer):
    """项目实时更新 WebSocket 消费者"""

    async def connect(self):
        logger.info(f"WebSocket connecting: {self.channel_name}")
        await self.channel_layer.group_add('items', self.channel_name)
        await self.accept()
        logger.info(f"WebSocket connected: {self.channel_name}")

    async def disconnect(self, close_code):
        logger.info(f"WebSocket disconnecting: {self.channel_name}")
        await self.channel_layer.group_discard('items', self.channel_name)
        logger.info(f"WebSocket disconnected: {self.channel_name}")

    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message_type = text_data_json.get('type', '')
        logger.info(f"Received message: {message_type}")

        if message_type == 'fetch_items':
            await self.send_items()

    async def send_items(self):
        items = await self.get_items()
        await self.send(text_data=json.dumps({
            'type': 'items_list',
            'items': items
        }))

    async def item_update(self, event):
        """当项目更新时广播给所有连接的客户端"""
        logger.info(f"Received item_update event: {event}")
        await self.send(text_data=json.dumps({
            'type': 'item_updated',
            'data': event['data']
        }))
        logger.info("Sent item_update message to client")

    @database_sync_to_async
    def get_items(self):
        items = list(Item.objects.all().values('id', 'name', 'description', 'created_at', 'updated_at'))
        # 将 datetime 对象转换为字符串
        for item in items:
            item['created_at'] = item['created_at'].isoformat() if item['created_at'] else None
            item['updated_at'] = item['updated_at'].isoformat() if item['updated_at'] else None
        return items


class ChatConsumer(AsyncWebsocketConsumer):
    """聊天 WebSocket 消费者"""

    async def connect(self):
        self.room_name = self.scope['url_route']['kwargs'].get('room_name', 'default')
        self.room_group_name = f'chat_{self.room_name}'

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data):
        text_data_json = json.loads(text_data)
        message = text_data_json['message']
        username = text_data_json.get('username', '匿名用户')

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'chat_message',
                'message': message,
                'username': username,
            }
        )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'type': 'chat',
            'message': event['message'],
            'username': event['username'],
        }))
