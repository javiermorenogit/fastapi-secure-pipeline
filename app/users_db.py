def get_user(username: str):
    fake_users_db = {
        "admin": {
            "username": "admin",
            "password": "1234"
        }
    }
    return fake_users_db.get(username)