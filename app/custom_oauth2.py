from fastapi.openapi.models import OAuthFlows as OAuthFlowsModel, OAuthFlowPassword
from fastapi.security import OAuth2
from typing import Optional
from fastapi import Request
from pydantic import AnyUrl


class OAuth2PasswordBearerWithCookie(OAuth2):
    def __init__(self, tokenUrl: str, refreshUrl: Optional[AnyUrl] = None, scheme_name: Optional[str] = None):
        flows = OAuthFlowsModel(password=OAuthFlowPassword(tokenUrl=tokenUrl, refreshUrl=refreshUrl))
        super().__init__(flows=flows, scheme_name=scheme_name)

    async def __call__(self, request: Request) -> Optional[str]:
        auth = request.headers.get("Authorization")
        if auth and auth.lower().startswith("bearer "):
            return auth[7:]  # Remove "Bearer " prefix
        return None