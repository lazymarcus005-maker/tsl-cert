# How to Build to Device

คู่มือ build และรัน React Native (Expo) app บนอุปกรณ์จริง

---

## Prerequisites

| เครื่องมือ | เวอร์ชัน |
|---|---|
| Node.js | >= 18 |
| npm | >= 9 |
| Expo CLI | ติดตั้งผ่าน `npm install -g expo-cli` |
| Expo Go app | ติดตั้งจาก App Store / Play Store (สำหรับ development) |

---

## 1. ติดตั้ง Dependencies

```bash
cd mobile
npm install
```

---

## 2. รัน Development Server

```bash
npx expo start
```

Terminal จะแสดง QR code — เปิด **Expo Go** บนมือถือแล้วสแกน QR code ได้เลย (มือถือและเครื่อง dev ต้องอยู่ใน Wi-Fi เดียวกัน)

---

## 3. Build สำหรับ iOS (ผ่าน EAS Build)

> ต้องมี Apple Developer Account และ Expo account

### 3.1 ติดตั้ง EAS CLI

```bash
npm install -g eas-cli
eas login
```

### 3.2 ตั้งค่า EAS (ครั้งแรก)

```bash
eas build:configure
```

คำสั่งนี้จะสร้างไฟล์ `eas.json` ให้อัตโนมัติ

### 3.3 Build สำหรับ Simulator (ไม่ต้องมี certificate)

```bash
eas build --platform ios --profile development --local
```

### 3.4 Build สำหรับอุปกรณ์จริง (.ipa)

```bash
eas build --platform ios --profile preview
```

หลัง build เสร็จ EAS จะให้ลิงก์ดาวน์โหลด `.ipa` → ติดตั้งผ่าน AltStore หรือ TestFlight

---

## 4. Build สำหรับ Android (ผ่าน EAS Build)

### 4.1 Build APK (ติดตั้งตรงบนมือถือได้)

```bash
eas build --platform android --profile preview
```

ไฟล์ที่ได้คือ `.apk` → โอนลงมือถือแล้วเปิดติดตั้งได้เลย (ต้องเปิด "Unknown Sources" ใน Settings)

### 4.2 Build AAB (สำหรับ Play Store)

```bash
eas build --platform android --profile production
```

---

## 5. Build บนเครื่องตัวเอง (Local Build)

### iOS (ต้องใช้ macOS + Xcode)

```bash
npx expo run:ios --device
```

Xcode จะขึ้นมาให้เลือกอุปกรณ์ที่ต่ออยู่

### Android (ต้องเปิด USB Debugging บนมือถือ)

```bash
npx expo run:android --device
```

ตรวจสอบว่ามือถือเชื่อมต่อแล้วด้วย:

```bash
adb devices
```

---

## 6. ตัวอย่าง `eas.json` (ถ้าต้องการตั้งค่าเอง)

```json
{
  "cli": {
    "version": ">= 12.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "distribution": "internal"
    },
    "production": {}
  }
}
```

---

## 7. สรุปคำสั่งที่ใช้บ่อย

| คำสั่ง | ทำอะไร |
|---|---|
| `npx expo start` | เปิด dev server + QR code |
| `npx expo start --tunnel` | เปิด dev server ผ่าน tunnel (ข้าม Wi-Fi) |
| `npx expo run:android --device` | build + ติดตั้งบน Android (local) |
| `npx expo run:ios --device` | build + ติดตั้งบน iOS (local, macOS only) |
| `eas build --platform android --profile preview` | build APK ผ่าน cloud |
| `eas build --platform ios --profile preview` | build IPA ผ่าน cloud |

---

## Troubleshooting

**มือถือเชื่อมต่อ Expo Go ไม่ได้**
- ใช้ `npx expo start --tunnel` เพื่อใช้ Ngrok tunnel แทน LAN

**Android: adb ไม่เจออุปกรณ์**
- เปิด USB Debugging ใน Developer Options
- ลอง `adb kill-server && adb start-server`

**iOS: ติดตั้งไม่ได้ (Untrusted Developer)**
- ไปที่ Settings → General → VPN & Device Management → Trust

**TLS Error เวลาเรียก `/alive`**
- ตรวจสอบว่า CA cert ถูก trust บนอุปกรณ์แล้ว (สำหรับ self-signed cert ใน project นี้)
- Android: ใส่ cert ใน `res/xml/network_security_config.xml`
- iOS: ติดตั้ง profile ผ่าน Settings → General → VPN & Device Management
