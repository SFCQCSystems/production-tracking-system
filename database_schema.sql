-- =========================================================================
-- DATABASE SCHEMA: LUBRICANT MES TRACKING SYSTEM (ONLINE CLOUD DATABASE)
-- Modules:
--   1. Blender Station & Dashboard (ระบบควบคุมถังผสม)
--   2. First Fill / Filling Station & Dashboard (ระบบไลน์บรรจุ)
--   3. QC Lab Gate & Dashboard (ระบบศูนย์ตรวจห้องแล็บ)
--   4. Admin & Executive Management Control (ระบบแอดมินและผู้บริหารควบคุมทั้ง 3 ระบบ)
-- Engine: PostgreSQL 14+ / Supabase / Cloud REST API
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================================================
-- 1. MASTER CONFIGURATION & ADMIN CONTROLS (ควบคุมโดยแอดมิน)
-- =========================================================================

-- 1.1 ตารางถังผสม (แอดมินเป็นคนเพิ่ม/จัดการเมื่อมีถังใหม่)
CREATE TABLE IF NOT EXISTS blenders (
    blender_code VARCHAR(20) PRIMARY KEY, -- เช่น 'BLB01', 'BLB02', 'BLB13'
    name VARCHAR(100) NOT NULL,
    capacity_litres NUMERIC(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO blenders (blender_code, name, capacity_litres) VALUES
('BLB01', 'Blender Tank 01 (15,000 L)', 15000),
('BLB02', 'Blender Tank 02 (25,000 L)', 25000),
('BLB03', 'Blender Tank 03 (10,000 L)', 10000),
('BLB04', 'Blender Tank 04 (20,000 L)', 20000),
('BLB11', 'Blender Tank 11 (30,000 L)', 30000),
('BLB12', 'Blender Tank 12 (12,000 L)', 12000)
ON CONFLICT (blender_code) DO NOTHING;

-- 1.2 ตารางไลน์บรรจุ (แอดมินเป็นคนเพิ่ม/จัดการ)
CREATE TABLE IF NOT EXISTS filling_lines (
    line_code VARCHAR(20) PRIMARY KEY, -- เช่น 'Line 1', 'Line 2', 'Line Drum'
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO filling_lines (line_code, name) VALUES
('Line 1', 'ไลน์บรรจุดรัม 200 ลิตร (Drum Line 01)'),
('Line 2', 'ไลน์บรรจุถังเล็กและเพล (Pail Line 02)'),
('Line 3', 'ไลน์บรรจุแกลลอนอัตโนมัติ (Small Pack Line 03)')
ON CONFLICT (line_code) DO NOTHING;

-- 1.3 ตารางเหตุผลสั่ง Resample และ Reject (แอดมินเป็นคนกำหนดหัวข้อให้แล็บเลือก)
CREATE TABLE IF NOT EXISTS admin_reason_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reason_type VARCHAR(20) NOT NULL CHECK (reason_type IN ('RESAMPLE', 'REJECT')),
    reason_code VARCHAR(50) UNIQUE NOT NULL,
    reason_text_th VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER DEFAULT 1
);

INSERT INTO admin_reason_configs (reason_type, reason_code, reason_text_th, display_order) VALUES
('RESAMPLE', 'RES_CONTAMINATED', 'ขวดปนเปื้อน / มีคราบน้ำหรือสิ่งแปลกปลอม', 1),
('RESAMPLE', 'RES_INSUFFICIENT', 'ปริมาณตัวอย่างไม่เพียงพอต่อการทดสอบ', 2),
('RESAMPLE', 'RES_FOAM', 'ตัวอย่างมีฟองอากาศจัด / ไม่เป็นตัวแทนของน้ำมัน', 3),
('RESAMPLE', 'RES_RECHECK', 'แล็บต้องการ Re-check ตรวจสอบซ้ำเพื่อยืนยัน', 4),
('REJECT', 'REJ_OLD_OIL', 'พบคราบน้ำมันเก่าปนเปื้อน (ล้างถังไม่สะอาด)', 1),
('REJECT', 'REJ_VISCOSITY', 'ค่าความหนืดหลุดสเปกมาตรฐาน (Viscosity Out of Spec)', 2),
('REJECT', 'REJ_SEDIMENT', 'พบตะกอนหรือสิ่งแปลกปลอมเกินเกณฑ์', 3)
ON CONFLICT (reason_code) DO NOTHING;

-- =========================================================================
-- 2. BLENDING MODULE (ระบบถังผสม)
-- ข้อมูลหัว Job: Production No., Name, Batch (เช่น BLB01/1)
-- สถานะ: ยังไม่เริ่ม -> กำลังดำเนินการ -> ดำเนินการเสร็จสิ้น
-- =========================================================================

CREATE TABLE IF NOT EXISTS blending_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blender_code VARCHAR(20) NOT NULL REFERENCES blenders(blender_code),
    production_no VARCHAR(50) NOT NULL,
    oil_name VARCHAR(255) NOT NULL,
    batch_no VARCHAR(50) NOT NULL, -- เช่น 'BLB01/1' หรือ 'B260930011'
    job_status VARCHAR(30) NOT NULL DEFAULT 'ยังไม่เริ่ม'
        CHECK (job_status IN ('ยังไม่เริ่ม', 'กำลังดำเนินการ', 'ดำเนินการเสร็จสิ้น')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE, -- บันทึกเมื่อกด [ปุ่มเริ่มงาน]
    completed_at TIMESTAMP WITH TIME ZONE, -- บันทึกเมื่อกด [ปุ่มจบงาน]
    total_duration_minutes NUMERIC(8, 2) -- เวลารวมตั้งแต่เริ่มผลิตจนจบ
);

-- สเต็ป 4 ขั้นตอนการผสม (Flush กรอกสิ่งที่ใช้ + ปริมาตร + เวลาแต่ละขั้น)
CREATE TABLE IF NOT EXISTS job_steps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID NOT NULL REFERENCES blending_jobs(id) ON DELETE CASCADE,
    step_number SMALLINT NOT NULL CHECK (step_number BETWEEN 1 AND 4),
    step_name VARCHAR(150) NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    flush_material VARCHAR(100), -- ใช้อะไรในการ Flush (เช่น Base Oil 150N, Flush Oil)
    flush_volume_litre NUMERIC(10, 2), -- ปริมาตรที่ใช้ Flush (ลิตร)
    status VARCHAR(30) NOT NULL DEFAULT 'idle'
        CHECK (status IN ('idle', 'in_progress', 'waiting_lab', 'waiting_resample', 'lab_passed', 'lab_rejected', 'skipped')),
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE,
    step_duration_minutes NUMERIC(8, 2), -- เวลาเดินงานของขั้นตอนนี้
    CONSTRAINT uq_blending_job_step UNIQUE (job_id, step_number)
);

-- =========================================================================
-- 3. FILLING MODULE (ระบบไลน์บรรจุ)
-- ข้อมูลหัว Job: ไลน์บรรจุ, Production No., Name, Batch น้ำมัน
-- สถานะ: ยังไม่เริ่ม -> กำลังดำเนินการ -> ดำเนินการเสร็จสิ้น
-- =========================================================================

CREATE TABLE IF NOT EXISTS filling_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    line_code VARCHAR(20) NOT NULL REFERENCES filling_lines(line_code),
    production_no VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    bulk_oil_batch_no VARCHAR(50) NOT NULL, -- Batch น้ำมันต้นทาง
    job_status VARCHAR(30) NOT NULL DEFAULT 'ยังไม่เริ่ม'
        CHECK (job_status IN ('ยังไม่เริ่ม', 'กำลังดำเนินการ', 'ดำเนินการเสร็จสิ้น')),
    materials_ready BOOLEAN NOT NULL DEFAULT FALSE, -- ได้รับการจ่ายภาชนะจากแผนกบรรจุภัณฑ์
    first_fill_approved BOOLEAN NOT NULL DEFAULT FALSE, -- First Fill ผ่านแล็บ
    approved_density_30c NUMERIC(6, 4), -- ค่า Density @ 30°C จากแล็บ
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE, -- บันทึกเมื่อกด [ปุ่มเริ่มงาน]
    completed_at TIMESTAMP WITH TIME ZONE, -- บันทึกเมื่อกด [ปุ่มจบงาน]
    total_duration_minutes NUMERIC(8, 2)
);

-- =========================================================================
-- 4. PACKAGING MODULE (ระบบคลังและจัดการบรรจุภัณฑ์)
-- รับงานเบิกจาก Filling ตาม Production No. / จ่ายภาชนะเรียบร้อย (ไม่ต้องกรอก Lot)
-- =========================================================================

CREATE TABLE IF NOT EXISTS packaging_requests (
    request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filling_job_id UUID NOT NULL REFERENCES filling_jobs(id) ON DELETE CASCADE,
    production_no VARCHAR(50) NOT NULL, -- แสดงเลข Production No. เด่นชัด
    item_name VARCHAR(255) NOT NULL,
    bulk_oil_batch_no VARCHAR(50) NOT NULL,
    line_code VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PREPARING', 'DISPATCHED')),
    t_requested TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    t_received TIMESTAMP WITH TIME ZONE, -- สแตมป์เมื่อกด [รับงานเบิก]
    t_dispatched TIMESTAMP WITH TIME ZONE, -- สแตมป์เมื่อกด [จ่ายภาชนะเรียบร้อย]
    prep_duration_minutes NUMERIC(8, 2) -- เวลาจัดเตรียมจนจ่ายเสร็จ
);

-- =========================================================================
-- 5. QC LAB GATE (ระบบศูนย์ตรวจห้องแล็บ)
-- รับตัวอย่างจาก Blender และ ไลน์บรรจุ / [ปุ่มรับงาน] / Density @ 30°C / Append-Only
-- =========================================================================

CREATE TABLE IF NOT EXISTS lab_sample_history (
    sample_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_module VARCHAR(20) NOT NULL CHECK (source_module IN ('BLENDING', 'FILLING')),
    blending_job_id UUID REFERENCES blending_jobs(id) ON DELETE CASCADE,
    filling_job_id UUID REFERENCES filling_jobs(id) ON DELETE CASCADE,
    step_number SMALLINT,
    production_no VARCHAR(50) NOT NULL,
    batch_no VARCHAR(50) NOT NULL,
    sample_tag VARCHAR(100) NOT NULL, -- 'Blending FG' หรือ 'First Fill'
    round_number INTEGER NOT NULL DEFAULT 1 CHECK (round_number >= 1),
    t_sent TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sent_by VARCHAR(100),
    t_received TIMESTAMP WITH TIME ZONE, -- สแตมป์เมื่อกด [ปุ่มรับงาน]
    received_by VARCHAR(100),
    t_approved TIMESTAMP WITH TIME ZONE, -- สแตมป์เมื่อลงผล
    inspector_id VARCHAR(100),
    lab_action VARCHAR(30) NOT NULL DEFAULT 'PENDING'
        CHECK (lab_action IN ('PENDING', 'APPROVE', 'REQUEST_RESAMPLE', 'REJECT_REWORK')),
    reason_code VARCHAR(50) REFERENCES admin_reason_configs(reason_code),
    reason_description_th VARCHAR(255),
    comment TEXT,
    density_30c NUMERIC(6, 4), -- มาตรฐาน Density @ 30°C
    viscosity_40c NUMERIC(8, 2),
    appearance VARCHAR(100),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    lab_pure_tat_minutes NUMERIC(8, 2), -- เวลาตรวจจริง = t_approved - t_received
    CONSTRAINT uq_sample_round UNIQUE (source_module, production_no, sample_tag, round_number)
);

-- Trigger ป้องกันการแก้ไขหรือลบผลแล็บที่สรุปแล้ว (Strict Append-Only Enforcement)
CREATE OR REPLACE FUNCTION trg_enforce_append_only_lab()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'STRICT DATA INTEGRITY: Lab audit records cannot be deleted!';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF OLD.is_locked = TRUE THEN
            RAISE EXCEPTION 'STRICT DATA INTEGRITY: Sample Round % is permanently LOCKED. Overwrites are strictly prohibited!', OLD.round_number;
        END IF;

        IF NEW.lab_action IN ('APPROVE', 'REQUEST_RESAMPLE', 'REJECT_REWORK') THEN
            NEW.is_locked := TRUE;
            NEW.t_approved := COALESCE(NEW.t_approved, CURRENT_TIMESTAMP);
            IF NEW.t_received IS NOT NULL THEN
                NEW.lab_pure_tat_minutes := ROUND(EXTRACT(EPOCH FROM (NEW.t_approved - NEW.t_received)) / 60.0, 2);
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_lab_audit_append_only ON lab_sample_history;
CREATE TRIGGER trg_lab_audit_append_only
    BEFORE UPDATE OR DELETE ON lab_sample_history
    FOR EACH ROW
    EXECUTE FUNCTION trg_enforce_append_only_lab();

-- =========================================================================
-- 6. DYNAMIC API INTEGRATIONS & EXTERNAL CREDENTIAL STORAGE (ENCRYPTED)
-- ตารางเก็บการตั้งค่าเชื่อมต่อ ERP และ LIMS แบบ Encrypted Storage
-- =========================================================================

CREATE TABLE IF NOT EXISTS system_api_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_type VARCHAR(20) NOT NULL UNIQUE CHECK (integration_type IN ('ERP', 'FILLING', 'LIMS')),
    label VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    endpoint_url TEXT NOT NULL DEFAULT '',
    auth_type VARCHAR(20) NOT NULL DEFAULT 'none' 
        CHECK (auth_type IN ('none', 'api_key', 'bearer', 'basic')),
    header_name VARCHAR(100) DEFAULT '',
    -- เข้ารหัส Secret Tokens / Passwords ด้วย pgcrypto (pgp_sym_encrypt) หรือบันทึก Ciphertext จาก Backend
    encrypted_secret_token TEXT DEFAULT '',
    basic_username VARCHAR(100) DEFAULT '',
    encrypted_basic_password TEXT DEFAULT '',
    polling_interval_minutes INTEGER NOT NULL DEFAULT 5 CHECK (polling_interval_minutes >= 1),
    ingestion_mode VARCHAR(20) NOT NULL DEFAULT 'manual' CHECK (ingestion_mode IN ('manual', 'auto')),
    -- JSON Dynamic Field Mapping: {'productionNo': '$.order_id', 'oilName': '$.sku_name'}
    field_mappings JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_test_status VARCHAR(30) DEFAULT 'untested',
    last_test_message TEXT,
    last_tested_at TIMESTAMP WITH TIME ZONE,
    last_synced_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ตาราง Log ประวัติการดึงข้อมูลและ Sync Audit Trail
CREATE TABLE IF NOT EXISTS api_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_type VARCHAR(20) NOT NULL REFERENCES system_api_integrations(integration_type) ON DELETE CASCADE,
    sync_direction VARCHAR(10) NOT NULL DEFAULT 'INBOUND', -- READ-ONLY INGESTION
    status VARCHAR(20) NOT NULL CHECK (status IN ('SUCCESS', 'FAILED', 'PARTIAL', 'TIMEOUT')),
    http_status INTEGER,
    records_fetched INTEGER DEFAULT 0,
    records_imported INTEGER DEFAULT 0,
    error_message TEXT,
    response_payload_preview TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Seed ค่าเริ่มต้นของ ERP, FILLING และ LIMS integration
INSERT INTO system_api_integrations (integration_type, label, is_enabled, polling_interval_minutes, ingestion_mode, field_mappings)
VALUES 
(
    'ERP', 
    'ERP / Order Ingestion API (Blending)', 
    FALSE, 
    5, 
    'manual', 
    '{"productionNo": "order_id", "oilName": "product_name", "batchNo": "batch_code", "targetVolume": "target_qty", "blenderCode": "tank_id"}'::jsonb
),
(
    'FILLING', 
    'Filling / Packaging Ingestion API', 
    FALSE, 
    5, 
    'manual', 
    '{"lineCode": "line_id", "productionNo": "order_id", "itemName": "item_name", "bulkOilBatchNo": "source_batch"}'::jsonb
),
(
    'LIMS', 
    'LIMS / Lab Result API', 
    FALSE, 
    10, 
    'manual', 
    '{"productionNo": "sample_order_no", "batchNo": "lot_no", "sampleTag": "stage", "density30c": "test_results.density_30c", "viscosity40c": "test_results.viscosity_40c", "appearance": "test_results.appearance", "labAction": "status"}'::jsonb
)
ON CONFLICT (integration_type) DO NOTHING;

-- =========================================================================
-- 6. GITHUB PAGES REAL-TIME SYNC STORE (สำหรับรันบน GitHub Pages & Mobile 100% Online)
-- =========================================================================

CREATE TABLE IF NOT EXISTS mes_sync_store (
    collection_name VARCHAR(50) PRIMARY KEY,
    data JSONB NOT NULL,
    revision BIGINT DEFAULT 1,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- อนุญาตให้ Anon Key อ่านและบันทึกข้อมูลได้สำหรับการใช้งานหน้าร้าน/มือถือ (Row Level Security)
ALTER TABLE mes_sync_store ENABLE ROW LEVEL SECURITY;

DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'mes_sync_store' AND policyname = 'Allow public read-write mes_sync_store'
    ) THEN
        CREATE POLICY "Allow public read-write mes_sync_store" 
        ON mes_sync_store FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;


