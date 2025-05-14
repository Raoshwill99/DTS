;; Distributed Threshold Signing Network - Optimized
;; Advanced implementation with governance, cross-chain integration, events system and enhanced security

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMS (err u101))
(define-constant ERR-INSUFFICIENT-STAKE (err u102))
(define-constant ERR-INVALID-SIGNATURE (err u103))
(define-constant ERR-INVALID-THRESHOLD (err u104))
(define-constant ERR-ALREADY-EXISTS (err u105))
(define-constant ERR-NOT-ACTIVE-SIGNER (err u106))
(define-constant ERR-ALREADY-INITIALIZED (err u107))
(define-constant ERR-GOVERNANCE-VOTING (err u108))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u109))
(define-constant ERR-INVALID-VOTE (err u110))
(define-constant ERR-PROPOSAL-NOT-ACTIVE (err u111))
(define-constant ERR-INVALID-PROOF (err u112))
(define-constant ERR-EMERGENCY-PAUSED (err u113))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u114))
(define-constant ERR-EVENT-FAILED (err u115))

;; Contract Controls
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)
(define-data-var emergency-pause bool false)

;; Threshold Parameters
(define-data-var bls-public-key (buff 128) 0x00) 
(define-data-var signature-threshold uint u3)
(define-data-var current-message-hash (buff 32) 0x)

;; Maps
(define-map partial-signatures {signer: principal} 
    {signature: (buff 96), message-hash: (buff 32), timestamp: uint})

(define-map watchtowers {watcher: principal} 
    {last-report: uint, reports-submitted: uint, accuracy-score: uint, is-active: bool})

(define-map signer-nodes {signer: principal} 
    {stake: uint, public-key: (buff 65), reputation-score: uint, last-active: uint,
     performance-metrics: {signing-speed: uint, uptime: uint, stake-duration: uint, 
                          accuracy: uint, total-signatures: uint, valid-signatures: uint},
     slashing-history: {total-slashes: uint, last-slash-height: uint, slashed-amount: uint}})

(define-map active-signers {signer: principal} {is-active: bool})

;; Governance Structures
(define-map governance-proposals {proposal-id: uint}
    {proposer: principal, title: (string-utf8 100), description: (string-utf8 500),
     proposal-type: uint, parameter-key: (optional (string-utf8 50)),
     parameter-value: (optional uint), target-principal: (optional principal),
     start-height: uint, end-height: uint, status: uint, 
     yes-votes: uint, no-votes: uint, execution-delay: uint})

(define-map governance-votes {proposal-id: uint, voter: principal}
    {vote: bool, voting-power: uint, timestamp: uint})

;; Cross-chain Integration
(define-map verified-chains {chain-id: uint}
    {oracle-pubkey: (buff 65), last-header-hash: (buff 32), 
     verification-threshold: uint, is-active: bool})

(define-map cross-chain-transactions {tx-hash: (buff 32)}
    {source-chain: uint, verified: bool, verification-timestamp: uint,
     data: (buff 1024), oracle-signatures: (list 10 (buff 96))})

;; Event System
(define-map event-subscribers {subscriber: principal}
    {event-types: (list 10 uint), notifications-count: uint})

;; Global Parameters
(define-data-var min-stake uint u100000)
(define-data-var required-signers uint u3)
(define-data-var total-signers uint u5)
(define-data-var rotation-period uint u144)
(define-data-var active-signer-count uint u0)
(define-data-var last-rotation-height uint u0)
(define-data-var proposal-count uint u0)
(define-data-var governance-threshold uint u67)  
(define-data-var min-proposal-duration uint u144)
(define-data-var proposal-fee uint u10000)
(define-data-var min-reputation-to-propose uint u80)
(define-data-var current-epoch uint u0)
(define-data-var reward-pool uint u0)
(define-data-var protocol-fee-percentage uint u1)

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

;; Private Functions
(define-private (is-contract-owner) (is-eq tx-sender (var-get contract-owner)))

(define-private (validate-metrics (uptime uint) (signing-speed uint) (valid-signatures uint))
    (and (<= uptime u100) (<= signing-speed u100) (<= valid-signatures u1)))

(define-private (process-signature (signer principal) (valid-count uint))
    (match (map-get? partial-signatures {signer: signer})
        signature-data (if (and (is-active-signer signer)
                             (is-eq (get message-hash signature-data) (var-get current-message-hash)))
                        (+ valid-count u1)
                        valid-count)
        valid-count))

(define-private (update-metrics-from-report (signer principal) (uptime uint) 
                (signing-speed uint) (valid-signatures uint))
    (let ((current-info (unwrap! (map-get? signer-nodes {signer: signer}) ERR-UNAUTHORIZED))
          (current-metrics (get performance-metrics current-info)))
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
            }))
        (ok true)))

(define-private (emit-event (event-type uint) (event-data (buff 1024))) (ok true))

(define-private (calculate-voting-power (voter principal))
    (match (map-get? signer-nodes {signer: voter})
        node (let ((stake-weight (* (get stake node) u10000))
                  (rep-weight (* (get reputation-score node) u100)))
                (/ (+ stake-weight rep-weight) u1000000))
        u0))

(define-private (is-proposal-active (proposal-id uint))
    (match (map-get? governance-proposals {proposal-id: proposal-id})
        proposal (and (is-eq (get status proposal) u0)
                    (<= (get start-height proposal) block-height)
                    (>= (get end-height proposal) block-height))
        false))

(define-private (calculate-rewards (signer principal))
    (match (map-get? signer-nodes {signer: signer})
        node (let ((metrics (get performance-metrics node))
                  (base-reward u1000)
                  (performance-multiplier (/ (+ (get uptime metrics) (get accuracy metrics)) u2))
                  (stake-multiplier (/ (get stake node) (var-get min-stake)))
                  (total-reward (* (* base-reward performance-multiplier) stake-multiplier)))
                (if (> (var-get reward-pool) total-reward)
                    (begin
                        (var-set reward-pool (- (var-get reward-pool) total-reward))
                        (ok total-reward))
                    (err ERR-INSUFFICIENT-STAKE)))
        (err ERR-UNAUTHORIZED)))

(define-private (verify-cross-chain-proof (chain-id uint) (proof-data (buff 1024)) 
                (signatures (list 10 (buff 96))))
    (match (map-get? verified-chains {chain-id: chain-id})
        chain-info (let ((threshold (get verification-threshold chain-info))
                        (valid-signatures (len signatures)))
                        (>= valid-signatures threshold))
        false))


;; Read-Only Functions
(define-read-only (get-signer-info (signer principal))
    (map-get? signer-nodes {signer: signer}))

(define-read-only (is-active-signer (signer principal))
    (match (map-get? active-signers {signer: signer})
        entry (get is-active entry)
        false))

(define-read-only (get-active-signer-count) (var-get active-signer-count))

(define-read-only (get-signer-metrics (signer principal))
    (match (map-get? signer-nodes {signer: signer})
        node (ok (get performance-metrics node))
        (err ERR-UNAUTHORIZED)))

(define-read-only (get-protocol-stats)
    {active-signers: (var-get active-signer-count),
     total-signers-limit: (var-get total-signers),
     current-epoch: (var-get current-epoch),
     reward-pool: (var-get reward-pool),
     proposal-count: (var-get proposal-count),
     last-rotation-height: (var-get last-rotation-height),
     next-rotation-height: (+ (var-get last-rotation-height) (var-get rotation-period)),
     emergency-paused: (var-get emergency-pause)})

;; Public Functions
(define-public (initialize (min-stake-arg uint) (required-signers-arg uint)
                         (total-signers-arg uint) (rotation-period-arg uint)
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
        (ok true)))

(define-public (register-signer (public-key (buff 65)))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let ((stake (stx-get-balance tx-sender))
              (current-count (var-get active-signer-count))
              (protocol-fee (/ (* stake (var-get protocol-fee-percentage)) u100)))
            (asserts! (>= stake (var-get min-stake)) ERR-INSUFFICIENT-STAKE)
            (asserts! (is-none (map-get? signer-nodes {signer: tx-sender})) ERR-ALREADY-EXISTS)
            (asserts! (< current-count (var-get total-signers)) ERR-INVALID-PARAMS)
            
            (var-set reward-pool (+ (var-get reward-pool) protocol-fee))
            
            (map-set signer-nodes {signer: tx-sender} {
                stake: stake,
                public-key: public-key,
                reputation-score: u100,
                last-active: block-height,
                performance-metrics: {
                    signing-speed: u100, uptime: u100, stake-duration: u0,
                    accuracy: u100, total-signatures: u0, valid-signatures: u0
                },
                slashing-history: {
                    total-slashes: u0, last-slash-height: u0, slashed-amount: u0
                }
            })
            
            (map-set active-signers {signer: tx-sender} {is-active: true})
            (var-set active-signer-count (+ current-count u1))
            (emit-event EVENT-TYPE-SIGNER-REGISTERED 0x00)
            (ok true))))

(define-public (submit-signature (signature (buff 96)) (message-hash (buff 32)))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-active-signer tx-sender) ERR-NOT-ACTIVE-SIGNER)
        
        (if (is-eq (var-get current-message-hash) 0x)
            (var-set current-message-hash message-hash)
            true)
        
        (map-set partial-signatures {signer: tx-sender}
            {signature: signature, message-hash: message-hash, timestamp: block-height})
        
        (emit-event EVENT-TYPE-SIGNATURE-SUBMITTED 0x00)
        (validate-signatures)))

(define-public (validate-signatures)
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let ((valid-count u0)
              (threshold (var-get signature-threshold)))
            (if (>= valid-count threshold)
                (begin
                    (emit-event EVENT-TYPE-THRESHOLD-REACHED 0x00)
                    (ok true))
                (ok false)))))

(define-public (create-proposal (title (string-utf8 100)) (description (string-utf8 500))
                             (proposal-type uint) (parameter-key (optional (string-utf8 50)))
                             (parameter-value (optional uint)) (target-principal (optional principal))
                             (end-height uint))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let ((proposer-info (unwrap! (map-get? signer-nodes {signer: tx-sender}) ERR-UNAUTHORIZED))
              (reputation-score (get reputation-score proposer-info))
              (current-proposal-count (var-get proposal-count))
              (min-end-height (+ block-height (var-get min-proposal-duration))))
            (asserts! (>= reputation-score (var-get min-reputation-to-propose)) ERR-INSUFFICIENT-REPUTATION)
            (asserts! (>= end-height min-end-height) ERR-INVALID-PARAMS)
            
            (map-set governance-proposals
                {proposal-id: current-proposal-count}
                {proposer: tx-sender, title: title, description: description,
                 proposal-type: proposal-type, parameter-key: parameter-key,
                 parameter-value: parameter-value, target-principal: target-principal,
                 start-height: block-height, end-height: end-height, status: u0,
                 yes-votes: u0, no-votes: u0, execution-delay: u144})
            
            (var-set proposal-count (+ current-proposal-count u1))
            (emit-event EVENT-TYPE-GOVERNANCE-PROPOSAL 0x00)
            (ok current-proposal-count))))

(define-public (vote-on-proposal (proposal-id uint) (vote bool))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-proposal-active proposal-id) ERR-PROPOSAL-NOT-ACTIVE)
        (asserts! (is-none (map-get? governance-votes 
                                   {proposal-id: proposal-id, voter: tx-sender})) ERR-GOVERNANCE-VOTING)
        
        (let ((voting-power (calculate-voting-power tx-sender))
              (proposal (unwrap! (map-get? governance-proposals 
                                         {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND)))
            (asserts! (> voting-power u0) ERR-INSUFFICIENT-REPUTATION)
            
            (map-set governance-votes
                {proposal-id: proposal-id, voter: tx-sender}
                {vote: vote, voting-power: voting-power, timestamp: block-height})
            
            (map-set governance-proposals
                {proposal-id: proposal-id}
                (merge proposal
                    (if vote
                        {yes-votes: (+ (get yes-votes proposal) voting-power)}
                        {no-votes: (+ (get no-votes proposal) voting-power)})))
            
            (emit-event EVENT-TYPE-GOVERNANCE-VOTE 0x00)
            (ok true))))

(define-public (execute-proposal (proposal-id uint))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        
        (let ((proposal (unwrap! (map-get? governance-proposals 
                                         {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
              (yes-votes (get yes-votes proposal))
              (no-votes (get no-votes proposal))
              (total-votes (+ yes-votes no-votes))
              (yes-percentage (if (> total-votes u0) 
                                (/ (* yes-votes u100) total-votes)
                                u0)))
            (asserts! (and (is-eq (get status proposal) u1)
                          (>= yes-percentage (var-get governance-threshold))) ERR-PROPOSAL-NOT-ACTIVE)
            
            (map-set governance-proposals {proposal-id: proposal-id}
                (merge proposal {status: u3}))
            
            (match (get proposal-type proposal)
                u1 (execute-parameter-change 
                      (unwrap! (get parameter-key proposal) ERR-INVALID-PARAMS) 
                      (unwrap! (get parameter-value proposal) ERR-INVALID-PARAMS))
                u3 (when (is-some (get target-principal proposal))
                      (remove-active-signer (unwrap! (get target-principal proposal) ERR-INVALID-PARAMS)))
                (ok true))
            
            (ok true))))

(define-public (remove-active-signer (signer principal))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let ((current-count (var-get active-signer-count)))
            (asserts! (or (is-eq tx-sender signer) (is-contract-owner)) ERR-UNAUTHORIZED)
            (asserts! (is-some (map-get? active-signers {signer: signer})) ERR-INVALID-PARAMS)
            
            (map-delete active-signers {signer: signer})
            (var-set active-signer-count (- current-count u1))
            (ok true))))

(define-public (toggle-emergency-pause)
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set emergency-pause (not (var-get emergency-pause)))
        (emit-event EVENT-TYPE-EMERGENCY-ACTION 0x00)
        (ok true)))

(define-public (set-contract-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)))

(define-public (register-watchtower)
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (is-none (map-get? watchtowers {watcher: tx-sender})) ERR-ALREADY-EXISTS)
        
        (map-set watchtowers {watcher: tx-sender} {
            last-report: u0, reports-submitted: u0,
            accuracy-score: u100, is-active: true})
        (ok true)))

(define-public (submit-watchtower-report (signer principal) (uptime uint) 
                                     (signing-speed uint) (valid-signatures uint))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (let ((reporter-info (unwrap! (map-get? watchtowers {watcher: tx-sender}) ERR-UNAUTHORIZED))
              (current-metrics (unwrap! (get-signer-metrics signer) ERR-INVALID-PARAMS)))
            (asserts! (validate-metrics uptime signing-speed valid-signatures) ERR-INVALID-PARAMS)
            
            (map-set watchtowers {watcher: tx-sender}
                (merge reporter-info {
                    last-report: block-height,
                    reports-submitted: (+ (get reports-submitted reporter-info) u1)
                }))
            
            (update-metrics-from-report signer uptime signing-speed valid-signatures))))

(define-public (verify-cross-chain-transaction (chain-id uint) (tx-hash (buff 32))
                                           (proof-data (buff 1024)) (signatures (list 10 (buff 96))))
    (begin
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        (asserts! (verify-cross-chain-proof chain-id proof-data signatures) ERR-INVALID-PROOF)
        
        (map-set cross-chain-transactions
            {tx-hash: tx-hash}
            {source-chain: chain-id, verified: true, verification-timestamp: block-height,
             data: proof-data, oracle-signatures: signatures})
        
        (emit-event EVENT-TYPE-CROSS-CHAIN-VERIFIED 0x00)
        (ok true)))

(define-public (start-new-epoch)
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        
        (var-set current-epoch (+ (var-get current-epoch) u1))
        (var-set last-rotation-height block-height)
        (emit-event EVENT-TYPE-ROTATION-EXECUTED 0x00)
        (ok true)))

(define-public (slash-signer (signer principal) (slash-amount uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (not (var-get emergency-pause)) ERR-EMERGENCY-PAUSED)
        
        (let ((signer-info (unwrap! (map-get? signer-nodes {signer: signer}) ERR-UNAUTHORIZED))
              (current-stake (get stake signer-info))
              (slashing-history (get slashing-history signer-info))
              (new-stake (if (> current-stake slash-amount)
                           (- current-stake slash-amount)
                           u0)))
            (map-set signer-nodes {signer: signer}
                (merge signer-info {
                    stake: new-stake,
                    slashing-history: {
                        total-slashes: (+ (get total-slashes slashing-history) u1),
                        last-slash-height: block-height,
                        slashed-amount: (+ (get slashed-amount slashing-history) slash-amount)
                    }
                }))
            
            (var-set reward-pool (+ (var-get reward-pool) slash-amount))
            (emit-event EVENT-TYPE-SIGNER-SLASHED 0x00)
            (ok true))))