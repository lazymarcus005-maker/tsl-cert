# TSL Cert — React Native Alive Test

Expo app สำหรับทดสอบ endpoint `/alive` ผ่าน HTTPS ด้วย TLS certificate ที่ตั้งค่าไว้ใน project นี้

## Endpoint ที่ทดสอบ

```
GET https://api.test.mxlabs.cloud:8443/alive
```

## วิธีรัน

```bash
cd mobile
npm install
npx expo start
```

แล้วเปิด Expo Go บนมือถือ หรือกด `w` เพื่อรันใน browser

## Features

- กดปุ่ม **Test /alive** เพื่อยิง HTTP GET ไปที่ endpoint
- แสดง HTTP status code, response time (ms), และ response body
- แสดงสีเขียว = สำเร็จ, แดง = error
