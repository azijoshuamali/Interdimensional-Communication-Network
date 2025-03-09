;; Interdimensional Bandwidth Allocation Contract
;; Manages bandwidth allocation between different realities

(define-map bandwidth-pools
  { id: uint }
  {
    name: (string-utf8 64),
    total-capacity: uint,
    available-capacity: uint,
    manager: principal,
    creation-time: uint
  }
)

(define-map bandwidth-allocations
  { allocation-id: uint }
  {
    pool-id: uint,
    source-reality: uint,
    destination-reality: uint,
    allocated-amount: uint,
    expiration: uint,
    owner: principal
  }
)

(define-map bandwidth-usage
  { allocation-id: uint }
  {
    used-amount: uint,
    last-usage-time: uint
  }
)

(define-data-var next-pool-id uint u0)
(define-data-var next-allocation-id uint u0)

;; Create a new bandwidth pool
(define-public (create-bandwidth-pool (name (string-utf8 64)) (total-capacity uint))
  (let
    ((pool-id (var-get next-pool-id)))

    ;; Store the pool
    (map-set bandwidth-pools
      { id: pool-id }
      {
        name: name,
        total-capacity: total-capacity,
        available-capacity: total-capacity,
        manager: tx-sender,
        creation-time: block-height
      }
    )

    ;; Increment pool ID counter
    (var-set next-pool-id (+ pool-id u1))

    ;; Return the new pool ID
    (ok pool-id)
  )
)

;; Allocate bandwidth from a pool
(define-public (allocate-bandwidth (pool-id uint) (source-reality uint) (destination-reality uint)
                               (amount uint) (duration uint))
  (match (map-get? bandwidth-pools { id: pool-id })
    pool
      (begin
        ;; Check if enough bandwidth is available
        (asserts! (>= (get available-capacity pool) amount) (err u400))

        (let
          ((allocation-id (var-get next-allocation-id))
           (expiration (+ block-height duration)))

          ;; Update pool available capacity
          (map-set bandwidth-pools
            { id: pool-id }
            (merge pool { available-capacity: (- (get available-capacity pool) amount) })
          )

          ;; Create allocation
          (map-set bandwidth-allocations
            { allocation-id: allocation-id }
            {
              pool-id: pool-id,
              source-reality: source-reality,
              destination-reality: destination-reality,
              allocated-amount: amount,
              expiration: expiration,
              owner: tx-sender
            }
          )

          ;; Initialize usage tracking
          (map-set bandwidth-usage
            { allocation-id: allocation-id }
            {
              used-amount: u0,
              last-usage-time: block-height
            }
          )

          ;; Increment allocation ID counter
          (var-set next-allocation-id (+ allocation-id u1))

          ;; Return the new allocation ID
          (ok allocation-id)
        ))
    (err u404)
  )
)

;; Record bandwidth usage
(define-public (record-usage (allocation-id uint) (amount uint))
  (match (map-get? bandwidth-allocations { allocation-id: allocation-id })
    allocation
      (begin
        ;; Check if allocation is still valid
        (asserts! (< block-height (get expiration allocation)) (err u400))

        ;; Check if caller is the owner
        (asserts! (is-eq tx-sender (get owner allocation)) (err u403))

        (match (map-get? bandwidth-usage { allocation-id: allocation-id })
          usage
            (let
              ((new-used-amount (+ (get used-amount usage) amount)))

              ;; Check if usage exceeds allocation
              (asserts! (<= new-used-amount (get allocated-amount allocation)) (err u400))

              ;; Update usage
              (ok (map-set bandwidth-usage
                { allocation-id: allocation-id }
                {
                  used-amount: new-used-amount,
                  last-usage-time: block-height
                }
              )))
          (err u404))
      )
    (err u404)
  )
)

;; Release bandwidth allocation back to the pool
(define-public (release-allocation (allocation-id uint))
  (match (map-get? bandwidth-allocations { allocation-id: allocation-id })
    allocation
      (begin
        ;; Check if caller is the owner
        (asserts! (is-eq tx-sender (get owner allocation)) (err u403))

        (match (map-get? bandwidth-pools { id: (get pool-id allocation) })
          pool
            (let
              ((remaining-amount (- (get allocated-amount allocation)
                                   (get used-amount (default-to { used-amount: u0, last-usage-time: u0 }
                                                   (map-get? bandwidth-usage { allocation-id: allocation-id }))))))

              ;; Return unused bandwidth to the pool
              (map-set bandwidth-pools
                { id: (get pool-id allocation) }
                (merge pool { available-capacity: (+ (get available-capacity pool) remaining-amount) })
              )

              ;; Delete the allocation
              (map-delete bandwidth-allocations { allocation-id: allocation-id })
              (map-delete bandwidth-usage { allocation-id: allocation-id })

              (ok true))
          (err u404))
      )
    (err u404)
  )
)

;; Get bandwidth pool details
(define-read-only (get-bandwidth-pool (pool-id uint))
  (map-get? bandwidth-pools { id: pool-id })
)

;; Get allocation details
(define-read-only (get-allocation (allocation-id uint))
  (map-get? bandwidth-allocations { allocation-id: allocation-id })
)

;; Get usage details
(define-read-only (get-usage (allocation-id uint))
  (map-get? bandwidth-usage { allocation-id: allocation-id })
)

;; Check if allocation is active
(define-read-only (is-allocation-active (allocation-id uint))
  (match (map-get? bandwidth-allocations { allocation-id: allocation-id })
    allocation (< block-height (get expiration allocation))
    false
  )
)

;; Calculate remaining bandwidth in an allocation
(define-read-only (get-remaining-bandwidth (allocation-id uint))
  (match (map-get? bandwidth-allocations { allocation-id: allocation-id })
    allocation
      (match (map-get? bandwidth-usage { allocation-id: allocation-id })
        usage (- (get allocated-amount allocation) (get used-amount usage))
        (get allocated-amount allocation))
    u0
  )
)
