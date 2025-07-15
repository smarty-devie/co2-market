# CO2 Market - Carbon Credit Trading Smart Contract

A comprehensive smart contract for trading verified carbon offset certificates on the Stacks blockchain, built with Clarity.

## Overview

The CO2 Market contract enables the creation, verification, and trading of carbon offset certificates in a decentralized marketplace. It provides a transparent and secure platform for carbon credit transactions with built-in verification mechanisms and automated fee collection.

## Features

### 🌱 Certificate Management
- Issue new carbon offset certificates with detailed project information
- Track CO2 offset amounts in tons
- Support for various verification standards (VCS, Gold Standard, etc.)
- Immutable certificate history and provenance

### 🔍 Verification System
- Authorized verifier network for certificate validation
- Only verified certificates can be traded
- Transparent verification status tracking

### 🏪 Marketplace
- List certificates for sale with flexible pricing
- Purchase credits directly from sellers
- Automatic quantity management
- Real-time marketplace listings

### 💰 Fee Structure
- Platform fee collection (default 2.5%)
- Automatic fee distribution
- Configurable fee rates (admin only)

### ♻️ Credit Retirement
- Retire credits to claim carbon offsets
- Prevent double-spending of retired credits
- Permanent retirement tracking

## Contract Structure

### Data Maps
- `certificates`: Core certificate data and metadata
- `certificate-balances`: User balances for each certificate
- `marketplace-listings`: Active marketplace listings
- `verifiers`: Authorized verifier addresses

### Key Functions

#### Certificate Operations
```clarity
(issue-certificate project-name co2-amount verification-standard)
(verify-certificate certificate-id)
(retire-credits certificate-id quantity)
```

#### Trading Operations
```clarity
(list-for-sale certificate-id price-per-ton quantity)
(purchase-credits certificate-id quantity)
(cancel-listing certificate-id)
```

#### Admin Operations
```clarity
(add-verifier verifier-address)
(remove-verifier verifier-address)
(set-platform-fee new-fee)
```

## Getting Started

### Prerequisites
- Stacks wallet (Hiro Wallet, Xverse, etc.)
- STX tokens for transaction fees
- Clarity development environment (optional for testing)

### Deployment

1. **Deploy the contract** to the Stacks blockchain
2. **Add authorized verifiers** using the `add-verifier` function
3. **Configure platform fees** if needed using `set-platform-fee`

### Usage Examples

#### For Certificate Issuers
```clarity
;; Issue a new certificate
(contract-call? .co2-market issue-certificate 
  "Solar Farm Project Alpha" 
  u1000 
  "VCS")
```

#### For Verifiers
```clarity
;; Verify a certificate
(contract-call? .co2-market verify-certificate u1)
```

#### For Traders
```clarity
;; List credits for sale
(contract-call? .co2-market list-for-sale u1 u50000000 u100)

;; Purchase credits
(contract-call? .co2-market purchase-credits u1 u50)
```

#### For End Users
```clarity
;; Retire credits to claim offsets
(contract-call? .co2-market retire-credits u1 u10)
```

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | err-owner-only | Function restricted to contract owner |
| u101 | err-not-found | Certificate or listing not found |
| u102 | err-insufficient-balance | Insufficient certificate balance |
| u103 | err-invalid-amount | Invalid amount specified |
| u104 | err-not-verified | Certificate not verified |
| u105 | err-already-exists | Resource already exists |
| u106 | err-unauthorized | Unauthorized access |

## Security Features

### Access Controls
- Owner-only functions for critical operations
- Verifier authorization system
- Balance validation for all transfers

### Data Integrity
- Immutable certificate records
- Transparent ownership tracking
- Atomic transaction processing

### Economic Security
- Platform fee collection
- Automatic price calculation
- Overflow protection

## Read-Only Functions

Query contract state without transaction costs:

```clarity
(get-certificate certificate-id)
(get-balance owner certificate-id)
(get-listing certificate-id)
(is-verifier verifier-address)
(get-next-certificate-id)
(get-platform-fee)
```

## Fee Structure

- **Platform Fee**: 2.5% of transaction value (configurable)
- **Maximum Fee**: 10% (hardcoded limit)
- **Fee Collection**: Automatic during purchases
- **Fee Recipient**: Contract owner

## Verification Standards

The contract supports various verification standards including:
- Verified Carbon Standard (VCS)
- Gold Standard
- Climate Action Reserve (CAR)
- American Carbon Registry (ACR)
- Custom standards (up to 50 characters)

## Best Practices

### For Certificate Issuers
- Provide detailed project names and descriptions
- Use recognized verification standards
- Ensure accurate CO2 amount calculations
- Maintain proper documentation

### For Verifiers
- Thoroughly validate project documentation
- Verify CO2 calculation methodologies
- Ensure compliance with standards
- Maintain verification records

### For Traders
- Verify certificate authenticity before purchase
- Check verifier credibility
- Review project details and standards
- Consider market prices and fees

## Limitations

- Maximum project name length: 100 characters
- Maximum verification standard length: 50 characters
- Platform fee cap: 10%
- No fractional tons (minimum 1 ton units)

## Development

### Testing
Use the Clarinet testing framework for local development:

```bash
clarinet test
```

### Deployment
Deploy to testnet first for testing:

```bash
clarinet deploy --testnet
```
