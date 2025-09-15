# Compact Distributed Threshold Signing Network

A streamlined threshold signature scheme implemented on the Stacks blockchain. This system enables distributed key management and signature generation with essential functionality and minimal complexity.

## Overview

The Compact Distributed Threshold Signing Network (CDTSN) is a simplified infrastructure for distributed key management and threshold signatures. It uses threshold cryptography to allow a subset of signers to collectively produce cryptographic signatures while maintaining security and fault tolerance.

### What are Threshold Signatures?

Threshold signatures allow a group of participants to collectively generate a single cryptographic signature. With an (n,t) threshold scheme, any t participants out of n total can collaborate to create a valid signature, while fewer than t cannot. This provides both security and fault tolerance.

### Key Benefits

- Decentralized Key Management: No single entity has complete control of cryptographic keys
- Fault Tolerance: System continues operating even if some signers are offline
- Compact Signatures: Produces single signatures regardless of the number of signers
- Simple Governance: Basic parameter management by contract owner
- Performance: Streamlined implementation with minimal overhead

## Architecture

The CDTSN consists of the following core components:

1. **Signer Network**: Nodes that stake tokens and participate in signature generation
2. **Threshold Management**: Configurable signature threshold requirements
3. **Access Control**: Owner-based administration and parameter management
4. **State Management**: Essential data structures for signer and signature tracking

## Features

### Core Features
- Threshold signature generation and verification
- Stake-based signer registration and management
- Configurable signature threshold
- Basic signer rotation capabilities

### Security Features
- Minimum stake requirements
- Active signer validation
- Owner-based access control
- Signature validation mechanisms

### Administrative Features
- Contract owner management
- Threshold parameter updates
- Signer removal capabilities
- System status queries

## Technical Implementation

The CDTSN is implemented as a Clarity smart contract on the Stacks blockchain with simplified data structures and streamlined logic.

### Key Data Structures

- **Signer Management**:
  - `signer-nodes`: Tracks registered signers with stake, public key, and status
  - `active-signers`: Identifies current active signers
  - `partial-signatures`: Stores submitted signatures with timestamps

### System Parameters

The protocol includes essential configurable parameters:
- `min-stake`: Minimum tokens required to become a signer
- `signature-threshold`: Minimum signatures required for verification
- `contract-owner`: Principal with administrative privileges

## Functions

### Initialization
- `initialize`: Set up threshold and minimum stake parameters

### Signer Management
- `register-signer`: Join the network as a signer with stake requirement
- `remove-signer`: Leave the active signer set
- `get-signer-info`: Query signer details and status

### Signature Operations
- `submit-signature`: Submit a partial signature for threshold verification
- `validate-threshold`: Check if sufficient valid signatures have been collected

### Administrative Functions
- `update-threshold`: Modify signature threshold (owner only)
- `set-owner`: Transfer contract ownership
- `get-contract-stats`: Query system statistics

### Query Functions
- `get-threshold-status`: Get current threshold and signature counts
- `get-contract-stats`: Get system overview including owner and parameters

## Installation

To deploy this contract on the Stacks blockchain:

1. Install the Clarinet development environment:
   ```bash
   curl -sS https://get.clarinet.build | sh
   ```

2. Create a new project:
   ```bash
   clarinet new cdtsn-project
   cd cdtsn-project
   ```

3. Replace the default contract with the CDTSN contract:
   ```bash
   cp path/to/cdtsn-contract.clar contracts/cdtsn.clar
   ```

4. Test and deploy:
   ```bash
   clarinet test
   clarinet deploy
   ```

## Usage

### Becoming a Signer

To join the network as a signer:

1. Ensure you have sufficient STX tokens to meet the minimum stake
2. Generate a public key for signature operations
3. Call the register-signer function

```clarity
(contract-call? .cdtsn register-signer 0x[your-public-key])
```

### Submitting a Signature

To participate in signature generation:

1. Generate your partial signature for the current message
2. Submit it to the network

```clarity
(contract-call? .cdtsn submit-signature 0x[your-signature] 0x[message-hash])
```

### Administrative Operations

Contract owner can update parameters:

```clarity
(contract-call? .cdtsn update-threshold u5) ;; Set new threshold
(contract-call? .cdtsn set-owner 'SP1ABC...) ;; Transfer ownership
```

## Security

The CDTSN includes essential security mechanisms:

### Stake Requirements

All signers must maintain a minimum stake to participate in the network, ensuring economic incentive alignment.

### Access Control

Administrative functions are restricted to the contract owner, preventing unauthorized parameter changes.

### Signature Validation

The system validates that signatures come from active signers and match the current message hash before counting them toward the threshold.

### Active Signer Management

Only registered and active signers can submit signatures, with mechanisms to remove inactive or malicious participants.

## Error Handling

The contract defines clear error codes for different failure scenarios:

- `ERR-UNAUTHORIZED`: Caller lacks required permissions
- `ERR-INVALID-PARAMS`: Invalid function parameters
- `ERR-INSUFFICIENT-STAKE`: Stake below minimum requirement
- `ERR-NOT-ACTIVE-SIGNER`: Caller not an active signer
- `ERR-ALREADY-EXISTS`: Signer already registered
- `ERR-THRESHOLD-NOT-REACHED`: Insufficient valid signatures

## Development

### Testing

The contract includes comprehensive validation logic that can be tested using Clarinet:

```bash
clarinet test
```

### Deployment

Deploy to testnet for testing:

```bash
clarinet deploy --testnet
```

Deploy to mainnet:

```bash
clarinet deploy --mainnet
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create your feature branch
3. Commit your changes with clear descriptions
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions or support, please open an issue in the GitHub repository.
