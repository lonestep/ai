from rest_framework import viewsets, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from .models import Item
from .serializers import ItemSerializer


class ItemViewSet(viewsets.ModelViewSet):
    """项目视图集"""
    queryset = Item.objects.all()
    serializer_class = ItemSerializer
    permission_classes = [AllowAny]


@api_view(['GET'])
@permission_classes([AllowAny])
def api_info(request):
    """API 信息"""
    return Response({
        'message': 'Django REST API is running',
        'version': '1.0.0',
        'endpoints': {
            'items': '/api/items/',
            'health': '/health/',
        }
    })
