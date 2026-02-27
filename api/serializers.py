from rest_framework import serializers
from .models import Item


class ItemSerializer(serializers.ModelSerializer):
    """项目序列化器"""

    class Meta:
        model = Item
        fields = ['id', 'name', 'description', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']
