import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import datetime
import uuid
import binascii

from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization

from app.database import Base
from app import models, schemas, crypto, reconciliation

# Setup Test Database (In-Memory SQLite)
TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSessionLocal()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture
def client_keypair():
    """Generate a mock client-side secp256r1 keypair simulating Android Keystore."""
    private_key = ec.generate_private_key(ec.SECP256R1())
    public_key = private_key.public_key()
    
    # Export public key as uncompressed point hex
    pub_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint
    )
    public_key_hex = binascii.hexlify(pub_bytes).decode()
    return private_key, public_key_hex

def sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver_id, amount, sequence_number, timestamp):
    """Simulates Android Keystore signing an offline transaction."""
    timestamp_str = timestamp.isoformat()
    payload = f"{voucher_id}:{sender_id}:{receiver_id}:{amount:.2f}:{sequence_number}:{timestamp_str}"
    
    signature = private_key.sign(
        payload.encode('utf-8'),
        ec.ECDSA(hashes.SHA256())
    )
    return binascii.hexlify(signature).decode()

def test_wallet_registration(db, client_keypair):
    _, public_key_hex = client_keypair
    wallet_id = "test_wallet@transact"
    
    wallet = models.Wallet(id=wallet_id, public_key=public_key_hex, balance=10000.0)
    db.add(wallet)
    db.commit()
    
    fetched = db.query(models.Wallet).filter(models.Wallet.id == wallet_id).first()
    assert fetched is not None
    assert fetched.id == wallet_id
    assert fetched.public_key == public_key_hex
    assert fetched.balance == 10000.0

def test_voucher_issuance_and_verification(db):
    wallet_id = "test_wallet@transact"
    voucher_id = str(uuid.uuid4())
    amount = 1000.0
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    expiry_timestamp = int(expiry.timestamp())
    
    # Generate Server Signature
    signature = crypto.sign_voucher(
        voucher_id=voucher_id,
        wallet_id=wallet_id,
        amount=amount,
        expiry_timestamp=expiry_timestamp
    )
    
    # Verify Signature
    is_valid = crypto.verify_voucher_signature(
        voucher_id=voucher_id,
        wallet_id=wallet_id,
        amount=amount,
        expiry_timestamp=expiry_timestamp,
        signature_hex=signature
    )
    assert is_valid is True

def test_successful_reconciliation(db, client_keypair):
    private_key, public_key_hex = client_keypair
    sender_id = "sender@transact"
    receiver_id = "receiver@transact"
    
    # Setup Wallets
    sender = models.Wallet(id=sender_id, public_key=public_key_hex, balance=5000.0)
    receiver = models.Wallet(id=receiver_id, public_key="mock_receiver_pubkey", balance=1000.0)
    db.add(sender)
    db.add(receiver)
    
    # Setup Voucher
    voucher_id = str(uuid.uuid4())
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    voucher = models.Voucher(
        id=voucher_id,
        wallet_id=sender_id,
        amount=2000.0,
        remaining_balance=2000.0,
        max_offline_transaction=200.0,
        expiry=expiry,
        signature="mock_sig",
        is_active=True
    )
    db.add(voucher)
    db.commit()

    # Create two sequential offline transactions within the ₹200 cap
    now = datetime.datetime.utcnow()
    
    # Transaction 1: ₹150, seq = 1
    sig1 = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver_id, 150.0, 1, now)
    tx1 = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver_id,
        amount=150.0,
        sequence_number=1,
        timestamp=now,
        signature=sig1
    )
    
    # Transaction 2: ₹50, seq = 2
    sig2 = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver_id, 50.0, 2, now)
    tx2 = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver_id,
        amount=50.0,
        sequence_number=2,
        timestamp=now,
        signature=sig2
    )

    sync_req = schemas.SyncRequest(transactions=[tx1, tx2])
    
    # Process sync
    response = reconciliation.process_sync_transactions(db, sync_req)
    
    assert response.status == "SUCCESS"
    assert response.reconciled_count == 2
    assert response.failed_count == 0
    assert response.details[0].status == "SETTLED"
    assert response.details[1].status == "SETTLED"
    
    # Validate final database states
    db.refresh(voucher)
    assert voucher.remaining_balance == 1800.0  # 2000 - 150 - 50
    assert voucher.last_settled_seq == 2
    
    db.refresh(receiver)
    assert receiver.balance == 1200.0  # Initial 1000 + 200

def test_double_spend_replay_detection(db, client_keypair):
    private_key, public_key_hex = client_keypair
    sender_id = "sender@transact"
    receiver1_id = "receiver1@transact"
    receiver2_id = "receiver2@transact"
    
    # Setup sender
    sender = models.Wallet(id=sender_id, public_key=public_key_hex, balance=5000.0)
    db.add(sender)
    
    # Setup voucher
    voucher_id = str(uuid.uuid4())
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    voucher = models.Voucher(
        id=voucher_id,
        wallet_id=sender_id,
        amount=1000.0,
        remaining_balance=1000.0,
        max_offline_transaction=200.0,
        expiry=expiry,
        signature="mock_sig",
        is_active=True
    )
    db.add(voucher)
    db.commit()

    now = datetime.datetime.utcnow()
    
    # Transaction 1: Pay receiver1 ₹100, seq = 1
    sig1 = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver1_id, 100.0, 1, now)
    tx1 = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver1_id,
        amount=100.0,
        sequence_number=1,
        timestamp=now,
        signature=sig1
    )
    
    # Transaction 2 (Double Spend): Replay seq = 1 to receiver2 for ₹100
    sig2 = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver2_id, 100.0, 1, now)
    tx2 = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver2_id,
        amount=100.0,
        sequence_number=1,
        timestamp=now,
        signature=sig2
    )

    sync_req = schemas.SyncRequest(transactions=[tx1, tx2])
    response = reconciliation.process_sync_transactions(db, sync_req)
    
    # Expect the first one to settle, but second to fail as duplicate
    assert response.reconciled_count == 1
    assert response.failed_count == 1
    assert response.details[0].status == "SETTLED"
    assert response.details[1].status in ["DUPLICATE", "CONFLICT"]
    assert "Double spend detected" in response.details[1].error_message
    
    # Check that voucher has been marked inactive due to fraud detection
    db.refresh(voucher)
    assert voucher.is_active is False
    assert voucher.remaining_balance == 900.0

def test_sequence_rollback_detection(db, client_keypair):
    private_key, public_key_hex = client_keypair
    sender_id = "sender@transact"
    receiver_id = "receiver@transact"
    
    # Setup
    sender = models.Wallet(id=sender_id, public_key=public_key_hex, balance=5000.0)
    db.add(sender)
    
    voucher_id = str(uuid.uuid4())
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    voucher = models.Voucher(
        id=voucher_id,
        wallet_id=sender_id,
        amount=1000.0,
        remaining_balance=1000.0,
        max_offline_transaction=200.0,
        expiry=expiry,
        signature="mock_sig",
        is_active=True,
        last_settled_seq=3  # Settled up to seq 3 online previously
    )
    db.add(voucher)
    db.commit()

    now = datetime.datetime.utcnow()
    
    # Transaction with seq = 2 (rollback attempt)
    sig = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver_id, 100.0, 2, now)
    tx = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver_id,
        amount=100.0,
        sequence_number=2,
        timestamp=now,
        signature=sig
    )

    sync_req = schemas.SyncRequest(transactions=[tx])
    response = reconciliation.process_sync_transactions(db, sync_req)
    
    assert response.reconciled_count == 0
    assert response.failed_count == 1
    assert response.details[0].status == "CONFLICT"
    assert "Sequence rollback" in response.details[0].error_message

def test_insufficient_voucher_balance(db, client_keypair):
    private_key, public_key_hex = client_keypair
    sender_id = "sender@transact"
    receiver_id = "receiver@transact"
    
    # Setup
    sender = models.Wallet(id=sender_id, public_key=public_key_hex, balance=5000.0)
    db.add(sender)
    
    voucher_id = str(uuid.uuid4())
    expiry = datetime.datetime.utcnow() + datetime.timedelta(days=7)
    voucher = models.Voucher(
        id=voucher_id,
        wallet_id=sender_id,
        amount=50.0,  # Only ₹50 left
        remaining_balance=50.0,
        max_offline_transaction=200.0,
        expiry=expiry,
        signature="mock_sig",
        is_active=True
    )
    db.add(voucher)
    db.commit()

    now = datetime.datetime.utcnow()
    
    # Transaction with ₹150 (exceeds balance)
    sig = sign_transaction_with_client_key(private_key, voucher_id, sender_id, receiver_id, 150.0, 1, now)
    tx = schemas.OfflineTransaction(
        voucher_id=voucher_id,
        sender_wallet_id=sender_id,
        receiver_wallet_id=receiver_id,
        amount=150.0,
        sequence_number=1,
        timestamp=now,
        signature=sig
    )

    sync_req = schemas.SyncRequest(transactions=[tx])
    response = reconciliation.process_sync_transactions(db, sync_req)
    
    assert response.reconciled_count == 0
    assert response.failed_count == 1
    assert response.details[0].status == "REJECTED"
    assert "Insufficient voucher balance" in response.details[0].error_message
