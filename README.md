# Ceremony-First-Admission# Ceremony-First Admission (CFA)

A practical defense for securing group-admission in end-to-end encrypted (E2EE) messaging.

## What is CFA?

Ceremony-First Admission ensures that a participant is not granted access to a secure group chat until the *human* admission intent has been cryptographically validated. Modern secure messaging (Signal, WhatsApp, MLS-based systems) protects message content, yet still allows accidental or malicious “wrong-person” additions due to reliance on OS-level contacts. CFA fixes this **membership boundary** failure.

This repository contains the **prototype implementation** (Ceremony-Chat) demonstrating CFA’s effectiveness in preventing the **Membership Misbind Attack (MMA)** described in our paper. 

## Key Security Guarantees

| Risk in current E2EE systems | CFA Defense Mechanism |
|----------------------------|----------------------|
| Wrong contact added → full plaintext exposure | Verified Directory prevents activation without explicit identity binding |
| Silent joins unnoticed by users | Pending state with visible endorsement requirement |
| No proof of who authorized membership | Signed, auditable **Admission Proofs** |
| Attack success after one UI mis-tap | Threshold endorsements (t-of-n) eliminate single-point human failure |

CFA enforces an **admission correctness rule**:
A member becomes active only if:

Verified via human binding (QR or SAS), and

Endorsed by ≥ threshold authorized members (t-of-n)


No plaintext ever flows to unverified or insufficiently endorsed identifiers.

## Architecture Overview

**Three-tier deployment:**

- **Flutter Client**: Android, iOS, Web, Desktop
- **Node.js Coordination Service**: enforces ceremony policy & group state
- **Persistent Store**: JSON-based state for users, groups, endorsements

Human-binding checks and Admission Proofs occur entirely at the **application layer**, so no cryptographic protocol (Signal/MLS) changes are required. 


## Running the Prototype

### Backend

```bash
cd server
npm install
npm start
Server defaults to http://localhost:3000

Client (Flutter)
cd client
flutter pub get
flutter run


Choose target: -d chrome, -d android, etc.