# 🗄️ TrueNAS + FTP System - Enhanced Version 2.0

> نظام متطور لإدارة التحميلات من خوادم FTP مع تكامل TrueNAS ومراقبة شاملة

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/your-repo/truenas-ftp-system)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-production--ready-success.svg)]()

## 🚀 المميزات الجديدة في الإصدار 2.0

### ⚡ تحسينات الأداء
- **تحميلات متوازية**: دعم لتحميل عدة ملفات في نفس الوقت
- **استئناف التحميل**: إمكانية استكمال التحميلات المتوقفة
- **ضغط ذكي**: ضغط تلقائي للملفات القديمة
- **إلغاء التكرار**: تجنب تحميل الملفات المكررة

### 🔒 الأمان المتقدم
- **شهادات SSL**: دعم HTTPS مع شهادات مخصصة
- **مصادقة قوية**: كلمات مرور معقدة ومشفرة
- **عزل الشبكة**: شبكات Docker منفصلة للأمان
- **مراقبة الأمان**: تنبيهات عند محاولات الوصول المشبوهة

### 📊 المراقبة والتحليل
- **Prometheus**: جمع المقاييس في الوقت الفعلي
- **Grafana**: لوحات تحكم تفاعلية للبيانات
- **Loki**: تجميع وتحليل السجلات
- **تنبيهات ذكية**: إشعارات عبر البريد الإلكتروني أو Webhook

### 🎨 واجهة المستخدم المحسنة
- **لوحة تحكم متطورة**: واجهة عربية حديثة ومتجاوبة
- **إحصائيات مفصلة**: رسوم بيانية لاستخدام النظام
- **إدارة الملفات**: تصفح وإدارة الملفات بسهولة
- **التحكم المباشر**: تنفيذ العمليات من الواجهة

## 📋 متطلبات النظام

### الحد الأدنى
- **المعالج**: 2 أنوية
- **الذاكرة**: 4 GB RAM
- **التخزين**: 20 GB مساحة فارغة
- **الشبكة**: اتصال إنترنت مستقر

### موصى به
- **المعالج**: 4+ أنوية
- **الذاكرة**: 8+ GB RAM
- **التخزين**: 100+ GB SSD
- **الشبكة**: 100 Mbps+

### البرامج المطلوبة
- Docker >= 20.0
- Docker Compose >= 1.27
- Bash >= 4.0
- curl, wget

## 🚀 التثبيت السريع

### 1. تحميل وتثبيت
```bash
# تحميل أحدث إصدار
git clone https://github.com/your-repo/truenas-ftp-system.git
cd truenas-ftp-system

# تشغيل المثبت التفاعلي
chmod +x deploy-optimized.sh
./deploy-optimized.sh
```

### 2. التكوين السريع
```bash
# نسخ ملف التكوين
cp .env.example .env

# تحرير الإعدادات (مطلوب!)
nano .env

# بدء النظام
./deploy-optimized.sh install
```

### 3. الوصول للخدمات
- **لوحة التحكم**: http://localhost:8080
- **TrueNAS**: http://localhost
- **Grafana**: http://localhost:3000
- **Prometheus**: http://localhost:9090

## ⚙️ التكوين المتقدم

### ملف .env
```bash
# إعدادات FTP (مطلوبة)
FTP_HOST=ftp71.nitroflare.com
FTP_USER=your_username
FTP_PASS=your_password

# إعدادات الأداء
MAX_CONCURRENT_DOWNLOADS=3
DOWNLOAD_SPEED_LIMIT=0
PARALLEL_TRANSFERS=2

# إعدادات الأمان (غيّر هذه!)
TRUENAS_ADMIN_PASSWORD=SecureAdmin2024!
POSTGRES_PASSWORD=SecurePostgres2024!
REDIS_PASSWORD=SecureRedis2024!
```

### التكوين المتقدم
```yaml
# docker-compose.override.yml
version: '3.9'
services:
  ftp-client:
    environment:
      - CUSTOM_SETTING=value
    volumes:
      - ./custom-config:/config
```

## 🎮 الاستخدام

### الأوامر الأساسية
```bash
# عرض حالة النظام
./deploy-optimized.sh status

# تحميل ملف واحد
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh download /remote/file.zip

# تحميل متعدد من قائمة
echo -e "file1.zip\nfile2.rar" > download-list.txt
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh batch download-list.txt

# مزامنة البيانات
docker-compose exec ftp-client /scripts/sync-truenas.sh

# عرض الإحصائيات
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh stats 24h

# فحص صحة النظام
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh health
```

### واجهة الويب
1. **لوحة التحكم الرئيسية**: مراقبة شاملة للنظام
2. **إدارة التحميلات**: بدء وإيقاف التحميلات
3. **إدارة الملفات**: تصفح وتنظيم الملفات
4. **الإعدادات**: تكوين النظام من الواجهة

## 📊 المراقبة والإحصائيات

### Grafana Dashboards
- **System Overview**: نظرة عامة على النظام
- **FTP Performance**: أداء التحميلات
- **Storage Usage**: استخدام التخزين
- **Network Activity**: نشاط الشبكة

### Prometheus Metrics
```promql
# معدل التحميل
rate(ftp_downloads_total[5m])

# استخدام التخزين
storage_used_bytes / storage_total_bytes * 100

# أداء النظام
system_cpu_usage_percent
```

### التنبيهات التلقائية
- مساحة التخزين منخفضة (< 10%)
- فشل في الاتصال بـ FTP
- استخدام CPU عالي (> 80%)
- ذاكرة منخفضة (< 500MB)

## 🔧 الصيانة والاستكشاف

### النسخ الاحتياطية
```bash
# إنشاء نسخة احتياطية يدوية
./deploy-optimized.sh backup

# النسخ الاحتياطية التلقائية
# يتم تشغيلها يومياً في الساعة 2:00 صباحاً
```

### حل المشاكل الشائعة

#### مشكلة: فشل الاتصال بـ FTP
```bash
# فحص الاتصال
docker-compose exec ftp-client ping ftp71.nitroflare.com

# اختبار بيانات الدخول
docker-compose exec ftp-client /scripts/connect-ftp.sh

# فحص السجلات
docker-compose logs ftp-client
```

#### مشكلة: مساحة التخزين ممتلئة
```bash
# تنظيف الملفات المؤقتة
docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh cleanup

# أرشفة الملفات القديمة
docker-compose exec ftp-client /scripts/sync-truenas.sh

# فحص استخدام المساحة
docker-compose exec ftp-client df -h /truenas
```

#### مشكلة: بطء في الأداء
```bash
# فحص استخدام الموارد
docker stats

# تحسين قاعدة البيانات
./deploy-optimized.sh maintenance

# إعادة تشغيل الخدمات
docker-compose restart
```

## 🛡️ الأمان

### أفضل الممارسات
1. **غيّر كلمات المرور الافتراضية** في ملف `.env`
2. **فعّل SSL** للاتصالات المشفرة
3. **حدّث النظام** بانتظام
4. **راقب السجلات** للأنشطة المشبوهة
5. **استخدم جدار ناري** لحماية إضافية

### إعدادات الأمان
```bash
# تفعيل SSL
SSL_ENABLED=true
SSL_CERT_PATH=./config/ssl/cert.pem
SSL_KEY_PATH=./config/ssl/private.key

# تقييد الوصول
API_RATE_LIMIT=100
SESSION_TIMEOUT=1800

# المصادقة الثنائية (اختياري)
REQUIRE_2FA=true
```

## 🔄 التحديث

### تحديث تلقائي
```bash
# تحديث إلى أحدث إصدار
git pull origin main
./deploy-optimized.sh install
```

### تحديث يدوي
```bash
# إيقاف النظام
docker-compose down

# تحديث التكوينات
./deploy-optimized.sh config

# إعادة البناء والتشغيل
docker-compose build
docker-compose up -d
```

## 🤝 المساهمة

### كيفية المساهمة
1. Fork المشروع
2. إنشاء فرع للميزة الجديدة
3. تطوير وتطبيق التحسينات
4. إرسال Pull Request

### Guidelines
- اتبع معايير الترميز الموجودة
- أضف اختبارات للميزات الجديدة
- حدّث الوثائق
- استخدم رسائل commit واضحة

## 🗺️ خارطة الطريق

### الإصدار 2.1 (Q2 2024)
- [ ] دعم خوادم FTP متعددة
- [ ] واجهة هاتف محمول
- [ ] تكامل مع خدمات التخزين السحابية
- [ ] API REST كامل

### الإصدار 2.2 (Q3 2024)
- [ ] ذكاء اصطناعي لتحسين التحميلات
- [ ] تحليل محتوى الملفات
- [ ] تصنيف تلقائي للملفات
- [ ] تنبيهات متقدمة

### الإصدار 3.0 (Q4 2024)
- [ ] إعادة تصميم كاملة للواجهة
- [ ] دعم Kubernetes
- [ ] تكامل مع نظم إدارة المحتوى
- [ ] مقاييس أداء متقدمة

## 📞 الدعم والمساعدة

### القنوات الرسمية
- **GitHub Issues**: للأخطاء وطلبات الميزات
- **Discord**: للمناقشات المجتمعية
- **Email**: keskasilyes@gmail.com
- **Documentation**: [Wiki](https://github.com/your-repo/wiki)

### الأسئلة الشائعة

**س: هل يمكن استخدام النظام مع خوادم FTP أخرى؟**
ج: نعم، يمكن تكوين أي خادم FTP عبر تحديث متغيرات البيئة.

**س: ما هو الحد الأقصى لحجم الملفات؟**
ج: لا يوجد حد نظرياً، ولكن يعتمد على مساحة التخزين المتاحة.

**س: هل يدعم النظام التحميل من روابط HTTP؟**
ج: حالياً لا، ولكن مخطط إضافة هذه الميزة في الإصدار 2.1.

**س: كيف يمكن إضافة تنبيهات مخصصة؟**
ج: يمكن تكوين التنبيهات عبر Grafana أو إضافة scripts مخصصة.

## 📄 الترخيص

هذا المشروع مرخص تحت رخصة MIT - انظر ملف [LICENSE](LICENSE) للتفاصيل.

## 🙏 شكر وتقدير

- **TrueNAS Community** - للنظام الأساسي الممتاز
- **Docker Team** - لتقنية الحاويات
- **Prometheus & Grafana** - لأدوات المراقبة
- **المساهمون** - لجهودهم في تطوير المشروع

---

## 📊 الإحصائيات

![GitHub stars](https://img.shields.io/github/stars/your-repo/truenas-ftp-system)
![GitHub forks](https://img.shields.io/github/forks/your-repo/truenas-ftp-system)
![GitHub issues](https://img.shields.io/github/issues/your-repo/truenas-ftp-system)
![GitHub downloads](https://img.shields.io/github/downloads/your-repo/truenas-ftp-system/total)

---

**صُنع بـ ❤️ للمجتمع العربي المفتوح المصدر**

> "أفضل طريقة للتنبؤ بالمستقبل هي إنشاؤه" - بيتر دراكر

## 🎯 بدء سريع في 3 خطوات

```bash
# 1. التحميل
git clone https://github.com/your-repo/truenas-ftp-system.git && cd truenas-ftp-system

# 2. التكوين
cp .env.example .env && nano .env  # أدخل بيانات FTP الخاصة بك

# 3. التشغيل
./deploy-optimized.sh install
```

🎉 **مبروك! النظام جاهز للاستخدام**

---

*آخر تحديث: يناير 2024*
