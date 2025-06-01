from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from app.auth import authenticate_user, create_access_token, get_current_user
from app.models import Token, User

app = FastAPI(title="API JWT con 1 campo Bearer")

@app.post("/login", response_model=Token)
def login(form: OAuth2PasswordRequestForm = Depends()):
    user = authenticate_user(form.username, form.password)
    if not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    token = create_access_token({"sub": user["username"]})
    return {"access_token": token, "token_type": "bearer"}

@app.get("/me", response_model=User)
def me(current_user: dict = Depends(get_current_user)):
    return {"username": current_user["username"]}
