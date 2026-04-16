"""add is_active to content_items

Revision ID: 20250402000000
Revises: 20250326000000
Create Date: 2025-04-02

"""
from alembic import op
import sqlalchemy as sa

revision = "20250402000000"
down_revision = "20250326000000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "content_items",
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
    )


def downgrade() -> None:
    op.drop_column("content_items", "is_active")
