"""widen content_items.subtitle from varchar(1000) to text

Revision ID: 20250310000001
Revises: 20250310000000
Create Date: 2025-03-10 00:01:00
"""
from alembic import op
import sqlalchemy as sa

revision = "20250310000001"
down_revision = "20250310000000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "content_items",
        "subtitle",
        type_=sa.Text(),
        existing_type=sa.String(1000),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "content_items",
        "subtitle",
        type_=sa.String(1000),
        existing_type=sa.Text(),
        existing_nullable=True,
    )
