# Phase 1: Authentication & Onboarding
## PoultryPro Frontend Development Guide

---

## 📋 PHASE OVERVIEW

**What You'll Build**:
- Public landing page
- Sign up flow with email verification
- Login flow with password reset
- 5-step onboarding wizard
- First batch creation
- Worker setup

**Database Tables**: `profiles`, `batches`, `workers`

**Estimated Time**: 2-3 days

---

## 1.1 LANDING PAGE

### Route: `/`

### Purpose
Marketing page to attract farmers and explain the product.

### Layout Structure
```
┌─────────────────────────────────────────┐
│ Navigation Bar                          │
│  Logo | Features | Pricing | Sign In   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Hero Section                            │
│  - Headline                             │
│  - Subheadline                          │
│  - CTA: "Start Free Trial"             │
│  - Hero image/illustration             │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Features Section (3 columns)            │
│  - Telegram Integration                 │
│  - Real-time Alerts                     │
│  - Financial Tracking                   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ How It Works (3 steps)                  │
│  1. Add your batches                    │
│  2. Workers report via Telegram         │
│  3. Track everything in one place       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Pricing Section                         │
│  - Basic: $10/mo                        │
│  - Premium: $25/mo                      │
│  - 14-day free trial                    │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ Footer                                  │
│  Links | Contact | Social               │
└─────────────────────────────────────────┘
```

### Components Needed
- `Navbar` - Sticky navigation
- `Hero` - Main value proposition
- `FeatureCard` - Feature highlights
- `PricingCard` - Pricing tiers
- `Footer` - Site footer

### Content

**Hero Headline**: "Manage Your Poultry Farm with Ease"

**Subheadline**: "Track birds, monitor production, manage workers, and boost profits—all from your phone or computer."

**Features**:
1. **📱 Telegram Integration**
   - Workers report daily via Telegram bot
   - No app installation needed
   - Voice messages supported

2. **🔔 Real-time Alerts**
   - High mortality warnings
   - Vaccination reminders
   - Production drop notifications

3. **💰 Financial Tracking**
   - Track income and expenses
   - Calculate ROI per batch
   - Generate financial reports

**Pricing**:
- **Basic**: $10/month
  - Up to 5 batches
  - 10 workers
  - Basic reports
  - 14-day free trial

- **Premium**: $25/month
  - Unlimited batches
  - Unlimited workers
  - Advanced analytics
  - Priority support
  - 14-day free trial

### Actions
- Click "Start Free Trial" → Navigate to `/signup`
- Click "Sign In" → Navigate to `/login`
- Click "Learn More" → Scroll to features

### Implementation Notes
- Use Next.js App Router
- Static page (no authentication required)
- Optimize images (use Next.js Image component)
- Add meta tags for SEO
- Mobile responsive

---

## 1.2 SIGN UP FLOW

### Route: `/signup`

### Purpose
Create new farmer account with email/password authentication.

### Form Fields

```typescript
interface SignUpForm {
  email: string;          // required, email validation
  password: string;       // required, min 8 chars
  confirmPassword: string; // must match password
  fullName: string;       // required, min 2 chars
  farmName?: string;      // optional
  phone?: string;         // optional, E.164 format
}
```

### UI Layout

```
┌─────────────────────────────────────────┐
│ Logo                                    │
│                                         │
│ Create Your Account                     │
│                                         │
│ [Email Input]                           │
│ [Password Input] (with strength meter)  │
│ [Confirm Password Input]                │
│ [Full Name Input]                       │
│ [Farm Name Input] (optional)            │
│ [Phone Input] (optional)                │
│                                         │
│ [✓] I agree to Terms & Privacy Policy   │
│                                         │
│ [Create Account Button]                 │
│                                         │
│ Already have an account? Sign in        │
└─────────────────────────────────────────┘
```

### Validation Rules

**Email**:
- Required
- Valid email format
- Check if already registered (on blur)

**Password**:
- Required
- Minimum 8 characters
- At least 1 uppercase letter
- At least 1 number
- Show strength indicator (Weak/Medium/Strong)

**Confirm Password**:
- Must match password
- Real-time validation

**Full Name**:
- Required
- Minimum 2 characters
- Letters and spaces only

**Phone** (optional):
- E.164 format validation
- Country code selector

### Implementation Flow

```typescript
// 1. Client-side validation
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8).regex(/[A-Z]/).regex(/[0-9]/),
  confirmPassword: z.string(),
  fullName: z.string().min(2),
  farmName: z.string().optional(),
  phone: z.string().optional(),
}).refine(data => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

// 2. Call Supabase Auth
const { data, error } = await supabase.auth.signUp({
  email: formData.email,
  password: formData.password,
  options: {
    data: {
      full_name: formData.fullName,
      farm_name: formData.farmName,
      phone: formData.phone,
    },
    emailRedirectTo: `${window.location.origin}/auth/callback`,
  },
});

// 3. Handle response
if (error) {
  // Show error message
  setError(error.message);
} else {
  // Redirect to verification page
  router.push('/verify-email');
}
```

### Database Operations

**Automatic** (via `handle_new_user()` trigger):
```sql
-- This happens automatically when user signs up
INSERT INTO profiles (id, email, full_name, phone, farm_name, subscription_status, subscription_ends_at)
VALUES (
  NEW.id,
  NEW.email,
  NEW.raw_user_meta_data->>'full_name',
  NEW.raw_user_meta_data->>'phone',
  NEW.raw_user_meta_data->>'farm_name',
  'trial',
  NOW() + INTERVAL '14 days'
);
```

### Error Handling

**Common Errors**:
- `User already registered` → "This email is already in use"
- `Invalid email` → "Please enter a valid email address"
- `Weak password` → "Password must be at least 8 characters with 1 uppercase and 1 number"
- Network error → "Connection failed. Please try again"

### Success State
- Show success message: "Account created! Check your email to verify."
- Redirect to `/verify-email`
- Display user's email address

### Components Needed
- `Input` - Text input with validation
- `PasswordInput` - Password with show/hide toggle
- `PasswordStrengthMeter` - Visual strength indicator
- `PhoneInput` - Phone with country selector
- `Checkbox` - Terms agreement
- `Button` - Submit button with loading state
- `FormError` - Error message display

---

## 1.3 EMAIL VERIFICATION

### Route: `/verify-email`

### Purpose
Inform user to check email and verify their account.

### UI Layout

```
┌─────────────────────────────────────────┐
│                                         │
│         📧 (Email Icon)                 │
│                                         │
│     Check Your Email                    │
│                                         │
│ We sent a verification link to:         │
│ user@example.com                        │
│                                         │
│ Click the link in the email to          │
│ activate your account.                  │
│                                         │
│ [Resend Email Button]                   │
│                                         │
│ Didn't receive it? Check spam folder    │
│                                         │
│ [Change Email Address]                  │
└─────────────────────────────────────────┘
```

### Actions

**Resend Email**:
```typescript
const { error } = await supabase.auth.resend({
  type: 'signup',
  email: userEmail,
});

if (!error) {
  toast.success('Verification email sent!');
}
```

**Change Email**:
- Navigate back to `/signup`
- Pre-fill form with previous data (except email)

### Email Verification Callback

**Route**: `/auth/callback`

**Purpose**: Handle email verification redirect from Supabase.

```typescript
// app/auth/callback/route.ts
export async function GET(request: Request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get('code');

  if (code) {
    const supabase = createServerClient();
    await supabase.auth.exchangeCodeForSession(code);
  }

  // Redirect to onboarding or dashboard
  return NextResponse.redirect(new URL('/onboarding', request.url));
}
```

---

## 1.4 LOGIN FLOW

### Route: `/login`

### Purpose
Existing users sign in to their account.

### Form Fields

```typescript
interface LoginForm {
  email: string;
  password: string;
  rememberMe: boolean;
}
```

### UI Layout

```
┌─────────────────────────────────────────┐
│ Logo                                    │
│                                         │
│ Welcome Back                            │
│                                         │
│ [Email Input]                           │
│ [Password Input]                        │
│                                         │
│ [✓] Remember me                         │
│                                         │
│ [Sign In Button]                        │
│                                         │
│ Forgot password?                        │
│                                         │
│ Don't have an account? Sign up          │
└─────────────────────────────────────────┘
```

### Implementation

```typescript
const { data, error } = await supabase.auth.signInWithPassword({
  email: formData.email,
  password: formData.password,
});

if (error) {
  setError('Invalid email or password');
} else {
  // Check if onboarding completed
  const { data: profile } = await supabase
    .from('profiles')
    .select('raw_user_meta_data')
    .eq('id', data.user.id)
    .single();

  const onboardingCompleted = profile?.raw_user_meta_data?.onboarding_completed;

  if (onboardingCompleted) {
    router.push('/dashboard');
  } else {
    router.push('/onboarding');
  }
}
```

### Error Handling
- Invalid credentials → "Invalid email or password"
- Email not verified → "Please verify your email first"
- Account disabled → "Your account has been disabled"

---

## 1.5 FORGOT PASSWORD

### Route: `/forgot-password`

### Purpose
Allow users to reset their password via email.

### UI Layout

```
┌─────────────────────────────────────────┐
│ Logo                                    │
│                                         │
│ Forgot Password?                        │
│                                         │
│ Enter your email and we'll send you     │
│ a link to reset your password.          │
│                                         │
│ [Email Input]                           │
│                                         │
│ [Send Reset Link Button]                │
│                                         │
│ Back to Sign In                         │
└─────────────────────────────────────────┘
```

### Implementation

```typescript
const { error } = await supabase.auth.resetPasswordForEmail(email, {
  redirectTo: `${window.location.origin}/reset-password`,
});

if (!error) {
  toast.success('Check your email for reset link');
}
```

---

## 1.6 RESET PASSWORD

### Route: `/reset-password`

### Purpose
Allow users to set a new password after clicking email link.

### UI Layout

```
┌─────────────────────────────────────────┐
│ Logo                                    │
│                                         │
│ Reset Your Password                     │
│                                         │
│ [New Password Input]                    │
│ [Confirm Password Input]                │
│                                         │
│ [Reset Password Button]                 │
└─────────────────────────────────────────┘
```

### Implementation

```typescript
const { error } = await supabase.auth.updateUser({
  password: newPassword,
});

if (!error) {
  toast.success('Password updated successfully');
  router.push('/login');
}
```

---

## 1.7 ONBOARDING WIZARD

### Route: `/onboarding`

### Purpose
Guide new users through initial setup in 5 steps.

### Overall Layout

```
┌─────────────────────────────────────────┐
│ Progress Bar: ●●○○○ (Step 2 of 5)       │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│                                         │
│         [Step Content Here]             │
│                                         │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│ [Back Button]          [Next Button]    │
└─────────────────────────────────────────┘
```

---

### STEP 1: WELCOME

**Content**:
```
Welcome to PoultryPro! 🐔

Let's get your farm set up in just a few minutes.

You'll be able to:
✓ Track your birds
✓ Monitor daily production
✓ Manage workers
✓ Track finances

[Get Started Button]
```

**Action**: Click "Get Started" → Go to Step 2

---

### STEP 2: FARM DETAILS

**Form Fields**:
```typescript
interface FarmDetailsForm {
  farmName: string;        // required
  location?: string;       // optional
  farmSize?: 'small' | 'medium' | 'large';
  primaryBirdType: 'layer' | 'broiler' | 'both';
}
```

**UI**:
```
Tell Us About Your Farm

[Farm Name Input] *required
[Location Input] (optional)

Farm Size:
○ Small (< 1,000 birds)
○ Medium (1,000 - 10,000 birds)
○ Large (> 10,000 birds)

What do you raise?
○ Layers (Egg production)
○ Broilers (Meat production)
○ Both

[Continue Button]
```

**Database Update**:
```typescript
await supabase
  .from('profiles')
  .update({
    farm_name: formData.farmName,
    raw_user_meta_data: {
      location: formData.location,
      farm_size: formData.farmSize,
      primary_bird_type: formData.primaryBirdType,
    },
  })
  .eq('id', user.id);
```

---

### STEP 3: CREATE FIRST BATCH

**Form Fields**:
```typescript
interface FirstBatchForm {
  batchName: string;           // required, e.g., "Batch A"
  birdType: 'layer' | 'broiler'; // required
  initialCount: number;        // required, min 1
  startDate: Date;             // required, default today
  chickCostPerBird?: number;   // optional
}
```

**UI**:
```
Create Your First Batch

A batch is a group of birds you're raising together.

[Batch Name Input] *required
Example: "Batch A", "January Layers"

Bird Type: *required
○ Layers (Egg production)
○ Broilers (Meat production)

[Initial Bird Count Input] *required
How many birds are in this batch?

[Start Date Picker] *required
When did this batch start?

[Cost Per Chick Input] (optional)
How much did each chick cost?

[Create Batch Button]
```

**Auto-calculations**:
```typescript
const totalChickCost = chickCostPerBird * initialCount;
const expectedEndDate = birdType === 'broiler' 
  ? addDays(startDate, 42)   // 6 weeks
  : addDays(startDate, 540);  // 18 months
```

**Database Insert**:
```sql
INSERT INTO batches (
  farmer_id,
  name,
  bird_type,
  initial_count,
  current_count,
  start_date,
  expected_end_date,
  chick_cost_per_bird,
  total_chick_cost,
  status
) VALUES (
  auth.uid(),
  ?,
  ?,
  ?,
  ?, -- same as initial_count
  ?,
  ?,
  ?,
  ?,
  'active'
) RETURNING *;
```

**Validation**:
- Batch name must be unique per farmer
- Initial count must be positive integer
- Start date cannot be more than 1 year in the past (warning, not error)

---

### STEP 4: ADD WORKERS (OPTIONAL)

**Purpose**: Add farm employees who will report daily data.

**UI**:
```
Add Your Workers (Optional)

Workers can report daily data via Telegram or SMS.
You can add more workers later.

┌─────────────────────────────────────────┐
│ Worker 1                                │
│ [Name Input] *required                  │
│ [Phone Input] (optional)                │
│ Role: ○ Worker ○ Supervisor             │
│ [Remove Button]                         │
└─────────────────────────────────────────┘

[+ Add Another Worker Button]

[Skip for Now]  [Continue]
```

**Form Fields** (per worker):
```typescript
interface WorkerForm {
  name: string;
  phone?: string;
  role: 'worker' | 'supervisor' | 'manager';
  communicationMethod: 'telegram' | 'sms' | 'both';
}
```

**Database Insert** (for each worker):
```sql
INSERT INTO workers (
  farmer_id,
  name,
  phone,
  role,
  communication_method,
  is_active
) VALUES (
  auth.uid(),
  ?,
  ?,
  ?,
  'telegram', -- default
  true
) RETURNING *;
```

**Features**:
- Add multiple workers (dynamic form)
- Remove worker before saving
- Skip this step entirely
- Workers can be added later from dashboard

---

### STEP 5: TELEGRAM SETUP

**Purpose**: Explain how workers connect via Telegram bot.

**UI**:
```
Connect Workers via Telegram

Your workers can report daily data through our
Telegram bot - no app installation needed!

How to connect:

1. Open Telegram
2. Search for: @PoultryProBot
3. Send: /start
4. Share this code with your workers:

   ┌─────────────────────────┐
   │  FARM-ABC123            │
   │  [Copy Code Button]     │
   └─────────────────────────┘

Workers will use this code to link their
Telegram account to your farm.

[I'll Do This Later]  [Complete Setup]
```

**Invitation Code Format**:
```typescript
const invitationCode = `FARM-${shortId(user.id)}`;
// Store in profiles.raw_user_meta_data
```

**Action**: Click "Complete Setup" → Mark onboarding complete → Redirect to `/dashboard`

**Database Update**:
```sql
UPDATE profiles
SET raw_user_meta_data = jsonb_set(
  raw_user_meta_data,
  '{onboarding_completed}',
  'true'
)
WHERE id = auth.uid();
```

---

## 1.8 ONBOARDING COMPLETION

### Success Screen

**UI**:
```
🎉 You're All Set!

Your farm is ready to go.

Here's what you can do next:
✓ View your dashboard
✓ Add daily records
✓ Invite more workers
✓ Track finances

[Go to Dashboard Button]
```

**Action**: Navigate to `/dashboard`

---

## COMPONENTS TO BUILD

### 1. AuthLayout
Wrapper for all auth pages with centered card layout.

### 2. Input
Text input with label, error message, validation states.

### 3. PasswordInput
Password field with show/hide toggle and strength meter.

### 4. PhoneInput
Phone number input with country code selector.

### 5. Button
Primary button with loading state and variants.

### 6. ProgressBar
Visual progress indicator for onboarding steps.

### 7. FormError
Error message display component.

### 8. Toast
Notification component for success/error messages.

---

## VALIDATION SCHEMAS

```typescript
// Sign Up
export const signUpSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string()
    .min(8, 'Password must be at least 8 characters')
    .regex(/[A-Z]/, 'Password must contain uppercase letter')
    .regex(/[0-9]/, 'Password must contain a number'),
  confirmPassword: z.string(),
  fullName: z.string().min(2, 'Name must be at least 2 characters'),
  farmName: z.string().optional(),
  phone: z.string().optional(),
}).refine(data => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

// Login
export const loginSchema = z.object({
  email: z.string().email('Invalid email address'),
  password: z.string().min(1, 'Password is required'),
});

// Farm Details
export const farmDetailsSchema = z.object({
  farmName: z.string().min(2, 'Farm name is required'),
  location: z.string().optional(),
  farmSize: z.enum(['small', 'medium', 'large']).optional(),
  primaryBirdType: z.enum(['layer', 'broiler', 'both']),
});

// First Batch
export const firstBatchSchema = z.object({
  batchName: z.string().min(1, 'Batch name is required'),
  birdType: z.enum(['layer', 'broiler']),
  initialCount: z.number().int().positive('Must be at least 1'),
  startDate: z.date(),
  chickCostPerBird: z.number().nonnegative().optional(),
});

// Worker
export const workerSchema = z.object({
  name: z.string().min(2, 'Name is required'),
  phone: z.string().optional(),
  role: z.enum(['worker', 'supervisor', 'manager']),
  communicationMethod: z.enum(['telegram', 'sms', 'both']),
});
```

---

## TESTING CHECKLIST

### Sign Up
- [ ] Valid email and password creates account
- [ ] Duplicate email shows error
- [ ] Weak password shows error
- [ ] Password mismatch shows error
- [ ] Profile auto-created in database
- [ ] Verification email sent
- [ ] Trial period set to 14 days

### Login
- [ ] Valid credentials log in successfully
- [ ] Invalid credentials show error
- [ ] Unverified email shows warning
- [ ] Remember me persists session
- [ ] Redirects to onboarding if not completed
- [ ] Redirects to dashboard if completed

### Onboarding
- [ ] Progress bar updates correctly
- [ ] Can navigate back and forward
- [ ] Farm details saved to profile
- [ ] Batch created successfully
- [ ] Workers added successfully
- [ ] Can skip worker step
- [ ] Onboarding completion flag set
- [ ] Redirects to dashboard after completion

---

## NEXT PHASE

Once Phase 1 is complete, proceed to **Phase 2: Dashboard & Core Features** to build the main application interface.

---

**Phase 1 Complete! ✅**
