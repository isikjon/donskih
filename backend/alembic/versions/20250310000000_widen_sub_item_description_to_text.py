"""widen content_sub_items.description from varchar(2000) to text

Revision ID: 20250310000000
Revises: 20250225000004
Create Date: 2025-03-10 00:00:00
"""
from alembic import op
import sqlalchemy as sa

revision = "20250310000000"
down_revision = "20250225000004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "content_sub_items",
        "description",
        type_=sa.Text(),
        existing_type=sa.String(2000),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "content_sub_items",
        "description",
        type_=sa.String(2000),
        existing_type=sa.Text(),
        existing_nullable=True,
    )
