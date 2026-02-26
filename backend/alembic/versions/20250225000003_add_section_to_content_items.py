"""add section to content_items

Revision ID: 20250225000003
Revises: 20250225000002
Create Date: 2025-02-25 00:00:03
"""
from alembic import op
import sqlalchemy as sa

revision = "20250225000003"
down_revision = "20250225000002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "content_items",
        sa.Column(
            "section",
            sa.String(10),
            nullable=False,
            server_default="main",
        ),
    )
    op.create_index(
        "ix_content_items_section", "content_items", ["section"]
    )


def downgrade() -> None:
    op.drop_index("ix_content_items_section", table_name="content_items")
    op.drop_column("content_items", "section")
