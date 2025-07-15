;; CO2 Market - Carbon Credit Trading Contract
;; A smart contract for trading verified carbon offset certificates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-not-verified (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-unauthorized (err u106))

;; Data Variables
(define-data-var next-certificate-id uint u1)
(define-data-var platform-fee uint u250) ;; 2.5% fee (250 basis points)

;; Data Maps
(define-map certificates
  { certificate-id: uint }
  {
    issuer: principal,
    owner: principal,
    project-name: (string-ascii 100),
    co2-amount: uint, ;; in tons
    verification-standard: (string-ascii 50),
    issue-date: uint,
    is-verified: bool,
    is-retired: bool
  }
)

(define-map certificate-balances
  { owner: principal, certificate-id: uint }
  { balance: uint }
)

(define-map marketplace-listings
  { certificate-id: uint }
  {
    seller: principal,
    price-per-ton: uint, ;; in microSTX
    quantity: uint,
    is-active: bool
  }
)

(define-map verifiers
  { verifier: principal }
  { is-authorized: bool }
)

;; Authorization Functions
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set verifiers { verifier: verifier } { is-authorized: true }))
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set verifiers { verifier: verifier } { is-authorized: false }))
  )
)

;; Certificate Management Functions
(define-public (issue-certificate 
  (project-name (string-ascii 100))
  (co2-amount uint)
  (verification-standard (string-ascii 50))
)
  (let
    (
      (certificate-id (var-get next-certificate-id))
    )
    (asserts! (> co2-amount u0) err-invalid-amount)
    (map-set certificates
      { certificate-id: certificate-id }
      {
        issuer: tx-sender,
        owner: tx-sender,
        project-name: project-name,
        co2-amount: co2-amount,
        verification-standard: verification-standard,
        issue-date: block-height,
        is-verified: false,
        is-retired: false
      }
    )
    (map-set certificate-balances
      { owner: tx-sender, certificate-id: certificate-id }
      { balance: co2-amount }
    )
    (var-set next-certificate-id (+ certificate-id u1))
    (ok certificate-id)
  )
)

(define-public (verify-certificate (certificate-id uint))
  (let
    (
      (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id }) err-not-found))
      (verifier-data (unwrap! (map-get? verifiers { verifier: tx-sender }) err-unauthorized))
    )
    (asserts! (get is-authorized verifier-data) err-unauthorized)
    (map-set certificates
      { certificate-id: certificate-id }
      (merge certificate { is-verified: true })
    )
    (ok true)
  )
)

;; Trading Functions
(define-public (list-for-sale 
  (certificate-id uint)
  (price-per-ton uint)
  (quantity uint)
)
  (let
    (
      (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id }) err-not-found))
      (balance (default-to u0 (get balance (map-get? certificate-balances { owner: tx-sender, certificate-id: certificate-id }))))
    )
    (asserts! (get is-verified certificate) err-not-verified)
    (asserts! (not (get is-retired certificate)) err-not-found)
    (asserts! (>= balance quantity) err-insufficient-balance)
    (asserts! (> quantity u0) err-invalid-amount)
    (asserts! (> price-per-ton u0) err-invalid-amount)
    
    (map-set marketplace-listings
      { certificate-id: certificate-id }
      {
        seller: tx-sender,
        price-per-ton: price-per-ton,
        quantity: quantity,
        is-active: true
      }
    )
    (ok true)
  )
)

(define-public (cancel-listing (certificate-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings { certificate-id: certificate-id }) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (map-set marketplace-listings
      { certificate-id: certificate-id }
      (merge listing { is-active: false })
    )
    (ok true)
  )
)

(define-public (purchase-credits 
  (certificate-id uint)
  (quantity uint)
)
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings { certificate-id: certificate-id }) err-not-found))
      (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id }) err-not-found))
      (seller (get seller listing))
      (price-per-ton (get price-per-ton listing))
      (total-price (* price-per-ton quantity))
      (platform-fee-amount (/ (* total-price (var-get platform-fee)) u10000))
      (seller-amount (- total-price platform-fee-amount))
      (seller-balance (default-to u0 (get balance (map-get? certificate-balances { owner: seller, certificate-id: certificate-id }))))
      (buyer-balance (default-to u0 (get balance (map-get? certificate-balances { owner: tx-sender, certificate-id: certificate-id }))))
    )
    (asserts! (get is-active listing) err-not-found)
    (asserts! (get is-verified certificate) err-not-verified)
    (asserts! (not (get is-retired certificate)) err-not-found)
    (asserts! (>= (get quantity listing) quantity) err-insufficient-balance)
    (asserts! (> quantity u0) err-invalid-amount)
    
    ;; Transfer STX from buyer to seller and contract owner
    (try! (stx-transfer? seller-amount tx-sender seller))
    (try! (stx-transfer? platform-fee-amount tx-sender contract-owner))
    
    ;; Update balances
    (map-set certificate-balances
      { owner: seller, certificate-id: certificate-id }
      { balance: (- seller-balance quantity) }
    )
    
    (map-set certificate-balances
      { owner: tx-sender, certificate-id: certificate-id }
      { balance: (+ buyer-balance quantity) }
    )
    
    ;; Update listing
    (if (is-eq (get quantity listing) quantity)
      (map-set marketplace-listings
        { certificate-id: certificate-id }
        (merge listing { is-active: false, quantity: u0 })
      )
      (map-set marketplace-listings
        { certificate-id: certificate-id }
        (merge listing { quantity: (- (get quantity listing) quantity) })
      )
    )
    
    (ok true)
  )
)

;; Retirement Function
(define-public (retire-credits 
  (certificate-id uint)
  (quantity uint)
)
  (let
    (
      (certificate (unwrap! (map-get? certificates { certificate-id: certificate-id }) err-not-found))
      (balance (default-to u0 (get balance (map-get? certificate-balances { owner: tx-sender, certificate-id: certificate-id }))))
    )
    (asserts! (get is-verified certificate) err-not-verified)
    (asserts! (>= balance quantity) err-insufficient-balance)
    (asserts! (> quantity u0) err-invalid-amount)
    
    (map-set certificate-balances
      { owner: tx-sender, certificate-id: certificate-id }
      { balance: (- balance quantity) }
    )
    
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-certificate (certificate-id uint))
  (map-get? certificates { certificate-id: certificate-id })
)

(define-read-only (get-balance (owner principal) (certificate-id uint))
  (default-to u0 (get balance (map-get? certificate-balances { owner: owner, certificate-id: certificate-id })))
)

(define-read-only (get-listing (certificate-id uint))
  (map-get? marketplace-listings { certificate-id: certificate-id })
)

(define-read-only (is-verifier (verifier principal))
  (default-to false (get is-authorized (map-get? verifiers { verifier: verifier })))
)

(define-read-only (get-next-certificate-id)
  (var-get next-certificate-id)
)

(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

;; Admin Functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10% fee
    (ok (var-set platform-fee new-fee))
  )
)