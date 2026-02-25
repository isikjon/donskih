from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class ChatMessageOut(BaseModel):
    id: str
    user_id: str
    sender_name: str
    sender_photo_url: str | None
    text: str | None
    image_url: str | None
    is_edited: bool
    is_deleted: bool
    created_at: str

    model_config = {"from_attributes": True}


class SendMessageRequest(BaseModel):
    text: str | None = None
    image_url: str | None = None


class EditMessageRequest(BaseModel):
    text: str


class ImageUploadResponse(BaseModel):
    image_url: str
