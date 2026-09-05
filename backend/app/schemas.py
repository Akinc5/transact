from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional
import datetime

class WalletRegister(BaseModel):
    id: str = Field(..., json_schema_extra={"example": "9999999999@transact"})
    public_key: str = Field(..., description="Hex or PEM encoded public key of the device's Keystore-backed keypair")

class WalletResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    balance: float
    created_at: datetime.datetime

class VoucherIssueRequest(BaseModel):
    wallet_id: str = Field(..., json_schema_extra={"example": "9999999999@transact"})
    amount: float = Field(..., gt=0, le=5000, description="Amount to load, maximum ₹5,000")

class VoucherResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    wallet_id: str
    amount: float
    remaining_balance: float
    max_offline_transaction: float
    max_cumulative_spending: float
    max_transactions_count: int
    expiry: datetime.datetime
    last_settled_seq: int
    signature: str
    is_active: bool

class OfflineTransaction(BaseModel):
    voucher_id: str
    sender_wallet_id: str
    receiver_wallet_id: str
    amount: float
    sequence_number: int
    timestamp: datetime.datetime
    signature: str

class SyncRequest(BaseModel):
    transactions: List[OfflineTransaction]

class TransactionDetail(BaseModel):
    sequence_number: int
    sender: str
    receiver: str
    amount: float
    status: str
    error_message: Optional[str] = None

class SyncResponse(BaseModel):
    status: str
    reconciled_count: int
    failed_count: int
    details: List[TransactionDetail]

class LedgerEntryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    voucher_id: str
    sender_wallet_id: str
    receiver_wallet_id: str
    amount: float
    sequence_number: int
    timestamp: datetime.datetime
    signature: str
    reconciled_at: datetime.datetime
    status: str
    fraud_flag: bool

class FraudDashboardResponse(BaseModel):
    total_transactions: int
    settled_count: int
    fraud_count: int
    conflict_count: int
    duplicate_count: int
    flagged_transactions: List[LedgerEntryResponse]
