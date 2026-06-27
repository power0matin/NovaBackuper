<div align="center">  
  <img src="https://github.com/user-attachments/assets/16cc16e2-f1e5-4ae8-9b5f-bbea33fa39bd" alt=" لوگوی NovaBackuper" />  
</div>

<div dir="rtl" align="right">

# نوا بکاپر چیه؟

**NovaBackuper** یک اسکریپت بکاپ‌گیری سبک و حرفه‌ای برای **پنل x-ui** است که دیتابیس x-ui را فشرده می‌کند و به صورت خودکار برای شما در **تلگرام** ارسال یا در یک **پوشه محلی** ذخیره می‌کند.  
نصب آن تعاملی (ویزارد‌ی) است و در نهایت برای شما اسکریپت بکاپ + کران‌جاب می‌سازد تا بکاپ‌ها به صورت خودکار انجام شوند. همچنین رمزنگاری AES-256 اختیاری و پشتیبانی کامل از خط فرمان (CLI) نیز ارائه می‌دهد.

## پلتفرم‌های پشتیبانی‌شده

- [x] **Telegram** (با استفاده از bot token و chat ID)
- [x] **پوشه محلی** (هر مسیر قابل نوشتن روی سرور)
- [x] **Telegram + پوشه محلی** (ارسال همزمان به هر دو مقصد)

## ویژگی‌های کلیدی

- **نصاب تعاملی (Wizard)**  
  در حین نصب از شما می‌پرسد:
  - نام/توضیح بکاپ (Remark)
  - بازه زمانی بکاپ‌گیری (دقیقه‌ای / ساعتی با cron)
  - مقصد بکاپ (Telegram / پوشه محلی / هر دو)
  - Bot Token و Chat ID تلگرام
  - رمزنگاری اختیاری AES-256

- **رمزنگاری بکاپ** _(جدید در v1.4.0)_
  - رمزنگاری اختیاری AES-256 به ازای هر پروفایل
  - اولویت: `7z` (AES-256) ← اگر نبود: `zip -e`
  - پسورد به صورت امن در اسکریپت تولیدشده ذخیره می‌شود؛ در زمان اجرا نیازی به وارد کردن دستی ندارید

- **چند مقصد بکاپ** _(جدید در v1.4.0)_
  - **فقط Telegram** – آپلود آرشیو به ربات
  - **فقط پوشه محلی** – کپی آرشیو به یک مسیر قابل نوشتن
  - **Telegram + پوشه محلی** – هر دو در یک اجرا

- **تمرکز روی x-ui**  
  بکاپ‌گیری از فایل‌های اصلی دیتابیس x-ui:
  <div dir="ltr" align="left">
    <ul dir="ltr">
      <li><code>/etc/x-ui/x-ui.db</code></li>
      <li><code>/etc/x-ui/x-ui.db-wal</code></li>
      <li><code>/etc/x-ui/x-ui.db-shm</code></li>
    </ul>
  </div>

- **زمان‌بندی خودکار**
  - ساخت اسکریپت اختصاصی بکاپ در مسیر زیر:
    <div dir="ltr" align="left">

    `/root/_<remark>_backuper_script.sh`

    </div>

  - تنظیم خودکار **cron job** بر اساس بازه زمانی‌ای که انتخاب می‌کنید

- **ویرایشگر واقعی پروفایل** _(جدید در v1.4.0)_

  بعد از انتخاب یک پروفایل، می‌توانید تنظیمات جداگانه را بدون حذف و ساخت مجدد پروفایل تغییر دهید:

  <div dir="ltr" align="left">

  ```
  1) Change Remark
  2) Change Interval
  3) Change Timezone
  4) Change Telegram Settings
  5) Change Backup Destination
  6) Change Encryption Settings
  7) Save
  8) Cancel
  ```

  </div>

  با تغییر بازه زمانی یا remark، کران‌جاب هم به صورت خودکار به‌روزرسانی می‌شود.

- **حالت CLI / Silent** _(جدید در v1.4.0)_

  <div dir="ltr" align="left">

  ```bash
  # نصب یک پروفایل جدید بدون تعامل
  ./nova-backuper.sh --silent --install \
      --remark main \
      --interval 60 \
      --telegram-token XXXXX \
      --telegram-chat-id XXXXX \
      --telegram-topic-id 123 \
      --timezone Asia/Tehran \
      --destination telegram \
      --encrypt yes \
      --password mypassword

  # ویرایش یک فیلد از پروفایل موجود
  ./nova-backuper.sh --silent --edit main --interval 30

  # سایر عملیات
  ./nova-backuper.sh --silent --remove
  ./nova-backuper.sh --silent --run
  ./nova-backuper.sh --silent --update
  ./nova-backuper.sh --help
  ```

  </div>

- **مدیریت امن فایل‌ها**
  - فشرده‌سازی با `zip` (در صورت نیاز split-safe) یا رمزنگاری‌شده با `7z` / `zip -e`
  - پاک‌سازی چانک‌های قدیمی مربوط به همان remark قبل و بعد از هر بکاپ

- **گزارش کامل در تلگرام**
  - کپشن HTML حرفه‌ای شامل:
    - تاریخ، ساعت و منطقه زمانی
    - IP سرور و Hostname
    - Backup ID
  - ارسال مستقیم به چت تلگرام/گروه/تاپیک مورد نظر شما

### نمونه مقادیر Timezone (IANA)

<details>
<summary><b>نمایش لیست رایج‌ترین timezone ها</b></summary>

<p>
برای وارد کردن مقدار timezone در مرحله تنظیمات NovaBackuper می‌توانید از این مثال‌ها استفاده کنید.
</p>

<div dir="ltr" align="left">

| Region       | Country / City              | Timezone (IANA)                  |
| ------------ | --------------------------- | -------------------------------- |
| Middle East  | Iran                        | `Asia/Tehran`                    |
| Middle East  | Türkiye                     | `Europe/Istanbul`                |
| Middle East  | Saudi Arabia                | `Asia/Riyadh`                    |
| Middle East  | United Arab Emirates        | `Asia/Dubai`                     |
| Middle East  | Qatar                       | `Asia/Qatar`                     |
| Middle East  | Iraq                        | `Asia/Baghdad`                   |
| Middle East  | Israel                      | `Asia/Jerusalem`                 |
| Europe       | United Kingdom (London)     | `Europe/London`                  |
| Europe       | Germany (Berlin)            | `Europe/Berlin`                  |
| Europe       | France (Paris)              | `Europe/Paris`                   |
| Europe       | Italy (Rome)                | `Europe/Rome`                    |
| Europe       | Spain (Madrid)              | `Europe/Madrid`                  |
| Europe       | Netherlands (Amsterdam)     | `Europe/Amsterdam`               |
| Europe       | Sweden (Stockholm)          | `Europe/Stockholm`               |
| Europe       | Norway (Oslo)               | `Europe/Oslo`                    |
| Europe       | Russia (Moscow)             | `Europe/Moscow`                  |
| Americas     | USA – East (New York)       | `America/New_York`               |
| Americas     | USA – Central (Chicago)     | `America/Chicago`                |
| Americas     | USA – Mountain (Denver)     | `America/Denver`                 |
| Americas     | USA – West (Los Angeles)    | `America/Los_Angeles`            |
| Americas     | Canada – East (Toronto)     | `America/Toronto`                |
| Americas     | Canada – West (Vancouver)   | `America/Vancouver`              |
| Americas     | Brazil (São Paulo)          | `America/Sao_Paulo`              |
| Americas     | Argentina (Buenos Aires)    | `America/Argentina/Buenos_Aires` |
| Americas     | Mexico (Mexico City)        | `America/Mexico_City`            |
| Asia-Pacific | India (Kolkata)             | `Asia/Kolkata`                   |
| Asia-Pacific | Pakistan (Karachi)          | `Asia/Karachi`                   |
| Asia-Pacific | China (Shanghai)            | `Asia/Shanghai`                  |
| Asia-Pacific | Hong Kong                   | `Asia/Hong_Kong`                 |
| Asia-Pacific | Japan (Tokyo)               | `Asia/Tokyo`                     |
| Asia-Pacific | South Korea (Seoul)         | `Asia/Seoul`                     |
| Asia-Pacific | Singapore                   | `Asia/Singapore`                 |
| Asia-Pacific | Indonesia (Jakarta)         | `Asia/Jakarta`                   |
| Asia-Pacific | Australia (Sydney)          | `Australia/Sydney`               |
| Asia-Pacific | Australia (Perth)           | `Australia/Perth`                |
| Asia-Pacific | New Zealand (Auckland)      | `Pacific/Auckland`               |
| Africa       | Egypt (Cairo)               | `Africa/Cairo`                   |
| Africa       | South Africa (Johannesburg) | `Africa/Johannesburg`            |
| Africa       | Nigeria (Lagos)             | `Africa/Lagos`                   |
| Africa       | Kenya (Nairobi)             | `Africa/Nairobi`                 |

</div>

</details>

- **پشتیبانی از چند توزیع لینوکس**
  - تشخیص خودکار پکیج منیجر  
    <span dir="ltr">`apt`, `dnf`, `yum`, `pacman`</span>
  - نصب اتوماتیک ابزارهای مورد نیاز  
    <span dir="ltr">`curl`, `zip`, `cron` و …</span>

## قالب‌های پشتیبانی‌شده

NovaBackuper عمداً مینیمال و تخصصی طراحی شده:

- [x] **پنل x-ui** (دیتابیس SQLite در مسیر <span dir="ltr">`/etc/x-ui`</span>)

## نصب

برای نصب آخرین نسخه، این دستور را اجرا کنید:

<div dir="ltr" align="left">

```bash
sudo bash -c "$(curl -sL https://github.com/power0matin/NovaBackuper/raw/master/nova-backuper.sh)"
```

</div>

این اسکریپت کارهای زیر را انجام می‌دهد:

1. آپدیت پکیج‌های سیستم
2. نصب وابستگی‌های لازم
3. اجرای ویزارد نصب NovaBackuper
4. ساخت اسکریپت بکاپ در `/root/`
5. اجرای اولین بکاپ به صورت خودکار
6. ساخت cron job برای بکاپ‌گیری خودکار در بازه زمانی دلخواه شما

## استفاده (خلاصه)

بعد از نصب، معمولاً اسکریپت ساخته‌شده این شکلی است:

<div dir="ltr" align="left">

```bash
/root/_<remark>_backuper_script.sh
```

</div>

کران‌جاب هم شبیه این خواهد بود (مثلاً هر ۳۰ دقیقه):

<div dir="ltr" align="left">

```cron
*/5 * * * * /root/_myxui_backuper_script.sh
```

</div>

شما می‌توانید:

- برای ویرایش یا حذف کران‌جاب:

  <div dir="ltr" align="left">

  ```bash
  crontab -e
  ```

  </div>

- برای اجرای دستی بکاپ:

  <div dir="ltr" align="left">

  ```bash
  bash /root/_<remark>_backuper_script.sh
  ```

  </div>

- برای اجرای اجباری فوری (بدون توجه به بازه زمانی):

  <div dir="ltr" align="left">

  ```bash
  FORCE_RUN=1 bash /root/_<remark>_backuper_script.sh
  ```

  </div>

## تاریخچه تغییرات

### v1.4.0

- **رمزنگاری بکاپ** – رمزنگاری اختیاری AES-256 به ازای هر پروفایل از طریق `7z` یا `zip -e`
- **چند مقصد** – Telegram، پوشه محلی، یا هر دو به صورت همزمان
- **ویرایشگر واقعی پروفایل** – ویرایش تنظیمات جداگانه بدون حذف پروفایل؛ کران‌جاب به صورت خودکار به‌روز می‌شود
- **حالت Silent / CLI** – پشتیبانی کامل از `--install`، `--edit`، `--remove`، `--run`، `--update`، `--help` برای استقرار خودکار

### v1.0.0

- انتشار اولیه: ویزارد تعاملی، بکاپ x-ui، ارسال به Telegram، زمان‌بندی با cron

## 💙 حمایت از پروژه

اگر NovaBackuper برای شما مفید بود، یک **ستاره (⭐)** روی ریپو، بهترین حمایت است.
ممنون که از آن استفاده می‌کنید.

🔹 توسعه و نگهداری توسط [@power0matin](https://github.com/power0matin)

> [!NOTE]  
> NovaBackuper بر اساس پروژه‌ی [Backuper](https://github.com/erfjab/Backuper) توسعه داده شده و به نسخه‌ای متمرکز روی **x-ui + Telegram** تبدیل شده است.  
> از **@ErfJabs** برای ایده و پایه‌ی اولیه پروژه قدردانی می‌کنیم.

[![Stargazers over time](https://starchart.cc/power0matin/NovaBackuper.svg?variant=adaptive)](https://starchart.cc/power0matin/NovaBackuper)

</div>
