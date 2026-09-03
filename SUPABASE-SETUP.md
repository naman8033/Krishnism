# Supabase & Free Mode UPI Store Setup

Krishnism is configured to run in **100% Free Mode** with zero third-party payment gateway fees using direct UPI payments, QR codes, and WhatsApp study group onboarding.

### 1. Configure Supabase Project
1. Create a free project at [supabase.com](https://supabase.com).
2. Copy your **Project URL** and **Publishable (anon)** API key from `Project Settings → API` into [`supabase-config.js`](file:///c:/Users/naman/Documents/Codex/2026-09-02/bu/outputs/supabase-config.js).
3. In `supabase-config.js`, set your default UPI ID (e.g. `naman8080@ybl`) and business name (`Krishnism`).

### 2. Create the Store Admin Account
1. In Supabase Dashboard → **Authentication** → **Users**, click **Add user** (or sign up with email).
2. Note the admin email you created (e.g. `naman8033@example.com`).

### 3. Run Database Schema
1. Open [`supabase-schema.sql`](file:///c:/Users/naman/Documents/Codex/2026-09-02/bu/outputs/supabase-schema.sql).
2. Replace `'naman8033@example.com'` in line 67 with your actual admin email.
3. Paste the entire SQL file into **Supabase Dashboard → SQL Editor** and click **Run**.
4. (Optional) Run [`supabase-customer-profiles.sql`](file:///c:/Users/naman/Documents/Codex/2026-09-02/bu/outputs/supabase-customer-profiles.sql) if you want automatic customer profile syncing on signup.

### 4. Back Office Administration
1. Open [`backoffice.html`](file:///c:/Users/naman/Documents/Codex/2026-09-02/bu/outputs/backoffice.html) in your browser.
2. Sign in with your admin email (`naman8033@gmail.com`) and password.
3. In **Customers & Students**, view all registered customers and learners, search by name/email/phone, see lifetime spend, course enrolments, and track WhatsApp cohort group onboarding.
4. In **Orders & Payments**, view customer orders, inspect their UPI UTR reference number, change order status (`Pending` → `Paid` → `Shipped`), and add tracking courier numbers.
5. In **Books & Courses**, add, edit, publish or hide store offerings.
6. In **Store & UPI Settings**, dynamically change your UPI ID, Payee Name, Owner/Support WhatsApp number for customer queries, WhatsApp Cohort link, and Google Meet link at any time without code changes!

### 5. Deployment
- Host the files on any static host (Cloudflare Pages, Vercel, Netlify, or GitHub Pages).
- Ensure your custom domain is served over HTTPS.
