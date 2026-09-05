from fastapi import FastAPI, Depends, HTTPException, status
from sqlalchemy.orm import Session
import uuid
import datetime
from typing import List

from .database import engine, Base, get_db
from . import models, schemas, crypto, reconciliation

# Initialize SQLite database tables
Base.metadata.create_all(bind=engine)

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Transact Offline UPI Backend",
    description="Secure, production-grade offline payment reconciliation backend service.",
    version="1.0.0"
)

# Enable CORS for Flutter web / local client debugging
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/public-key")
def get_public_key():
    """Retrieve the server public key for verifying voucher signatures on mobile."""
    return {"public_key": crypto.get_server_public_key_hex()}

@app.post("/api/wallets/register", response_model=schemas.WalletResponse, status_code=status.HTTP_201_CREATED)
def register_wallet(wallet: schemas.WalletRegister, db: Session = Depends(get_db)):
    """Register a mobile device public key under a unique wallet ID (UPI ID or Phone number)."""
    db_wallet = db.query(models.Wallet).filter(models.Wallet.id == wallet.id).first()
    if db_wallet:
        # For ease of testing and demoing, let's allow updating the public key if the wallet already exists
        db_wallet.public_key = wallet.public_key
        db.commit()
        db.refresh(db_wallet)
        return db_wallet

    db_wallet = models.Wallet(id=wallet.id, public_key=wallet.public_key)
    db.add(db_wallet)
    db.commit()
    db.refresh(db_wallet)
    return db_wallet

@app.get("/api/wallets/{wallet_id}", response_model=schemas.WalletResponse)
def get_wallet(wallet_id: str, db: Session = Depends(get_db)):
    """Retrieve details for a specific wallet."""
    db_wallet = db.query(models.Wallet).filter(models.Wallet.id == wallet_id).first()
    if not db_wallet:
        raise HTTPException(status_code=404, detail="Wallet not found")
    return db_wallet

@app.post("/api/vouchers/issue", response_model=schemas.VoucherResponse)
def issue_voucher(req: schemas.VoucherIssueRequest, db: Session = Depends(get_db)):
    """
    Issue a cryptographically signed voucher for offline use.
    Deducts the voucher amount from the user's online bank ledger balance.
    """
    wallet = db.query(models.Wallet).filter(models.Wallet.id == req.wallet_id).first()
    if not wallet:
        raise HTTPException(status_code=404, detail="Wallet not registered")
    
    if wallet.balance < req.amount:
        raise HTTPException(status_code=400, detail="Insufficient online ledger balance to issue voucher")

    # Lock the funds from the online wallet ledger balance
    wallet.balance -= req.amount
    
    voucher_id = str(uuid.uuid4())
    # Voucher expires in 7 days
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    expiry_timestamp = int(expiry.timestamp())

    # Generate server cryptographic signature
    signature = crypto.sign_voucher(
        voucher_id=voucher_id,
        wallet_id=req.wallet_id,
        amount=req.amount,
        expiry_timestamp=expiry_timestamp
    )

    db_voucher = models.Voucher(
        id=voucher_id,
        wallet_id=req.wallet_id,
        amount=req.amount,
        remaining_balance=req.amount,
        max_offline_transaction=min(200.0, req.amount),
        max_cumulative_spending=req.amount,
        max_transactions_count=10,
        expiry=expiry,
        signature=signature,
        is_active=True
    )
    
    db.add(db_voucher)
    db.commit()
    db.refresh(db_voucher)
    return db_voucher

@app.get("/api/vouchers/active/{wallet_id}", response_model=List[schemas.VoucherResponse])
def get_active_vouchers(wallet_id: str, db: Session = Depends(get_db)):
    """Fetch all active, valid vouchers for a specific wallet."""
    now = datetime.datetime.utcnow()
    vouchers = db.query(models.Voucher).filter(
        models.Voucher.wallet_id == wallet_id,
        models.Voucher.is_active == True,
        models.Voucher.expiry > now
    ).all()
    return vouchers

@app.post("/api/sync", response_model=schemas.SyncResponse)
def sync_transactions(sync_req: schemas.SyncRequest, db: Session = Depends(get_db)):
    """
    Sync offline transaction logs uploaded by clients.
    Reconciles balances and catches double-spend attempts.
    """
    return reconciliation.process_sync_transactions(db, sync_req)

@app.get("/api/transactions", response_model=List[schemas.LedgerEntryResponse])
def get_all_transactions(db: Session = Depends(get_db)):
    """Retrieve all reconciled transactions from the ledger."""
    return db.query(models.TransactionLedger).order_by(models.TransactionLedger.id.desc()).all()

@app.get("/api/transactions/wallet/{wallet_id}", response_model=List[schemas.LedgerEntryResponse])
def get_wallet_transactions(wallet_id: str, db: Session = Depends(get_db)):
    """Retrieve all reconciled transactions involving a specific wallet."""
    return db.query(models.TransactionLedger).filter(
        (models.TransactionLedger.sender_wallet_id == wallet_id) |
        (models.TransactionLedger.receiver_wallet_id == wallet_id)
    ).order_by(models.TransactionLedger.id.desc()).all()

@app.get("/api/fraud-dashboard", response_model=schemas.FraudDashboardResponse)
def get_fraud_dashboard(db: Session = Depends(get_db)):
    """Retrieve fraud analytics and all flagged double-spend/conflict transactions."""
    total = db.query(models.TransactionLedger).count()
    settled = db.query(models.TransactionLedger).filter(models.TransactionLedger.status == "SETTLED").count()
    fraud = db.query(models.TransactionLedger).filter(models.TransactionLedger.fraud_flag == True).count()
    conflict = db.query(models.TransactionLedger).filter(models.TransactionLedger.status == "CONFLICT").count()
    duplicate = db.query(models.TransactionLedger).filter(models.TransactionLedger.status == "DUPLICATE").count()
    flagged = db.query(models.TransactionLedger).filter(models.TransactionLedger.fraud_flag == True).order_by(models.TransactionLedger.id.desc()).all()

    return schemas.FraudDashboardResponse(
        total_transactions=total,
        settled_count=settled,
        fraud_count=fraud,
        conflict_count=conflict,
        duplicate_count=duplicate,
        flagged_transactions=flagged
    )

@app.post("/api/reset-demo")
def reset_demo(db: Session = Depends(get_db)):
    """Reset database tables for a fresh demonstration run."""
    db.query(models.TransactionLedger).delete()
    db.query(models.Voucher).delete()
    # Reset wallet balances to 10,000
    wallets = db.query(models.Wallet).all()
    for w in wallets:
        w.balance = 10000.0
    db.commit()
    return {"status": "Demo reset successful", "wallets_reset": len(wallets)}

