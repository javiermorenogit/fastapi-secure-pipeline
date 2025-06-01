from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt
from datetime import datetime, timedelta
from typing import Optional
from .users_db import get_user

SECRET_KEY = "mysecret"
ALGORITHM  = "HS256"
ACCESS_TOKEN_EXPIRE = 30  # minutos

bearer_scheme = HTTPBearer(auto_error=False)

def create_access_token(data: dict, expires: Optional[int] = ACCESS_TOKEN_EXPIRE):
    to_encode = data.copy()
    to_encode.update(exp=datetime.utcnow() + timedelta(minutes=expires))
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def authenticate_user(username: str, password: str):
    user = get_user(username)
    if not user or user["password"] != password:
        return None
    return user

def get_current_user(
        credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme)):
    if not credentials:
        raise HTTPException(status_code=401, detail="Token faltante")

    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
    except Exception:
        raise HTTPException(status_code=401, detail="Token inválido")

    user = get_user(username)
    if not user:
        raise HTTPException(status_code=401, detail="Usuario no encontrado")
    return user
