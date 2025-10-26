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
(define-constant ERR_EXAM_PAUSED (err u111))
(define-constant ERR_INVALID_EXTENSION (err u112))
(define-constant ERR_REPORT_NOT_FOUND (err u113))
(define-constant ERR_INVALID_REPORTER_KEY (err u114))
(define-constant ERR_DUPLICATE_ANONYMOUS_REPORT (err u115))
(define-constant ERR_INSUFFICIENT_REPUTATION (err u116))
(define-constant ERR_DELEGATE_NOT_FOUND (err u117))
(define-constant ERR_ALREADY_DELEGATED (err u118))
(define-constant ERR_CANNOT_DELEGATE_TO_SELF (err u119))
(define-constant ERR_INVALID_PERMISSION (err u120))

(define-data-var next-exam-id uint u1)
(define-data-var total-exams uint u0)
(define-data-var total-submissions uint u0)
(define-data-var next-report-id uint u1)
(define-data-var min-reporter-reputation uint u50)

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
    is-active: bool,
    is-paused: bool,
    total-pause-time: uint,
    extension-granted: uint
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

(define-map anonymous-reports
  uint
  {
    exam-id: uint,
    reported-student: principal,
    evidence-hash: (buff 32),
    reporter-key-hash: (buff 32),
    reported-at: uint,
    verification-status: (string-ascii 20),
    integrity-score: uint,
    verified-by: (optional principal)
  })

(define-map reporter-reputation
  (buff 32)
  {
    total-reports: uint,
    verified-reports: uint,
    false-reports: uint,
    reputation-score: uint,
    last-report-block: uint
  })

(define-map exam-anonymous-reports
  {exam-id: uint, reporter-key-hash: (buff 32)}
  {
    report-id: uint,
    duplicate-check: bool
  })

(define-map exam-delegates
  {exam-id: uint, delegate: principal}
  {
    delegated-at: uint,
    delegator: principal,
    can-grade: bool,
    can-verify-reports: bool,
    can-pause: bool,
    can-extend: bool,
    is-active: bool
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
        (not (get is-paused exam-data))
        (>= current-block start-block)
        (< current-block (+ end-block (get total-pause-time exam-data) (get extension-granted exam-data)))))
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

(define-read-only (get-anonymous-report (report-id uint))
  (map-get? anonymous-reports report-id))

(define-read-only (get-reporter-reputation (reporter-key-hash (buff 32)))
  (map-get? reporter-reputation reporter-key-hash))

(define-read-only (calculate-integrity-score (reporter-key-hash (buff 32)))
  (match (get-reporter-reputation reporter-key-hash)
    rep-data (let
      ((total (get total-reports rep-data))
       (verified (get verified-reports rep-data))
       (false-reports (get false-reports rep-data)))
      (if (> total u0)
        (- (* (/ verified total) u100) (* (/ false-reports total) u50))
        u50))
    u50))

(define-read-only (can-report-anonymously (reporter-key-hash (buff 32)))
  (>= (calculate-integrity-score reporter-key-hash) (var-get min-reporter-reputation)))

(define-read-only (get-total-stats)
  {
    total-exams: (var-get total-exams),
    total-submissions: (var-get total-submissions),
    next-exam-id: (var-get next-exam-id),
    next-report-id: (var-get next-report-id)
  })

(define-read-only (get-delegate (exam-id uint) (delegate principal))
  (map-get? exam-delegates {exam-id: exam-id, delegate: delegate}))

(define-read-only (is-authorized (exam-id uint) (caller principal) (permission (string-ascii 20)))
  (let
    ((exam-data (get-exam exam-id))
     (delegate-data (get-delegate exam-id caller)))
    (match exam-data
      exam (or
        (is-eq caller (get creator exam))
        (match delegate-data
          delegate (and
            (get is-active delegate)
            (if (is-eq permission "grade")
              (get can-grade delegate)
              (if (is-eq permission "verify")
                (get can-verify-reports delegate)
                (if (is-eq permission "pause")
                  (get can-pause delegate)
                  (if (is-eq permission "extend")
                    (get can-extend delegate)
                    false)))))
          false))
      false)))

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
      is-active: true,
      is-paused: false,
      total-pause-time: u0,
      extension-granted: u0
    })
    
    (var-set next-exam-id (+ exam-id u1))
    (var-set total-exams (+ (var-get total-exams) u1))
    (ok exam-id)))

(define-public (submit-anonymous-report
  (exam-id uint)
  (reported-student principal)
  (evidence-hash (buff 32))
  (reporter-key-hash (buff 32)))
  (let
    ((exam-data (get-exam exam-id))
     (report-id (var-get next-report-id))
     (existing-report (map-get? exam-anonymous-reports {exam-id: exam-id, reporter-key-hash: reporter-key-hash})))
    
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (can-report-anonymously reporter-key-hash) ERR_INSUFFICIENT_REPUTATION)
    (asserts! (is-none existing-report) ERR_DUPLICATE_ANONYMOUS_REPORT)
    
    (let
      ((integrity-score (calculate-integrity-score reporter-key-hash)))
      
      (map-set anonymous-reports report-id {
        exam-id: exam-id,
        reported-student: reported-student,
        evidence-hash: evidence-hash,
        reporter-key-hash: reporter-key-hash,
        reported-at: stacks-block-height,
        verification-status: "pending",
        integrity-score: integrity-score,
        verified-by: none
      })
      
      (map-set exam-anonymous-reports
        {exam-id: exam-id, reporter-key-hash: reporter-key-hash}
        {report-id: report-id, duplicate-check: true})
      
      (let
        ((current-rep (default-to 
          {total-reports: u0, verified-reports: u0, false-reports: u0, reputation-score: u50, last-report-block: u0}
          (get-reporter-reputation reporter-key-hash))))
        
        (map-set reporter-reputation reporter-key-hash
          (merge current-rep {
            total-reports: (+ (get total-reports current-rep) u1),
            last-report-block: stacks-block-height
          }))
        
        (var-set next-report-id (+ report-id u1))
        (ok report-id)))))

(define-public (verify-anonymous-report
  (report-id uint)
  (is-verified bool))
  (let
    ((report (get-anonymous-report report-id))
     (exam-data (get-exam (get exam-id (unwrap! report ERR_REPORT_NOT_FOUND)))))
    
    (asserts! (is-some report) ERR_REPORT_NOT_FOUND)
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-authorized (get exam-id (unwrap! report ERR_REPORT_NOT_FOUND)) tx-sender "verify") ERR_NOT_AUTHORIZED)
    
    (let
      ((report-data (unwrap! report ERR_REPORT_NOT_FOUND))
       (reporter-key (get reporter-key-hash report-data))
       (current-rep (default-to 
         {total-reports: u0, verified-reports: u0, false-reports: u0, reputation-score: u50, last-report-block: u0}
         (get-reporter-reputation reporter-key))))
      
      (map-set anonymous-reports report-id
        (merge report-data {
          verification-status: (if is-verified "verified" "rejected"),
          verified-by: (some tx-sender)
        }))
      
      (map-set reporter-reputation reporter-key
        (merge current-rep {
          verified-reports: (if is-verified 
                              (+ (get verified-reports current-rep) u1) 
                              (get verified-reports current-rep)),
          false-reports: (if is-verified 
                           (get false-reports current-rep)
                           (+ (get false-reports current-rep) u1)),
          reputation-score: (calculate-integrity-score reporter-key)
        }))
      
      (ok is-verified))))

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
    (asserts! (not (get is-paused (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_EXAM_PAUSED)
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
    (asserts! (is-authorized exam-id tx-sender "grade") ERR_NOT_AUTHORIZED)
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
    (asserts! (is-authorized exam-id tx-sender "verify") ERR_NOT_AUTHORIZED)
    
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

(define-map pause-timestamps uint uint)

(define-read-only (get-pause-timestamp (exam-id uint))
  (map-get? pause-timestamps exam-id))

(define-public (pause-exam (exam-id uint))
  (let
    ((exam-data (get-exam exam-id)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-authorized exam-id tx-sender "pause") ERR_NOT_AUTHORIZED)
    (asserts! (get is-active (unwrap! exam-data ERR_EXAM_NOT_FOUND)) ERR_EXAM_NOT_ACTIVE)
    (asserts! (not (get is-paused (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_EXAM_PAUSED)
    
    (map-set pause-timestamps exam-id stacks-block-height)
    (map-set exams exam-id
      (merge (unwrap! exam-data ERR_EXAM_NOT_FOUND) {is-paused: true}))
    
    (ok true)))

(define-public (resume-exam (exam-id uint))
  (let
    ((exam-data (get-exam exam-id))
     (pause-time (get-pause-timestamp exam-id)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-authorized exam-id tx-sender "pause") ERR_NOT_AUTHORIZED)
    (asserts! (get is-paused (unwrap! exam-data ERR_EXAM_NOT_FOUND)) ERR_EXAM_NOT_ACTIVE)
    (asserts! (is-some pause-time) ERR_EXAM_NOT_ACTIVE)
    
    (let
      ((pause-duration (- stacks-block-height (unwrap! pause-time ERR_EXAM_NOT_ACTIVE)))
       (current-pause-time (get total-pause-time (unwrap! exam-data ERR_EXAM_NOT_FOUND))))
      
      (map-delete pause-timestamps exam-id)
      (map-set exams exam-id
        (merge (unwrap! exam-data ERR_EXAM_NOT_FOUND) 
          {is-paused: false, total-pause-time: (+ current-pause-time pause-duration)}))
      
      (ok pause-duration))))

(define-public (extend-exam-time (exam-id uint) (extension-blocks uint))
  (let
    ((exam-data (get-exam exam-id)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-authorized exam-id tx-sender "extend") ERR_NOT_AUTHORIZED)
    (asserts! (> extension-blocks u0) ERR_INVALID_EXTENSION)
    (asserts! (<= extension-blocks u1000) ERR_INVALID_EXTENSION)
    
    (let
      ((current-extension (get extension-granted (unwrap! exam-data ERR_EXAM_NOT_FOUND))))
      
      (map-set exams exam-id
        (merge (unwrap! exam-data ERR_EXAM_NOT_FOUND) 
          {extension-granted: (+ current-extension extension-blocks)}))
      
      (ok (+ current-extension extension-blocks)))))

(define-public (delegate-permissions
  (exam-id uint)
  (delegate principal)
  (can-grade bool)
  (can-verify-reports bool)
  (can-pause bool)
  (can-extend bool))
  (let
    ((exam-data (get-exam exam-id))
     (existing-delegate (get-delegate exam-id delegate)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    (asserts! (not (is-eq delegate tx-sender)) ERR_CANNOT_DELEGATE_TO_SELF)
    (asserts! (is-none existing-delegate) ERR_ALREADY_DELEGATED)
    (asserts! (or can-grade (or can-verify-reports (or can-pause can-extend))) ERR_INVALID_PERMISSION)
    
    (map-set exam-delegates
      {exam-id: exam-id, delegate: delegate}
      {
        delegated-at: stacks-block-height,
        delegator: tx-sender,
        can-grade: can-grade,
        can-verify-reports: can-verify-reports,
        can-pause: can-pause,
        can-extend: can-extend,
        is-active: true
      })
    (ok true)))

(define-public (revoke-delegation (exam-id uint) (delegate principal))
  (let
    ((exam-data (get-exam exam-id))
     (delegate-data (get-delegate exam-id delegate)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    (asserts! (is-some delegate-data) ERR_DELEGATE_NOT_FOUND)
    
    (map-set exam-delegates
      {exam-id: exam-id, delegate: delegate}
      (merge (unwrap! delegate-data ERR_DELEGATE_NOT_FOUND) {is-active: false}))
    (ok true)))

(define-public (update-delegate-permissions
  (exam-id uint)
  (delegate principal)
  (can-grade bool)
  (can-verify-reports bool)
  (can-pause bool)
  (can-extend bool))
  (let
    ((exam-data (get-exam exam-id))
     (delegate-data (get-delegate exam-id delegate)))
    (asserts! (is-some exam-data) ERR_EXAM_NOT_FOUND)
    (asserts! (is-eq tx-sender (get creator (unwrap! exam-data ERR_EXAM_NOT_FOUND))) ERR_NOT_AUTHORIZED)
    (asserts! (is-some delegate-data) ERR_DELEGATE_NOT_FOUND)
    (asserts! (get is-active (unwrap! delegate-data ERR_DELEGATE_NOT_FOUND)) ERR_DELEGATE_NOT_FOUND)
    (asserts! (or can-grade (or can-verify-reports (or can-pause can-extend))) ERR_INVALID_PERMISSION)
    
    (map-set exam-delegates
      {exam-id: exam-id, delegate: delegate}
      (merge (unwrap! delegate-data ERR_DELEGATE_NOT_FOUND) {
        can-grade: can-grade,
        can-verify-reports: can-verify-reports,
        can-pause: can-pause,
        can-extend: can-extend
      }))
    (ok true)))
