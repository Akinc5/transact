from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.utils import Prehashed
import binascii
import os

SERVER_KEY_PATH = "server_private_key.pem"

def get_or_create_server_key() -> ec.EllipticCurvePrivateKey:
    """Load or generate a secp256r1 private key for signing vouchers."""
    if os.path.exists(SERVER_KEY_PATH):
        with open(SERVER_KEY_PATH, "rb") as key_file:
            private_key = serialization.load_pem_private_key(
                key_file.read(),
                password=None
            )
            return private_key
    else:
        # Generate new secp256r1 key
        private_key = ec.generate_private_key(ec.SECP256R1())
        pem = private_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        )
        with open(SERVER_KEY_PATH, "wb") as key_file:
            key_file.write(pem)
        return private_key

def get_server_public_key_hex() -> str:
    """Get the hex representation of the server's public key for mobile client verification."""
    private_key = get_or_create_server_key()
    public_key = private_key.public_key()
    pub_bytes = public_key.public_bytes(
        encoding=serialization.Encoding.X962,
        format=serialization.PublicFormat.UncompressedPoint
    )
    return binascii.hexlify(pub_bytes).decode()

def sign_voucher(voucher_id: str, wallet_id: str, amount: float, expiry_timestamp: int) -> str:
    """Sign a voucher's parameters using the server's private key."""
    private_key = get_or_create_server_key()
    # Canonical payload format
    payload = f"{voucher_id}:{wallet_id}:{amount:.2f}:{expiry_timestamp}".encode('utf-8')
    signature = private_key.sign(
        payload,
        ec.ECDSA(hashes.SHA256())
    )
    return binascii.hexlify(signature).decode()

def verify_device_signature(public_key_hex: str, payload_str: str, signature_hex: str) -> bool:
    """Verify a client signature using the device's registered public key (secp256r1)."""
    try:
        # Load public key from raw hex (Uncompressed point format)
        pub_bytes = binascii.unhexlify(public_key_hex)
        public_key = ec.EllipticCurvePublicKey.from_encoded_point(ec.SECP256R1(), pub_bytes)
        
        # Decode signature
        signature = binascii.unhexlify(signature_hex)
        
        # Verify
        public_key.verify(
            signature,
            payload_str.encode('utf-8'),
            ec.ECDSA(hashes.SHA256())
        )
        return True
    except Exception as e:
        print(f"Device signature verification failed: {e}")
        return False

def verify_voucher_signature(voucher_id: str, wallet_id: str, amount: float, expiry_timestamp: int, signature_hex: str) -> bool:
    """Verify a voucher's signature using the server's public key (useful for verification tasks)."""
    try:
        private_key = get_or_create_server_key()
        public_key = private_key.public_key()
        
        payload = f"{voucher_id}:{wallet_id}:{amount:.2f}:{expiry_timestamp}".encode('utf-8')
        signature = binascii.unhexlify(signature_hex)
        
        public_key.verify(
            signature,
            payload,
            ec.ECDSA(hashes.SHA256())
        )
        return True
    except Exception as e:
        print(f"Voucher signature verification failed: {e}")
        return False
