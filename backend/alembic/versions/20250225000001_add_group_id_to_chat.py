"""add group_id to chat_messages

Revision ID: 20250225000001
Revises: 20250225000000
Create Date: 2025-02-25

"""
from alembic import op
import sqlalchemy as sa

revision = "20250225000001"
down_revision = "20250225000000"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("group_id", sa.String(36), nullable=True),
    )
    op.create_index(
        "ix_chat_messages_group_id", "chat_messages", ["group_id"]
    )


def downgrade() -> None:
    op.drop_index("ix_chat_messages_group_id", table_name="chat_messages")
    op.drop_column("chat_messages", "group_id")
