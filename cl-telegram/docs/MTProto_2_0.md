# MTProto 2.0 Protocol Documentation

## Overview

MTProto 2.0 is Telegram's custom transport and encryption protocol. This document describes the implementation in cl-telegram.

## Protocol Layers

```
┌─────────────────────────────────────┐
│      Application Layer (TDLib)      │
├─────────────────────────────────────┤
│      RPC / Message Layer            │
├─────────────────────────────────────┤
│      MTProto Encryption             │
├─────────────────────────────────────┤
│      TCP Transport                  │
└─────────────────────────────────────┘
```

## Encryption

### AES-256 IGE Mode

MTProto 2.0 uses AES-256 in IGE (Infinite Garble Extension) mode, which is **not** the same as CBC or CTR mode.

**IGE Formula:**
```
C[i] = AES(P[i] XOR C[i-1], K) XOR P[i-1]
P[i] = AES^-1(C[i] XOR P[i-1], K) XOR C[i-1]
```

Where:
- P[-1] = IV1 (first 16 bytes of derived IV)
- C[-1] = IV2 (second 16 bytes of derived IV)

### Key Derivation

```
msg_key = SHA256(auth_key + message)[0:16]
aes_key, iv = KDF(auth_key, msg_key)
```

The KDF produces:
- 32-byte AES key
- 32-byte IV (split into two 16-byte halves for IGE)

## Authentication Flow

### Step 1: req_pq_multi

```tl
req_pq_multi#be7e8ef1 nonce:int128 = ResPQ
```

Client sends random 128-bit nonce.

### Step 2: resPQ Response

```tl
resPQ#05162463 nonce:int128 server_nonce:int128 
           pq:string server_public_key_fingerprints:Vector<long> = ResPQ
```

Server responds with:
- Original nonce
- Server nonce (128-bit)
- PQ factorization problem (as bytes)
- List of known server public key fingerprints

### Step 3: Factorize PQ

Client factorizes PQ into P and Q primes. For MTProto, PQ is intentionally small enough for this.

### Step 4: req_DH_params

```tl
req_DH_params#d712e4be nonce:int128 server_nonce:int128 
             p:string q:string public_key_fingerprint:long 
             encrypted_data:string = Server_DH_Params
```

Client sends:
- Both nonces
- P and Q factors
- Selected public key fingerprint
- Encrypted `p_q_inner_data`

### Step 5: server_DH_inner_data

```tl
server_DH_inner_data#b5890dba nonce:int128 server_nonce:int128 
                        g:int dh_prime:string g_a:string server_time:int
```

Server responds with DH parameters.

### Step 6: set_client_DH_params

```tl
set_client_DH_params#f5045f1f nonce:int128 server_nonce:int128 
                        encrypted_data:string = Set_client_DH_params_answer
```

Client sends `client_DH_inner_data` with g_b.

### Step 7: dh_gen_ok

```tl
dh_gen_ok#3bcbf734 nonce:int128 server_nonce:int128 
           new_nonce_hash1:int128 = Set_client_DH_params_answer
```

Server confirms key generation.

### Step 8: Compute auth_key

```
auth_key = SHA256(nonce + server_nonce + new_nonce)
```

## Message Format

### Transport Packet

```
+----------------+----------------+------------------+
|  auth_key_id   |    msg_key     |  encrypted_data  |
|   8 bytes      |   16 bytes     |  variable        |
+----------------+----------------+------------------+
```

### Encrypted Message Structure

After decryption:
```
+-------------+-------------+------------+----------+
|   msg_id    |    seqno    |   length   |  body    |
|  8 bytes    |   4 bytes   |  4 bytes   | variable |
+-------------+-------------+------------+----------+
```

## Security Considerations

1. **Authorization Key**: The auth_key is the master secret. If compromised, all communications can be decrypted.

2. **Forward Secrecy**: Cloud chats do NOT have forward secrecy. Secret Chats (end-to-end) provide forward secrecy.

3. **Key Rotation**: auth_key should be periodically rotated for security.

## References

- [Official MTProto 2.0 Spec](https://core.telegram.org/mtproto)
- [Detailed Protocol](https://core.telegram.org/mtproto/description)
- [Formal Verification](https://github.com/miculan/telegram-mtproto2-verification)
