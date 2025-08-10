# TrueNAS + FTP System - Quick Start Guide

## 🚀 التثبيت السريع (3 خطوات)

### 1. تحضير النظام
```bash
# تشغيل سكريبت إعداد البيئة
chmod +x scripts/setup-environment.sh
./scripts/setup-environment.sh setup
```

### 2. تكوين النظام
```bash
# نسخ ملف التكوين
cp .env.example .env

# تحرير بيانات FTP (مطلوب!)
nano .env
# أو
vim .env
```

**⚠️ مهم جداً:** قم بتعديل هذه المتغيرات في ملف `.env`:
```bash
FTP_HOST=ftp71.nitroflare.com
FTP_USER=your_username_here    # ضع اسم المستخدم الخاص بك
FTP_PASS=your_password_here    # ضع كلمة المرور الخاصة بك

# غيّر كلمات المرور الافتراضية
TRUENAS_ADMIN_PASSWORD=YourSecurePassword2024!
POSTGRES_PASSWORD=YourSecureDBPassword2024!
REDIS_PASSWORD=YourSecureRedisPassword2024!
```

### 3. تشغيل النظام
```bash
# جعل سكريبت التثبيت قابل للتنفيذ
chmod +x deploy-complete.sh

# تشغيل التثبيت الكامل
./deploy-complete.sh install
```

## 🌐 الوصول للخدمات

بعد التثبيت الناجح، يمكنك الوصول إلى:

- **لوحة التحكم المتقدمة**: http://localhost:8080
- **TrueNAS Web Interface**: http://localhost:80
- **Grafana Monitoring**: http://localhost:3000 (admin/admin123)
- **Prometheus Metrics**: http://localhost:9090

## 📥 استخدام نظام التحميل

### تحميل ملف واحد
```bash
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh download "/path/to/file.zip"
```

### تحميل متعدد من قائمة
```bash
# إنشاء قائمة الملفات
echo -e "file1.zip\nfile2.rar\nfolder/file3.pdf" > download-list.txt

# تحميل جميع الملفات
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh batch download-list.txt
```

### اختبار الاتصال
```bash
docker-compose exec ftp-client /scripts/connect-ftp.sh test
```

## 🔧 إدارة النظام

### عرض حالة النظام
```bash
./deploy-complete.sh status
# أو
docker-compose exec ftp-client /scripts/status.sh
```

### مزامنة البيانات
```bash
docker-compose exec ftp-client /scripts/sync-truenas.sh
```

### عرض السجلات
```bash
# سجلات جميع الخدمات
docker-compose logs -f

# سجل خدمة معينة
docker-compose logs -f ftp-client
```

### إنشاء نسخة احتياطية
```bash
./deploy-complete.sh backup
```

## ❗ حل المشاكل الشائعة

### المشكلة: فشل الاتصال بـ FTP
**الحل:**
1. تأكد من صحة بيانات الدخول في `.env`
2. اختبر الاتصال: `docker-compose exec ftp-client /scripts/connect-ftp.sh test`
3. تحقق من السجلات: `docker-compose logs ftp-client`

### المشكلة: لا يمكن الوصول للوحة التحكم
**الحل:**
1. تأكد من تشغيل الخدمات: `docker-compose ps`
2. تحقق من المنفذ: `netstat -tulpn | grep 8080`
3. إعادة تشغيل لوحة التحكم: `docker-compose restart dashboard`

### المشكلة: مساحة القرص ممتلئة
**الحل:**
1. تنظيف الملفات المؤقتة: `docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh cleanup`
2. أرشفة الملفات القديمة: `docker-compose exec ftp-client /scripts/sync-truenas.sh`
3. حذف الحاويات غير المستخدمة: `docker system prune -f`

## 🛡️ الأمان

### تغيير كلمات المرور
```bash
# تحرير ملف .env
nano .env

# إعادة تشغيل الخدمات لتطبيق التغييرات
docker-compose down
docker-compose up -d
```

### تفعيل SSL/HTTPS
```bash
# تحرير ملف .env
SSL_ENABLED=true

# إعادة التشغيل
docker-compose restart nginx
```

## 📱 الاستخدام من الهاتف المحمول

لوحة التحكم متجاوبة وتعمل على الهواتف المحمولة:
- افتح المتصفح
- اذهب إلى: `http://your-server-ip:8080`
- استخدم جميع الميزات من الهاتف

## 🔄 التحديث

```bash
# سحب أحدث التحديثات
git pull origin main

# إعادة بناء وتشغيل
docker-compose build
docker-compose up -d
```

## 📞 الحصول على المساعدة

- **الوثائق الكاملة**: راجع `README.md`
- **السجلات**: تحقق من مجلد `./logs/`
- **GitHub Issues**: قم بإنشاء issue جديد
- **البريد الإلكتروني**: keskasilyes@gmail.com

---

**💡 نصائح إضافية:**
- استخدم `htop` لمراقبة الموارد
- قم بإنشاء نسخ احتياطية دورية
- راقب مساحة القرص بانتظام
- حافظ على تحديث النظام
