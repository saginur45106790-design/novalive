# NovaLive — Android social video chat application source

**এই ফাইলগুলো বাস্তব ফিচার বাস্তবায়নের কোড; কেবল ছবি বা UI mockup নয়।** তবে এগুলোকে এখনই “১০০% সম্পূর্ণ/নিরীক্ষিত/লাইভ-প্রোডাকশন” বলা যাবে না। Android APK এই প্যাকেজে নেই—GitHub Actions-এ বিল্ড করতে হবে। লাইভ ভিডিওর জন্য প্রকৃত LiveKit অ্যাকাউন্ট ও URL, সার্ভারের জন্য Postgres, অ্যাডমিনের জন্য আলাদা পাসওয়ার্ড প্রয়োজন। সেগুলো ChatGPT ব্যবহারকারীর হয়ে তৈরি করতে পারে না।

## প্রকল্পের ফাইল

- `mobile/lib/` — Flutter Android অ্যাপের স্ক্রিন, লগইন, কল, লাইভ, চ্যাট, কয়েন, রিপোর্ট, প্রোফাইল।
- `mobile/pubspec.yaml` — Flutter dependencies।
- `mobile/android/app/src/main/AndroidManifest.xml` — ক্যামেরা, মাইক, ইন্টারনেট অনুমতি।
- `server/src.js` — বাস্তব API, authentication, role checks, media token issuing, messaging, rooms, gifts, points ledger, moderation।
- `server/schema.sql` — PostgreSQL tables।
- `server/public/index.html` — ওয়েব অ্যাডমিন প্যানেল।
- `.github/workflows/android-apk.yml` — GitHub Actions দিয়ে APK বানানোর ব্যবস্থা।
- `render.yaml` — Render Web Service blueprint।

## ধাপ ১ — GitHub

1. GitHub-এ নতুন **private** রিপোজিটরি তৈরি করুন।
2. এই ZIP extract করে **`source` ফোল্ডারের ভেতরের সব ফাইল** রিপোজিটরির root-এ আপলোড করুন। `.github` ফোল্ডারটিও লাগবে।
3. সব ফাইল GitHub-এ Commit করুন।

## ধাপ ২ — Postgres

1. Neon বা অন্য managed PostgreSQL-এ একটি নতুন database তৈরি করুন।
2. সেখান থেকে `DATABASE_URL` কপি করুন (পাসওয়ার্ড কখনো GitHub-এ দেবেন না)।
3. SQL Editor-এ `server/schema.sql`-এর সম্পূর্ণ কোড একবার চালান।
4. SSL-enabled PostgreSQL URL ব্যবহার করুন।

## ধাপ ৩ — LiveKit

1. LiveKit Cloud-এ প্রজেক্ট তৈরি করুন অথবা production LiveKit SFU host করুন।
2. প্রকৃত `LIVEKIT_URL` (wss://...), `LIVEKIT_HTTP_URL` (https://...), `LIVEKIT_API_KEY` এবং `LIVEKIT_API_SECRET` নিন।
3. এগুলো কেবল backend-এ রাখতে হবে। **মোবাইল অ্যাপে API secret বসাবেন না।**

## ধাপ ৪ — Render

1. Render Dashboard → New → Web Service → Connect GitHub private repository।
2. Root Directory `server`, Build Command `npm install`, Start Command `npm start` দিন।
3. Environment Variables যোগ করুন: `DATABASE_URL`, `JWT_SECRET` (কমপক্ষে ৩২ অক্ষরের এলোমেলো গোপন মান), `LIVEKIT_URL`, `LIVEKIT_HTTP_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`।
4. Deploy দিন। `https://<আপনার-সার্ভিস>.onrender.com/health` খুলে `ok:true` নিশ্চিত করুন।
5. আপনার অ্যাডমিন প্যানেল `https://<আপনার-সার্ভিস>.onrender.com/admin/`।

## ধাপ ৫ — অ্যাডমিন অ্যাকাউন্ট তৈরি

এই ধাপটি নিজে থেকে জনসাধারণের রেজিস্ট্রেশনে অ্যাডমিন দেয় না। সার্ভারের shell/বিশ্বাসযোগ্য কম্পিউটারে `server`-এ গিয়ে নিচের কমান্ড **একবার** চালাতে হবে।

```bash
npm install
npm run migrate
ADMIN_BOOTSTRAP_EMAIL=owner@example.com ADMIN_BOOTSTRAP_PASSWORD='A_STRONG_UNIQUE_16_CHAR_PASSWORD' npm run admin:create
```

Windows PowerShell-এ আগে environment variables set করতে হবে। Render-এর কোন প্ল্যানে Shell পাওয়া যায় তা নির্ভর করে; ফ্রি প্ল্যানে Shell না থাকলে নিজের PC-তে Node.js দিয়ে এই command চালানো যাবে, এবং `server/.env`-এ সত্যিকারের `DATABASE_URL` দিতে হবে। তার পরে `server/.env` ফাইল GitHub-এ আপলোড করবেন না।

## ধাপ ৬ — APK বানানো (Android ফোনে ইনস্টলযোগ্য)

1. GitHub রিপোজিটরি খুলুন → Settings → Secrets and variables → Actions → Variables।
2. `API_BASE_URL` নামে variable তৈরি করুন। Value হবে `https://<আপনার-সার্ভিস>.onrender.com` (শেষে `/` নয়)।
3. GitHub → Actions → **Build Android APK** → Run workflow।
4. সফল হলে Run-এর `Artifacts` থেকে `NovaLive-Android-APK` ডাউনলোড করুন। ZIP-এর ভিতরে `app-release.apk` থাকবে।
5. APK নিজের ফোনে ইনস্টল করে ২টি আলাদা অ্যাকাউন্ট দিয়ে ভিডিও কল পরীক্ষা করুন। GitHub Actions-এ compiler সমস্যা থাকলে Log দেখতে হবে; ফাইল অপরীক্ষিত হওয়ায় বিল্ড সফল হবে এমন নিশ্চয়তা দেওয়া যাচ্ছে না।

**Google Play-তে প্রকাশের জন্য production signing key, app identity, Data Safety, privacy policy, account deletion, UGC moderation, age assurance, and developer verification আরও লাগবে।** GitHub থেকে পাওয়া সাধারণ release APK-কে Play Store-ready ধরে নেবেন না।

## বর্তমানে বাস্তবায়িত কোড

- ✅ Email/password login/register (১৮+ self-declaration; আসল পরিচয় যাচাই নয়)
- ✅ Public profile and discovery, messaging, block and report
- ✅ User-to-user private video call invitation and acceptance → LiveKit video room
- ✅ Host-controlled live stream and party rooms with LiveKit tokens
- ✅ Role-based admin user/host/suspension control
- ✅ Gifts with server-authoritative coin deduction and earning points credit
- ✅ Withdraw requests with approval/rejection ledger (manual bookkeeping)
- ✅ Admin dashboard with people, reports, payout review and controlled coin reconciliation

## যেগুলো ছাড়া ১০০% Chamet-class product হবে না

- ⚠️ Automatic real payment settlement (Google Play Billing, verified payout rails, refunds, AML/KYC and legal/compliance)
- ⚠️ Real ID/age verification, biometric consent and large scale trust & safety team
- ⚠️ Host agency multi-tier commissions, PK battle, 3D gifts, AI translations, filters, mini-games, push notifications, background incoming calls, friends and social feed
- ⚠️ Production monitoring, mobile security audit, data deletion tools, fraud tests, live room moderation, spam protection improvements, load tests, accessibility and app store compliance
- ⚠️ Reliable paid call metering, reconnect billing, background call push notifications, and complete user rights workflows
- ⚠️ Independent end-to-end tests (compiler, backend DB, real devices, LiveKit service)

This package is a concrete, expandable **source-code foundation**, not a guaranteed 100%-complete commercial service. Do not accept real funds until legally compliant payments, independent testing, and operational safety controls exist.
