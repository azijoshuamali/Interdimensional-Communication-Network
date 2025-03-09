;; Cross-reality Message Routing Contract
;; Routes messages between different realities/dimensions

(define-map messages
  { id: uint }
  {
    sender: principal,
    source-reality: uint,
    destination-reality: uint,
    content-hash: (buff 32),
    status: (string-ascii 20),
    timestamp: uint
  }
)

(define-map reality-routes
  { source: uint, destination: uint }
  {
    is-open: bool,
    hop-count: uint,
    last-active: uint
  }
)

(define-data-var next-message-id uint u0)

;; Send a message to another reality
(define-public (send-message (source-reality uint) (destination-reality uint) (content-hash (buff 32)))
  (let
    ((message-id (var-get next-message-id)))

    ;; Check if route exists and is open
    (asserts! (route-exists source-reality destination-reality) (err u404))

    ;; Store the message
    (map-set messages
      { id: message-id }
      {
        sender: tx-sender,
        source-reality: source-reality,
        destination-reality: destination-reality,
        content-hash: content-hash,
        status: "sent",
        timestamp: block-height
      }
    )

    ;; Update route activity
    (match (map-get? reality-routes { source: source-reality, destination: destination-reality })
      route
        (map-set reality-routes
          { source: source-reality, destination: destination-reality }
          (merge route { last-active: block-height })
        )
      false
    )

    ;; Increment message ID counter
    (var-set next-message-id (+ message-id u1))

    ;; Return the message ID
    (ok message-id)
  )
)

;; Update message status (e.g., when delivered or failed)
(define-public (update-message-status (message-id uint) (new-status (string-ascii 20)))
  (match (map-get? messages { id: message-id })
    message
      (begin
        ;; Only allow status updates for messages from the sender or to the receiver
        (asserts! (is-eq tx-sender (get sender message)) (err u403))

        ;; Update the message status
        (ok (map-set messages
          { id: message-id }
          (merge message { status: new-status })
        )))
    (err u404)
  )
)

;; Open a route between realities
(define-public (open-route (source-reality uint) (destination-reality uint) (hop-count uint))
  (ok (map-set reality-routes
    { source: source-reality, destination: destination-reality }
    {
      is-open: true,
      hop-count: hop-count,
      last-active: block-height
    }
  ))
)

;; Close a route between realities
(define-public (close-route (source-reality uint) (destination-reality uint))
  (match (map-get? reality-routes { source: source-reality, destination: destination-reality })
    route
      (ok (map-set reality-routes
        { source: source-reality, destination: destination-reality }
        (merge route { is-open: false })
      ))
    (err u404)
  )
)

;; Check if a route exists and is open
(define-read-only (route-exists (source-reality uint) (destination-reality uint))
  (match (map-get? reality-routes { source: source-reality, destination: destination-reality })
    route (get is-open route)
    false
  )
)

;; Get message details
(define-read-only (get-message (message-id uint))
  (map-get? messages { id: message-id })
)

;; Get route details
(define-read-only (get-route (source-reality uint) (destination-reality uint))
  (map-get? reality-routes { source: source-reality, destination: destination-reality })
)
