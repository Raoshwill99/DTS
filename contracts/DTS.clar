;; Distributed Threshold Signing Network - Phase 3
;; Advanced implementation with governance, cross-chain integration, events system and enhanced security

;; Error codes (existing)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMS (err u101))
(define-constant ERR-INSUFFICIENT-STAKE (err u102))
(define-constant ERR-INVALID-SIGNATURE (err u103))
(define-constant ERR-INVALID-THRESHOLD (err u104))
(define-constant ERR-WATCHTOWER-EXISTS (err u105))
(define-constant ERR-NOT-ACTIVE-SIGNER (err u106))
(define-constant ERR-ALREADY-REGISTERED (err u107))
(define-constant ERR-INVALID-METRICS (err u108))
(define-constant ERR-INVALID-SIGNATURE-LENGTH (err u109))
(define-constant ERR-INVALID-KEY-LENGTH (err u110))
(define-constant ERR-ALREADY-INITIALIZED (err u111))

;; New error codes for Phase 3
(define-constant ERR-GOVERNANCE-VOTING-CLOSED (err u112))
(define-constant ERR-ALREADY-VOTED (err u113))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u114))
(define-constant ERR-INVALID-VOTE (err u115))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u116))
(define-constant ERR-INVALID-CROSS-CHAIN-PROOF (err u117))
(define-constant ERR-EMERGENCY-PAUSED (err u118))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u119))
(define-constant ERR-EVENT-EMISSION-FAILED (err u120))

;; Contract Owner
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)
(define-data-var emergency-pause bool false)

;; BLS Threshold Parameters
(define-data-var bls-public-key (buff 128) 0x00) ;; Aggregate public key
(define-data-var signature-threshold uint u3) ;; Minimum signatures required
(define-data-var current-message-hash (buff 32) 0x) ;; Current message being validated

;; Maps with proper tuple types (existing)
(define-map partial-signatures 
    {signer: principal} 
    {
        signature: (buff 96),
        message-hash: (buff 32),
        timestamp: uint
    }
)

(define-map watchtowers 
    {watcher: principal} 
    {
        last-report: uint,
        reports-submitted: uint,
        accuracy-score: uint,
        is-active: bool
    }
)

(define-map signer-nodes 
    {signer: principal} 
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
)

(define-map active-signers 
    {signer: principal} 
    {is-active: bool}
)

;; New Phase 3 Maps and Data Structures

;; Governance Structures
(define-map governance-proposals
    {proposal-id: uint}
    {
        proposer: principal,
        title: (string-utf8 100),
        description: (string-utf8 500),
        proposal-type: uint, ;; 1=parameter change, 2=feature activation, 3=signer removal, etc.
        parameter-key: (optional (string-utf8 50)),
        parameter-value: (optional uint),
        target-principal: (optional principal),
        start-height: uint,
        end-height: uint,
        status: uint, ;; 0=active, 1=passed, 2=rejected, 3=executed
        yes-votes: uint,
        no-votes: uint,
        execution-delay: uint
    }
)

(define-map governance-votes
    {proposal-id: uint, voter: principal}
    {
        vote: bool, ;; true=yes, false=no
        voting-power: uint,
        timestamp: uint
    }
)

;; Cross-chain Integration
(define-map verified-chains
    {chain-id: uint}
    {
        oracle-pubkey: (buff 65),
        last-header-hash: (buff 32),
        verification-threshold: uint,
        is-active: bool
    }
)

(define-map cross-chain-transactions
    {tx-hash: (buff 32)}
    {
        source-chain: uint,
        verified: bool,
        verification-timestamp: uint,
        data: (buff 1024),
        oracle-signatures: (list 10 (buff 96))
    }
)

;; Event System
(define-map event-subscribers
    {subscriber: principal}
    {
        event-types: (list 10 uint),
        notifications-count: uint
    }
)

;; Performance Metrics History
(define-map metrics-history
    {signer: principal, epoch: uint}
    {
        uptime: uint,
        signing-speed: uint,
        reputation-score: uint,
        total-signatures: uint,
        valid-signatures: uint
    }
)

;; Data Variables (existing)
(define-data-var min-stake uint u100000)
(define-data-var required-signers uint u3)
(define-data-var total-signers uint u5)
(define-data-var rotation-period uint u144)
(define-data-var active-signer-count uint u0)
(define-data-var last-rotation-height uint u0)

;; New Phase 3 Data Variables
(define-data-var proposal-count uint u0)
(define-data-var governance-threshold uint u67) ;; 67% approval threshold
(define-data-var min-proposal-duration uint u144) ;; Minimum blocks for voting period
(define-data-var proposal-fee uint u10000) ;; Fee to create proposal
(define-data-var min-reputation-to-propose uint u80) ;; Minimum reputation to create proposal
(define-data-var current-epoch uint u0) ;; For tracking rotation and metrics history
(define-data-var oracle-rotation-height uint u0) ;; For oracle rotation
(define-data-var reward-pool uint u0) ;; Pool for distributing rewards
(define-data-var protocol-fee-percentage uint u1) ;; 1% fee on operations

;; Event Types
(define-constant EVENT-TYPE-SIGNER-REGISTERED u1)
(define-constant EVENT-TYPE-SIGNATURE-SUBMITTED u2)
(define-constant EVENT-TYPE-THRESHOLD-REACHED u3)
(define-constant EVENT-TYPE-GOVERNANCE-PROPOSAL u4)
(define-constant EVENT-TYPE-GOVERNANCE-VOTE u5)
(define-constant EVENT-TYPE-SIGNER-SLASHED u6)
(define-constant EVENT-TYPE-ROTATION-EXECUTED u7)
(define-constant EVENT-TYPE-CROSS-CHAIN-VERIFIED u8)
(define-constant EVENT-TYPE-EMERGENCY-ACTION u9)
(define-constant EVENT-TYPE-REWARD-DISTRIBUTED u10)

;; Private Functions (existing)

;; Check if caller is contract owner
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Validate metrics are within acceptable range
(define-private (validate-metrics (uptime uint) (signing-speed uint) (valid-signatures uint))
    (and
        (<= uptime u100)
        (<= signing-speed u100)
        (<= valid-signatures u1)
    )
)

;; Process signature for validation
(define-private (process-signature (signer principal) (valid-count uint))
    (match (map-get? partial-signatures {signer: signer})
        signature-data (if (and 
                            (is-active-signer signer)
                            (is-eq (get message-hash signature-data) (var-get current-message-hash)))
                        (+ valid-count u1)
                        valid-count)
        valid-count)
)

;; Update metrics from report
(define-private (update-metrics-from-report 
    (signer principal)
    (uptime uint)
    (signing-speed uint)
    (valid-signatures uint))
    
    (let
        (
            (current-info (unwrap! (map-get? signer-nodes {signer: signer}) ERR-UNAUTHORIZED))
            (current-metrics (get performance-metrics current-info))
        )
        (begin
            (map-set signer-nodes {signer: signer}
                (merge current-info {
                    last-active: block-height,
                    performance-metrics: {
                        signing-speed: signing-speed,
                        uptime: uptime,
                        stake-duration: (- block-height (get stake-duration current-metrics)),
                        accuracy: (get accuracy current-metrics),
                        total-signatures: (+ (get total-signatures current-metrics) u1),
                        valid-signatures: (+ (get valid-signatures current-metrics) valid-signatures)
                    }
                })
            )
            (ok true)
        )
    )
)

;; New Phase 3 Private Functions

;; Emit event for subscribers
(define-private (emit-event (event-type uint) (event-data (buff 1024)))
    (begin
        ;; In actual implementation, this would notify external systems
        ;; For now, we just return true
        (ok true)
    )
)

;; Calculate voting power based on stake and reputation
(define-private (calculate-voting-power (voter principal))
    (match (map-get? signer-nodes {signer: voter})
        node (let
                (
                    (stake-weight (* (get stake node) u10000))
                    (rep-weight (* (get reputation-score node) u100))
                )
                (/ (+ stake-weight rep-weight) u1000000)
             )
        u0) ;; No voting power if not a signer
)

;; Update reputation score based on performance
(define-private (update-reputation (signer principal) (performance-delta int))
    (match (map-get? signer-nodes {signer: signer})
        node (let
                (
                    (current-reputation (get reputation-score node))
                    (new-reputation (+ current-reputation (if (< performance-delta i0)
                                                            ;; Decrease cannot go below 1
                                                            (to-uint (max (to-int current-reputation) (+ (to-int current-reputation) performance-delta)))
                                                            ;; Increase cannot go above 100
                                                            (min (+ current-reputation (to-uint performance-delta)) u100))))
                )
                (map-set signer-nodes {signer: signer}
                    (merge node {
                        reputation-score: new-reputation
                    })
                )
                (ok new-reputation)
             )
        (err ERR-UNAUTHORIZED)
    )
)

;; Check if proposal exists and is active
(define-private (is-proposal-active (proposal-id uint))
    (match (map-get? governance-proposals {proposal-id: proposal-id})
        proposal (and
                    (is-eq (get status proposal) u0)
                    (<= (get start-height proposal) block-height)
                    (>= (get end-height proposal) block-height)
                 )
        false
    )
)

;; Execute governance proposal actions
(define-private (execute-proposal (proposal-id uint))
    (match (map-get? governance-proposals {proposal-id: proposal-id})
        proposal (begin
                    (match (get proposal-type proposal)
                        ;; Parameter change
                        u1 (match (get parameter-key proposal)
                                (some "min-stake") (begin (var-set min-stake (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "required-signers") (begin (var-set required-signers (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "total-signers") (begin (var-set total-signers (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "rotation-period") (begin (var-set rotation-period (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "signature-threshold") (begin (var-set signature-threshold (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "governance-threshold") (begin (var-set governance-threshold (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                (some "protocol-fee") (begin (var-set protocol-fee-percentage (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS)) (ok true))
                                ;; Add more parameters as needed
                                (err ERR-INVALID-PARAMS)
                            )
                        ;; Signer removal
                        u3 (match (get target-principal proposal)
                                (some principal) (remove-active-signer principal)
                                (err ERR-INVALID-PARAMS)
                            )
                        ;; Add more types as needed
                            (err ERR-INVALID-PARAMS)
                    )
                  )
        (err ERR-PROPOSAL-NOT-FOUND)
    )
)

;; Calculate rewards for a signer based on performance
(define-private (calculate-rewards (signer principal))
    (match (map-get? signer-nodes {signer: signer})
        node (let
                (
                    (metrics (get performance-metrics node))
                    (base-reward u1000)
                    (performance-multiplier (/ (+ (get uptime metrics) (get accuracy metrics)) u2))
                    (stake-multiplier (/ (get stake node) (var-get min-stake)))
                    (total-reward (* (* base-reward performance-multiplier) stake-multiplier))
                )
                (if (> (var-get reward-pool) total-reward)
                    (begin
                        (var-set reward-pool (- (var-get reward-pool) total-reward))
                        (ok total-reward)
                    )
                    (err ERR-INSUFFICIENT-STAKE)
                )
             )
        (err ERR-UNAUTHORIZED)
    )
)

;; Verify cross-chain proof (simplified for example)
(define-private (verify-cross-chain-proof 
    (chain-id uint) 
    (proof-data (buff 1024)) 
    (signatures (list 10 (buff 96))))
    
    (match (map-get? verified-chains {chain-id: chain-id})
        chain-info (let
                        (
                            (threshold (get verification-threshold chain-info))
                            ;; In a real implementation, would verify BLS signatures here
                            ;; This is simplified for the example
                            (valid-signatures (len signatures))
                        )
                        (>= valid-signatures threshold)
                    )
        false
    )
)

;; Rotate active signers based on performance
(define-private (execute-rotation)
    (let
        (
            (current-height block-height)
        )
        (if (>= current-height (+ (var-get last-rotation-height) (var-get rotation-period)))
            (begin
                ;; Logic for signer rotation based on performance metrics
                ;; This would be more complex in a real implementation
                (var-set last-rotation-height current-height)
                (var-set current-epoch (+ (var-get current-epoch) u1))
                (emit-event EVENT-TYPE-ROTATION-EXECUTED 0x00)
                (ok true)
            )
            (ok false)
        )
    )
)

;; Public Read-Only Functions (existing)

;; Get signer information
(define-read-only (get-signer-info (signer principal))
    (map-get? signer-nodes {signer: signer})
)

;; Check if signer is active
(define-read-only (is-active-signer (signer principal))
    (match (map-get? active-signers {signer: signer})
        entry (get is-active entry)
        false)
)

;; Get active signer count
(define-read-only (get-active-signer-count)
    (var-get active-signer-count)
)

;; Get signer metrics
(define-read-only (get-signer-metrics (signer principal))
    (match (map-get? signer-nodes {signer: signer})
        node (ok (get performance-metrics node))
        (err ERR-UNAUTHORIZED))
)

;; Get watchtower information
(define-read-only (get-watchtower-info (watchtower principal))
    (map-get? watchtowers {watcher: watchtower})
)

;; New Phase 3 Read-Only Functions

;; Get proposal details
(define-read-only (get-proposal (proposal-id uint))
    (map-get? governance-proposals {proposal-id: proposal-id})
)

;; Get vote details
(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? governance-votes {proposal-id: proposal-id, voter: voter})
)

;; Get chain verification details
(define-read-only (get-chain-info (chain-id uint))
    (map-get? verified-chains {chain-id: chain-id})
)

;; Get cross-chain transaction details
(define-read-only (get-cross-chain-tx (tx-hash (buff 32)))
    (map-get? cross-chain-transactions {tx-hash: tx-hash})
)

;; Get metrics history by epoch
(define-read-only (get-metrics-history (signer principal) (epoch uint))
    (map-get? metrics-history {signer: signer, epoch: epoch})
)

;; Get current protocol stats
(define-read-only (get-protocol-stats)
    {
        active-signers: (var-get active-signer-count),
        total-signers-limit: (var-get total-signers),
        current-epoch: (var-get current-epoch),
        reward-pool: (var-get reward-pool),
        proposal-count: (var-get proposal-count),
        last-rotation-height: (var-get last-rotation-height),
        next-rotation-height: (+ (var-get last-rotation-height) (var-get rotation-period)),
        emergency-paused: (var-get emergency-pause)
    }
)

;; Public Functions (existing)

;; Initialize contract
(define-public (initialize (min-stake-arg uint) 
                         (required-signers-arg uint)
                         (total-signers-arg uint)
                         (rotation-period-arg uint)
                         (signature-threshold-arg uint))
    (begin
        (asserts! (not (var-get initialized)) ERR-ALREADY-INITIALIZED)
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (> min-stake-arg u0) ERR-INVALID-PARAMS)
        (asserts! (> required-signers-arg u0) ERR-INVALID-PARAMS)
        (asserts! (>= total-signers-arg required-signers-arg) ERR-INVALID-PARAMS)
        (asserts! (> rotation-period-arg u0) ERR-INVALID-PARAMS)
        (asserts! (> signature-threshold-arg u0) ERR-INVALID-PARAMS)
        
        (var-set min-stake min-stake-arg)
        (var-set required-signers required-signers-arg)
        (var-set total-signers total-signers-arg)
        (var-set rotation-period rotation-period-arg)
        (var-set signature-threshold signature-threshold-arg)
        (var-set last-rotation-height block-height)
        (var-set initialized true)
        (ok true)
    )
)

;; Register new signer
(define-public (register-signer (public-key (buff 65)))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (stake (stx-get-balance tx-sender))
                (current-count (var-get active-signer-count))
                (protocol-fee (/ (* stake (var-get protocol-fee-percentage)) u100))
            )
            (asserts! (>= stake (var-get min-stake)) ERR-INSUFFICIENT-STAKE)
            (asserts! (is-none (map-get? signer-nodes {signer: tx-sender})) ERR-ALREADY-REGISTERED)
            (asserts! (is-eq (len public-key) u65) ERR-INVALID-KEY-LENGTH)
            
            ;; Collect protocol fee
            (var-set reward-pool (+ (var-get reward-pool) protocol-fee))
            
            (map-set signer-nodes {signer: tx-sender} {
                stake: stake,
                public-key: public-key,
                reputation-score: u100,
                last-active: block-height,
                performance-metrics: {
                    signing-speed: u100,
                    uptime: u100,
                    stake-duration: u0,
                    accuracy: u100,
                    total-signatures: u0,
                    valid-signatures: u0
                },
                slashing-history: {
                    total-slashes: u0,
                    last-slash-height: u0,
                    slashed-amount: u0
                }
            })
            
            ;; Add to active signers if slots available
            (if (< current-count (var-get total-signers))
                (begin
                    (map-set active-signers {signer: tx-sender} {is-active: true})
                    (var-set active-signer-count (+ current-count u1))
                    (emit-event EVENT-TYPE-SIGNER-REGISTERED 0x00)
                    (ok true)
                )
                (ok false)
            )
        )
    )
)

;; Register Watchtower
(define-public (register-watchtower)
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-none (map-get? watchtowers {watcher: tx-sender})) ERR-WATCHTOWER-EXISTS)
        
        (map-set watchtowers {watcher: tx-sender} {
            last-report: u0,
            reports-submitted: u0,
            accuracy-score: u100,
            is-active: true
        })
        (ok true)
    )
)

;; Submit Watchtower Report
(define-public (submit-watchtower-report 
    (signer principal)
    (uptime uint)
    (signing-speed uint)
    (valid-signatures uint))
    
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (reporter-info (unwrap! (map-get? watchtowers {watcher: tx-sender}) ERR-UNAUTHORIZED))
                (current-metrics (unwrap! (get-signer-metrics signer) ERR-INVALID-PARAMS))
            )
            (asserts! (validate-metrics uptime signing-speed valid-signatures) ERR-INVALID-METRICS)
            
            ;; Update watchtower stats
            (map-set watchtowers {watcher: tx-sender}
                (merge reporter-info {
                    last-report: block-height,
                    reports-submitted: (+ (get reports-submitted reporter-info) u1)
                })
            )
            
            ;; Update signer metrics based on report
            (unwrap! (update-metrics-from-report signer uptime signing-speed valid-signatures)
                    ERR-INVALID-METRICS)
            
            ;; Store metrics history
            (map-set metrics-history 
                {signer: signer, epoch: (var-get current-epoch)}
                {
                    uptime: uptime,
                    signing-speed: signing-speed,
                    reputation-score: (get reputation-score (unwrap! (map-get? signer-nodes {signer: signer}) ERR-UNAUTHORIZED)),
                    total-signatures: (get total-signatures current-metrics),
                    valid-signatures: (get valid-signatures current-metrics)
                }
            )
            
            (ok true)
        )
    )
)

;; Submit partial BLS signature
(define-public (submit-partial-signature 
    (message-hash (buff 32))
    (signature (buff 96)))
    
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-eq (len message-hash) u32) ERR-INVALID-SIGNATURE-LENGTH)
        (asserts! (is-eq (len signature) u96) ERR-INVALID-SIGNATURE-LENGTH)
        
        (let
            (
                (signer-info (unwrap! (map-get? signer-nodes {signer: tx-sender}) ERR-UNAUTHORIZED))
                (protocol-fee (/ (* u1000 (var-get protocol-fee-percentage)) u100))
            )
            (asserts! (is-active-signer tx-sender) ERR-NOT-ACTIVE-SIGNER)
            
            ;; Collect small protocol fee
            (var-set reward-pool (+ (var-get reward-pool) protocol-fee))
            
            ;; Store partial signature
            (map-set partial-signatures {signer: tx-sender} {
                signature: signature,
                message-hash: message-hash,
                timestamp: block-height
            })
            
            ;; Update signer metrics
            (unwrap! (update-metrics-from-report 
                tx-sender
                (get uptime (get performance-metrics signer-info))
                (get signing-speed (get performance-metrics signer-info))
                u1)
                ERR-INVALID-METRICS)
                
            (emit-event EVENT-TYPE-SIGNATURE-SUBMITTED 0x00)
            (ok true)
        )
    )
)

;; Verify and combine partial signatures
(define-public (combine-signatures (message-hash (buff 32)) (signers (list 10 principal)))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (var-set current-message-hash message-hash)
        (let
            (
                (valid-count (fold process-signature signers u0))
            )
            (asserts! (>= valid-count (var-get signature-threshold)) ERR-INVALID-THRESHOLD)
            
            ;; Log event for threshold reached
            (emit-event EVENT-TYPE-THRESHOLD-REACHED 0x00)
            
            ;; Attempt rotation if conditions are met
            (execute-rotation)
            
            (ok true)
        )
    )
)

;; Remove signer from active set
(define-public (remove-active-signer (signer principal))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (current-count (var-get active-signer-count))
            )
            (asserts! (or (is-eq tx-sender signer) (is-contract-owner)) ERR-UNAUTHORIZED)
            (asserts! (is-some (map-get? active-signers {signer: signer})) ERR-INVALID-PARAMS)
            
            (map-delete active-signers {signer: signer})
            (var-set active-signer-count (- current-count u1))
            (ok true)
        )
    )
)

;; Slash misbehaving signer
(define-public (slash-signer 
    (signer principal)
    (slash-amount uint)
    (evidence (buff 32)))
    
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (signer-info (unwrap! (map-get? signer-nodes {signer: signer}) ERR-UNAUTHORIZED))
            )
            (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
            
            ;; Update slashing history
            (map-set signer-nodes {signer: signer}
                (merge signer-info {
                    slashing-history: {
                        total-slashes: (+ (get total-slashes (get slashing-history signer-info)) u1),
                        last-slash-height: block-height,
                        slashed-amount: (+ (get slashed-amount (get slashing-history signer-info)) slash-amount)
                    }
                })
            )
            
            ;; Update reputation negatively
            (unwrap! (update-reputation signer i-10) ERR-INVALID-PARAMS)
            
            ;; Emit slashing event
            (emit-event EVENT-TYPE-SIGNER-SLASHED 0x00)
            
            ;; Remove from active signers if too many slashes
            (if (> (get total-slashes (get slashing-history signer-info)) u2)
                (remove-active-signer signer)
                (ok true)
            )
        )
    )
)

;; Change contract owner
(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

;; New Phase 3 Public Functions

;; Create governance proposal
(define-public (create-proposal 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (proposal-type uint)
    (parameter-key (optional (string-utf8 50)))
    (parameter-value (optional uint))
    (target-principal (optional principal))
    (duration uint))
    
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (signer-info (unwrap! (map-get? signer-nodes {signer: tx-sender}) ERR-UNAUTHORIZED))
                (reputation (get reputation-score signer-info))
                (current-proposal-id (var-get proposal-count))
            )
            (asserts! (>= reputation (var-get min-reputation-to-propose)) ERR-INSUFFICIENT-REPUTATION)
            (asserts! (>= duration (var-get min-proposal-duration)) ERR-INVALID-PARAMS)
            
            ;; Collect proposal fee
            (var-set reward-pool (+ (var-get reward-pool) (var-get proposal-fee)))
            
            ;; Create new proposal
            (var-set proposal-count (+ current-proposal-id u1))
            (map-set governance-proposals 
                {proposal-id: current-proposal-id}
                {
                    proposer: tx-sender,
                    title: title,
                    description: description,
                    proposal-type: proposal-type,
                    parameter-key: parameter-key,
                    parameter-value: parameter-value,
                    target-principal: target-principal,
                    start-height: block-height,
                    end-height: (+ block-height duration),
                    status: u0,
                    yes-votes: u0,
                    no-votes: u0,
                    execution-delay: u144
                }
            )
            
            ;; Emit proposal creation event
            (emit-event EVENT-TYPE-GOVERNANCE-PROPOSAL 0x00)
            
            (ok current-proposal-id)
        )
    )
)

;; Vote on a governance proposal
(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-proposal-active proposal-id) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (is-none (map-get? governance-votes {proposal-id: proposal-id, voter: tx-sender})) ERR-ALREADY-VOTED)
        
        (let
            (
                (voting-power (calculate-voting-power tx-sender))
                (proposal (unwrap! (map-get? governance-proposals {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
            )
            (asserts! (> voting-power u0) ERR-UNAUTHORIZED)
            
            ;; Record vote
            (map-set governance-votes 
                {proposal-id: proposal-id, voter: tx-sender}
                {
                    vote: vote,
                    voting-power: voting-power,
                    timestamp: block-height
                }
            )
            
            ;; Update vote counts in proposal
            (map-set governance-proposals 
                {proposal-id: proposal-id}
                (merge proposal {
                    yes-votes: (if vote (+ (get yes-votes proposal) voting-power) (get yes-votes proposal)),
                    no-votes: (if vote (get no-votes proposal) (+ (get no-votes proposal) voting-power))
                })
            )
            
            ;; Emit voting event
            (emit-event EVENT-TYPE-GOVERNANCE-VOTE 0x00)
            
            (ok true)
        )
    )
)

;; Finalize proposal after voting period ends
(define-public (finalize-proposal (proposal-id uint))
    (begin
        (let
            (
                (proposal (unwrap! (map-get? governance-proposals {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
            )
            ;; Check if voting period has ended
            (asserts! (>= block-height (get end-height proposal)) ERR-GOVERNANCE-VOTING-CLOSED)
            ;; Check proposal is still active (not already finalized)
            (asserts! (is-eq (get status proposal) u0) ERR-PROPOSAL-NOT-ACTIVE)
            
            (let
                (
                    (total-votes (+ (get yes-votes proposal) (get no-votes proposal)))
                    (yes-percentage (if (is-eq total-votes u0) 
                                       u0 
                                       (/ (* (get yes-votes proposal) u100) total-votes)))
                    (passed (>= yes-percentage (var-get governance-threshold)))
                    (new-status (if passed u1 u2)) ;; 1=passed, 2=rejected
                )
                
                ;; Update proposal status
                (map-set governance-proposals 
                    {proposal-id: proposal-id}
                    (merge proposal {
                        status: new-status
                    })
                )
                
                ;; Execute if passed (after delay is implemented in a production system)
                (if passed
                    (execute-proposal proposal-id)
                    (ok false)
                )
            )
        )
    )
)

;; Register cross-chain verification
(define-public (register-cross-chain (chain-id uint) (oracle-pubkey (buff 65)) (verification-threshold uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (> verification-threshold u0) ERR-INVALID-THRESHOLD)
        
        (map-set verified-chains
            {chain-id: chain-id}
            {
                oracle-pubkey: oracle-pubkey,
                last-header-hash: 0x00,
                verification-threshold: verification-threshold,
                is-active: true
            }
        )
        (ok true)
    )
)

;; Submit cross-chain transaction proof
(define-public (submit-cross-chain-tx 
    (chain-id uint)
    (tx-hash (buff 32))
    (data (buff 1024))
    (signatures (list 10 (buff 96))))
    
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (verify-cross-chain-proof chain-id data signatures) ERR-INVALID-CROSS-CHAIN-PROOF)
        
        ;; Store verified transaction
        (map-set cross-chain-transactions
            {tx-hash: tx-hash}
            {
                source-chain: chain-id,
                verified: true,
                verification-timestamp: block-height,
                data: data,
                oracle-signatures: signatures
            }
        )
        
        ;; Emit cross-chain verification event
        (emit-event EVENT-TYPE-CROSS-CHAIN-VERIFIED 0x00)
        
        (ok true)
    )
)

;; Subscribe to events
(define-public (subscribe-to-events (event-types (list 10 uint)))
    (begin
        (map-set event-subscribers
            {subscriber: tx-sender}
            {
                event-types: event-types,
                notifications-count: u0
            }
        )
        (ok true)
    )
)

;; Claim rewards for signer
(define-public (claim-rewards)
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let
            (
                (reward-amount (unwrap! (calculate-rewards tx-sender) ERR-UNAUTHORIZED))
            )
            ;; In a production system, would transfer STX here
            
            ;; Emit reward distribution event
            (emit-event EVENT-TYPE-REWARD-DISTRIBUTED 0x00)
            
            (ok reward-amount)
        )
    )
)

;; Emergency pause or unpause contract
(define-public (toggle-emergency-pause)
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        
        (var-set emergency-pause (not (var-get emergency-pause)))
        
        ;; Emit emergency action event
        (emit-event EVENT-TYPE-EMERGENCY-ACTION 0x00)
        
        (ok (var-get emergency-pause))
    )
)

;; Manual rotation trigger (for testing or emergency)
(define-public (trigger-rotation)
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (execute-rotation)
    )
)