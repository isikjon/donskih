"""add reply_to_message_id to chat_messages

Revision ID: 20250225000004
Revises: 20250225000003
Create Date: 2025-02-25

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "20250225000004"
down_revision = "20250225000003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column(
            "reply_to_message_id",
            postgresql.UUID(as_uuid=True),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_chat_messages_reply_to_message_id",
        "chat_messages",
        ["reply_to_message_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_chat_messages_reply_to_message_id", table_name="chat_messages")
    op.drop_column("chat_messages", "reply_to_message_id")
