(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_EXAM_NOT_FOUND (err u101))
(define-constant ERR_EXAM_ALREADY_EXISTS (err u102))
(define-constant ERR_STUDENT_NOT_REGISTERED (err u103))
(define-constant ERR_ALREADY_SUBMITTED (err u104))
(define-constant ERR_SUBMISSION_PERIOD_ENDED (err u105))
(define-constant ERR_INVALID_HASH (err u106))
(define-constant ERR_CHEATING_DETECTED (err u107))
(define-constant ERR_EXAM_NOT_ACTIVE (err u108))
(define-constant ERR_INVALID_DURATION (err u109))
(define-constant ERR_ALREADY_REGISTERED (err u110))

(define-data-var next-exam-id uint u1)
(define-data-var total-exams uint u0)
(define-data-var total-submissions uint u0)

(define-map exams 
  uint 
  {
    creator: principal,
    title: (string-ascii 128),
    description: (string-ascii 256),
    questions-hash: (buff 32),
    start-block: uint,
    duration-blocks: uint,
    max-attempts: uint,
    passing-score: uint,
    is-active: bool
  })

(define-map exam-registrations
  {exam-id: uint, student: principal}
  {
    registered-at: uint,
    attempts-used: uint,
    is-approved: bool
  })

(define-map submissions
  {exam-id: uint, student: principal, attempt: uint}
  {
    answers-hash: (buff 32),
    submitted-at: uint,
    score: uint,
    integrity-proof: (buff 32),
    verification-status: (string-ascii 20)
  })

(define-map exam-results
  {exam-id: uint, student: principal}
  {
    best-score: uint,
    total-attempts: uint,
    passed: bool,
    last-attempt-block: uint
  })

(define-map cheating-reports
  {exam-id: uint, student: principal}
  {
    reported-at: uint,
    evidence-hash: (buff 32),
    verified: bool,
    reporter: principal
  })

(define-read-only (get-exam (exam-id uint))
  (map-get? exams exam-id))

(define-read-only (get-registration (exam-id uint) (student principal))
  (map-get? exam-registrations {exam-id: exam-id, student: student}))

(define-read-only (get-submission (exam-id uint) (student principal) (attempt uint))
  (map-get? submissions {exam-id: exam-id, student: student, attempt: attempt}))

(define-read-only (get-result (exam-id uint) (student principal))
  (map-get? exam-results {exam-id: exam-id, student: student}))

(define-read-only (get-cheating-report (exam-id uint) (student principal))
  (map-get? cheating-reports {exam-id: exam-id, student: student}))

(define-read-only (is-exam-active (exam-id uint))
  (match (get-exam exam-id)
    exam-data (let
      ((current-block stacks-block-height)
       (start-block (get start-block exam-data))
       (end-block (+ start-block (get duration-blocks exam-data))))
      (and 
        (get is-active exam-data)
        (>= current-block start-block)
        (< current-block end-block)))
    false))

(define-read-only (get-exam-status (exam-id uint))
  (match (get-exam exam-id)
    exam-data (let
      ((current-block stacks-block-height)
       (start-block (get start-block exam-data))
       (end-block (+ start-block (get duration-blocks exam-data))))
      (if (< current-block start-block)
        "pending"
        (if (< current-block end-block)
          "active"
          "ended")))
    "not-found"))

(define-read-only (can-submit (exam-id uint) (student principal))
  (let
    ((registration (get-registration exam-id student))
     (exam-data (get-exam exam-id)))
    (match registration
      reg-data (match exam-data
        exam (and
          (get is-approved reg-data)
          (is-exam-active exam-id)
          (< (get attempts-used reg-data) (get max-attempts exam)))
        false)
      false)))

(define-read-only (get-total-stats)
  {
    total-exams: (var-get total-exams),
    total-submissions: (var-get total-submissions),
    next-exam-id: (var-get next-exam-id)
  })

(define-public (create-exam 
  (title (string-ascii 128))
  (description (string-ascii 256))
  (questions-hash (buff 32))
  (start-block uint)
  (duration-blocks uint)
  (max-attempts uint)
  (passing-score uint))
  (let
    ((exam-id (var-get next-exam-id)))
    (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)
    (asserts! (<= passing-score u100) ERR_INVALID_HASH)
    (asserts! (> max-attempts u0) ERR_INVALID_DURATION)
    (asserts! (> start-block stacks-block-height) ERR_INVALID_DURATION)
    
    (map-set exams exam-id {
      creator: tx-sender,
      title: title,
      description: description,
      questions-hash: questions-hash,
      start-block: start-block,
      duration-blocks: duration-blocks,
      max-attempts: max-attempts,
      passing-score: passing-score,
      is-active: true
    })
    
    (var-set next-exam-id (+ exam-id u1))
    (var-set total-exams (+ (var-get total-exams) u1))
    (ok exam-id)))

(define-public (register-for-exam (exam-id uint))
  (let
    ((exam-data (get-exam exam-id))
     (existing-reg (get-registration exam-id tx-sender)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-none existing-reg) ERR_ALREADY_REGISTERED)
    (asserts! (get is-active (unwrap! exam-data ERR_EXAM_NOT_FOUND)) ERR_EXAM_NOT_ACTIVE)
    
    (map-set exam-registrations
      {exam-id: exam-id, student: tx-sender}
      {
        registered-at: stacks-block-height,
        attempts-used: u0,
        is-approved: true
      })
    (ok true)))

(define-public (submit-exam
  (exam-id uint)
  (answers-hash (buff 32))
  (integrity-proof (buff 32)))
  (let
    ((registration (get-registration exam-id tx-sender))
     (exam-data (get-exam exam-id))
     (current-attempt (+ (get attempts-used (unwrap! registration ERR_STUDENT_NOT_REGISTERED)) u1)))
    
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (can-submit exam-id tx-sender) ERR_SUBMISSION_PERIOD_ENDED)
    (asserts! (is-none (get-submission exam-id tx-sender current-attempt)) ERR_ALREADY_SUBMITTED)
    
    (map-set submissions
      {exam-id: exam-id, student: tx-sender, attempt: current-attempt}
      {
        answers-hash: answers-hash,
        submitted-at: stacks-block-height,
        score: u0,
        integrity-proof: integrity-proof,
        verification-status: "pending"
      })
    
    (map-set exam-registrations
      {exam-id: exam-id, student: tx-sender}
      (merge (unwrap! registration ERR_STUDENT_NOT_REGISTERED) {attempts-used: current-attempt}))
    
    (var-set total-submissions (+ (var-get total-submissions) u1))
    (ok current-attempt)))

(define-public (grade-submission
  (exam-id uint)
  (student principal)
  (attempt uint)
  (score uint))
  (let
    ((exam-data (get-exam exam-id))
     (submission (get-submission exam-id student attempt))
     (current-result (get-result exam-id student)))
    
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-some submission) ERR_STUDENT_NOT_REGISTERED)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    (asserts! (<= score u100) ERR_INVALID_HASH)
    
    (map-set submissions
      {exam-id: exam-id, student: student, attempt: attempt}
      (merge (unwrap! submission ERR_STUDENT_NOT_REGISTERED) 
        {score: score, verification-status: "graded"}))
    
    (let
      ((passing-score (get passing-score (unwrap! exam-data ERR_EXAM_NOT_FOUND)))
       (default-result {best-score: u0, total-attempts: u0, passed: false, last-attempt-block: u0})
       (current-best (get best-score (default-to default-result current-result)))
       (new-best (if (> score current-best) score current-best)))
      
      (map-set exam-results
        {exam-id: exam-id, student: student}
        {
          best-score: new-best,
          total-attempts: attempt,
          passed: (>= new-best passing-score),
          last-attempt-block: stacks-block-height
        }))
    
    (ok score)))

(define-public (report-cheating
  (exam-id uint)
  (student principal)
  (evidence-hash (buff 32)))
  (let
    ((exam-data (get-exam exam-id)))
    
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-some (get-registration exam-id student)) ERR_STUDENT_NOT_REGISTERED)
    
    (map-set cheating-reports
      {exam-id: exam-id, student: student}
      {
        reported-at: stacks-block-height,
        evidence-hash: evidence-hash,
        verified: false,
        reporter: tx-sender
      })
    
    (ok true)))

(define-public (verify-cheating-report
  (exam-id uint)
  (student principal)
  (is-verified bool))
  (let
    ((exam-data (get-exam exam-id))
     (report (get-cheating-report exam-id student)))
    
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-some report) ERR_STUDENT_NOT_REGISTERED)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    
    (map-set cheating-reports
      {exam-id: exam-id, student: student}
      (merge (unwrap! report ERR_STUDENT_NOT_REGISTERED) {verified: is-verified}))
    
    (if is-verified
      (map-set exam-results
        {exam-id: exam-id, student: student}
        (merge 
          (default-to {best-score: u0, total-attempts: u0, passed: false, last-attempt-block: u0} 
                     (get-result exam-id student))
          {passed: false}))
      true)
    
    (ok is-verified)))

(define-public (deactivate-exam (exam-id uint))
  (let
    ((exam-data (get-exam exam-id)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    
    (map-set exams exam-id
      (merge (unwrap! exam-data ERR_EXAM_NOT_FOUND) {is-active: false}))
    
    (ok true)))
