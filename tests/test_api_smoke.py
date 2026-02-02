def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "rbk-api"}

def test_list_labs(client):
    response = client.get("/labs")
    assert response.status_code == 200
    data = response.json()
    assert "labs" in data
    assert isinstance(data["labs"], list)
