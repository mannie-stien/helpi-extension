# Phase 6: Settings & Telegram Integration
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- User profile settings
- Farm settings
- Subscription management and billing
- Payment history
- Telegram bot setup and configuration
- Worker invitation system
- Bot conversation flows
- Edge function for webhook

**Database Tables**: `profiles`, `subscriptions`, `payments`, `telegram_conversations`, `workers`

**Estimated Time**: 3-4 days

---

## 6.1 SETTINGS PAGE

**Route**: `/settings`

**Layout**: Sidebar with sections + content area

**Sidebar Sections**:
- Profile
- Farm
- Subscription & Billing
- Notifications
- Telegram Bot
- Security
- Danger Zone

---

## 6.2 PROFILE SETTINGS

**Route**: `/settings/profile`

**Editable Fields**:
- Full name
- Email (with verification if changed)
- Phone number
- Profile photo (upload to Storage)
- Timezone
- Language preference

**Data Source**: `profiles` table
- Where: `id = auth.uid()`

**Update**: Update `profiles` table

**Photo Upload**:
- Upload to Storage bucket: `avatars/{user_id}`
- Max size: 2MB
- Allowed types: JPG, PNG
- Store URL in profile

---

## 6.3 FARM SETTINGS

**Route**: `/settings/farm`

**Editable Fields**:
- Farm name
- Location/Address
- Farm size (Small, Medium, Large)
- Primary bird type (Layer, Broiler, Both)
- Farm description

**Data Source**: `profiles` table
- Fields: `farm_name`, `raw_user_meta_data`

**Update**: Update `profiles` table

---

## 6.4 SUBSCRIPTION & BILLING

**Route**: `/settings/subscription`

**Current Plan Section**:
- Plan name (Basic/Premium)
- Status badge (Trial, Active, Past Due, Cancelled)
- Current period (start and end dates)
- Next billing date
- Amount
- "Upgrade" or "Change Plan" button
- "Cancel Subscription" button

**Data Source**: `subscriptions` table
- Where: `farmer_id = auth.uid()`

**Plan Comparison**:
- Show Basic vs Premium features
- Pricing
- "Select Plan" buttons

**Upgrade/Downgrade Flow**:
1. User selects new plan
2. Calculate prorated amount
3. Redirect to payment provider (Paystack/Stripe)
4. Handle webhook to update subscription
5. Update `subscriptions` table

**Cancel Subscription**:
- Confirmation modal
- Set `cancelled_at` timestamp
- Subscription remains active until period end
- Update `status` to 'cancelled'

---

## 6.5 PAYMENT HISTORY

**Route**: `/settings/payments`

**Purpose**: View all past payments

**Table Columns**:
- Date
- Description
- Amount
- Status (badge: Success, Failed, Pending, Refunded)
- Payment Method
- Receipt (download link)

**Data Source**: `payments` table
- Where: `farmer_id = auth.uid()`
- Order by: `created_at DESC`

**Pagination**: 20 items per page

**Download Receipt**:
- Generate PDF receipt
- Include: Date, amount, payment method, transaction ID
- Farmer details, farm name

---

## 6.6 TELEGRAM BOT SETUP

**Route**: `/settings/telegram`

**Purpose**: Configure Telegram bot for farm

**Setup Instructions Section**:
1. Bot username: `@PoultryProBot`
2. Farm invitation code: `FARM-{short_id}`
3. Instructions for workers
4. QR code for easy access

**Connected Workers Section**:
- List workers with Telegram connected
- Show: Name, Telegram username, connection date
- "Disconnect" button per worker

**Data Source**: `workers` table
- Where: `farmer_id = auth.uid()` AND `telegram_id IS NOT NULL`

**Bot Commands Reference**:
- `/start` - Connect to farm
- `/record` - Start guided recording
- `/status` - View batch status
- `/help` - Show help

**Test Bot Section**:
- "Send Test Message" button
- Sends message to farmer's Telegram (if connected)

---

## 6.7 WORKER INVITATION FLOW

**Farmer Side** (Web):
1. Add worker in system
2. Get invitation code: `FARM-{farmer_id_short}-{worker_id_short}`
3. Share code with worker (SMS, WhatsApp, in person)

**Worker Side** (Telegram):
1. Worker opens Telegram
2. Searches for `@PoultryProBot`
3. Sends `/start {invitation_code}`
4. Bot validates code
5. Bot links worker's `telegram_id` to worker record
6. Bot sends welcome message with instructions

**Database Update** (via Edge Function):
- Table: `workers`
- Set `telegram_id` = message sender's Telegram ID
- Set `telegram_username` = message sender's username
- Set `last_active_at` = NOW()

**Validation**:
- Check invitation code format
- Verify farmer and worker exist
- Ensure worker not already connected
- Check worker belongs to farmer

---

## 6.8 TELEGRAM BOT CONVERSATION FLOWS

### Flow 1: Simple Text Parsing
**Worker sends**: "3 dead, 120 eggs, 2 bags"

**Bot logic**:
1. Parse using regex: `(\d+)\s*(dead|died|death)`, `(\d+)\s*egg`, `(\d+\.?\d*)\s*(bag|sack)`
2. Extract: mortality=3, eggs=120, feed=2
3. Determine batch (if worker assigned to multiple, ask which one)
4. Show confirmation message
5. Wait for confirmation
6. Insert into `daily_records`

### Flow 2: Guided Conversation
**Worker sends**: `/record`

**Bot conversation**:
1. Bot: "Which batch? 1) Batch A, 2) Batch B"
2. Worker: "1"
3. Bot: "How many deaths today?"
4. Worker: "2"
5. Bot: "How many eggs collected?"
6. Worker: "118"
7. Bot: "Feed bags used?"
8. Worker: "1.5"
9. Bot: "Any notes? (Send 'skip' to skip)"
10. Worker: "skip"
11. Bot: Shows summary, asks for confirmation
12. Worker: Confirms
13. Bot: Saves to database

**State Management**:
- Store in `telegram_conversations` table
- Fields: `current_state`, `pending_data` (JSONB)
- Update on each message
- Clear after completion or timeout (30 minutes)

### Flow 3: Voice Message
**Worker sends**: Voice note saying "Today we had 2 deaths and collected 115 eggs"

**Bot logic**:
1. Download voice file
2. Transcribe using speech-to-text API (OpenAI Whisper, Google Speech-to-Text)
3. Parse transcript like text message
4. Show confirmation with transcript
5. Save with `voice_transcript` field

### Flow 4: Photo with Caption
**Worker sends**: Photo with caption "5 dead birds"

**Bot logic**:
1. Download photo
2. Upload to Supabase Storage: `batch-photos/{farmer_id}/{batch_id}/{timestamp}`
3. Parse caption for data
4. Show confirmation
5. Save record with photo URL in `photo_urls` array

---

## 6.9 TELEGRAM EDGE FUNCTION

**File**: `supabase/functions/telegram-webhook/index.ts`

**Purpose**: Handle incoming Telegram messages

**Endpoint**: POST `/telegram-webhook`

**Flow**:
1. Receive webhook from Telegram
2. Verify webhook signature
3. Extract message data
4. Identify worker by `telegram_id`
5. Determine message type (text, voice, photo)
6. Process based on type
7. Update conversation state if needed
8. Save data to database
9. Send response to worker

**Database Operations**:
- Query: `workers` table to find worker by `telegram_id`
- Query: `batches` table to get worker's assigned batches
- Insert: `daily_records` table
- Update: `telegram_conversations` table for state
- Update: `workers.last_active_at`

**Error Handling**:
- Worker not found: Send "Not registered" message
- Invalid data: Send "Could not understand" message
- Database error: Send "Error saving" message, log error

**Telegram API Calls**:
- Send message: `sendMessage`
- Send photo: `sendPhoto`
- Send keyboard: `sendMessage` with `reply_markup`

---

## 6.10 NOTIFICATION SETTINGS

**Route**: `/settings/notifications`

**Email Notifications**:
- Daily summary (checkbox)
- Weekly report (checkbox)
- High mortality alerts (checkbox)
- Vaccination reminders (checkbox)
- Subscription updates (checkbox)

**Push Notifications** (Future):
- Browser push notifications
- Mobile app notifications

**Data Storage**: `profiles.raw_user_meta_data.notification_preferences`

---

## 6.11 SECURITY SETTINGS

**Route**: `/settings/security`

**Features**:
- Change password
- Two-factor authentication (2FA) setup
- Active sessions list
- Sign out all devices

**Change Password**:
- Current password (required)
- New password (required, validation)
- Confirm new password
- Call: `supabase.auth.updateUser({ password })`

**2FA Setup** (Future):
- Generate QR code
- Verify with code
- Store in Supabase Auth

---

## 6.12 DANGER ZONE

**Route**: `/settings/danger-zone`

**Actions**:

### Export All Data
- Generate ZIP file with all data
- Include: Batches, records, transactions, workers
- Format: CSV files
- Download link

### Delete Account
- Confirmation modal with password
- Warning: "This action cannot be undone"
- Checkbox: "I understand all data will be deleted"
- Delete all related data (cascading)
- Sign out user
- Redirect to landing page

**Database Operations**:
- Delete from `profiles` (cascades to all related tables due to ON DELETE CASCADE)
- Delete from Supabase Auth

---

## PAYMENT INTEGRATION

### Paystack Integration (Africa)

**Setup**:
1. Create Paystack account
2. Get API keys (public and secret)
3. Store in environment variables

**Subscription Flow**:
1. User selects plan
2. Frontend calls backend API
3. Backend creates Paystack subscription
4. Redirect user to Paystack checkout
5. User completes payment
6. Paystack sends webhook
7. Backend verifies webhook
8. Update `subscriptions` and `payments` tables

**Webhook Handler** (Edge Function):
- Verify webhook signature
- Handle events: `subscription.create`, `subscription.disable`, `charge.success`
- Update database accordingly

### Stripe Integration (Global)

**Similar flow to Paystack**:
- Use Stripe Checkout for subscriptions
- Handle webhooks for events
- Update database

---

## COMPONENTS TO BUILD

1. **SettingsLayout** - Sidebar + content layout
2. **SettingSection** - Section with title and description
3. **ProfileForm** - Edit profile fields
4. **FarmForm** - Edit farm details
5. **SubscriptionCard** - Current plan display
6. **PlanComparison** - Compare plans table
7. **PaymentTable** - Payment history table
8. **TelegramSetup** - Bot setup instructions
9. **InvitationCode** - Display and copy code
10. **NotificationToggle** - Checkbox with label
11. **PasswordChangeForm** - Change password
12. **DangerButton** - Red button for dangerous actions

---

## KEY QUERIES TO IMPLEMENT

1. **Get profile**: Select from `profiles` where `id = auth.uid()`
2. **Get subscription**: Select from `subscriptions` where `farmer_id = auth.uid()`
3. **Get payments**: Select from `payments` where `farmer_id = auth.uid()` order by date
4. **Get connected workers**: Select from `workers` where `farmer_id = auth.uid()` and `telegram_id IS NOT NULL`
5. **Validate invitation code**: Decode code, verify farmer and worker exist
6. **Update worker telegram**: Update `workers` set `telegram_id`, `telegram_username`
7. **Get conversation state**: Select from `telegram_conversations` where `telegram_id = ?`
8. **Update conversation state**: Update `telegram_conversations` set `current_state`, `pending_data`

---

## TELEGRAM BOT SETUP (Separate Service)

**Technology Options**:
1. **Node.js** with `node-telegram-bot-api` or `telegraf`
2. **Python** with `python-telegram-bot`
3. **Supabase Edge Function** (Deno)

**Recommended**: Supabase Edge Function for simplicity

**Bot Registration**:
1. Talk to @BotFather on Telegram
2. Create new bot: `/newbot`
3. Get bot token
4. Set webhook: `https://your-project.supabase.co/functions/v1/telegram-webhook`

**Environment Variables**:
- `TELEGRAM_BOT_TOKEN`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

---

## TESTING CHECKLIST

### Settings
- [ ] Profile updates save correctly
- [ ] Farm settings update
- [ ] Subscription displays correctly
- [ ] Payment history loads
- [ ] Change password works
- [ ] Delete account works (test in dev only)

### Telegram
- [ ] Bot responds to `/start`
- [ ] Invitation code validates
- [ ] Worker connects successfully
- [ ] Text parsing works
- [ ] Guided conversation works
- [ ] Voice transcription works
- [ ] Photo upload works
- [ ] Data saves to database
- [ ] Confirmation messages sent
- [ ] Error messages handled

---

## DEPLOYMENT CHECKLIST

### Frontend
- [ ] Build Next.js app
- [ ] Deploy to Vercel
- [ ] Set environment variables
- [ ] Configure custom domain
- [ ] Enable HTTPS

### Database
- [ ] Run schema in Supabase
- [ ] Enable RLS on all tables
- [ ] Test policies
- [ ] Create storage buckets
- [ ] Set storage policies

### Telegram Bot
- [ ] Deploy Edge Function
- [ ] Set webhook URL
- [ ] Test webhook receives messages
- [ ] Configure environment variables
- [ ] Test all conversation flows

### Payment Provider
- [ ] Set up Paystack/Stripe account
- [ ] Configure webhook URL
- [ ] Test payment flow
- [ ] Test subscription creation
- [ ] Test webhook handling

---

## NEXT STEPS

### Post-Launch
1. Monitor error logs
2. Collect user feedback
3. Track key metrics (signups, active users, retention)
4. Iterate based on feedback
5. Add requested features

### Future Enhancements
- Mobile app (React Native)
- SMS integration for workers without Telegram
- Advanced analytics with ML predictions
- Multi-language support
- Integration with IoT sensors
- Marketplace for selling eggs/birds
- Community forum for farmers

---

## 🎉 ALL PHASES COMPLETE!

You now have complete documentation to build the entire PoultryPro application from scratch. Each phase builds on the previous one, and all database tables, queries, and features are documented.

**Ready to build? Start with Phase 1 and work through sequentially!**

---

**Phase 6 Complete! ✅**
**Full Documentation Complete! 🚀**
