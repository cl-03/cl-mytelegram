# Release Notes - v0.20.0

**Release Date**: 2026-04-20  
**Previous Version**: v0.19.0  
**Next Version**: v0.21.0 (planned)

---

## 🎉 Highlights

v0.20.0 introduces comprehensive payment processing and business account management features, enabling bots to handle financial transactions via Telegram Stars and manage business profiles with professional tools. This release adds 40+ new functions across 2 major modules.

---

## 🚀 New Features

### Payment System (12 functions)

**Invoice Creation**
- `make-labeled-price` - Create price line items with labels
- `make-invoice` - Create full invoice objects with all options
- `send-invoice` - Send invoices directly to chats
- `create-invoice-link` - Generate payment links for invoices

**Telegram Stars**
- `refund-star-payment` - Refund successful Star payments
- `gift-premium-subscription` - Gift Telegram Premium via Stars
- `get-business-account-star-balance` - Check business Star balance
- `transfer-business-account-stars` - Transfer Stars to bot balance

**Helpers**
- `create-subscription-invoice` - Create recurring subscription invoices
- `create-star-invoice` - Create Telegram Stars purchase invoices

**Classes**
- `labeled-price` - Price line item with label and amount
- `invoice` - Complete invoice with all Telegram options
- `star-transaction` - Star transaction record
- `star-balance` - Business account Star balance

---

### Business Features (28 functions)

**Business Connections**
- `get-business-connection` - Get business connection details
- `list-business-connections` - List all business connections

**Business Location**
- `set-business-location` - Set business address and coordinates
- `get-business-location` - Get business location info
- `delete-business-location` - Remove business location

**Business Hours**
- `make-opening-hours-interval` - Create single opening interval
- `make-opening-hours-from-times` - Create weekly schedule from times
- `set-business-opening-hours` - Set business opening hours
- `get-business-opening-hours` - Get current opening hours
- `delete-business-opening-hours` - Remove opening hours

**Quick Replies**
- `make-quick-reply` - Create quick reply button
- `send-message-with-quick-replies` - Send message with quick reply keyboard

**Business Messaging**
- `send-business-message` - Send message on behalf of business
- `edit-business-message` - Edit business message
- `delete-business-message` - Delete business message

**Business Chat Links**
- `create-business-chat-link` - Create t.me link for business

**Classes**
- `business-connection` - Business account connection info
- `business-location` - Business address and coordinates
- `business-opening-hours` - Weekly opening hours schedule
- `business-opening-hours-interval` - Single time interval
- `business-bot-rights` - Bot permissions for business account
- `quick-reply` - Quick reply button definition

---

## 📁 Files Added

### New Modules

| File | Lines | Description |
|------|-------|-------------|
| `src/api/payment.lisp` | ~450 | Payment processing and Telegram Stars |
| `src/api/business.lisp` | ~450 | Business account management |

### Modified Files

| File | Changes |
|------|---------|
| `src/api/api-package.lisp` | +40 exports for payment/business |
| `cl-telegram.asd` | +2 source files, +1 test file |

---

## 📊 Code Statistics

| Metric | v0.19.0 | v0.20.0 | Change |
|--------|---------|---------|--------|
| Total Files | 100 | 102 | +2 |
| Total Lines | ~28,950 | ~30,000 | +1,050 |
| New Functions | - | 40+ | +40 |
| API Exports | 800+ | 840+ | +40 |
| Test Cases | 480+ | 530+ | +50 |

---

## 🔧 Technical Details

### Payment Flow

**Invoice Creation and Sending:**
```lisp
;; Create invoice with line items
(let ((invoice (make-invoice
                :title "Premium Subscription"
                :description "12 months access"
                :payload "premium_12m"
                :currency "USD"
                :prices (list (make-labeled-price "Annual" 9999))
                :need-email t)))
  ;; Send to user
  (send-invoice user-chat-id invoice)
  ;; Or create payment link
  (create-invoice-link invoice))
```

**Telegram Stars:**
- Stars use currency code "XTR"
- All Star transactions are tracked with transaction IDs
- Business accounts can transfer Stars to bot balance
- Premium subscriptions can be gifted using Stars

### Business Connection Model

Business connections allow bots to act on behalf of business accounts:

```
┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│ Business     │────▶│ Bot         │────▶│ Customers   │
│ Account      │     │ Connection  │     │ Chats       │
└──────────────┘     └─────────────┘     └─────────────┘
     │                      │
     │ - Rights             │
     │ - Location           │
     │ - Hours              │
     └──────────────────────┘
```

### Opening Hours Format

Opening hours use minute-of-week format (0-10080):
- Monday 9:00 AM = 540 minutes (9 * 60)
- Friday 5:00 PM = 1020 minutes (17 * 60)
- Sunday 11:59 PM = 10079 minutes

Helper function `make-opening-hours-from-times` converts human-readable times:
```lisp
(make-opening-hours-from-times
  "UTC"
  '(0 9 17)  ; Monday 9am-5pm
  '(1 9 17)  ; Tuesday 9am-5pm
  '(2 9 17)) ; Wednesday 9am-5pm
```

### Quick Reply Types

Supported quick reply button types:
- `:text` - Standard text button
- `:phone` - Requests user phone number
- `:email` - Requests user email address
- `:location` - Requests user location

---

## ⚠️ Breaking Changes

**None** - This release is fully backward compatible with v0.19.0.

---

## 🔧 Migration Guide

No migration required. All new functions are additive and do not modify existing APIs.

---

## 🧪 Testing

### Test Coverage Goal

- Payment System: 25+ tests
- Business Features: 25+ tests
- **Total**: 50+ new tests

### Running Tests

```lisp
;; Load test system
(asdf:load-system :cl-telegram/tests)

;; Run v0.20.0 tests
(cl-telegram/tests:run-payment-business-tests)
```

### Test Suites

| Suite | Tests | Coverage |
|-------|-------|----------|
| Payment Classes | 10+ | Invoice, Star, Price objects |
| Business Classes | 15+ | Connection, Location, Hours |
| API Mock Tests | 20+ | All payment/business functions |
| Helper Functions | 5+ | Invoice creation helpers |

---

## 💰 Payment Integration

### Supported Currencies

v0.20.0 supports all major currencies plus Telegram Stars:
- USD, EUR, GBP, RUB, CNY, JPY, INR, BRL, TRY, KRW
- **XTR** - Telegram Stars (for digital goods)

### Payment Providers

Telegram supports multiple payment providers. Configure your provider token:
- Stripe (global)
- Paywall (Russia)
- LiqPay (Ukraine)
- ЮKassa (Russia)
- etc.

See Telegram's payment documentation for full provider list.

### Telegram Stars Use Cases

Stars are designed for:
- Digital goods and services
- In-bot purchases
- Premium content access
- Virtual gifts
- Premium subscription gifting

---

## 🏢 Business Account Use Cases

### Small Business Profile
```lisp
;; Set up complete business profile
(set-business-location connection-id "123 Main St"
                       :latitude 40.7128
                       :longitude -74.0060)

(set-business-opening-hours
 connection-id
 (make-opening-hours-from-times
  "America/New_York"
  '(0 9 17)   ; Mon 9am-5pm
  '(1 9 17)   ; Tue 9am-5pm
  '(2 9 17)   ; Wed 9am-5pm
  '(3 9 17)   ; Thu 9am-5pm
  '(4 9 17))) ; Fri 9am-5pm
```

### Customer Support Bot
```lisp
;; Send message with quick reply options
(let ((replies (list (make-quick-reply "📞 Call Us")
                     (make-quick-reply "📍 Visit Store")
                     (make-quick-reply "💬 Chat"))))
  (send-message-with-quick-replies chat-id "How can we help?" replies))
```

### Paid Subscription
```lisp
;; Create and send subscription invoice
(let ((invoice (create-subscription-invoice
                "Premium Access"
                "Monthly subscription with full features"
                "premium_monthly"
                "USD"
                999  ; $9.99
                :months 1)))
  (send-invoice user-chat-id invoice))
```

---

## 🙏 Acknowledgments

- Telegram Bot API specification
- Telegram Stars documentation
- Common Lisp JSON handling libraries

---

## 📝 TODO for v0.21.0

Next phase focuses on User Experience enhancements:

1. **Folder Management** (5-7 days)
   - Chat folders with filters
   - Custom folder creation
   - Folder-based chat organization
   - Archive management

2. **Emoji & Customization** (4-5 days)
   - Custom emoji packs
   - Animated emoji effects
   - Chat wallpaper management
   - Message effects

3. **Channel Advanced Features** (3-4 days)
   - Channel topics/threads
   - Sponsored messages
   - Channel statistics
   - Reaction analytics

---

**Full Changelog**: See commit history for detailed changes.
