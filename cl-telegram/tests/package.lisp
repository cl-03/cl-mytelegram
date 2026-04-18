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
   #:run-integration-tests-with-creds
   #:run-proxy-tests
   ;; Live tests
   #:run-live-tests
   #:run-single-live-test
   #:*live-test-api-id*
   #:*live-test-api-hash*
   #:*live-test-phone*
   #:*live-test-dc-id*
   #:*live-test-code*
   ;; Update handler tests
   #:run-update-handler-tests
   ;; Secret chat tests
   #:run-secret-chat-tests
   ;; Database tests
   #:run-database-tests
   ;; Group/Channel tests
   #:run-group-channel-tests
   ;; Bot API tests
   #:run-bot-api-tests
   ;; VoIP tests
   #:run-voip-tests))
