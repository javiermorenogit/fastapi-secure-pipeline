from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_login_ok():
    r = client.post("/login", data={"username": "admin", "password": "1234"})
    assert r.status_code == 200
    assert "access_token" in r.json()

def test_login_fail():
    r = client.post("/login", data={"username": "bad", "password": "bad"})
    assert r.status_code == 401
