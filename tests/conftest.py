import pytest
from fastapi.testclient import TestClient
import mongomock
from unittest.mock import patch

from app.main import app
from app.db import get_db

@pytest.fixture
def mock_mongo():
    with mongomock.patch(servers=(('127.0.0.1', 27017),)):
        yield

@pytest.fixture
def client(mock_mongo):
    # Override the dependency if used via Depends
    # Also patch the direct import just in case
    
    def override_get_db():
        client = mongomock.MongoClient()
        return client["rbk_labs"]

    app.dependency_overrides[get_db] = override_get_db
    
    with TestClient(app) as c:
        yield c
    
    app.dependency_overrides.clear()
