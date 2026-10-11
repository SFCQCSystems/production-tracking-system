# ระบบ MES ติดตามการผสมและการบรรจุน้ำมันหล่อลื่น (Production Tracking System)

ระบบ MES / Shopfloor Production Tracking เกรดอุตสาหกรรมสำหรับโรงงานผสมและบรรจุน้ำมันหล่อลื่น ออกแบบตามมาตรฐาน **Apple Human Interface Guidelines (HIG)** แยกหน้าจอประจำตำแหน่งงาน 5 แผนกอย่างเด็ดขาด เชื่อมต่อฐานข้อมูลออนไลน์กลางแบบ Real-time และระบบความปลอดภัยระดับองค์กร (Zero-Trust Security)

---

## 🌟 5 ระบบประจำตำแหน่งงาน (5 Dedicated Stations)

### 1. 🛢️ ระบบควบคุมถังผสม (Blender Station & Dashboard)
- **หน้าปฏิบัติงาน:**
  - ข้อมูลหัว Job: **Production No., Name (ชื่อน้ำมัน), Batch (เช่น `BLB01/1`)** ระบบดึงรหัสถังผสมจากเลข Batch อัตโนมัติ
  - **ขั้นตอน Flush (1, 2, 4):** ช่องบันทึก "ใช้อะไรในการ Flush" และ "ปริมาตร (ลิตร)"
  - **สเต็ป 3 (Blending FG):** กดปุ่ม **`[ ปุ่มส่งตัวอย่างเข้าแลป ]`**
  - **วงจรสถานะ:** ยังไม่เริ่ม ➔ กำลังดำเนินการ (เริ่มจับเวลา) ➔ ดำเนินการเสร็จสิ้น (หยุดจับเวลา)
- **แดชบอร์ดเฉพาะ:** แสดงสถานะถังผสมทุกลูก (BLB01–BLB22, BLS01) และเวลารวมตั้งแต่เริ่มผลิต

---

### 2. 📦 ระบบไลน์บรรจุ (Filling Line Station & Dashboard)
- **หน้าปฏิบัติงาน:**
  - เลือกไลน์บรรจุ (Line 1, Line 2, Line 3 ฯลฯ)
  - ข้อมูลหัว Job: **Production No., Name, Batch น้ำมัน**
  - **ขอเบิกภาชนะ:** กดปุ่ม **`[ 📤 แจ้งขอเบิกภาชนะ ]`** ส่งเลข Production No. ไปแผนกบรรจุภัณฑ์
  - **ส่งตรวจ First Fill:** กดปุ่ม **`[ ปุ่มส่งตัวอย่างเข้าแลป ]`** รอผลอนุมัติพร้อมค่า **Density @ 30°C**
  - **Interlock หัวจ่าย:** ปลดล็อกเมื่อได้ของครบ + แล็บผ่าน ➔ ปลดล็อกเปิดหัวจ่าย
  - **วงจรสถานะ:** ยังไม่เริ่ม ➔ กำลังดำเนินการ ➔ ดำเนินการเสร็จสิ้น
- **แดชบอร์ดเฉพาะ:** มอนิเตอร์ทุกไลน์บรรจุและเวลาการทำงาน

---

### 3. 🏭 ระบบบรรจุภัณฑ์ (Packaging Station & Dashboard)
- แสดงคิวงานขอเบิกภาชนะจากไลน์บรรจุ โดยแสดง Production No. เด่นชัด, ชื่อสินค้า, Batch, ไลน์ที่ขอ
- กดปุ่ม **`[ 📥 รับงานเบิก ]`** (บันทึกเวลาเริ่มจัดของ)
- จัดของเสร็จกดปุ่ม **`[ ✅ จ่ายภาชนะเรียบร้อย ]`** ส่งสัญญาณปลดล็อกไปยังไลน์บรรจุทันที
- สรุปยอดจ่ายภาชนะและ Lead Time ในการจัดเตรียม

---

### 4. 🧪 ระบบศูนย์ตรวจห้องแล็บ (QC Lab Gate & Dashboard)
- คิวตรวจรับตัวอย่างจาก Blender (Bulk) และ ไลน์บรรจุ (First Fill)
- กด **`[ ปุ่มรับงาน ]`** เมื่อตัวอย่างมาถึงเพื่อเริ่มจับเวลาตรวจจริง (Pure Lab TAT)
- บันทึกผลแล็บแบบ Append-Only:
  1. **`[ ✅ อนุมัติ (APPROVE) ]`** ➔ บังคับกรอก **Density @ 30°C**
  2. **`[ 🔄 สั่ง Resample ]`** ➔ เลือกเหตุผลจาก Dropdown พร้อมคำสั่งการ
  3. **`[ ❌ ปฏิเสธ (REJECT) ]`** ➔ เลือกเหตุผลจาก Dropdown
- ระบบเสียงสังเคราะห์แจ้งเตือนตัวอย่างใหม่ (Web Audio API)
- ระบบ Lab Override พร้อมบันทึกเหตุผลกำกับ

---

### 5. 👔 ระบบแอดมินและศูนย์สั่งการ (Admin Command Center)
- **การจัดการสิทธิ์ & ผู้ใช้ (RBAC):** กำหนดบทบาทและสิทธิ์เข้าถึง 5 แผนก
- **บันทึกความปลอดภัย (Audit Logs):** ประวัติการเข้าสู่ระบบ, การสุ่มรหัสผ่าน (Brute-Force Lockout), การแก้ไขสิทธิ์ พร้อมส่งออก CSV
- **จัดการถังผสมและไลน์บรรจุ:** เพิ่ม/ปิดถังผสมและไลน์บรรจุ
- **นำเข้าคำสั่งผลิตจาก SAP (Excel Staging):** รองรับไฟล์ `Blending_daily_report` และ `Production Overview Plan`
- **วิเคราะห์ผลการทำงาน (Executive Analytics):** OEE, Lead Time, Cycle Time, Throughput, Pass Rate, Defect Rate

---

## 🔒 มาตรฐานความปลอดภัย (Enterprise Security)

1. **One-Way Password Hashing**: เข้ารหัสผ่านด้วย Pure JS SHA-256 ผสม Cryptographic Salt มาตรฐานสากล
2. **Auto-Upgrade**: บัญชีเดิมที่ล็อกอินด้วยรหัสผ่าน Plaintext จะถูกแปลงเป็น SHA-256 Hash อัตโนมัติทันที
3. **Session Integrity & Anti-Privilege Escalation**: ตรวจสอบ Role เทียบกับฐานข้อมูลหลักเสมอ ป้องกันการแก้ไขสิทธิ์ผ่าน DevTools
4. **Brute-Force Protection**: ล็อกอินผิดเกิน 5 ครั้ง ระบบสั่งล็อกบัญชี 60 วินาที พร้อมนับถอยหลัง
5. **Security Audit Trail**: บันทึกทุกเหตุการณ์ความปลอดภัย พร้อมดาวน์โหลดรายงาน CSV

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```text
📁 Production Tracking System/
├── 📁 src/                      # Source Code แบบแยกโมดูล (React + Vite)
│   ├── 📁 components/           # UI Components, 13 Modals, AppIcon
│   ├── 📁 constants/            # Storage keys, Systems, Initial Data
│   ├── 📁 services/             # Security, Storage, Audio, SAP Parser
│   ├── 📁 systems/              # Auth & LoginScreen
│   ├── 📁 utils/                # Helpers & Analytics
│   ├── App.jsx                  # Main App Component
│   ├── main.jsx                 # Vite Entry
│   └── index.css                # Apple HIG Styling + Tailwind CSS
├── 📁 server/                   # Node.js Zero-Dependency Central Database Server
│   └── server.js
├── 📁 public/                   # Static Assets (Favicon, Icons)
├── 📁 tools/                    # สคริปต์เครื่องมือภายในสำหรับผู้ดูแลระบบ
├── index.html                   # Standalone Production File (พร้อมใช้งานหน้างานทันที)
├── dev.html                     # Vite Development Entry
├── vite.config.js               # Vite Configuration
├── package.json
└── README.md
```

---

## 🚀 วิธีการเปิดใช้งาน (Getting Started)

### วิธีที่ 1: ดับเบิลคลิกเปิดใช้งานทันที (Shopfloor Standalone)
สามารถดับเบิลคลิกไฟล์ **`index.html`** เพื่อเปิดใช้งานบนเบราว์เซอร์ (Chrome / Edge / Safari) ได้ทันทีโดยไม่ต้องติดตั้งโปรแกรมเสริม
- **หน้าเลือกระบบกลาง (Portal Hub):** เปิด `index.html`
- **เครื่องหน้าถังผสม:** เปิด `index.html?system=blender`
- **เครื่องหน้าไลน์บรรจุ:** เปิด `index.html?system=filling`
- **เครื่องห้องแล็บ:** เปิด `index.html?system=lab`
- **เครื่องแอดมิน:** เปิด `index.html?system=admin`

### วิธีที่ 2: รันผ่าน Server กลางในโรงงาน (LAN / WiFi)
ดับเบิลคลิกไฟล์ **`start_server.bat`** หรือพิมพ์คำสั่ง:
```bash
npm run server
```
- ระบบจะเปิดเซิร์ฟเวอร์ฐานข้อมูลกลางที่พอร์ต `3001`
- เครื่องอื่นๆ ในวง LAN สามารถเข้าใช้งานผ่าน `http://<IP_เครื่องแม่>:3001`

### วิธีที่ 3: โหมดพัฒนา (Developer Hot-Reload)
```bash
npm install
npm run dev
```
- เปิด Vite Dev Server พร้อม Hot Module Replacement ที่ `http://localhost:3000/dev.html`

### คำสั่งคอมไพล์โค้ด (Production Build)
```bash
npm run build
```
- คอมไพล์โค้ดใน `src/` ออกมาเป็นไฟล์ Bundle Standalone ภายในเวลา ~4 วินาที
