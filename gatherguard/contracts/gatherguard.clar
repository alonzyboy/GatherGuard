;; GatherGuard
;; A POAP (Proof of Attendance Protocol) smart contract with rewards

(define-non-fungible-token attendance-proof uint)
(define-non-fungible-token merit-token uint)

(define-map gatherings 
    { gathering-id: uint } 
    { 
        title: (string-ascii 50),
        timestamp: uint,
        capacity: uint,
        attendee-count: uint,
        merit-points: uint
    }
)

(define-map attendee-proofs 
    { attendee: principal } 
    { proofs: (list 100 uint) }
)

(define-map attendee-merits
    { attendee: principal }
    { 
        earned-points: uint,
        claimed-points: uint
    }
)

(define-map gathering-attendees
    { gathering-id: uint }
    { attendees: (list 1000 principal) }
)

(define-data-var proof-counter uint u0)
(define-data-var gathering-counter uint u0)

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-CAPACITY-REACHED (err u101))
(define-constant ERR-DUPLICATE-REGISTRATION (err u102))
(define-constant ERR-INSUFFICIENT-MERITS (err u103))
(define-constant ERR-MERIT-AWARD-FAILED (err u104))

;; Administrative Functions

(define-public (create-gathering (title (string-ascii 50)) (timestamp uint) (capacity uint) (merit-points uint))
    (let
        ((gathering-id (+ (var-get gathering-counter) u1)))
        (try! (is-contract-owner))
        (map-set gatherings 
            { gathering-id: gathering-id }
            {
                title: title,
                timestamp: timestamp,
                capacity: capacity,
                attendee-count: u0,
                merit-points: merit-points
            }
        )
        (var-set gathering-counter gathering-id)
        (ok gathering-id)
    )
)

;; Attendee Functions

(define-public (join-gathering (gathering-id uint))
    (let
        ((gathering (unwrap! (map-get? gatherings { gathering-id: gathering-id }) (err u404)))
         (current-attendees (get attendee-count gathering))
         (max-attendees (get capacity gathering)))
        
        ;; Check if gathering is full
        (asserts! (< current-attendees max-attendees) ERR-CAPACITY-REACHED)
        
        ;; Check if attendee is already registered
        (asserts! (is-not-attending tx-sender gathering-id) ERR-DUPLICATE-REGISTRATION)
        
        ;; Mint proof
        (let
            ((proof-id (+ (var-get proof-counter) u1))
             (points-result (grant-merits tx-sender (get merit-points gathering))))
            
            ;; Ensure points were awarded successfully
            (unwrap! points-result ERR-MERIT-AWARD-FAILED)
            
            ;; Update proof counter
            (var-set proof-counter proof-id)
            
            ;; Mint NFT proof
            (try! (nft-mint? attendance-proof proof-id tx-sender))
            
            ;; Update attendee proofs
            (map-set attendee-proofs
                { attendee: tx-sender }
                { proofs: (append-proof (default-to (list ) (get proofs (map-get? attendee-proofs { attendee: tx-sender }))) proof-id) }
            )
            
            ;; Update gathering attendees
            (map-set gatherings 
                { gathering-id: gathering-id }
                (merge gathering { attendee-count: (+ current-attendees u1) })
            )
            
            (ok proof-id)
        )
    )
)

(define-public (claim-merits (points uint))
    (let
        ((attendee-info (unwrap! (map-get? attendee-merits { attendee: tx-sender }) (err u404)))
         (available-points (- (get earned-points attendee-info) (get claimed-points attendee-info))))
        
        ;; Check if attendee has enough points
        (asserts! (>= available-points points) ERR-INSUFFICIENT-MERITS)
        
        ;; Update claimed points
        (map-set attendee-merits
            { attendee: tx-sender }
            { 
                earned-points: (get earned-points attendee-info),
                claimed-points: (+ (get claimed-points attendee-info) points)
            }
        )
        
        (ok points)
    )
)

;; Helper Functions

(define-private (is-contract-owner)
    (ok (asserts! (is-eq tx-sender contract-caller) ERR-UNAUTHORIZED))
)

(define-private (is-not-attending (attendee principal) (gathering-id uint))
    (is-none (index-of 
        (default-to (list ) 
            (get attendees (map-get? gathering-attendees { gathering-id: gathering-id }))
        )
        attendee
    ))
)

(define-private (append-proof (proofs (list 100 uint)) (proof-id uint))
    (unwrap! (as-max-len? (append proofs proof-id) u100) proofs)
)

(define-private (grant-merits (attendee principal) (points uint))
    (let
        ((current-merits (default-to { earned-points: u0, claimed-points: u0 } 
            (map-get? attendee-merits { attendee: attendee }))))
        (map-set attendee-merits
            { attendee: attendee }
            {
                earned-points: (+ (get earned-points current-merits) points),
                claimed-points: (get claimed-points current-merits)
            }
        )
        (ok points)
    )
)

;; Read-Only Functions

(define-read-only (get-attendee-proofs (attendee principal))
    (map-get? attendee-proofs { attendee: attendee })
)

(define-read-only (get-attendee-merits (attendee principal))
    (map-get? attendee-merits { attendee: attendee })
)

(define-read-only (get-gathering-details (gathering-id uint))
    (map-get? gatherings { gathering-id: gathering-id })
)

(define-read-only (get-gathering-attendees (gathering-id uint))
    (map-get? gathering-attendees { gathering-id: gathering-id })
)