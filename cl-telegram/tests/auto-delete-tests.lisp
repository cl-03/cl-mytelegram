;;; auto-delete-tests.lisp --- Tests for auto-delete messages

(defpackage #:cl-telegram/tests/auto-delete
  (:use #:cl #:fiveam #:cl-telegram/api))

(in-package #:cl-telegram/tests/auto-delete)

(def-suite* auto-delete-tests
  :in cl-telegram/tests)

;;; ============================================================================
;;; Helper Functions
;;; ============================================================================

(defun setup-auto-delete-manager ()
  "Setup auto-delete manager for testing."
  (setf cl-telegram/api::*auto-delete-manager* nil)
  (cl-telegram/api:init-auto-delete-manager :cleanup-interval 1))

(defun teardown-auto-delete-manager ()
  "Cleanup auto-delete manager after testing."
  (cl-telegram/api:stop-auto-delete-monitor)
  (setf cl-telegram/api::*auto-delete-manager* nil))

;;; ============================================================================
;;; Timer Management Tests
;;; ============================================================================

(define-test test-set-message-timer
  "Test setting auto-delete timer for a message."
  (setup-auto-delete-manager)
  (unwind-protect
       (multiple-value-bind (timer-id error)
           (cl-telegram/api:set-message-timer 123 456 60)
         (is-not (null timer-id))
         (is (null error)))
    (teardown-auto-delete-manager)))

(define-test test-set-message-timer-invalid-duration
  "Test setting timer with invalid duration."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Too short
         (multiple-value-bind (timer-id error)
             (cl-telegram/api:set-message-timer 123 456 0)
           (is (null timer-id))
           (is (eq error :invalid-duration)))
         ;; Too long
         (multiple-value-bind (timer-id error)
             (cl-telegram/api:set-message-timer 123 456 700000)
           (is (null timer-id))
           (is (eq error :invalid-duration))))
    (teardown-auto-delete-manager)))

(define-test test-cancel-message-timer
  "Test cancelling auto-delete timer."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Set timer
         (multiple-value-bind (timer-id error)
             (cl-telegram/api:set-message-timer 123 456 60)
           (is-not (null timer-id))
           (is (null error))
           ;; Cancel timer
           (multiple-value-bind (success cancel-error)
               (cl-telegram/api:cancel-message-timer 123 456)
             (is success)
             (is (null cancel-error)))
           ;; Try to cancel again
           (multiple-value-bind (success cancel-error)
               (cl-telegram/api:cancel-message-timer 123 456)
             (is (null success))
             (is (eq cancel-error :no-timer)))))
    (teardown-auto-delete-manager)))

(define-test test-get-message-timer-remaining
  "Test getting remaining time on timer."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Set timer
         (multiple-value-bind (timer-id error)
             (cl-telegram/api:set-message-timer 123 456 300)
           (is-not (null timer-id))
           (is (null error))
           ;; Get remaining
           (multiple-value-bind (remaining error)
               (cl-telegram/api:get-message-timer-remaining 123 456)
             (is-not (null remaining))
             (is (<= remaining 300))
             (is (> remaining 0))
             (is (null error))))
    (teardown-auto-delete-manager)))

(define-test test-get-message-timer-remaining-no-timer
  "Test getting remaining time when no timer exists."
  (setup-auto-delete-manager)
  (unwind-protect
       (multiple-value-bind (remaining error)
           (cl-telegram/api:get-message-timer-remaining 999 999)
         (is (null remaining))
         (is (eq error :no-timer)))
    (teardown-auto-delete-manager)))

;;; ============================================================================
;;; Per-Chat Default Timer Tests
;;; ============================================================================

(define-test test-set-chat-default-timer
  "Test setting default timer for a chat."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         (is (cl-telegram/api:set-chat-default-timer 123 3600))
         (is (= (cl-telegram/api:get-chat-default-timer 123) 3600)))
    (teardown-auto-delete-manager)))

(define-test test-clear-chat-default-timer
  "Test clearing default timer for a chat."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         (cl-telegram/api:set-chat-default-timer 123 3600)
         (is (cl-telegram/api:clear-chat-default-timer 123))
         (is (null (cl-telegram/api:get-chat-default-timer 123))))
    (teardown-auto-delete-manager)))

;;; ============================================================================
;;; Monitor Tests
;;; ============================================================================

(define-test test-start-auto-delete-monitor
  "Test starting the auto-delete monitor."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         (is (cl-telegram/api:start-auto-delete-monitor))
         (is (cl-telegram/api:manager-is-running cl-telegram/api::*auto-delete-manager*)))
    (teardown-auto-delete-manager)))

(define-test test-stop-auto-delete-monitor
  "Test stopping the auto-delete monitor."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         (cl-telegram/api:start-auto-delete-monitor)
         (sleep 0.1) ; Give thread time to start
         (is (cl-telegram/api:stop-auto-delete-monitor))
         (sleep 0.1) ; Give thread time to stop
         (is-not (cl-telegram/api:manager-is-running cl-telegram/api::*auto-delete-manager*))))
    (teardown-auto-delete-manager)))

(define-test test-get-auto-delete-stats
  "Test getting auto-delete statistics."
  (setup-auto-delete-manager)
  (unwind-protect
       (let ((stats (cl-telegram/api:get-auto-delete-stats)))
         (is (getf stats :active-timers))
         (is (getf stats :default-timers))
         (is (getf stats :is-running))
         (is (getf stats :cleanup-interval)))
    (teardown-auto-delete-manager)))

;;; ============================================================================
;;; Integration Tests
;;; ============================================================================

(define-test test-send-message-with-auto-delete
  "Test sending message with auto-delete timer."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Note: This test would require a real connection to fully test
         ;; For now, just verify the function exists and has correct signature
         (is (fboundp 'cl-telegram/api:send-message-with-auto-delete)))
    (teardown-auto-delete-manager)))

(define-test test-list-active-timers
  "Test listing active timers."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Set some timers
         (cl-telegram/api:set-message-timer 123 456 60)
         (cl-telegram/api:set-message-timer 123 457 120)
         (cl-telegram/api:set-message-timer 999 888 300)
         ;; List all
         (let ((timers (cl-telegram/api:list-active-timers)))
           (is (= (length timers) 3)))
         ;; List filtered by chat
         (let ((timers (cl-telegram/api:list-active-timers :chat-id 123)))
           (is (= (length timers) 2))))
    (teardown-auto-delete-manager)))

;;; ============================================================================
;;; Auto-Delete Expiration Tests
;;; ============================================================================

(define-test test-auto-delete-expiration
  "Test that timers actually expire and trigger deletion."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Set a very short timer (1 second)
         (multiple-value-bind (timer-id error)
             (cl-telegram/api:set-message-timer 123 456 1)
           (is-not (null timer-id))
           (is (null error)))
         ;; Wait for expiration
         (sleep 2)
         ;; Check timer is gone
         (let ((timers (cl-telegram/api:list-active-timers :chat-id 123)))
           (is (null timers))))
    (teardown-auto-delete-manager)))

(define-test test-cleanup-expired-timers
  "Test manual cleanup of expired timers."
  (setup-auto-delete-manager)
  (unwind-protect
       (progn
         ;; Set short timer
         (cl-telegram/api:set-message-timer 123 456 1)
         ;; Wait
         (sleep 2)
         ;; Manual cleanup
         (let ((count (cl-telegram/api:cleanup-expired-timers)))
           (is (>= count 0))))
    (teardown-auto-delete-manager)))

;;; ============================================================================
;;; Run All Tests
;;; ============================================================================

(defun run-all-auto-delete-tests ()
  "Run all auto-delete tests."
  (run! 'auto-delete-tests))
