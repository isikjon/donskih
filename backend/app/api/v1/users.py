from fastapi import APIRouter, Depends

from app.models.user import User
from app.schemas.user import UserOut
from app.security.jwt import get_current_user

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserOut)
async def get_me(user: User = Depends(get_current_user)):
    """Return the current authenticated user's profile."""
    return user
