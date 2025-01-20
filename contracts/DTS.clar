;; Distributed Threshold Signing Network
;; Initial Implementation - Core Structure

;; Error codes
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-INVALID-PARAMS (err u101))
(define-constant ERR-INSUFFICIENT-STAKE (err u102))

;; Contract Owner
(define-data-var contract-owner principal tx-sender)

;; Data Variables
(define-data-var min-stake uint u100000) ;; Minimum stake required to be a signer
(define-data-var required-signers uint u3) ;; t in t-of-n
(define-data-var total-signers uint u5) ;; n in t-of-n
(define-data-var rotation-period uint u144) ;; ~1 day in blocks
(define-data-var active-signer-count uint u0) ;; Track number of active signers

;; Principal -> SignerNode mapping
(define-map signer-nodes
    principal
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
)

;; Active signers set
(define-map active-signers principal bool)

;; Check if caller is contract owner
(define-private (is-contract-owner)
    (is-eq tx-sender (var-get contract-owner))
)

;; Getter for signer information
(define-read-only (get-signer-info (signer principal))
    (map-get? signer-nodes signer)
)

;; Check if signer is active
(define-read-only (is-active-signer (signer principal))
    (default-to false (map-get? active-signers signer))
)

;; Get active signer count
(define-read-only (get-active-signer-count)
    (var-get active-signer-count)
)

;; Register new signer
(define-public (register-signer (public-key (buff 65)))
    (let
        (
            (stake (stx-get-balance tx-sender))
            (current-count (var-get active-signer-count))
        )
        (asserts! (>= stake (var-get min-stake)) ERR-INSUFFICIENT-STAKE)
        (asserts! (is-none (map-get? signer-nodes tx-sender)) ERR-UNAUTHORIZED)
        
        (map-set signer-nodes tx-sender {
            stake: stake,
            public-key: public-key,
            reputation-score: u100, ;; Initial reputation score
            last-active: block-height,
            performance-metrics: {
                signing-speed: u100,
                uptime: u100,
                stake-duration: u0,
                accuracy: u100
            }
        })
        
        ;; Add to active signers if slots available
        (if (< current-count (var-get total-signers))
            (begin
                (map-set active-signers tx-sender true)
                (var-set active-signer-count (+ current-count u1))
                (ok true)
            )
            (ok false)
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
        (asserts! (is-some (map-get? active-signers signer)) ERR-INVALID-PARAMS)
        
        (map-delete active-signers signer)
        (var-set active-signer-count (- current-count u1))
        (ok true)
    )
)

;; Update signer metrics
(define-public (update-metrics (signer principal) 
                             (signing-speed uint) 
                             (uptime uint)
                             (accuracy uint))
    (let
        (
            (current-info (unwrap! (map-get? signer-nodes signer) ERR-UNAUTHORIZED))
        )
        ;; Only contract owner or self can update metrics
        (asserts! (or (is-eq tx-sender signer) (is-contract-owner)) ERR-UNAUTHORIZED)
        
        (map-set signer-nodes signer
            (merge current-info {
                last-active: block-height,
                performance-metrics: {
                    signing-speed: signing-speed,
                    uptime: uptime,
                    stake-duration: (- block-height (get stake-duration (get performance-metrics current-info))),
                    accuracy: accuracy
                }
            })
        )
        (ok true)
    )
)

;; Calculate reputation score based on metrics
(define-private (calculate-reputation
    (metrics {
        signing-speed: uint,
        uptime: uint,
        stake-duration: uint,
        accuracy: uint
    }))
    (let
        (
            (speed-weight u25)
            (uptime-weight u25)
            (duration-weight u25)
            (accuracy-weight u25)
        )
        (+
            (* (get signing-speed metrics) speed-weight)
            (* (get uptime metrics) uptime-weight)
            (* (get stake-duration metrics) duration-weight)
            (* (get accuracy metrics) accuracy-weight)
        )
    )
)

;; Initialize contract
(define-public (initialize (min-stake-arg uint) 
                         (required-signers-arg uint)
                         (total-signers-arg uint)
                         (rotation-period-arg uint))
    (begin
        (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
        (var-set min-stake min-stake-arg)
        (var-set required-signers required-signers-arg)
        (var-set total-signers total-signers-arg)
        (var-set rotation-period rotation-period-arg)
        (ok true)
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