;; GatherGuard
;; A POAP (Proof of Attendance Protocol) smart contract with cross-platform rewards

(define-non-fungible-token attendance-proof uint)
(define-non-fungible-token merit-token uint)

(define-map gatherings 
    { gathering-id: uint } 
    { 
        title: (string-ascii 50),
        timestamp: uint,
        capacity: uint,
        attendee-count: uint,
        merit-points: uint,
        network-tags: (list 10 (string-ascii 20))
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
        claimed-points: uint,
        network-multipliers: (list 10 uint)
    }
)

(define-map gathering-attendees
    { gathering-id: uint }
    { attendees: (list 1000 principal) }
)

(define-map network-partnerships
    { network-tag: (string-ascii 20) }
    { partnership-multiplier: uint }
)

(define-data-var proof-counter uint u0)
(define-data-var gathering-counter uint u0)

;; Error constants
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-CAPACITY-REACHED (err u101))
(define-constant ERR-DUPLICATE-REGISTRATION (err u102))
(define-constant ERR-INSUFFICIENT-MERITS (err u103))
(define-constant ERR-MERIT-AWARD-FAILED (err u104))
(define-constant ERR-INVALID-GATHERING-PARAMS (err u105))
(define-constant ERR-NETWORK-NOT-FOUND (err u106))
(define-constant ERR-INVALID-NETWORK-TAG (err u107))

;; Validation Constants
(define-constant MAX-GATHERING-TITLE-LENGTH u50)
(define-constant MAX-ATTENDEES u1000)
(define-constant MAX-MERIT-POINTS u10000)
(define-constant MAX-NETWORK-TAGS u10)
(define-constant MAX-PARTNERSHIP-MULTIPLIER u5)
(define-constant MAX-NETWORK-TAG-LENGTH u20)

;; Administrative Functions

(define-public (create-network-partnership 
    (network-tag (string-ascii 20)) 
    (multiplier uint)
)
    (begin
        ;; Validate network-tag
        (asserts! 
            (and 
                (> (len network-tag) u0)
                (<= (len network-tag) MAX-NETWORK-TAG-LENGTH)
            ) 
            ERR-INVALID-NETWORK-TAG
        )

        ;; Validate multiplier
        (asserts! 
            (and 
                (> multiplier u0)
                (<= multiplier MAX-PARTNERSHIP-MULTIPLIER)
            ) 
            ERR-INVALID-GATHERING-PARAMS
        )

        (try! (is-contract-owner))
        (map-set network-partnerships 
            { network-tag: network-tag }
            { partnership-multiplier: multiplier }
        )
        (ok network-tag)
    )
)

(define-public (create-gathering 
    (title (string-ascii 50)) 
    (timestamp uint) 
    (capacity uint) 
    (merit-points uint)
    (network-tags (list 10 (string-ascii 20)))
)
    ;; Input validation
    (begin
        ;; Validate gathering title length
        (asserts! 
            (and 
                (> (len title) u0)
                (<= (len title) MAX-GATHERING-TITLE-LENGTH)
            ) 
            ERR-INVALID-GATHERING-PARAMS
        )

        ;; Validate network tags
        (asserts! 
            (<= (len network-tags) MAX-NETWORK-TAGS) 
            ERR-INVALID-GATHERING-PARAMS
        )

        ;; Validate timestamp (ensure it's a future date)
        (asserts! (> timestamp block-height) ERR-INVALID-GATHERING-PARAMS)

        ;; Validate capacity
        (asserts! 
            (and 
                (> capacity u0)
                (<= capacity MAX-ATTENDEES)
            ) 
            ERR-INVALID-GATHERING-PARAMS
        )

        ;; Validate merit points
        (asserts! 
            (and 
                (> merit-points u0)
                (<= merit-points MAX-MERIT-POINTS)
            ) 
            ERR-INVALID-GATHERING-PARAMS
        )

        ;; Proceed with gathering creation
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
                    merit-points: merit-points,
                    network-tags: network-tags
                }
            )
            (var-set gathering-counter gathering-id)
            (ok gathering-id)
        )
    )
)

(define-public (join-gathering (gathering-id uint))
    (let
        ((gathering (unwrap! (map-get? gatherings { gathering-id: gathering-id }) (err u404)))
         (current-count (get attendee-count gathering))
         (max-count (get capacity gathering)))
        
        ;; Check if gathering is full
        (asserts! (< current-count max-count) ERR-CAPACITY-REACHED)
        
        ;; Check if attendee is already registered
        (asserts! (is-not-attending tx-sender gathering-id) ERR-DUPLICATE-REGISTRATION)
        
        ;; Mint proof and calculate cross-network points
        (let
            ((proof-id (+ (var-get proof-counter) u1))
             (points-result (calculate-cross-network-points 
                 tx-sender 
                 (get merit-points gathering) 
                 (get network-tags gathering)
             )))
            
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
                (merge gathering { attendee-count: (+ current-count u1) })
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
                claimed-points: (+ (get claimed-points attendee-info) points),
                network-multipliers: (get network-multipliers attendee-info)
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

(define-private (calculate-cross-network-points 
    (attendee principal) 
    (base-points uint)
    (gathering-networks (list 10 (string-ascii 20)))
)
    (let
        ((current-merits (default-to 
            { 
                earned-points: u0, 
                claimed-points: u0, 
                network-multipliers: (list ) 
            } 
            (map-get? attendee-merits { attendee: attendee })))
         (network-bonus (calculate-network-bonus gathering-networks)))
        
        (map-set attendee-merits
            { attendee: attendee }
            {
                earned-points: (+ 
                    (get earned-points current-merits) 
                    (* base-points (+ u1 network-bonus))
                ),
                claimed-points: (get claimed-points current-merits),
                network-multipliers: (append-multiplier 
                    (get network-multipliers current-merits) 
                    network-bonus
                )
            }
        )
        (ok base-points)
    )
)

(define-private (calculate-network-bonus (networks (list 10 (string-ascii 20))))
    (fold 
        + 
        (map get-network-multiplier networks)
        u0
    )
)

(define-private (get-network-multiplier (network-tag (string-ascii 20)))
    (default-to u0 
        (get partnership-multiplier 
            (map-get? network-partnerships { network-tag: network-tag })
        )
    )
)

(define-private (append-multiplier 
    (multipliers (list 10 uint)) 
    (multiplier uint)
)
    (unwrap! 
        (as-max-len? 
            (if (is-none (index-of multipliers multiplier))
                (append multipliers multiplier)
                multipliers
            ) 
            u10
        ) 
        multipliers
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

(define-read-only (get-network-partnership (network-tag (string-ascii 20)))
    (map-get? network-partnerships { network-tag: network-tag })
)