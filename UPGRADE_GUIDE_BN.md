# NovaLive V2 — Android Network Repair + Major Source Upgrade

**এটি সোর্স কোডের আপডেট, ইনস্টলযোগ্য APK নয়।** Android release build এখনো এই পরিবেশে চালানো হয়নি। GitHub Actions-এ বিল্ড ও প্রকৃত ফোনে পরীক্ষা প্রয়োজন।

## গুরুত্বপূর্ণ: আপনার ডেটাবেস, অ্যাডমিন ও Render সার্ভার মুছবেন না

পুরোনো `server/schema.sql` আগের মতোই আছে। পুরোনো Registered Users এবং Admin-এর তথ্য Neon-এ থাকবে। `DATABASE_URL`, `JWT_SECRET`, LiveKit-এর সব Secret Render-এ আগের মতোই রাখবেন।

## কী আপডেট হলো

1. GitHub Actions এখন `flutter create`-এর **পরে** Release `AndroidManifest.xml` ঠিক করে।
2. Build-এর **শেষে আসল APK** খুলে `android.permission.INTERNET`, CAMERA এবং RECORD_AUDIO আছে কি না যাচাই করবে। Permission না থাকলে Build সবুজ হবে না।
3. Native launcher icon আর Flutter-এর ডিফল্ট নীল আইকন নয়: NovaLive-এর নিজস্ব gradient star icon।
4. অ্যাপের Login/Register-এর নিচে **Server Connection Test** বাটন।
5. Connection Test-এ `/health`, HTTP status, সময় ও সহজ বাংলা Error।
6. Render Free-এর Sleep থেকে জাগার সময় প্রায় ৮৫ সেকেন্ড পর্যন্ত Server response অপেক্ষা।
7. Network Error-এ গোপন Login Token মুছে ফেলা হয় না।
8. Register-এর আগে নাম, ইমেইল ও পাসওয়ার্ড প্রাথমিক যাচাই।
9. Backend-এ ঐচ্ছিক `/health/ready` DB test। Admin Panel টেবিল মোবাইলে স্ক্রল করা যায়।
10. আগের live/video/chat/wallet/moderation route ও data model সংরক্ষিত।

## আপনার GitHub-এ আপডেটের ফাইল

পুরোনো **novalive** repository-তেই নিচের ফাইলগুলো Update/Upload করুন। ZIP-এর `NovaLive_v2_Upgrade/` ফোল্ডারের ভিতরের বিষয়বস্তু Repository Root-এ রাখতে হবে।

- `.github/workflows/build-novalive.yml` — **সবার আগে এটি Update**
- `scripts/ensure_android_release.py` — **নতুন ফাইল**
- `mobile/lib/api.dart` — Update
- `mobile/lib/main.dart` — Update
- `mobile/lib/network_status_screen.dart` — নতুন ফাইল
- `mobile/pubspec.yaml` — version bump
- `mobile/branding/mipmap-*/ic_launcher.png` — নতুন icon files
- `server/src.js` — optional backend update
- `server/public/index.html` — optional admin UI improvement

বাকি ফাইলগুলোও প্যাকেজে আছে, কিন্তু পূর্বের কার্যকর সার্ভার/ডেটাবেস ফাইলগুলো মুছবেন না।

### সহজ পথ (ফোন থেকেও সম্ভব)

1. **দ্রুত Network Fix:** চাইলে শুধু `.github/workflows/build-novalive.yml` আপডেট করে Build চালাতে পারেন। কারণ পুরোনো মূল Manifest-এ Internet Permission আগেই আছে; নতুন Workflow সেটি Generate-এর আগে সংরক্ষণ ও পরে Restore করে, এবং চূড়ান্ত APK পরীক্ষা করে।
2. ZIP Extract করুন।
2. GitHub → আপনার `novalive` Repository → Code খুলুন।
3. `build-novalive.yml` খুলে Edit → নতুন ফাইলের পুরো কোড বসিয়ে Commit করুন।
4. `scripts/ensure_android_release.py` নামে নতুন ফাইল তৈরি করে কোড বসিয়ে Commit করুন।
5. `mobile/lib/api.dart`, `mobile/lib/main.dart` Replace/Commit করুন।
6. `mobile/lib/network_status_screen.dart` নতুন করে যোগ করুন।
7. `mobile/pubspec.yaml` Replace/Commit করুন।
8. `mobile/branding`-এ প্যাকেজের পাঁচটি launcher icon PNG নিজ নিজ ফোল্ডারে আপলোড করুন। GitHub ওয়েব UI-তে nested path-সহ ফাইল তৈরি বা drag/drop করা যায়; চাইলে PC থেকে GitHub Desktop-এ পুরো ফোল্ডার আপলোড সহজ।
9. GitHub → Settings → Secrets and variables → Actions → **Variables** → `API_BASE_URL` = `https://novalive-uo79.onrender.com` (Render থেকে সঠিক URL মিলিয়ে নিন)।
10. GitHub → Actions → **Build NovaLive Android APK** → Run workflow (`main`)। সবুজ হলে **NovaLive-Android-APK-v2** নামের Artifact নামান।
11. ZIP Extract করে APK ইনস্টল করুন। APK-এর package/signature আগের সঙ্গে না মিললে Android ইনস্টল আটকাতে পারে; এ ক্ষেত্রে APK signing নিশ্চিত করে নেবেন। পুরোনো অ্যাপ আনইনস্টল করলে ফোনে সেভ থাকা সেশন হারাতে পারেন, কিন্তু Neon account থাকবে।
12. অ্যাপ → **Server Connection Test** → `Server Online` এলে Login/Register পরীক্ষা করুন।

**খেয়াল করুন:** পুরোনো `.github/workflows/android-apk.yml` কাজ না করলে সেটি সরানো/নিষ্ক্রিয় করা যায়। Active build হিসেবে `build-novalive.yml` ব্যবহার করুন। একই APK-এর জন্য দুটি Workflow চালাবেন না।

## সম্ভাব্য Error

- **Build fails `scripts/ensure_android_release.py` missing** → `scripts/` নতুন ফাইলটি GitHub-এ সঠিক স্থানে নেই।
- **`mobile/lib/network_status_screen.dart` missing** → ফাইলটি GitHub-এ যোগ হয়নি।
- **`cp: cannot stat mobile/branding/...`** → icon PNG ফাইলগুলো সব আপলোড হয়নি।
- **aapt error** → Android SDK Build Tools runner-এ সমস্যা; লগের `Verify permission inside FINAL APK` step পাঠান।
- **App APK succeeded, `Server Online` নয়** → GitHub Variable-এর URL, নেটওয়ার্ক ও APK permission Log দেখুন।
- **`Email already registered`** → আগের অ্যাকাউন্ট থাকলে নতুন Registration নয়, Sign in করুন।

## নিরাপত্তা ও সীমাবদ্ধতা

এখানে আসল পেমেন্ট provider, KYC/age verification, push notifications, agency multi-level commission, ভিডিও মডারেশন বা production security audit বাস্তবায়িত নয়। ১০০% Chamet-এর সব ফিচার তৈরি হয়েছে বলে দাবি করবেন না। Google Play-এ পাবলিশ করতে Play policy, SDK signing ও privacy compliance লাগবে।

গোপন API Secret কখনও APK, `mobile/` বা GitHub Public Repository-তে দেবেন না। `JWT_SECRET` Render-এ রাখুন।
