"""add video_url and video_thumbnail_url to chat_messages

Revision ID: 20250310000003
Revises: 20250310000002
Create Date: 2025-03-10

"""
from alembic import op
import sqlalchemy as sa

revision = "20250310000003"
down_revision = "20250310000002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("video_url", sa.String(1024), nullable=True),
    )
    op.add_column(
        "chat_messages",
        sa.Column("video_thumbnail_url", sa.String(1024), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("chat_messages", "video_thumbnail_url")
    op.drop_column("chat_messages", "video_url")
