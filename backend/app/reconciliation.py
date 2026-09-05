from sqlalchemy.orm import Session
from . import models, schemas, crypto
import datetime

def process_sync_transactions(db: Session, sync_req: schemas.SyncRequest) -> schemas.SyncResponse:
    """
    Process batch of offline transactions uploaded by syncing devices.
    Executes sequence verification, cryptographic signature checks,
    and ledger reconciliation. Detects double-spends.
    """
    # Sort transactions chronologically to process sequence numbers in order
    sorted_txs = sorted(sync_req.transactions, key=lambda tx: (tx.voucher_id, tx.sequence_number, tx.timestamp))
    
    reconciled_count = 0
    failed_count = 0
    details = []

    for tx in sorted_txs:
        status = "SETTLED"
        error_msg = None
        fraud_flag = False

        # 1. Fetch Sender Wallet & Public Key
        sender_wallet = db.query(models.Wallet).filter(models.Wallet.id == tx.sender_wallet_id).first()
        if not sender_wallet:
            failed_count += 1
            details.append(schemas.TransactionDetail(
                sequence_number=tx.sequence_number,
                sender=tx.sender_wallet_id,
                receiver=tx.receiver_wallet_id,
                amount=tx.amount,
                status="REJECTED",
                error_message="Sender wallet not registered"
            ))
            continue

        # 2. Fetch Voucher
        voucher = db.query(models.Voucher).filter(models.Voucher.id == tx.voucher_id).first()
        if not voucher:
            failed_count += 1
            details.append(schemas.TransactionDetail(
                sequence_number=tx.sequence_number,
                sender=tx.sender_wallet_id,
                receiver=tx.receiver_wallet_id,
                amount=tx.amount,
                status="REJECTED",
                error_message="Invalid Voucher ID"
            ))
            continue

        # 3. Verify Sender's Signature on the Transaction
        # Format payload precisely: voucher_id:sender_id:receiver_id:amount:seq_no:timestamp_iso
        # Use ISO format for timestamp
        timestamp_str = tx.timestamp.isoformat()
        payload = f"{tx.voucher_id}:{tx.sender_wallet_id}:{tx.receiver_wallet_id}:{tx.amount:.2f}:{tx.sequence_number}:{timestamp_str}"
        
        is_sig_valid = crypto.verify_device_signature(
            public_key_hex=sender_wallet.public_key,
            payload_str=payload,
            signature_hex=tx.signature
        )

        if not is_sig_valid:
            failed_count += 1
            details.append(schemas.TransactionDetail(
                sequence_number=tx.sequence_number,
                sender=tx.sender_wallet_id,
                receiver=tx.receiver_wallet_id,
                amount=tx.amount,
                status="REJECTED",
                error_message="Cryptographic signature verification failed"
            ))
            continue

        # 4. Check for Double-Spend / Sequence Replays
        # If sequence number has already been settled for this voucher
        existing_tx = db.query(models.TransactionLedger).filter(
            models.TransactionLedger.voucher_id == tx.voucher_id,
            models.TransactionLedger.sequence_number == tx.sequence_number
        ).first()

        if existing_tx:
            status = "DUPLICATE" if existing_tx.signature == tx.signature else "CONFLICT"
            fraud_flag = True
            error_msg = "Double spend detected: sequence number already used"
            failed_count += 1
        elif tx.sequence_number <= voucher.last_settled_seq:
            status = "CONFLICT"
            fraud_flag = True
            error_msg = f"Sequence rollback: transaction sequence {tx.sequence_number} is below last settled {voucher.last_settled_seq}"
            failed_count += 1
        elif tx.amount > voucher.remaining_balance:
            status = "REJECTED"
            fraud_flag = True
            error_msg = f"Insufficient voucher balance: offline transaction of {tx.amount} exceeds voucher balance {voucher.remaining_balance}"
            failed_count += 1
        elif tx.amount > voucher.max_offline_transaction:
            status = "REJECTED"
            fraud_flag = True
            error_msg = f"Transaction amount {tx.amount} exceeds offline risk limit of {voucher.max_offline_transaction}"
            failed_count += 1
        else:
            # Check transaction count limit
            tx_count = db.query(models.TransactionLedger).filter(models.TransactionLedger.voucher_id == tx.voucher_id).count()
            if tx_count >= voucher.max_transactions_count:
                status = "REJECTED"
                fraud_flag = True
                error_msg = "Maximum number of transactions reached for this voucher"
                failed_count += 1

        # 5. Fetch Receiver Wallet (if not registered, auto-register them for demo convenience)
        receiver_wallet = db.query(models.Wallet).filter(models.Wallet.id == tx.receiver_wallet_id).first()
        if not receiver_wallet:
            # For testing/demo purposes, we can create a dummy receiver wallet
            receiver_wallet = models.Wallet(
                id=tx.receiver_wallet_id,
                public_key="00" * 33,  # Mock public key
                balance=1000.0
            )
            db.add(receiver_wallet)
            db.commit()
            db.refresh(receiver_wallet)

        # 6. Apply to Ledger
        db_tx = models.TransactionLedger(
            voucher_id=tx.voucher_id,
            sender_wallet_id=tx.sender_wallet_id,
            receiver_wallet_id=tx.receiver_wallet_id,
            amount=tx.amount,
            sequence_number=tx.sequence_number,
            timestamp=tx.timestamp,
            signature=tx.signature,
            status=status,
            fraud_flag=fraud_flag
        )
        db.add(db_tx)

        if status == "SETTLED":
            # Update voucher balance and track sequence progress
            voucher.remaining_balance -= tx.amount
            voucher.last_settled_seq = tx.sequence_number

            # Credit the receiver wallet online balance
            receiver_wallet.balance += tx.amount
            reconciled_count += 1
        else:
            # Lock the voucher if fraud is detected
            voucher.is_active = False

        db.commit()

        details.append(schemas.TransactionDetail(
            sequence_number=tx.sequence_number,
            sender=tx.sender_wallet_id,
            receiver=tx.receiver_wallet_id,
            amount=tx.amount,
            status=status,
            error_message=error_msg
        ))

    overall_status = "SUCCESS" if failed_count == 0 else "PARTIAL_SUCCESS" if reconciled_count > 0 else "FAILED"
    return schemas.SyncResponse(
        status=overall_status,
        reconciled_count=reconciled_count,
        failed_count=failed_count,
        details=details
    )
