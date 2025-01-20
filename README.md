# Distributed Threshold Signing Network (DTS)

## Overview
DTS is a secure and decentralized threshold signing network implemented on the Stacks blockchain using Clarity smart contracts. The system enables distributed signing operations using a t-of-n threshold signature scheme with dynamic signer rotation, robust reputation-based governance, and comprehensive security measures.

## Technical Architecture

### Core Components

1. **Signature Management**
   - BLS threshold signature scheme (t-of-n)
   - Partial signature submission and verification
   - Signature aggregation mechanism
   - Configurable threshold parameters

2. **Node Types**
   - Primary Signers: Active validators with stake
   - Backup Signers: Ready for rotation
   - Watchtowers: Network monitors

3. **Security Features**
   - Stake-based participation
   - Slashing conditions
   - Multi-signature verification
   - Initialization protection
   - Emergency controls

### Data Structures

```clarity
;; Signer Node
{
    stake: uint,
    public-key: (buff 65),
    reputation-score: uint,
    last-active: uint,
    performance-metrics: {
        signing-speed: uint,
        uptime: uint,
        stake-duration: uint,
        accuracy: uint,
        total-signatures: uint,
        valid-signatures: uint
    },
    slashing-history: {
        total-slashes: uint,
        last-slash-height: uint,
        slashed-amount: uint
    }
}

;; Watchtower
{
    last-report: uint,
    reports-submitted: uint,
    accuracy-score: uint,
    is-active: bool
}

;; Partial Signature
{
    signature: (buff 96),
    message-hash: (buff 32),
    timestamp: uint
}
```

## Features

### Security Measures
- Minimum stake requirements
- Performance-based rotation
- Slashing for misbehavior
- Watchtower monitoring
- One-time initialization
- Length validation for cryptographic inputs

### Performance Metrics
- Signing speed
- Node uptime
- Stake duration
- Signature accuracy
- Total participation
- Historical performance

### Governance
- Dynamic signer rotation
- Reputation-based selection
- Automated penalties
- Performance thresholds
- Stake-weighted voting

## Getting Started

### Prerequisites
- Clarity CLI
- Stacks blockchain environment
- Node.js and NPM

### Installation
```bash
# Clone repository
git clone https://github.com/yourusername/dts-network.git
cd dts-network

# Install dependencies
npm install

# Deploy contract
clarinet contract deploy
```

### Contract Initialization
```clarity
;; Initialize with default parameters
(contract-call? .dts initialize
    u100000  ;; minimum stake
    u3       ;; required signers
    u5       ;; total signers
    u144     ;; rotation period
    u3       ;; signature threshold
)
```

## Usage Guide

### Register as Signer
```clarity
;; Register new signer
(contract-call? .dts register-signer <public-key>)
```

### Submit Signature
```clarity
;; Submit partial signature
(contract-call? .dts submit-partial-signature
    <message-hash>
    <signature>
)
```

### Monitor Network
```clarity
;; Register as watchtower
(contract-call? .dts register-watchtower)

;; Submit monitoring report
(contract-call? .dts submit-watchtower-report
    <signer>
    <uptime>
    <signing-speed>
    <valid-signatures>
)
```

## Error Handling

### Error Codes
```clarity
ERR-UNAUTHORIZED (err u100)
ERR-INVALID-PARAMS (err u101)
ERR-INSUFFICIENT-STAKE (err u102)
ERR-INVALID-SIGNATURE (err u103)
ERR-INVALID-THRESHOLD (err u104)
ERR-WATCHTOWER-EXISTS (err u105)
ERR-NOT-ACTIVE-SIGNER (err u106)
ERR-ALREADY-REGISTERED (err u107)
ERR-INVALID-METRICS (err u108)
ERR-INVALID-SIGNATURE-LENGTH (err u109)
ERR-INVALID-KEY-LENGTH (err u110)
ERR-ALREADY-INITIALIZED (err u111)
```

## Development Roadmap

### Phase 1 (Completed)
- Basic contract structure
- Core data structures
- Initial security measures

### Phase 2 (Current)
- Enhanced signature validation
- Improved type safety
- Robust error handling
- Initialization protection
- Map structure improvements

### Phase 3 (Planned)
- Advanced governance features
- Performance optimization
- Enhanced security measures
- Cross-chain integration
- Event system implementation

## Testing

### Unit Tests
```bash
# Run test suite
clarinet test

# Run specific test
clarinet test tests/dts_test.ts
```

### Security Considerations
- Regular security audits
- Formal verification
- Penetration testing
- Stress testing
- Performance benchmarking

## Contributing
Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License
This project is licensed under the MIT License.
