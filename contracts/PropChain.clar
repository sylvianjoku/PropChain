;; PropChain - Real Estate Property Registry System
;; Version: 1.0.0
;; Track property ownership and transactions with agent validation

(define-map properties uint {
  owner: principal,
  property-address: (string-utf8 64),
  listing-details: (string-utf8 256),
  listing-date: uint,
  district-location: (string-utf8 64),
  transaction-validated: bool
})

(define-map owner-properties principal (list 100 uint))
(define-map certified-agents principal bool)
(define-data-var property-id-generator uint u0)

;; Error codes
(define-constant err-not-owner (err u700))
(define-constant err-not-agent (err u701))
(define-constant err-property-not-found (err u702))
(define-constant err-access-restricted (err u703))
(define-constant err-property-limit-exceeded (err u704))
(define-constant err-invalid-agent-address (err u705))
(define-constant err-invalid-property-address (err u706))
(define-constant err-invalid-listing-details (err u707))
(define-constant err-invalid-listing-date (err u708))
(define-constant err-invalid-district-name (err u709))
(define-constant err-invalid-property-id (err u710))

;; Registry administrator for agent certification
(define-constant registry-admin tx-sender)

;; Register certified real estate agent
(define-public (register-certified-agent (agent principal))
  (begin
    ;; Check if sender is registry administrator
    (asserts! (is-eq tx-sender registry-admin) err-access-restricted)
    
    ;; Validate agent principal
    (asserts! (not (is-eq agent 'SP000000000000000000002Q6VF78)) err-invalid-agent-address)
    
    ;; Add agent to registry
    (ok (map-set certified-agents agent true))
  ))

;; Register property listing
(define-public (register-property-listing
  (property-address (string-utf8 64))
  (listing-details (string-utf8 256))
  (listing-date uint)
  (district-location (string-utf8 64)))
  (let
    ((property-id (var-get property-id-generator))
     (owner tx-sender)
     (current-properties (default-to (list) (map-get? owner-properties owner))))
    
    ;; Validate inputs
    (asserts! (> (len property-address) u0) err-invalid-property-address)
    (asserts! (> (len listing-details) u0) err-invalid-listing-details)
    (asserts! (> listing-date u0) err-invalid-listing-date)
    (asserts! (> (len district-location) u0) err-invalid-district-name)
    
    ;; Check property limit
    (asserts! (< (len current-properties) u100) err-property-limit-exceeded)
    
    ;; Store property information
    (map-set properties property-id {
      owner: owner,
      property-address: property-address,
      listing-details: listing-details,
      listing-date: listing-date,
      district-location: district-location,
      transaction-validated: false
    })
    
    ;; Update owner properties
    (let
      ((updated-properties (unwrap-panic (as-max-len? (concat (list property-id) current-properties) u100))))
      (map-set owner-properties owner updated-properties)
    )
    
    ;; Increment property ID generator
    (var-set property-id-generator (+ property-id u1))
    
    (ok property-id)))

;; Validate property transaction
(define-public (validate-property-transaction (property-id uint))
  (begin
    ;; Validate property ID
    (asserts! (< property-id (var-get property-id-generator)) err-invalid-property-id)
    
    (let
      ((property (unwrap! (map-get? properties property-id) err-property-not-found)))
      
      ;; Check if sender is certified agent
      (asserts! (default-to false (map-get? certified-agents tx-sender)) err-not-agent)
      
      ;; Update property transaction validation status
      (ok (map-set properties property-id (merge property {transaction-validated: true})))
    )
  ))

;; Get property details
(define-read-only (get-property (property-id uint))
  (map-get? properties property-id))

;; Get owner properties
(define-read-only (get-owner-properties (owner principal))
  (default-to (list) (map-get? owner-properties owner)))

;; Check certified agent status
(define-read-only (is-certified-agent (address principal))
  (default-to false (map-get? certified-agents address)))

;; Get total properties
(define-read-only (get-total-properties)
  (var-get property-id-generator))

;; Get registry stats
(define-read-only (get-registry-stats)
  {
    admin: registry-admin,
    total-properties: (var-get property-id-generator)
  })