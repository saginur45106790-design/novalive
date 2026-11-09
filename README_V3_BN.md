# NovaLive V3 — স্থায়ী নেটওয়ার্ক বিল্ড সংশোধন (বাংলা)

এই ZIP বর্তমান GitHub Repository-তে **মিলিয়ে কপি করার জন্য**। ZIP-এ `NovaLive_V3_Network_Fix/` মূল ফোল্ডার নামে আলাদা ফোল্ডার GitHub-এ আপলোড করবেন না। তার ভেতরের ফাইলগুলো GitHub-এর একদম একই পাথে Replace করবেন।

## কোন ৫টি ফাইল বদলাবেন

1. `.github/workflows/build-novalive.yml`
2. `mobile/lib/api.dart`
3. `mobile/lib/main.dart`
4. `mobile/lib/network_status_screen.dart` (না থাকলে নতুন করে তৈরি)
5. `mobile/android/app/src/main/AndroidManifest.xml`

**জরুরি:** এই প্যাকেজটি আপনার আগের NovaLive সোর্স (V1/V2)-এর জন্য। অন্য অ্যাপের ফাইলের ওপর ব্যবহার করবেন না। `server/` ও Render-এর Environment বদলাতে হবে না।

## Github Variable

Repository > Settings > Secrets and variables > Actions > Variables > `API_BASE_URL` — এখানে Render-এর প্রকৃত HTTPS বেস URL বসাতে হবে, ঠিক যেমন: `https://YOUR-APP.onrender.com`। এখানে `/health`, `/admin/`, `/api` থাকবে না। বানান ও সংখ্যা Render থেকে কপি করুন।

## কিভাবে চালাবেন

1. পাঁচটি ফাইল Commit directly to `main` করুন।
2. Actions > `Build NovaLive V3 Verified Android APK` এর নতুন Run খুলুন। (বেশি Workflow থাকলে এই নতুন নাম খুঁজুন।)
3. সবুজ টিক হলে Artifacts থেকে শুধু `NovaLive-V3-Verified-Internet-APK` নামের Artifact ডাউনলোড করুন। অন্য পুরোনো APK নয়।
4. ZIP থেকে `app-release.apk` Extract করুন।
5. পুরোনো NovaLive অ্যাপের গুরুত্বপূর্ণ স্থানীয় তথ্য থাকলে আগে নোট করুন। তারপর পুরোনো APK Version 1.x আনইনস্টল করে নতুন APK ইনস্টল করুন। পুরোনো APK-এর signing certificate আলাদা হলে সরাসরি Update ব্যর্থ হতে পারে।
6. ফোনে Settings > Apps > NovaLive > App info-তে Version `3.0.0` দেখুন। Version 3.0.0 না হলে আপনি পুরোনো APK ব্যবহার করছেন।
7. অ্যাপের Registration-এর আগে `Server Connection Test` থাকলে সেটিতে `Server Online` দেখুন। তারপর Registration করুন।

## সমস্যার কারণ এবং কী পরীক্ষা হচ্ছে

Flutter Release APK-এর `INTERNET` Permission ভুল করে বিল্ডে বাদ যেতে পারে, কারণ আপনার GitHub Workflow-তে `flutter create` আবার Android ফাইল তৈরি করছে। V3-তে Source Manifest সংরক্ষণ/ফিরিয়ে আনা হয়, তৈরি APK-এর ভেতর `aapt dump permissions` দিয়ে পরীক্ষা হয়, এবং Render-এর একই `API_BASE_URL/health` CI-তে যাচাই করা হয়। ভুল হলে Build-কে ব্যর্থ দেখাবে—সবুজ টিক দেখাবে না।

আপনি অ্যাপে ইংরেজি `Network problem: ClientException` বার্তা দেখলে বুঝবেন পুরোনো V1 Dart API কোড এখনো ইনস্টল আছে। V3 বাংলা Error ও Server Test অন্তর্ভুক্ত করে।

### Build ব্যর্থ হলে

* `ERROR: ... API_BASE_URL ...` — Github Actions Variables-এ URL দিন।
* `curl: (6) Could not resolve host` — Render থেকে URL হুবহু কপি করুন।
* `FAIL: Final APK does not include android.permission.INTERNET` — Workflow বা Manifest সঠিকভাবে Replace হয়নি।
* `Dart Error` — Android Job-এর লাল Step-এর Log দেখুন।

### সীমাবদ্ধতা

এখানে Flutter SDK/Android Runner নেই, তাই এই V3 APK সরাসরি কম্পাইল বা আপনার ফোনে পরীক্ষা করা হয়নি। YAML ও সোর্স ফাইলের static পরীক্ষা করা হয়েছে। Chrome-এ /health কাজ করলে কিন্তু V3 APK-তেও DNS না মেলে, তখন ডিভাইস DNS, VPN, নেটওয়ার্ক নীতি, অথবা runtime সমস্যা থাকতে পারে। Render Free-এর idle sleep, ডিসকানেকশন এবং ইনকামিং ভিডিও কলের নির্ভরযোগ্যতার জন্য পেইড always-on অবকাঠামো দরকার।
