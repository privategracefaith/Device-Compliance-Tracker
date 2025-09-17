;; Healthcare Device Regulatory Compliance and Lifecycle Management System Contract
;; Advanced blockchain-based platform for comprehensive medical device registration, lifecycle 
;; monitoring, regulatory compliance certification, and complete audit trail management from 
;; manufacturing inception through end-of-life decommissioning phases

(define-trait healthcare-device-regulatory-management-interface
  (
    (create-device-registration (uint uint) (response bool uint))
    (update-device-lifecycle-phase (uint uint) (response bool uint))
    (get-device-complete-history (uint) (response (list 10 {stage: uint, timestamp: uint}) uint))
    (issue-compliance-certificate (uint uint principal) (response bool uint))
    (validate-device-certification-status (uint uint) (response bool uint))
  )
)

;; Device operational lifecycle phase constants
(define-constant device-phase-initial-manufacturing u1)
(define-constant device-phase-quality-testing u2)
(define-constant device-phase-clinical-active u3)
(define-constant device-phase-maintenance-mode u4)
(define-constant device-phase-decommissioned u5)

;; Regulatory certification authority type constants
(define-constant certification-authority-fda-approval u1)
(define-constant certification-authority-european-conformity u2)
(define-constant certification-authority-international-standards u3)
(define-constant certification-authority-safety-compliance u4)
(define-constant certification-authority-quality-assurance u5)

;; Comprehensive error handling constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-INVALID-DEVICE-ID (err u101))
(define-constant ERR-LIFECYCLE-TRANSITION-BLOCKED (err u102))
(define-constant ERR-UNSUPPORTED-PHASE (err u103))
(define-constant ERR-UNKNOWN-CERTIFICATION-AUTHORITY (err u104))
(define-constant ERR-CERTIFICATION-ALREADY-EXISTS (err u105))
(define-constant ERR-CERTIFICATION-NOT-FOUND (err u106))
(define-constant ERR-INVALID-AUTHORITY (err u107))
(define-constant ERR-DEVICE-REGISTRATION-CONFLICT (err u108))

;; Core system management variables
(define-data-var contract-administrator principal tx-sender)
(define-data-var global-timestamp-counter uint u0)
(define-data-var registered-devices-count uint u0)

;; Primary device information storage mapping
(define-map healthcare-device-records 
  {device-unique-id: uint} 
  {
    device-owner-address: principal,
    current-lifecycle-phase: uint,
    phase-transition-log: (list 10 {stage: uint, timestamp: uint}),
    initial-registration-time: uint,
    most-recent-update: uint
  }
)

;; Regulatory compliance certification tracking mapping
(define-map device-compliance-certificates
  {device-id: uint, certificate-type: uint}
  {
    issuing-authority: principal,
    certificate-issued-at: uint,
    certificate-is-active: bool,
    certificate-expires-at: (optional uint)
  }
)

;; Authorized regulatory bodies management mapping
(define-map approved-regulatory-authorities
  {authority-principal: principal, certification-scope: uint}
  {
    authority-is-active: bool,
    authority-approved-at: uint,
    approved-by-admin: principal
  }
)

;; Device ownership change history mapping
(define-map device-ownership-history
  {device-reference: uint, transfer-index: uint}
  {
    former-owner: principal,
    current-owner: principal,
    transfer-completed-at: uint
  }
)

;; Generate incremental timestamp for audit purposes
(define-private (generate-next-timestamp)
  (begin
    (var-set global-timestamp-counter 
      (+ (var-get global-timestamp-counter) u1))
    (var-get global-timestamp-counter)
  )
)

;; Verify if requesting user has administrative privileges
(define-read-only (check-admin-privileges (requesting-principal principal))
  (is-eq requesting-principal (var-get contract-administrator))
)

;; Validate device lifecycle phase value against supported phases
(define-private (is-supported-lifecycle-phase (proposed-phase uint))
  (or 
    (is-eq proposed-phase device-phase-initial-manufacturing)
    (is-eq proposed-phase device-phase-quality-testing)
    (is-eq proposed-phase device-phase-clinical-active)
    (is-eq proposed-phase device-phase-maintenance-mode)
    (is-eq proposed-phase device-phase-decommissioned)
  )
)

;; Validate certification authority type against supported authorities
(define-private (is-valid-certification-authority (authority-type uint))
  (or
    (is-eq authority-type certification-authority-fda-approval)
    (is-eq authority-type certification-authority-european-conformity)
    (is-eq authority-type certification-authority-international-standards)
    (is-eq authority-type certification-authority-safety-compliance)
    (is-eq authority-type certification-authority-quality-assurance)
  )
)

;; Validate device identifier within acceptable parameters
(define-private (is-acceptable-device-id (device-identifier uint))
  (and 
    (> device-identifier u0) 
    (<= device-identifier u999999999)
  )
)

;; Verify regulatory authority has proper authorization for certification scope
(define-private (validate-authority-certification-rights 
    (authority-principal principal) 
    (certification-scope uint))
  (default-to 
    false
    (get authority-is-active 
      (map-get? approved-regulatory-authorities 
        {
          authority-principal: authority-principal, 
          certification-scope: certification-scope
        }
      )
    )
  )
)

;; Validate regulatory authority principal legitimacy
(define-private (is-valid-authority-principal (candidate-principal principal))
  (and 
    (not (is-eq candidate-principal (var-get contract-administrator)))
    (not (is-eq candidate-principal tx-sender))
    (not (is-eq candidate-principal 'SP000000000000000000002Q6VF78))
  )
)

;; Verify device ownership or administrative access
(define-private (validate-device-access-rights (device-id uint) (requesting-principal principal))
  (let 
    (
      (device-data (map-get? healthcare-device-records 
        {device-unique-id: device-id}))
    )
    (match device-data
      found-device (or 
        (check-admin-privileges requesting-principal)
        (is-eq (get device-owner-address found-device) requesting-principal)
      )
      false
    )
  )
)

;; Register new medical device with initial lifecycle phase
(define-public (create-device-registration 
    (device-unique-id uint) 
    (initial-phase uint))
  (let
    (
      (registration-time (generate-next-timestamp))
      (initial-log-entry {stage: initial-phase, timestamp: registration-time})
    )
    (asserts! (is-acceptable-device-id device-unique-id) ERR-INVALID-DEVICE-ID)
    (asserts! (is-supported-lifecycle-phase initial-phase) ERR-UNSUPPORTED-PHASE)
    (asserts! 
      (is-none (map-get? healthcare-device-records {device-unique-id: device-unique-id}))
      ERR-DEVICE-REGISTRATION-CONFLICT
    )
    (asserts! 
      (or 
        (check-admin-privileges tx-sender) 
        (is-eq initial-phase device-phase-initial-manufacturing)
      ) 
      ERR-UNAUTHORIZED-ACCESS
    )
    
    (map-set healthcare-device-records 
      {device-unique-id: device-unique-id}
      {
        device-owner-address: tx-sender,
        current-lifecycle-phase: initial-phase,
        phase-transition-log: (list initial-log-entry),
        initial-registration-time: registration-time,
        most-recent-update: registration-time
      }
    )
    
    (var-set registered-devices-count (+ (var-get registered-devices-count) u1))
    (ok true)
  )
)

;; Update device lifecycle phase with comprehensive audit trail
(define-public (update-device-lifecycle-phase 
    (target-device-id uint) 
    (new-lifecycle-phase uint))
  (let 
    (
      (current-device-data (unwrap! 
        (map-get? healthcare-device-records {device-unique-id: target-device-id}) 
        ERR-INVALID-DEVICE-ID))
      (update-timestamp (generate-next-timestamp))
      (new-log-entry {stage: new-lifecycle-phase, timestamp: update-timestamp})
    )
    (asserts! (is-acceptable-device-id target-device-id) ERR-INVALID-DEVICE-ID)
    (asserts! (is-supported-lifecycle-phase new-lifecycle-phase) ERR-UNSUPPORTED-PHASE)
    (asserts! 
      (validate-device-access-rights target-device-id tx-sender)
      ERR-UNAUTHORIZED-ACCESS
    )
    
    (map-set healthcare-device-records 
      {device-unique-id: target-device-id}
      (merge current-device-data 
        {
          current-lifecycle-phase: new-lifecycle-phase,
          phase-transition-log: (unwrap-panic 
            (as-max-len? 
              (append 
                (get phase-transition-log current-device-data) 
                new-log-entry
              ) 
              u10
            )
          ),
          most-recent-update: update-timestamp
        }
      )
    )
    (ok true)
  )
)

;; Transfer device ownership with complete audit documentation
(define-public (execute-ownership-transfer 
    (device-id uint) 
    (new-owner-address principal))
  (let 
    (
      (existing-device-record (unwrap! 
        (map-get? healthcare-device-records {device-unique-id: device-id}) 
        ERR-INVALID-DEVICE-ID))
      (transfer-time (generate-next-timestamp))
    )
    (asserts! (is-acceptable-device-id device-id) ERR-INVALID-DEVICE-ID)
    (asserts! 
      (validate-device-access-rights device-id tx-sender)
      ERR-UNAUTHORIZED-ACCESS
    )
    (asserts! 
      (not (is-eq (get device-owner-address existing-device-record) new-owner-address))
      ERR-DEVICE-REGISTRATION-CONFLICT
    )
    
    (map-set healthcare-device-records 
      {device-unique-id: device-id}
      (merge existing-device-record 
        {
          device-owner-address: new-owner-address,
          most-recent-update: transfer-time
        }
      )
    )
    (ok true)
  )
)

;; Grant regulatory authority certification permissions
(define-public (authorize-regulatory-body 
    (authority-principal principal) 
    (certification-scope uint))
  (let
    (
      (authorization-time (generate-next-timestamp))
    )
    (asserts! (check-admin-privileges tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (is-valid-certification-authority certification-scope) ERR-UNKNOWN-CERTIFICATION-AUTHORITY)
    (asserts! (is-valid-authority-principal authority-principal) ERR-INVALID-AUTHORITY)
    
    (asserts! (is-some (some authority-principal)) ERR-INVALID-AUTHORITY)
    (asserts! (> certification-scope u0) ERR-UNKNOWN-CERTIFICATION-AUTHORITY)
    
    (map-set approved-regulatory-authorities
      {authority-principal: authority-principal, certification-scope: certification-scope}
      {
        authority-is-active: true,
        authority-approved-at: authorization-time,
        approved-by-admin: tx-sender
      }
    )
    (ok true)
  )
)

;; Revoke regulatory authority certification permissions
(define-public (revoke-regulatory-authority 
    (authority-principal principal) 
    (certification-scope uint))
  (let
    (
      (current-authorization (unwrap!
        (map-get? approved-regulatory-authorities
          {authority-principal: authority-principal, certification-scope: certification-scope})
        ERR-INVALID-AUTHORITY
      ))
    )
    (asserts! (check-admin-privileges tx-sender) ERR-UNAUTHORIZED-ACCESS)
    
    (asserts! (is-some (some authority-principal)) ERR-INVALID-AUTHORITY)
    (asserts! (> certification-scope u0) ERR-UNKNOWN-CERTIFICATION-AUTHORITY)
    
    (map-set approved-regulatory-authorities
      {authority-principal: authority-principal, certification-scope: certification-scope}
      (merge current-authorization {authority-is-active: false})
    )
    (ok true)
  )
)

;; Issue regulatory compliance certification for medical device
(define-public (issue-compliance-certificate 
    (target-device-id uint) 
    (certificate-type uint))
  (let
    (
      (issuance-time (generate-next-timestamp))
    )
    (asserts! (is-acceptable-device-id target-device-id) ERR-INVALID-DEVICE-ID)
    (asserts! (is-valid-certification-authority certificate-type) ERR-UNKNOWN-CERTIFICATION-AUTHORITY)
    (asserts! 
      (validate-authority-certification-rights tx-sender certificate-type) 
      ERR-UNAUTHORIZED-ACCESS
    )
    
    (asserts! 
      (is-none 
        (map-get? device-compliance-certificates 
          {device-id: target-device-id, certificate-type: certificate-type})
      )
      ERR-CERTIFICATION-ALREADY-EXISTS
    )
    
    (map-set device-compliance-certificates
      {device-id: target-device-id, certificate-type: certificate-type}
      {
        issuing-authority: tx-sender,
        certificate-issued-at: issuance-time,
        certificate-is-active: true,
        certificate-expires-at: none
      }
    )
    (ok true)
  )
)

;; Revoke existing regulatory compliance certification
(define-public (revoke-compliance-certificate 
    (target-device-id uint) 
    (certificate-type uint))
  (let
    (
      (current-certificate (unwrap! 
        (map-get? device-compliance-certificates 
          {device-id: target-device-id, certificate-type: certificate-type})
        ERR-CERTIFICATION-NOT-FOUND
      ))
    )
    (asserts! (is-acceptable-device-id target-device-id) ERR-INVALID-DEVICE-ID)
    (asserts! (is-valid-certification-authority certificate-type) ERR-UNKNOWN-CERTIFICATION-AUTHORITY)
    (asserts! 
      (or
        (check-admin-privileges tx-sender)
        (is-eq (get issuing-authority current-certificate) tx-sender)
      )
      ERR-UNAUTHORIZED-ACCESS
    )
    
    (map-set device-compliance-certificates
      {device-id: target-device-id, certificate-type: certificate-type}
      (merge current-certificate {certificate-is-active: false})
    )
    (ok true)
  )
)

;; Validate active device certification status
(define-read-only (validate-device-certification-status 
    (device-id uint) 
    (certificate-type uint))
  (let
    (
      (certificate-record (unwrap! 
        (map-get? device-compliance-certificates 
          {device-id: device-id, certificate-type: certificate-type})
        ERR-CERTIFICATION-NOT-FOUND
      ))
    )
    (ok (get certificate-is-active certificate-record))
  )
)

;; Retrieve complete device lifecycle audit trail
(define-read-only (get-device-complete-history (device-id uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? healthcare-device-records {device-unique-id: device-id}) 
        ERR-INVALID-DEVICE-ID))
    )
    (ok (get phase-transition-log device-record))
  )
)

;; Get current device operational phase
(define-read-only (get-current-device-phase (device-id uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? healthcare-device-records {device-unique-id: device-id}) 
        ERR-INVALID-DEVICE-ID))
    )
    (ok (get current-lifecycle-phase device-record))
  )
)

;; Retrieve comprehensive certification information
(define-read-only (get-certificate-details 
    (device-id uint) 
    (certificate-type uint))
  (ok (map-get? device-compliance-certificates 
    {device-id: device-id, certificate-type: certificate-type}))
)

;; Get device ownership and registration information
(define-read-only (get-device-ownership-details (device-id uint))
  (let 
    (
      (device-record (unwrap! 
        (map-get? healthcare-device-records {device-unique-id: device-id}) 
        ERR-INVALID-DEVICE-ID))
    )
    (ok {
      owner: (get device-owner-address device-record),
      registered-at: (get initial-registration-time device-record),
      updated-at: (get most-recent-update device-record)
    })
  )
)

;; Get comprehensive system statistics
(define-read-only (get-system-statistics)
  (ok {
    total-registered-devices: (var-get registered-devices-count),
    current-timestamp: (var-get global-timestamp-counter),
    system-admin: (var-get contract-administrator)
  })
)

;; Check regulatory authority authorization status
(define-read-only (get-authority-status 
    (authority-principal principal) 
    (certification-scope uint))
  (ok (map-get? approved-regulatory-authorities 
    {authority-principal: authority-principal, certification-scope: certification-scope}))
)