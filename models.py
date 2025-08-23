from sqlmodel import SQLModel, Field, UniqueConstraint
from typing import Optional
from datetime import datetime
from uuid import uuid4


class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    email: str = Field(max_length=255, index=True, unique=True)
    username: Optional[str] = Field(default=None, max_length=50, index=True, unique=True)
    password_hash: str = Field(max_length=255)
    role: str = Field(default="user", max_length=50)
    totp_secret: Optional[str] = Field(default=None, max_length=32)
    phrase: str = Field(max_length=255)
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Offer(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    public_id: str = Field(default_factory=lambda: str(uuid4()), index=True, unique=True, max_length=36)
    title: str = Field(max_length=255, index=True)
    desc: str = Field(max_length=2048)
    price_xmr: float = Field(gt=0)
    seller_id: int = Field(default=0, index=True)
    status: str = Field(default="open", index=True, max_length=32)
    timestamp: datetime = Field(default_factory=datetime.utcnow, index=True)


class Transaction(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    offer_id: int = Field(index=True)
    buyer_id: int = Field(default=0, index=True)
    seller_id: int = Field(default=0, index=True)
    amount: float = Field(gt=0)
    status: str = Field(default="pending", index=True, max_length=32)
    tx_hash: str = Field(index=True, unique=True, max_length=64)
    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)


class UserBalance(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int = Field(index=True)
    fake_xmr: float = Field(default=0.0)
    real_xmr: float = Field(default=0.0)
    updated_at: datetime = Field(default_factory=datetime.utcnow, index=True)

    __table_args__ = (
        UniqueConstraint("user_id", name="uq_user_balance_user_id"),
    )


class LedgerTx(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    from_user_id: int = Field(index=True)
    to_user_id: int = Field(index=True)
    amount_xmr: float = Field(gt=0)
    status: str = Field(default="completed", max_length=32, index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow, index=True)
