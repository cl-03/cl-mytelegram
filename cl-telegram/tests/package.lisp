;;; package.lisp --- Test package definition

(defpackage #:cl-telegram/tests
  (:use #:cl #:fiveam)
  (:export
   ;; Test suites
   #:run-all-tests
   #:run-crypto-tests
   #:run-tl-tests
   #:run-mtproto-tests
   #:run-network-tests
   #:run-api-tests
   #:run-ui-tests
   #:run-integration-tests
   #:run-integration-tests-with-creds))
