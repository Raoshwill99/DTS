;; Compact Distributed Threshold Signing Network
;; Essential functions only - streamlined implementation

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMS (err u101))
(define-constant ERR-INSUFFICIENT-STAKE (err u102))
(define-constant ERR-NOT-ACTIVE-SIGNER (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-THRESHOLD-NOT-REACHED (err u105))

;; Contract Controls
(define-data-var contract-owner principal tx-sender)
(define-data-var signature-threshold uint u3)
(define-data-var min-stake uint u100000)
(define-data-var current-message-hash (buff 32) 0x)

;; Core Maps
(define-map signer-nodes {signer: principal} 
    {stake: uint, public-key: (buff 65), is-active: bool, reputation: uint})

(define-map partial-signatures {signer: principal} 
    {signature: (buff 96), message-hash: (buff 32), timestamp: uint})

(define-map active-signers {signer: principal} {is-active: bool})

;; Global State
(define-data-var active-signer-count uint u0)
(define-data-var total-signatures uint u0)

;; Private Functions
(define-private (is-contract-owner) 
    (is-eq tx-sender (var-get contract-owner)))

(define-private (is-active-signer (signer principal))
    (match (map-get? active-signers {signer: signer})
        entry (get is-active entry)
        false))

(define-private (count-valid-signatures)
    (let ((threshold (var-get signature-threshold))
          (current-hash (var-get current-message-hash)))
        (fold check-signature-validity 
              (list tx-sender) ;; simplified - in real implementation would iterate all signers
              u0)))

(define-private (check-signature-validity (signer principal) (count uint))
    (match (map-get? partial-signatures {signer: signer})
        sig-data (if (and (is-active-signer signer)
                         (is-eq (get message-hash sig-data) (var-get current-message-hash)))
                    (+ count u1)
                    count)
        count))

;; Read-Only Functions
(define-read-only (get-signer-info (signer principal))
    (map-get? signer-nodes {signer: signer}))

(define-read-only (get-threshold-status)
    {threshold: (var-get signature-threshold),
     active-signers: (var-get active-signer-count),
     total-signatures: (var-get total-signatures),
     current-message: (var-get current-message-hash)})

(define-read-only (get-contract-stats)
    {owner: (var-get contract-owner),
     min-stake: (var-get min-stake),
     active-count: (var-get active-signer-count)})

;; Core Public Functions
(define-public (initialize (threshold uint) (min-stake-amount uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (> threshold u0) ERR-INVALID-PARAMS)
        (asserts! (> min-stake-amount u0) ERR-INVALID-PARAMS)
        
        (var-set signature-threshold threshold)
        (var-set min-stake min-stake-amount)
        (ok true)))

(define-public (register-signer (public-key (buff 65)))
    (let ((stake (stx-get-balance tx-sender)))
        (asserts! (>= stake (var-get min-stake)) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (map-get? signer-nodes {signer: tx-sender})) ERR-ALREADY-EXISTS)
        
        (map-set signer-nodes {signer: tx-sender} {
            stake: stake,
            public-key: public-key,
            is-active: true,
            reputation: u100
        })
        
        (map-set active-signers {signer: tx-sender} {is-active: true})
        (var-set active-signer-count (+ (var-get active-signer-count) u1))
        (ok true)))

(define-public (submit-signature (signature (buff 96)) (message-hash (buff 32)))
    (begin
        (asserts! (is-active-signer tx-sender) ERR-NOT-ACTIVE-SIGNER)
        
        ;; Set current message hash if not set
        (if (is-eq (var-get current-message-hash) 0x)
            (var-set current-message-hash message-hash)
            true)
        
        ;; Store signature
        (map-set partial-signatures {signer: tx-sender}
            {signature: signature, message-hash: message-hash, timestamp: block-height})
        
        (var-set total-signatures (+ (var-get total-signatures) u1))
        (ok true)))

(define-public (validate-threshold)
    (let ((valid-count (count-valid-signatures))
          (threshold (var-get signature-threshold)))
        (if (>= valid-count threshold)
            (begin
                ;; Reset for next signing round
                (var-set current-message-hash 0x)
                (var-set total-signatures u0)
                (ok true))
            (err ERR-THRESHOLD-NOT-REACHED))))

(define-public (remove-signer (signer principal))
    (begin
        (asserts! (or (is-eq tx-sender signer) (is-contract-owner)) ERR-UNAUTHORIZED)
        (asserts! (is-some (map-get? active-signers {signer: signer})) ERR-INVALID-PARAMS)
        
        (map-delete active-signers {signer: signer})
        (map-delete partial-signatures {signer: signer})
        (var-set active-signer-count (- (var-get active-signer-count) u1))
        (ok true)))

(define-public (update-threshold (new-threshold uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (asserts! (and (> new-threshold u0) 
                      (<= new-threshold (var-get active-signer-count))) ERR-INVALID-PARAMS)
        
        (var-set signature-threshold new-threshold)
        (ok true)))

(define-public (set-owner (new-owner principal))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)))
        