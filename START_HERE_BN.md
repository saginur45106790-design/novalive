# NovaLive V4 — প্রথমে অ্যাকাউন্ট ছাড়া প্রবেশ + Android নেটওয়ার্ক মেরামত

এই আপডেট আপনার আগের NovaLive (Flutter + Node.js + PostgreSQL + LiveKit) প্রজেক্টের জন্য। আলাদা অ্যাপ/ডেটাবেস বানাতে হবে না। এটি Chamet-এর ব্র্যান্ড/কোড নকল নয়—নিজস্ব NovaLive UI।

## কী বদলেছে

- অ্যাপ খুললেই Guest Explore/Home দেখাবে। প্রথমে Register/Login করতে হবে না।
- অনুমোদিত হোস্টের পাবলিক পরিচিতি এবং চলমান পাবলিক Live Room তালিকা দেখা যাবে; **ভুয়া অনলাইন কাউন্ট দেখায় না**।
- Guest ব্যবহারকারী ১৮+ সম্মতি দিয়ে পাবলিক Live দেখতে পারবেন। Guest token কেবল subscribe করতে পারে—ক্যামেরা, মাইক বা data publish করতে পারে না।
- Call, Chat, Gift, Wallet, Party এবং প্রোফাইলের জন্য Login/Register বাধ্যতামূলক থাকে।
- ভিডিও কল, চ্যাট, পেমেন্ট/কয়েন ইত্যাদির আগের কোড রাখা হয়েছে। নতুন Agency, PK Battle ও AI filter এই প্যাকে বাস্তবে তৈরি হয়নি।
- APK Build-এর সময় `flutter create`-এর আগে release Manifest সংরক্ষণ করে পরে ফেরত দেওয়া হয়; তৈরি APK-তে `INTERNET`, `CAMERA`, `RECORD_AUDIO` permissions পরীক্ষা হয়।
- Build version **4.0.0 (400)**। পুরোনো APK-এর সঙ্গে গুলিয়ে ফেলবেন না।

## ১. ZIP আপলোড

সবচেয়ে সহজ: **NovaLive_V4_Patch.zip** Extract করুন। ZIP-এর ফোল্ডারগুলো GitHub-এর একই path-এ বসান। ZIP ফাইল নিজেই GitHub-এ রেখে দেবেন না।

| ফাইলের path (GitHub root থেকে) | কী করবেন |
| --- | --- |
| `.github/workflows/build-novalive.yml` | পুরোনো ফাইল Replace করুন |
| `mobile/lib/main.dart` | Replace করুন |
| `mobile/lib/api.dart` | Replace করুন |
| `mobile/lib/room_screen.dart` | Replace করুন |
| `mobile/lib/guest_shell.dart` | নতুন ফাইল তৈরি করুন |
| `mobile/pubspec.yaml` | Replace করুন |
| `mobile/android/app/src/main/AndroidManifest.xml` | Replace করুন |
| `server/src.js` | Replace করুন (অন্য server files অক্ষত রাখুন) |
| `scripts/verify_v4.py` | নতুন ফাইল তৈরি করুন |

সব ফাইল **Commit directly to `main`**। Node.js server এবং database আগের মতো চলবে; পুরোনো user বা Admin মুছবেন না। ZIP-এ কোনো `.env`, password বা LiveKit secret নেই।

## ২. Render deploy: অপরিহার্য

`server/src.js` পরিবর্তন হয়েছে, তাই Render > `novalive` > Deploys থেকে নতুন Commit Deploy সম্পন্ন হয়েছে কি না দেখুন। Auto-deploy বন্ধ থাকলে **Manual Deploy → Deploy latest commit**।

ব্রাউজারে আপনার **নিজের Render URL**-এ পরীক্ষা করুন:

- `https://YOUR-SERVICE.onrender.com/health` → `ok: true`
- `https://YOUR-SERVICE.onrender.com/api/public/discover` → `hosts` ও `rooms` নামে দুটি array

শুধু Admin অ্যাকাউন্ট থাকলে `{"hosts":[],"rooms":[]}` স্বাভাবিক। `401 Login required` বা `404` এলে নতুন backend এখনও Deploy হয়নি। এই endpoint-এ password, email, coins বা ব্যক্তিগত তথ্য ফেরত আসে না।

Render Environment-এর `DATABASE_URL`, `JWT_SECRET`, `LIVEKIT_*` এবং বাকি গোপন সেটিংস পরিবর্তনের দরকার নেই।

## ৩. GitHub Variable

GitHub repository > Settings > Secrets and variables > Actions > Variables > `API_BASE_URL`

Value-তে Render থেকে copy করা URL বসান, যেমন:

`https://YOUR-SERVICE.onrender.com`

**কোনো `/health`, `/api`, `/admin/`, trailing slash, quotation mark থাকবে না।** URL-এর বানান খুব সাবধানে মিলিয়ে নিন।

## ৪. নতুন APK তৈরি

GitHub > Actions > **Build NovaLive V4 Guest APK** > Run workflow > main।

Workflow যা যাচাই করবে:

1. Guest/Home ও backend security code উপস্থিত কি না
2. Render-এর `/health` API যোগাযোগ করা যায় কি না
3. Flutter-এর Android ফাইল generate হওয়ার পরে release Manifest ঠিক রাখা হয়েছে কি না
4. APK Build হয় কি না
5. **কম্পাইল করা APK-তে** INTERNET/CAMERA/MIC অনুমতি আছে কি না

Green tick হলে Artifacts থেকে **NovaLive-V4-Guest-APK** ডাউনলোড করুন। এর ভিতরের `app-release.apk` ব্যবহার করুন।

পূর্বের APK Android-এ uninstall করতে হতে পারে, যদি signing certificate আলাদা হয়। পুরোনো APK uninstall করলে ফোনের local session হারাবে, Neon data নয়। আগে গুরুত্বপূর্ণ local তথ্য সংরক্ষণ করুন।

## ৫. ফোনে পরীক্ষা

1. Settings > Apps > NovaLive > App info থেকে Version **4.0.0** নিশ্চিত করুন।
2. NovaLive খুললেই **Explore** + **GUEST** badge দেখা উচিত। Register screen নয়।
3. App Bar-এর WiFi আইকন থেকে Server Connection Test খুলুন।
4. Explore-এ প্রকৃত host না থাকলে `No verified hosts yet` দেখানো স্বাভাবিক।
5. Login বোতাম থেকে নতুন account তৈরি করে Chat / Video Call ব্যবহার করুন।
6. পাবলিক Live চালু করতে আগে ব্যবহারকারীকে Admin Panel থেকে `host` role দিতে হবে। একটি public Live চালু হলে Guest Mode-এ তা দেখা যাবে।

### V4-তেও Failed host lookup হলে

- Version সত্যিই 4.0.0 কি না দেখুন; আগের V1/V3 APK-তে পুরোনো ইংরেজি error আসবে।
- GitHub Actions-এর **Inspect permissions in COMPILED APK** ধাপে `android.permission.INTERNET` আছে কি না দেখুন।
- ফোন Chrome-এ ওই **একই host**-এর `/health` খুলুন; WiFi/Mobile Data পাল্টে দেখুন; VPN/Private DNS/Firewall আছে কি না দেখুন।
- Server Test-এর error message ও GitHub-এর permission লগ নিয়ে পরবর্তী debug হবে। এই কোড দিয়ে সব ফোন বা DNS সমস্যার ১০০% স্থায়ী সমাধান নিশ্চয়তা দেওয়া যায় না।

## সীমাবদ্ধতা ও নিরাপত্তা

এই সোর্সে guest browse এবং public live watch কার্যকরীভাবে তৈরি করা হয়েছে, কিন্তু এখানে Flutter SDK নেই—APK স্থানীয়ভাবে কম্পাইল বা বাস্তব দুই ফোনে পরীক্ষা করা হয়নি। ১৮+ self-confirmation **পরিচয়/বয়স যাচাইয়ের বিকল্প নয়**। গ্রাহকের অর্থ, real payouts, billing, 24/7 live service, strong moderation এবং Store policy compliance-এর জন্য অতিরিক্ত কাজ ও পর্যালোচনা প্রয়োজন। Render Free নিরবচ্ছিন্ন সার্ভারের নিশ্চয়তা দেয় না।

### বর্তমান প্রযুক্তিগত দৃষ্টান্ত

- `server/src.js`-এ পাবলিক endpoints **auth middleware-এর আগে**, কিন্তু সব private endpoints আগের মতো authenticated।
- Public browse-এর তথ্য: শুধু অনুমোদিত host-এর `id,name,bio` এবং public live-এর `id,title,owner_name`।
- পাবলিক Live watch token `canPublish:false`, `canPublishData:false`।
- নতুন কোনো ভুয়া host, fake view count, fake earnings তৈরি করা হয়নি।
