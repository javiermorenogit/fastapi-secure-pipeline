from starlette.requests import Request
from starlette.datastructures import Headers
from starlette.types import Scope
from typing import Optional

# usa el nombre real de la clase
from app.custom_oauth2 import OAuth2PasswordBearerWithCookie as Scheme

oauth_scheme = Scheme(tokenUrl="login")

def build_request(auth_header: Optional[str]) -> Request:
    scope: Scope = {
        "type": "http",
        "headers": Headers({"Authorization": auth_header} if auth_header else {}).raw,
        "method": "GET",
        "path": "/",
    }
    return Request(scope)
