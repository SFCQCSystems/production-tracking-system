-- =========================================================================
-- DATABASE SCHEMA: PRODUCTION TRACKING SYSTEM (MES & SAP STAGING CLOUD DB)
-- Engine: PostgreSQL 14+ / Supabase
-- วิธีใช้งาน: คัดลอกโค้ดทั้งหมดนี้ไปวางใน Supabase -> SQL Editor -> กด Run
-- =========================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================================================================
-- 1. MASTER CONFIGURATION & ADMIN CONTROLS (ตารางตั้งค่าระบบและเครื่องจักร)
-- =========================================================================

-- 1.1 ตารางถังผสม (26 ถังมาตรฐานโรงงาน)
CREATE TABLE IF NOT EXISTS blenders (
    blender_code VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    capacity_litres NUMERIC(10, 2) NOT NULL DEFAULT 10000,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO blenders (blender_code, name, capacity_litres) VALUES
('BLB01', 'Blender BLB01', 15000),
('BLB02', 'Blender BLB02', 25000),
('BLB03', 'Blender BLB03', 10000),
('BLB04', 'Blender BLB04', 20000),
('BLB05', 'Blender BLB05', 20000),
('BLB06', 'Blender BLB06', 20000),
('BLB07', 'Blender BLB07', 20000),
('BLB08', 'Blender BLB08', 20000),
('BLB09', 'Blender BLB09', 20000),
('BLB10', 'Blender BLB10', 20000),
('BLB11', 'Blender BLB11', 30000),
('BLB12', 'Blender BLB12', 12000),
('BLB13', 'Blender BLB13', 15000),
('BLB14', 'Blender BLB14', 15000),
('BLB15', 'Blender BLB15', 15000),
('SM01', 'Small Mixer SM01', 5000),
('SM02', 'Small Mixer SM02', 5000),
('Premix1', 'Premix Tank 01', 3000),
('Premix2', 'Premix Tank 02', 3000),
('K01', 'Kettle Tank K01', 5000),
('K02', 'Kettle Tank K02', 5000),
('K03', 'Kettle Tank K03', 5000),
('G01', 'Grease Mixer G01', 5000),
('G02', 'Grease Mixer G02', 5000),
('G03', 'Grease Mixer G03', 5000),
('G04', 'Grease Mixer G04', 5000)
ON CONFLICT (blender_code) DO NOTHING;

-- 1.2 ตารางไลน์บรรจุ (27 ไลน์บรรจุมาตรฐานโรงงาน)
CREATE TABLE IF NOT EXISTS filling_lines (
    line_code VARCHAR(20) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO filling_lines (line_code, name) VALUES
('FLF01', 'Filling Line FLF01'),
('FLF02', 'Filling Line FLF02'),
('FLF03', 'Filling Line FLF03'),
('FLF04', 'Filling Line FLF04'),
('FLF05', 'Filling Line FLF05'),
('FLF06', 'Filling Line FLF06'),
('FLF07', 'Filling Line FLF07'),
('FLF08', 'Filling Line FLF08'),
('FLF09', 'Filling Line FLF09'),
('FLF10', 'Filling Line FLF10'),
('FLF11', 'Filling Line FLF11'),
('FLF12', 'Filling Line FLF12'),
('FLF13', 'Filling Line FLF13'),
('FLF14', 'Filling Line FLF14'),
('FLF15', 'Filling Line FLF15'),
('FLF16', 'Filling Line FLF16'),
('FLF17', 'Filling Line FLF17'),
('FLF18', 'Filling Line FLF18'),
('FLF19', 'Filling Line FLF19'),
('FLF20', 'Filling Line FLF20'),
('FLF21', 'Filling Line FLF21'),
('FLF22', 'Filling Line FLF22'),
('FLF23', 'Filling Line FLF23'),
('FLF24', 'Filling Line FLF24'),
('FLF25', 'Filling Line FLF25'),
('FLF26', 'Filling Line FLF26'),
('FLF27', 'Filling Line FLF27')
ON CONFLICT (line_code) DO NOTHING;

-- 1.3 ตารางเหตุผลแล็บ QC (Resample & Reject Reasons)
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

-- 1.4 ตารางเวลาเป้าหมาย KPI / SLA
CREATE TABLE IF NOT EXISTS kpi_sla_configs (
    config_key VARCHAR(50) PRIMARY KEY,
    target_minutes NUMERIC(8, 2) NOT NULL,
    description_th VARCHAR(255),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO kpi_sla_configs (config_key, target_minutes, description_th) VALUES
('blendingTargetMinutes', 180, 'เวลาเป้าหมายการผสมน้ำมันต่อ Batch (นาที)'),
('fillingTargetMinutes', 240, 'เวลาเป้าหมายการบรรจุต่อใบสั่งผลิต (นาที)'),
('packagingTargetMinutes', 30, 'เวลาเป้าหมายการจัดเตรียมและส่งบรรจุภัณฑ์ (นาที)'),
('labBlendingTargetMinutes', 45, 'เวลาเป้าหมายตรวจแล็บงานผสม (นาที)'),
('labFillingTargetMinutes', 20, 'เวลาเป้าหมายตรวจแล็บ First Fill ไลน์บรรจุ (นาที)')
ON CONFLICT (config_key) DO NOTHING;

-- =========================================================================
-- 2. SAP STAGING ORDERS (ตารางกลางแผนคำสั่งผลิต SAP ครบ 26 คอลัมน์ + Bulk Oil)
-- รองรับทั้งการซิงค์อัตโนมัติจาก SAP และการอัปโหลดไฟล์ Excel
-- =========================================================================

-- 2.1 ตารางกลางรวมคำสั่งผลิต SAP ทั้งหมด (Blending & Packing)
CREATE TABLE IF NOT EXISTS sap_staging_orders (
    production_no VARCHAR(50) PRIMARY KEY,
    order_type VARCHAR(30) NOT NULL DEFAULT 'Blending', -- 'Blending' หรือ 'Packing'
    production_type VARCHAR(30) DEFAULT 'Standard',
    item_code VARCHAR(100),
    external_code VARCHAR(100),
    production_name VARCHAR(255),
    bulk_oil_code VARCHAR(100), -- รหัสเนื้อน้ำมันที่ใช้บรรจุ (จาก WOR1)
    bulk_oil_name VARCHAR(255), -- ชื่อเนื้อน้ำมันที่ใช้บรรจุ
    product_group VARCHAR(50),
    warehouse VARCHAR(50),
    batch_no VARCHAR(100), -- เลข Batch (U_ZG_Batch หรือสกัดจาก Remark)
    status VARCHAR(30) DEFAULT 'Planned', -- 'Planned' หรือ 'Released'
    qty NUMERIC(14, 4) DEFAULT 0,
    unit VARCHAR(50) DEFAULT 'Litre',
    factor_to_litre NUMERIC(10, 4) DEFAULT 1,
    qty_litre NUMERIC(14, 4) DEFAULT 0,
    order_date VARCHAR(50),
    start_date VARCHAR(50),
    due_date VARCHAR(50),
    closing_date VARCHAR(50),
    product_tank VARCHAR(50), -- ถังเก็บปลายทาง (U_ZG_PDTank)
    chekendprod VARCHAR(20) DEFAULT 'N',
    link_so VARCHAR(50),
    remark TEXT,
    operation_1 VARCHAR(50), -- ถังผสม BLB หรือไลน์บรรจุ FLF (U_ZG_Oper1)
    operation_2 VARCHAR(50),
    operation_3 VARCHAR(50),
    create_by VARCHAR(150),
    sync_source VARCHAR(50) DEFAULT 'SAP_SYNC',
    is_manual BOOLEAN DEFAULT FALSE,
    raw_json JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2.2 ตารางพักเฉพาะคำสั่งผลิตงานผสม (ใช้ตอนหน้างานผสมค้นหา Production No.)
CREATE TABLE IF NOT EXISTS sap_staging_blending_orders (
    production_order_no VARCHAR(50) PRIMARY KEY,
    oil_name VARCHAR(255),
    material_code VARCHAR(100),
    planned_batch_no VARCHAR(100),
    target_blender_id VARCHAR(50),
    planned_qty NUMERIC(14, 4) DEFAULT 0,
    unit VARCHAR(50) DEFAULT 'Litre',
    target_tank VARCHAR(50),
    remark TEXT,
    status VARCHAR(30) DEFAULT 'Planned',
    order_type VARCHAR(30) DEFAULT 'Blending',
    is_staged_excel BOOLEAN DEFAULT TRUE,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2.3 ตารางพักเฉพาะคำสั่งผลิตงานบรรจุ (ใช้ตอนหน้างานบรรจุค้นหา Production No. + ผูก Bulk Oil)
CREATE TABLE IF NOT EXISTS sap_staging_packaging_orders (
    packaging_order_no VARCHAR(50) PRIMARY KEY,
    oil_name VARCHAR(255),
    material_code VARCHAR(100),
    bulk_oil_code VARCHAR(100),
    bulk_oil_name VARCHAR(255),
    filling_batch_no VARCHAR(100),
    target_package_type VARCHAR(50),
    planned_qty NUMERIC(14, 4) DEFAULT 0,
    unit VARCHAR(50),
    target_tank VARCHAR(50),
    remark TEXT,
    status VARCHAR(30) DEFAULT 'Planned',
    order_type VARCHAR(30) DEFAULT 'Packing',
    is_staged_excel BOOLEAN DEFAULT TRUE,
    synced_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 3. BLENDING MODULE & APPROVED BATCH HISTORY (ระบบถังผสม & ประวัติ Batch QC)
-- =========================================================================

-- 3.1 ตารางใบงานผสม (Blending Jobs)
CREATE TABLE IF NOT EXISTS blending_jobs (
    id VARCHAR(100) PRIMARY KEY,
    blender_code VARCHAR(20) NOT NULL,
    production_no VARCHAR(50) NOT NULL,
    oil_name VARCHAR(255) NOT NULL,
    item_code VARCHAR(100),
    batch_no VARCHAR(100) NOT NULL,
    target_volume_litre NUMERIC(14, 2) DEFAULT 0,
    target_tank VARCHAR(50),
    remark TEXT,
    job_status VARCHAR(50) NOT NULL DEFAULT 'ยังไม่เริ่ม',
    steps JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    total_duration_minutes NUMERIC(8, 2),
    source VARCHAR(50) DEFAULT 'NORMAL',
    raw_json JSONB DEFAULT '{}'::jsonb
);

-- 3.2 ตารางขั้นตอนย่อยในงานผสม (Job Steps)
CREATE TABLE IF NOT EXISTS job_steps (
    id VARCHAR(150) PRIMARY KEY,
    job_id VARCHAR(100) NOT NULL REFERENCES blending_jobs(id) ON DELETE CASCADE,
    step_number SMALLINT NOT NULL,
    step_name VARCHAR(150) NOT NULL,
    is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
    flush_material VARCHAR(100),
    flush_volume_litre NUMERIC(10, 2),
    target_tank VARCHAR(50),
    status VARCHAR(30) NOT NULL DEFAULT 'idle',
    started_at TIMESTAMP WITH TIME ZONE,
    finished_at TIMESTAMP WITH TIME ZONE,
    step_duration_minutes NUMERIC(8, 2)
);

-- 3.3 ตารางประวัติ Batch น้ำมันผสมที่ผ่านแล็บและค่า Density @ 30°C (ใช้ผูกกับไลน์บรรจุ)
CREATE TABLE IF NOT EXISTS approved_blending_batches (
    batch_no VARCHAR(100) PRIMARY KEY,
    production_no VARCHAR(50),
    oil_name VARCHAR(255),
    item_code VARCHAR(100),
    blender_code VARCHAR(50),
    density_30c NUMERIC(8, 4),
    approved_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    inspector_id VARCHAR(100),
    source VARCHAR(100) DEFAULT 'ระบบปกติ (Blender + Lab)',
    remark TEXT
);

-- =========================================================================
-- 4. FILLING MODULE (ระบบไลน์บรรจุ)
-- =========================================================================

CREATE TABLE IF NOT EXISTS filling_jobs (
    id VARCHAR(100) PRIMARY KEY,
    line_code VARCHAR(20) NOT NULL,
    production_no VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    item_code VARCHAR(100),
    bulk_oil_code VARCHAR(100),
    bulk_oil_name VARCHAR(255),
    bulk_oil_batch_no VARCHAR(100) NOT NULL,
    package_type VARCHAR(50),
    planned_qty NUMERIC(14, 2) DEFAULT 0,
    job_status VARCHAR(50) NOT NULL DEFAULT 'ยังไม่เริ่ม',
    materials_ready BOOLEAN NOT NULL DEFAULT FALSE,
    first_fill_approved BOOLEAN NOT NULL DEFAULT FALSE,
    approved_density_30c NUMERIC(8, 4),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    total_duration_minutes NUMERIC(8, 2),
    raw_json JSONB DEFAULT '{}'::jsonb
);

-- =========================================================================
-- 5. PACKAGING MODULE (ระบบคลังและจัดการบรรจุภัณฑ์)
-- =========================================================================

CREATE TABLE IF NOT EXISTS packaging_requests (
    request_id VARCHAR(100) PRIMARY KEY,
    filling_job_id VARCHAR(100),
    production_no VARCHAR(50) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    bulk_oil_batch_no VARCHAR(100) NOT NULL,
    line_code VARCHAR(20) NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    t_requested TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    t_received TIMESTAMP WITH TIME ZONE,
    t_dispatched TIMESTAMP WITH TIME ZONE,
    prep_duration_minutes NUMERIC(8, 2),
    raw_json JSONB DEFAULT '{}'::jsonb
);

-- =========================================================================
-- 6. QC LAB GATE (ระบบศูนย์ตรวจห้องแล็บ)
-- =========================================================================

CREATE TABLE IF NOT EXISTS lab_sample_history (
    sample_id VARCHAR(100) PRIMARY KEY,
    source_module VARCHAR(20) NOT NULL CHECK (source_module IN ('BLENDING', 'FILLING')),
    blending_job_id VARCHAR(100),
    filling_job_id VARCHAR(100),
    step_number SMALLINT,
    production_no VARCHAR(50) NOT NULL,
    batch_no VARCHAR(100) NOT NULL,
    oil_name VARCHAR(255),
    blender_code VARCHAR(50),
    line_code VARCHAR(50),
    sample_tag VARCHAR(100) NOT NULL,
    round_number INTEGER NOT NULL DEFAULT 1,
    t_sent TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sent_by VARCHAR(100),
    t_received TIMESTAMP WITH TIME ZONE,
    received_by VARCHAR(100),
    t_approved TIMESTAMP WITH TIME ZONE,
    inspector_id VARCHAR(100),
    lab_action VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    reason_code VARCHAR(50),
    reason_description_th VARCHAR(255),
    comment TEXT,
    density_30c NUMERIC(8, 4),
    viscosity_40c NUMERIC(8, 2),
    appearance VARCHAR(100),
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    lab_pure_tat_minutes NUMERIC(8, 2),
    raw_json JSONB DEFAULT '{}'::jsonb
);

-- =========================================================================
-- 7. USERS, RBAC & SECURITY AUDIT LOGS (ผู้ใช้งานและบันทึกความปลอดภัย)
-- =========================================================================

CREATE TABLE IF NOT EXISTS app_users (
    id VARCHAR(100) PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'OPERATOR',
    department VARCHAR(100),
    allowed_systems JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS security_audit_logs (
    id VARCHAR(100) PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    username VARCHAR(100),
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================================
-- 8. SAP ERP GATEWAY INTEGRATION CONFIG & SYNC LOGS
-- =========================================================================

CREATE TABLE IF NOT EXISTS system_api_integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_type VARCHAR(20) NOT NULL UNIQUE CHECK (integration_type IN ('ERP', 'FILLING')),
    label VARCHAR(100) NOT NULL,
    is_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    endpoint_url TEXT NOT NULL DEFAULT '',
    auth_type VARCHAR(20) NOT NULL DEFAULT 'none' CHECK (auth_type IN ('none', 'api_key', 'bearer', 'basic')),
    header_name VARCHAR(100) DEFAULT '',
    encrypted_secret_token TEXT DEFAULT '',
    basic_username VARCHAR(100) DEFAULT '',
    encrypted_basic_password TEXT DEFAULT '',
    polling_interval_minutes INTEGER NOT NULL DEFAULT 5,
    ingestion_mode VARCHAR(20) NOT NULL DEFAULT 'auto',
    field_mappings JSONB NOT NULL DEFAULT '{}'::jsonb,
    last_test_status VARCHAR(30) DEFAULT 'untested',
    last_test_message TEXT,
    last_tested_at TIMESTAMP WITH TIME ZONE,
    last_synced_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    integration_type VARCHAR(20) NOT NULL,
    sync_direction VARCHAR(10) NOT NULL DEFAULT 'INBOUND',
    status VARCHAR(20) NOT NULL,
    http_status INTEGER,
    records_fetched INTEGER DEFAULT 0,
    records_imported INTEGER DEFAULT 0,
    records_removed INTEGER DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO system_api_integrations (integration_type, label, is_enabled, polling_interval_minutes, ingestion_mode)
VALUES ('ERP', 'Central SAP ERP Gateway (Blending & Filling Unified)', FALSE, 5, 'auto')
ON CONFLICT (integration_type) DO NOTHING;

-- =========================================================================
-- 9. REAL-TIME MULTI-DEVICE SYNC STORE (หัวใจหลักสำหรับซิงค์ทุกหน้าจอ Real-time)
-- =========================================================================

CREATE TABLE IF NOT EXISTS mes_sync_store (
    collection_name VARCHAR(50) PRIMARY KEY,
    data JSONB NOT NULL DEFAULT '[]'::jsonb,
    revision BIGINT DEFAULT 1,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- สร้างรายการเริ่มต้นให้ครบทุก Collection ในระบบ
INSERT INTO mes_sync_store (collection_name, data, revision) VALUES
('blending', '[]'::jsonb, 1),
('filling', '[]'::jsonb, 1),
('packaging', '[]'::jsonb, 1),
('lab', '[]'::jsonb, 1),
('adminConfig', '{}'::jsonb, 1),
('users', '[]'::jsonb, 1),
('sapStagingOrders', '[]'::jsonb, 1),
('auditLogs', '[]'::jsonb, 1)
ON CONFLICT (collection_name) DO NOTHING;

-- =========================================================================
-- 10. ROW LEVEL SECURITY (RLS) POLICIES (เปิดสิทธิ์ให้หน้าเว็บเชื่อมต่อผ่าน Anon Key ได้ครบทุกตาราง)
-- =========================================================================

DO $$
DECLARE
    tbl TEXT;
    pol_name TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'blenders',
        'filling_lines',
        'admin_reason_configs',
        'kpi_sla_configs',
        'sap_staging_orders',
        'sap_staging_blending_orders',
        'sap_staging_packaging_orders',
        'blending_jobs',
        'job_steps',
        'approved_blending_batches',
        'filling_jobs',
        'packaging_requests',
        'lab_sample_history',
        'app_users',
        'security_audit_logs',
        'system_api_integrations',
        'api_sync_logs',
        'mes_sync_store'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY;', tbl);
        pol_name := 'Allow public access ' || tbl;
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE tablename = tbl AND policyname = pol_name
        ) THEN
            EXECUTE format('CREATE POLICY %I ON %I FOR ALL USING (true) WITH CHECK (true);', pol_name, tbl);
        END IF;
    END LOOP;
END $$;

-- =========================================================================
-- 11. SAFE COLUMN UPGRADES FOR EXISTING TABLES (รองรับการอัปเกรดตารางเดิมโดยข้อมูลไม่หาย)
-- =========================================================================
ALTER TABLE sap_staging_orders ADD COLUMN IF NOT EXISTS raw_json JSONB DEFAULT '{}'::jsonb;
ALTER TABLE blending_jobs ADD COLUMN IF NOT EXISTS raw_json JSONB DEFAULT '{}'::jsonb;
ALTER TABLE filling_jobs ADD COLUMN IF NOT EXISTS raw_json JSONB DEFAULT '{}'::jsonb;
ALTER TABLE packaging_requests ADD COLUMN IF NOT EXISTS raw_json JSONB DEFAULT '{}'::jsonb;
ALTER TABLE lab_sample_history ADD COLUMN IF NOT EXISTS raw_json JSONB DEFAULT '{}'::jsonb;
ALTER TABLE job_steps ADD COLUMN IF NOT EXISTS target_tank VARCHAR(50);
ALTER TABLE job_steps ALTER COLUMN id TYPE VARCHAR(150) USING id::text;

