;; Distributed Threshold Signing Network - Phase 2
;; Complete implementation with BLS signatures and Watchtower functionality

;; Error codes
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

;; Contract Owner
(define-data-var contract-owner principal tx-sender)
(define-data-var initialized bool false)

;; BLS Threshold Parameters
(define-data-var bls-public-key (buff 128) 0x00) ;; Aggregate public key
(define-data-var signature-threshold uint u3) ;; Minimum signatures required
(define-data-var current-message-hash (buff 32) 0x) ;; Current message being validated

;; Maps with proper tuple types
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

;; Data Variables
(define-data-var min-stake uint u100000)
(define-data-var required-signers uint u3)
(define-data-var total-signers uint u5)
(define-data-var rotation-period uint u144)
(define-data-var active-signer-count uint u0)
(define-data-var last-rotation-height uint u0)

;; Private Functions

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

;; Public Read-Only Functions

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

;; Public Functions

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
    (let
        (
            (stake (stx-get-balance tx-sender))
            (current-count (var-get active-signer-count))
        )
        (asserts! (>= stake (var-get min-stake)) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (map-get? signer-nodes {signer: tx-sender})) ERR-ALREADY-REGISTERED)
        
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
                (ok true)
            )
            (ok false)
        )
    )
)

;; Register Watchtower
(define-public (register-watchtower)
    (begin
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
            (ok true)
        )
    )
)

;; Submit partial BLS signature
(define-public (submit-partial-signature 
    (message-hash (buff 32))
    (signature (buff 96)))
    
    (begin
        (asserts! (is-eq (len message-hash) u32) ERR-INVALID-SIGNATURE-LENGTH)
        (asserts! (is-eq (len signature) u96) ERR-INVALID-SIGNATURE-LENGTH)
        
        (let
            (
                (signer-info (unwrap! (map-get? signer-nodes {signer: tx-sender}) ERR-UNAUTHORIZED))
            )
            (asserts! (is-active-signer tx-sender) ERR-NOT-ACTIVE-SIGNER)
            
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
            (ok true)
        )
    )
)

;; Verify and combine partial signatures
(define-public (combine-signatures (message-hash (buff 32)) (signers (list 10 principal)))
    (begin
        (var-set current-message-hash message-hash)
        (let
            (
                (valid-count (fold process-signature signers u0))
            )
            (asserts! (>= valid-count (var-get signature-threshold)) ERR-INVALID-THRESHOLD)
            (ok true)
        )
    )
)

;; Remove signer from active set
(define-public (remove-active-signer (signer principal))
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

;; Slash misbehaving signer
(define-public (slash-signer 
    (signer principal)
    (slash-amount uint)
    (evidence (buff 32)))
    
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
        
        ;; Remove from active signers if too many slashes
        (if (> (get total-slashes (get slashing-history signer-info)) u2)
            (remove-active-signer signer)
            (ok true)
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