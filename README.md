# Distributed Threshold Signing Network

A robust, Byzantine Fault Tolerant threshold signature scheme implemented on the Stacks blockchain. This system enables distributed key management and signature generation for cryptographic operations with advanced governance, cross-chain verification, and security features.

## 🔍 Overview

The Distributed Threshold Signing Network (DTSN) is a decentralized infrastructure for distributed key management and threshold signatures. It uses BLS (Boneh-Lynn-Shacham) signatures to allow a threshold of signers to collectively produce cryptographic signatures. This Phase 3 implementation adds governance, cross-chain integration, an event notification system, and enhanced security features.

### What are Threshold Signatures?

Threshold signatures allow a group of participants to collectively generate a single cryptographic signature. With an (n,t) threshold scheme, any t participants out of n total can collaborate to create a valid signature, while fewer than t cannot. This provides both security and fault tolerance.

### Key Benefits

- **Decentralized Key Management**: No single entity has complete control of cryptographic keys
- **Byzantine Fault Tolerance**: System can operate correctly even if some nodes are malicious
- **High Availability**: Continues operating even if some signers are offline
- **Performance**: Produces compact signatures regardless of the number of signers
- **Governance**: On-chain management of protocol parameters
- **Cross-Chain Integration**: Verification of external blockchain transactions

## 🏗️ Architecture

The DTSN consists of the following components:

1. **Signer Network**: Nodes that stake tokens and participate in signature generation
2. **Watchtower System**: Monitoring nodes that report on performance metrics
3. **Governance Layer**: Proposal and voting system for protocol management
4. **Cross-Chain Verification**: Oracle-based system for external chain verification
5. **Events System**: Subscription and notification infrastructure
6. **Economic Model**: Staking, rewards, and protocol fees

## ✨ Features

### Core Features
- BLS threshold signature generation and verification
- Stake-based signer registration and management
- Performance-based signer rotation
- Watchtower monitoring system

### Governance Features
- On-chain proposal creation and voting
- Parameter modification through governance
- Stake and reputation-weighted voting
- Timelocked execution of passed proposals

### Security Features
- Emergency pause mechanism
- Reputation system for signers
- Performance metrics tracking
- Slashing for malicious behavior

### Cross-Chain Features
- External blockchain registration
- Oracle-based transaction verification
- Proof verification with threshold consensus

### Economic Features
- Protocol fee collection
- Performance-based rewards
- Stake requirements for signers
- Reward pool management

### Event System
- Event subscription mechanism
- Ten different event types
- Notification infrastructure

## 💻 Technical Implementation

The DTSN is implemented as a Clarity smart contract on the Stacks blockchain. It uses a combination of maps, data variables, and functions to manage the state and logic of the protocol.

### Key Data Structures

- **Signer Management**:
  - `signer-nodes`: Tracks registered signers and their details
  - `active-signers`: Identifies current active signers
  - `metrics-history`: Historical performance data by epoch

- **Signature Management**:
  - `partial-signatures`: Stores BLS partial signatures
  - `current-message-hash`: Current message being validated

- **Governance**:
  - `governance-proposals`: Stores proposal details
  - `governance-votes`: Records votes on proposals

- **Cross-Chain**:
  - `verified-chains`: Information about registered external chains
  - `cross-chain-transactions`: Verified external transactions

- **Events**:
  - `event-subscribers`: Tracks subscription details

### System Parameters

The protocol includes several configurable parameters:
- `min-stake`: Minimum tokens required to become a signer
- `required-signers`: Minimum number of active signers
- `total-signers`: Maximum number of active signers
- `rotation-period`: Blocks between signer rotations
- `signature-threshold`: Minimum signatures required for verification
- `governance-threshold`: Approval percentage required for proposals
- `protocol-fee-percentage`: Fee collected on operations

## 🔧 Functions

### Initialization
- `initialize`: Set up initial protocol parameters

### Signer Management
- `register-signer`: Join the network as a signer
- `remove-active-signer`: Leave active signer set
- `slash-signer`: Penalize misbehaving signers

### Signature Operations
- `submit-partial-signature`: Submit a BLS partial signature
- `combine-signatures`: Verify and combine signatures

### Watchtower System
- `register-watchtower`: Register as a monitoring node
- `submit-watchtower-report`: Submit performance reports

### Governance
- `create-proposal`: Create a governance proposal
- `vote-on-proposal`: Vote on an active proposal
- `finalize-proposal`: Finalize and execute passed proposals

### Cross-Chain Operations
- `register-cross-chain`: Register external chain
- `submit-cross-chain-tx`: Submit proof of external transaction

### Economic Functions
- `claim-rewards`: Claim performance-based rewards

### Administration
- `set-contract-owner`: Change contract ownership
- `toggle-emergency-pause`: Pause/unpause in emergency
- `trigger-rotation`: Manually trigger rotation

### Query Functions
- `get-signer-info`: Get details about a signer
- `is-active-signer`: Check if a signer is active
- `get-active-signer-count`: Get count of active signers
- `get-signer-metrics`: Get performance metrics
- `get-proposal`: Get proposal details
- `get-vote`: Get vote details
- `get-chain-info`: Get information about a registered chain
- `get-metrics-history`: Get historical metrics by epoch
- `get-protocol-stats`: Get current protocol statistics

## 📥 Installation

To deploy this contract on the Stacks blockchain:

1. Install the [Clarinet](https://github.com/hirosystems/clarinet) development environment:
   ```bash
   curl -sS https://get.clarinet.build | sh
   ```

2. Create a new project:
   ```bash
   clarinet new dtsn-project
   cd dtsn-project
   ```

3. Replace the default contract with the DTSN contract:
   ```bash
   cp path/to/dtsn-contract.clar contracts/dtsn.clar
   ```

4. Test and deploy:
   ```bash
   clarinet test
   clarinet deploy
   ```

## 🚀 Usage

### Becoming a Signer

To join the network as a signer:

1. Ensure you have sufficient STX tokens to meet the minimum stake
2. Generate a BLS key pair
3. Call the `register-signer` function with your public key

```clarity
(contract-call? .dtsn register-signer 0x[your-public-key])
```

### Submitting a Partial Signature

To participate in signature generation:

1. Hash the message to be signed
2. Generate your partial BLS signature
3. Submit it to the network

```clarity
(contract-call? .dtsn submit-partial-signature 0x[message-hash] 0x[your-signature])
```

### Creating a Governance Proposal

To propose a parameter change:

```clarity
(contract-call? .dtsn create-proposal 
    "Increase Min Stake" 
    "Increase minimum stake to 150,000 STX to enhance security" 
    u1 
    (some "min-stake") 
    (some u150000) 
    none 
    u1440)
```

### Voting on a Proposal

To vote on an active proposal:

```clarity
(contract-call? .dtsn vote-on-proposal u1 true) ;; true for yes, false for no
```

## 🏛️ Governance

The governance system allows token holders to propose and vote on changes to the protocol. This includes parameter modifications, feature activations, and signer removals.

### Proposal Types

1. **Parameter Change (type 1)**: Modify protocol parameters
2. **Feature Activation (type 2)**: Enable/disable protocol features
3. **Signer Removal (type 3)**: Remove a misbehaving signer
4. **Custom Actions (types 4+)**: Extensible for future needs

### Voting Process

1. **Proposal Creation**: Any signer with sufficient reputation can create a proposal
2. **Voting Period**: Minimum duration defined by `min-proposal-duration`
3. **Vote Weight**: Based on stake and reputation score
4. **Approval Threshold**: Defined by `governance-threshold` (default 67%)
5. **Execution**: Automatically executed after approval and execution delay

## 🔗 Cross-Chain Integration

The cross-chain verification system allows the DTSN to verify and record transactions from external blockchains.

### Supported Operations

1. **Chain Registration**: Register external chains for verification
2. **Transaction Verification**: Verify external transactions with oracle signatures
3. **Proof Validation**: Validate proofs with threshold consensus

### Integration Process

1. Register an external chain with oracle public key and verification threshold
2. Oracles submit transaction proofs from the external chain
3. Once verification threshold is reached, the transaction is recorded
4. Events are emitted for subscribers

## 🔒 Security

The DTSN includes several security mechanisms:

### Emergency Pause

The contract owner can pause operations in case of emergency, preventing any state-changing operations until the pause is lifted.

### Reputation System

Signers have a reputation score (1-100) that:
- Affects voting power in governance
- Influences reward distribution
- Is required for certain operations
- Decreases on slashing events

### Slashing Mechanism

Malicious or poorly performing signers can be slashed, which:
- Reduces their reputation score
- Records the slashing event
- May remove them from active signer set after multiple offenses

### Performance Metrics

The system tracks several performance metrics:
- Signing speed
- Uptime
- Accuracy
- Total signatures
- Valid signatures ratio

## 📢 Events System

The events system allows external applications to subscribe to and receive notifications about protocol activities.

### Event Types

1. `EVENT-TYPE-SIGNER-REGISTERED`: New signer registration
2. `EVENT-TYPE-SIGNATURE-SUBMITTED`: Partial signature submission
3. `EVENT-TYPE-THRESHOLD-REACHED`: Signature threshold reached
4. `EVENT-TYPE-GOVERNANCE-PROPOSAL`: New governance proposal
5. `EVENT-TYPE-GOVERNANCE-VOTE`: Vote on proposal
6. `EVENT-TYPE-SIGNER-SLASHED`: Signer slashing event
7. `EVENT-TYPE-ROTATION-EXECUTED`: Signer rotation event
8. `EVENT-TYPE-CROSS-CHAIN-VERIFIED`: Cross-chain verification
9. `EVENT-TYPE-EMERGENCY-ACTION`: Emergency actions
10. `EVENT-TYPE-REWARD-DISTRIBUTED`: Reward distribution

### Subscription

To subscribe to specific events:

```clarity
(contract-call? .dtsn subscribe-to-events (list u1 u2 u3))
```

## 🛣️ Development Roadmap

### Phase 4 (Upcoming)
- Layer-2 scalability solution for high-throughput signature generation
- Enhanced privacy features with zero-knowledge proofs
- Multi-signature wallet integration
- Decentralized identity attestations
- Integration with Stacks 2.1 features

### Future Enhancements
- Advanced MEV (Maximal Extractable Value) protection
- Cross-chain bridge functionality
- Automated security auditing
- Dynamic threshold adjustment
- Machine learning-based performance prediction

## 👥 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## Contact

For questions or support, please open an issue in the GitHub repository.
