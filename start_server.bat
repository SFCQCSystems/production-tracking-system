@echo off
chcp 65001 >nul
title Production Tracking System - Central Online Server

echo =====================================================================
echo  🚀 กำลังเริ่มต้น Production Tracking System (MES Online Server)
echo =====================================================================
echo.

node -v >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ไม่พบ Node.js ในเครื่องนี้!
    echo กรุณาติดตั้ง Node.js จาก https://nodejs.org ก่อนเปิดใช้งาน
    echo.
    pause
    exit /b
)

echo [OK] ตรวจพบ Node.js ในระบบเรียบร้อยแล้ว
echo [*] กำลังรันเซิร์ฟเวอร์ฐานข้อมูลกลาง...
echo.

node server/server.js

pause
