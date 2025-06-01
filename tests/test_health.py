from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_login_ok():
    resp = client.post("/login", data={"username": "admin", "password": "1234"})
    assert resp.status_code == 200
    assert "access_token" in resp.json()

def test_login_fail():
    resp = client.post("/login", data={"username": "bad", "password": "bad"})
    assert resp.status_code == 401