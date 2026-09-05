from sqlalchemy import Column, String, Float, Integer, DateTime, Boolean, ForeignKey
from sqlalchemy.orm import relationship
import datetime
from .database import Base

class Wallet(Base):
    __tablename__ = "wallets"

    id = Column(String, primary_key=True, index=True)  # E.g., phone number or UPI ID: "9999999999@transact"
    public_key = Column(String, nullable=False)        # PEM or HEX public key of the device (ECDSA secp256r1)
    balance = Column(Float, default=10000.0)           # Initial mock balance (₹10,000 for demonstration)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    vouchers = relationship("Voucher", back_populates="wallet")

class Voucher(Base):
    __tablename__ = "vouchers"

    id = Column(String, primary_key=True, index=True)
    wallet_id = Column(String, ForeignKey("wallets.id"), nullable=False)
    amount = Column(Float, nullable=False)
    remaining_balance = Column(Float, nullable=False)
    
    # Risk Limits
    max_offline_transaction = Column(Float, default=200.0)
    max_cumulative_spending = Column(Float, default=1000.0)
    max_transactions_count = Column(Integer, default=10)
    
    expiry = Column(DateTime, nullable=False)
    last_settled_seq = Column(Integer, default=0)       # Tracks max sequence number successfully reconciled
    signature = Column(String, nullable=False)          # Backend signature validating the voucher
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    wallet = relationship("Wallet", back_populates="vouchers")
    transactions = relationship("TransactionLedger", back_populates="voucher")

class TransactionLedger(Base):
    __tablename__ = "transaction_ledger"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    voucher_id = Column(String, ForeignKey("vouchers.id"), nullable=False)
    sender_wallet_id = Column(String, nullable=False)
    receiver_wallet_id = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    sequence_number = Column(Integer, nullable=False)    # Signed monotonic counter
    timestamp = Column(DateTime, nullable=False)         # Signed transaction time
    signature = Column(String, nullable=False)           # Sender's cryptographic signature
    reconciled_at = Column(DateTime, default=datetime.datetime.utcnow)
    status = Column(String, default="SETTLED")           # SETTLED, REJECTED, DOUBLE_SPEND_FAILED
    fraud_flag = Column(Boolean, default=False)          # Flagged by ML / rule engine

    voucher = relationship("Voucher", back_populates="transactions")
