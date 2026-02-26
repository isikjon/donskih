"""add url and description to content_sub_items

Revision ID: 20250225000002
Revises: 20250225000001
Create Date: 2025-02-25 00:00:02
"""
from alembic import op
import sqlalchemy as sa

revision = "20250225000002"
down_revision = "20250225000001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "content_sub_items",
        sa.Column("description", sa.String(2000), nullable=True),
    )
    op.add_column(
        "content_sub_items",
        sa.Column("url", sa.String(2048), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("content_sub_items", "url")
    op.drop_column("content_sub_items", "description")
