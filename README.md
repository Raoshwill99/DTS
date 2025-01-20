# Distributed Threshold Signing Network (DTS)

## Overview
DTS is a decentralized threshold signing network implemented on the Stacks blockchain using Clarity smart contracts. The system enables secure, distributed signing operations using a t-of-n threshold signature scheme with dynamic signer rotation and reputation-based governance.

## Key Features
- **BLS Threshold Signatures**: Implements t-of-n threshold signatures using BLS signature scheme
- **Dynamic Signer Rotation**: Automatic rotation based on performance metrics and stake
- **Reputation System**: Comprehensive scoring system based on multiple performance metrics
- **Stake-Based Participation**: Minimum stake requirements for network participation
- **Performance Monitoring**: Continuous monitoring of signer performance and reliability

## Network Components
1. **Primary Signers**
   - High-stake validators responsible for signature generation
   - Must maintain minimum stake requirements
   - Subject to performance monitoring and rotation

2. **Backup Signers**
   - Ready to rotate into primary signer positions
   - Must meet same stake and performance requirements
   - Participate in network governance

3. **Watchtowers**
   - Monitor network for malicious behavior
   - Report performance metrics
   - Help maintain network security

## Technical Architecture

### Core Data Structures
```clarity
;; Signer Node Structure
{
    stake: uint,
    public-key: (buff 65),
    reputation-score: uint,
    last-active: uint,
    performance-metrics: {
        signing-speed: uint,
        uptime: uint,
        stake-duration: uint,
        accuracy: uint
    }
}
```

### Performance Metrics
- **Signing Speed**: Response time for signing operations
- **Uptime**: Node availability and reliability
- **Stake Duration**: Length of time stake has been maintained
- **Historical Accuracy**: Accuracy of previous signing operations

## Getting Started

### Prerequisites
- Stacks blockchain development environment
- Clarity CLI tools
- Node.js and NPM (for testing and deployment)

### Installation
1. Clone the repository:
```bash
git clone https://github.com/yourusername/dts-network.git
cd dts-network
```

2. Install dependencies:
```bash
npm install
```

3. Deploy the contract:
```bash
clarinet contract deploy
```

### Contract Initialization
To initialize the contract with default parameters:
```clarity
(contract-call? .dts initialize 
    u100000  ;; minimum stake
    u3       ;; required signers
    u5       ;; total signers
    u144     ;; rotation period
)
```

## Usage

### Register as a Signer
```clarity
(contract-call? .dts register-signer <public-key>)
```

### Update Metrics
```clarity
(contract-call? .dts update-metrics 
    <signer>
    <signing-speed>
    <uptime>
    <accuracy>
)
```

### Check Signer Status
```clarity
(contract-call? .dts get-signer-info <signer>)
```

## Security Considerations
- Minimum stake requirements protect against Sybil attacks
- Performance metrics prevent malicious actors from maintaining positions
- Slashing conditions for proven misbehavior
- Regular rotation prevents centralization of power

## Development Roadmap

### Phase 1 (Current)
- Basic contract structure
- Signer registration and management
- Performance metrics tracking
- Initial reputation system

### Phase 2
- BLS signature scheme implementation
- Enhanced signer rotation logic
- Watchtower implementation
- Advanced reputation scoring

### Phase 3
- Governance mechanisms
- Automated rotation systems
- Enhanced security features
- Network monitoring tools

## Contributing
We welcome contributions! Please see the contributing guidelines for more details.

## License
This project is licensed under the MIT License
