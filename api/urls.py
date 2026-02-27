from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ItemViewSet, api_info

router = DefaultRouter()
router.register(r'items', ItemViewSet, basename='item')

urlpatterns = [
    path('', include(router.urls)),
    path('info/', api_info),
]
