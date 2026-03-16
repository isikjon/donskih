"""add thumbnail_url to content_sub_items

Revision ID: 20250310000002
Revises: 20250310000001
Create Date: 2025-03-10 00:02:00
"""
from alembic import op
import sqlalchemy as sa

revision = "20250310000002"
down_revision = "20250310000001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "content_sub_items",
        sa.Column("thumbnail_url", sa.String(2048), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("content_sub_items", "thumbnail_url")
