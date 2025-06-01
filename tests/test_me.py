from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_me_flow():
    # login
    r = client.post("/login", data={"username": "admin", "password": "1234"})
    token = r.json()["access_token"]

    # me
    r2 = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert r2.status_code == 200
    assert r2.json()["username"] == "admin"
