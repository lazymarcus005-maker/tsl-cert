# How to Build & Trust Lab CA on Android (Debug APK)

> คู่มือสร้าง Android debug APK ที่เชื่อถือ Fake CA ของ SSL Test Lab  
> โดยไม่ต้องแก้ไข system CA ของ emulator/device

---

## สิ่งที่ต้องมี

| เครื่องมือ | รายละเอียด |
|---|---|
| Node.js & npm | v18+ |
| Java (JDK 17+) | ติดตั้งผ่าน Homebrew: `brew install --cask temurin@17` |
| Android SDK | ติดตั้งผ่าน Android Studio |
| Docker Compose | สำหรับ start test lab และสร้าง certs |
| adb | อยู่ใน `~/Library/Android/sdk/platform-tools/` |

---

## ทำไมต้องทำแบบนี้?

```
Expo Go (Managed)
  └── ไม่รองรับ network_security_config ของ project
  └── User CA ถูก ignore โดย Expo Go → Network request failed

Debug APK (Custom build)
  └── รวม CA ใน app resources (res/raw/my_ca.crt)
  └── network_security_config.xml บอกให้ app เชื่อถือ CA นั้น
  └── JS bundle ถูก embed ใน APK (ไม่ต้องการ Metro server)
  └── ✅ ทดสอบ HTTPS endpoints ได้โดยตรงจากแอป
```

---

## ขั้นตอน

### Step 1 — Start Test Lab และสร้าง certificates

```bash
# จาก root ของ project
docker compose up -d

# ตรวจสอบว่า CA file มีอยู่
ls certs/ca/ca.crt
```

---

### Step 2 — Install dependencies (ครั้งแรก)

```bash
cd mobile
npm install
```

---

### Step 3 — Copy CA เข้า Android resources

สคริปต์นี้คัดลอก `certs/ca/ca.crt` → `android/app/src/main/res/raw/my_ca.crt`

```bash
# จากโฟลเดอร์ mobile/
npm run apply-ca
```

ผลลัพธ์ที่ถูกต้อง:
```
Copied CA to .../mobile/android/app/src/main/res/raw/my_ca.crt
```

> ⚠️ ต้องรันทุกครั้งที่มีการ regenerate certs ใหม่

---

### Step 4 — Bundle JS เข้า Android assets

```bash
# จากโฟลเดอร์ mobile/
mkdir -p android/app/src/main/assets

NODE_ENV=production npx expo export:embed \
  --platform android \
  --entry-file node_modules/expo/AppEntry.js \
  --bundle-output android/app/src/main/assets/index.android.bundle \
  --assets-dest android/app/src/main/res
```

ผลลัพธ์ที่ถูกต้อง:
```
Android Bundled Xms node_modules/expo/AppEntry.js (653 modules)
Writing bundle output to: android/app/src/main/assets/index.android.bundle
Done writing bundle output
```

> ✅ APK รันได้แบบ standalone ไม่ต้องเปิด Metro server

---

### Step 5 — สร้าง Debug APK

```bash
# จากโฟลเดอร์ mobile/android/
chmod +x ./gradlew
./gradlew assembleDebug --no-daemon -x lint
```

APK ที่ได้จะอยู่ที่:
```
mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

> ถ้า Gradle หา SDK ไม่เจอ ให้สร้างไฟล์ `android/local.properties`:
> ```
> sdk.dir=/Users/<username>/Library/Android/sdk
> ```

---

### Step 6 — ติดตั้ง APK บน Emulator

```bash
# Start emulator ก่อน (ถ้ายังไม่ได้ start)
~/Library/Android/sdk/emulator/emulator -avd Pixel_5 -no-snapshot-load &

# ติดตั้ง APK
adb install -r mobile/android/app/build/outputs/apk/debug/app-debug.apk
```

---

### Step 7 — เปิดแอป

```bash
adb shell am start -n com.anonymous.tslcertalivetest/.MainActivity
```

---

## วิธีทำงานของ CA Trust

ไฟล์ที่เพิ่มเข้ามาในโปรเจ็กต์:

| ไฟล์ | หน้าที่ |
|---|---|
| `mobile/scripts/apply-ca.js` | คัดลอก `certs/ca/ca.crt` → `android/app/src/main/res/raw/my_ca.crt` |
| `mobile/android/app/src/main/res/xml/network_security_config.xml` | บอกให้แอปเชื่อถือ `@raw/my_ca` สำหรับ `*.test.mxlabs.cloud` |
| `mobile/android/app/src/main/AndroidManifest.xml` | อ้างอิง `networkSecurityConfig` ใน `<application>` tag |

### `network_security_config.xml` (สรุป)

```xml
<network-security-config>
  <!-- base: เชื่อถือ system + user CA ทั่วไป -->
  <base-config>
    <trust-anchors>
      <certificates src="system" />
      <certificates src="user" />
    </trust-anchors>
  </base-config>

  <!-- สำหรับโดเมน *.test.mxlabs.cloud: เพิ่ม CA จาก res/raw/my_ca -->
  <domain-config cleartextTrafficPermitted="false">
    <domain includeSubdomains="true">test.mxlabs.cloud</domain>
    <trust-anchors>
      <certificates src="@raw/my_ca" />
    </trust-anchors>
  </domain-config>
</network-security-config>
```

---

## Script รวม — Rebuild & Reinstall (ใช้ทุกครั้งที่แก้โค้ดหรือ regenerate certs)

```bash
cd /path/to/tsl-cert/mobile

npm run apply-ca \
  && mkdir -p android/app/src/main/assets \
  && NODE_ENV=production npx expo export:embed \
      --platform android \
      --entry-file node_modules/expo/AppEntry.js \
      --bundle-output android/app/src/main/assets/index.android.bundle \
      --assets-dest android/app/src/main/res \
  && cd android \
  && ./gradlew assembleDebug --no-daemon -x lint \
  && adb install -r app/build/outputs/apk/debug/app-debug.apk \
  && adb shell am start -n com.anonymous.tslcertalivetest/.MainActivity
```

---

## Troubleshooting

| ปัญหา | สาเหตุ | วิธีแก้ |
|---|---|---|
| `Unable to locate a Java Runtime` | ยังไม่ได้ install JDK | `brew install --cask temurin@17` แล้วเปิด terminal ใหม่ |
| `SDK location not found` | ไม่มี `local.properties` | สร้างไฟล์ `android/local.properties` → `sdk.dir=/Users/<user>/Library/Android/sdk` |
| `Unable to load script` (red screen) | ไม่มี JS bundle ใน APK | รัน Step 4 (expo export:embed) แล้ว rebuild |
| `Network request failed` | CA ไม่ถูก trust | ตรวจสอบว่า `npm run apply-ca` รันสำเร็จ และ APK ถูก rebuild หลังจากนั้น |
| `Remount failed` | Google Play image ไม่รองรับ system CA push | ใช้วิธี network_security_config ในคู่มือนี้แทน |
| Certs regenerated แต่ยังใช้ CA เดิม | ลืม apply-ca หลัง `docker compose down/up` | รัน `npm run apply-ca` + rebuild APK |
