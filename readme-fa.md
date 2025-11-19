<div align="center">  
  <img src="https://github.com/user-attachments/assets/16cc16e2-f1e5-4ae8-9b5f-bbea33fa39bd" alt=" لوگوی NovaBackuper" />  
</div>

<div dir="rtl" align="right">

# نوا بکاپر چیه؟

**NovaBackuper** یک اسکریپت بکاپ‌گیری سبک و حرفه‌ای برای **پنل x-ui** است که دیتابیس x-ui را فشرده می‌کند و به صورت خودکار برای شما در **تلگرام** ارسال می‌کند.  
نصب آن تعاملی (ویزارد‌ی) است و در نهایت برای شما اسکریپت بکاپ + کران‌جاب می‌سازد تا بکاپ‌ها به صورت خودکار انجام شوند.

## پلتفرم پشتیبانی‌شده

- [x] **Telegram** (با استفاده از bot token و chat ID)

## ویژگی‌های کلیدی

- **نصاب تعاملی (Wizard)**  
  در حین نصب از شما می‌پرسد:

  - نام/توضیح بکاپ (Remark)
  - بازه زمانی بکاپ‌گیری (دقیقه‌ای / ساعتی با cron)
  - Bot Token و Chat ID تلگرام

- **تمرکز روی x-ui**  
  بکاپ‌گیری از فایل‌های اصلی دیتابیس x-ui:

  <ul dir="ltr">
    <li><code>/etc/x-ui/x-ui.db</code></li>
    <li><code>/etc/x-ui/x-ui.db-wal</code></li>
    <li><code>/etc/x-ui/x-ui.db-shm</code></li>
  </ul>

- **زمان‌بندی خودکار**

  - ساخت اسکریپت اختصاصی بکاپ در مسیر زیر:
    <div dir="ltr" align="left">

    `/root/_<remark>_backuper_script.sh`

    </div>

  - تنظیم خودکار **cron job** بر اساس بازه زمانی‌ای که انتخاب می‌کنید

- **مدیریت امن فایل‌ها**

  - فشرده‌سازی با `zip`
  - پاک‌سازی چانک‌های قدیمی مربوط به همان remark قبل و بعد از هر بکاپ

- **گزارش کامل در تلگرام**

  - کپشن HTML حرفه‌ای شامل:
    - تاریخ، ساعت و منطقه زمانی
    - IP سرور و Hostname
    - Backup ID
  - ارسال مستقیم به چت تلگرام/گروه مورد نظر شما

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

همچنین در مراحل نصب می‌توانید **دایرکتوری‌های دلخواه** را اضافه یا حذف کنید تا همراه دیتابیس، مسیرهای دیگر هم داخل فایل بکاپ قرار بگیرند.

> [!NOTE]  
> NovaBackuper بر اساس پروژه‌ی [Backuper](https://github.com/erfjab/Backuper) توسعه داده شده و به نسخه‌ای متمرکز روی **x-ui + Telegram** تبدیل شده است.  
> از **@ErfJabs** برای ایده و پایه‌ی اولیه پروژه قدردانی می‌کنیم.

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
*/30 * * * * /root/_myxui_backuper_script.sh
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

## 💙 حمایت از پروژه

اگر NovaBackuper برای شما مفید بود، یک **ستاره (⭐)** روی ریپو، بهترین حمایت است.
ممنون که از آن استفاده می‌کنید.

🔹 توسعه و نگهداری توسط [@power0matin](https://github.com/power0matin)

[![Stargazers over time](https://starchart.cc/power0matin/NovaBackuper.svg?variant=adaptive)](https://starchart.cc/power0matin/NovaBackuper)

</div>
