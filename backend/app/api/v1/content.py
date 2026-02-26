from collections import defaultdict
from datetime import date

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models.content import ContentItem
from app.schemas.content import ContentItemOut, content_item_to_out
from sqlalchemy.ext.asyncio import AsyncSession

router = APIRouter(prefix="/content", tags=["content"])


@router.get("", response_model=dict[str, list[ContentItemOut]])
async def list_content(
    section: str = "main",
    db: AsyncSession = Depends(get_db),
):
    """
    List content items grouped by display_date.
    section=main (default) — main screen; section=base — library.
    """
    result = await db.execute(
        select(ContentItem)
        .where(ContentItem.section == section)
        .options(selectinload(ContentItem.sub_items))
        .order_by(ContentItem.display_date.asc(), ContentItem.sort_order.asc())
    )
    items = result.scalars().all()
    by_date: dict[str, list[ContentItemOut]] = defaultdict(list)
    for item in items:
        d = item.display_date.isoformat()
        by_date[d].append(content_item_to_out(item))
    return dict(by_date)
