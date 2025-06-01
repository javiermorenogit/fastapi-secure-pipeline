from pydantic import BaseModel

class User(BaseModel):
    username: str

class Token(BaseModel):
    access_token: str
    token_type: str
