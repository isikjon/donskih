from datetime import date
from uuid import UUID

from pydantic import BaseModel, Field


class ContentSubItemOut(BaseModel):
    id: UUID
    title: str
    description: str | None = None
    url: str | None = None
    duration: str | None = None
    sort_order: int = 0

    model_config = {"from_attributes": True}


class ContentSubItemIn(BaseModel):
    title: str = Field(..., max_length=500)
    description: str | None = Field(None, max_length=2000)
    url: str | None = Field(None, max_length=2048)
    duration: str | None = Field(None, max_length=20)
    sort_order: int = 0


class ContentItemOut(BaseModel):
    id: UUID
    type: str
    section: str = "main"
    display_date: date
    title: str
    subtitle: str | None = None
    sort_order: int
    url: str | None = None
    sub_items: list[ContentSubItemOut] = []

    model_config = {"from_attributes": True}


class ContentItemCreate(BaseModel):
    type: str = Field(..., pattern="^(video|checklist)$")
    section: str = Field("main", pattern="^(main|base)$")
    display_date: date
    title: str = Field(..., max_length=500)
    subtitle: str | None = Field(None, max_length=1000)
    sort_order: int = 0
    url: str | None = Field(None, max_length=2048)
    sub_items: list[ContentSubItemIn] = []


class ContentItemUpdate(BaseModel):
    section: str | None = Field(None, pattern="^(main|base)$")
    display_date: date | None = None
    title: str | None = Field(None, max_length=500)
    subtitle: str | None = Field(None, max_length=1000)
    sort_order: int | None = None
    url: str | None = Field(None, max_length=2048)
    sub_items: list[ContentSubItemIn] | None = None


def content_item_to_out(item) -> ContentItemOut:
    return ContentItemOut(
        id=item.id,
        type=item.type,
        section=item.section,
        display_date=item.display_date,
        title=item.title,
        subtitle=item.subtitle,
        sort_order=item.sort_order,
        url=item.url,
        sub_items=[
            ContentSubItemOut(
                id=s.id,
                title=s.title,
                description=s.description,
                url=s.url,
                duration=s.duration,
                sort_order=s.sort_order,
            )
            for s in item.sub_items
        ],
    )
