# VPS ပေါ် တင်နည်း (z.com)

Server တစ်လုံးထဲမှာ အကုန်လုံး run ပါမယ် — API, database, shop web, admin web။
HTTPS certificate က အလိုအလျောက် ရပါတယ် (Caddy က လုပ်ပေးတယ်၊ သက်တမ်းလည်း
အလိုအလျောက် တိုးပေးတယ်)။

ဖတ်ပြီးရင် သုံးရမယ့် command က တစ်ကြောင်းပဲ — `./scripts/deploy.sh`

---

## အဆင့် ၁ — DNS ချိတ်ပါ

Domain ဝယ်ထားတဲ့နေရာ (သို့) Cloudflare မှာ **A record ၃ ခု** ထည့်ပါ။
`203.0.113.10` နေရာမှာ ကိုယ့် VPS IP ထည့်ပါ —

| Type | Name | Value |
|---|---|---|
| A | `@` | `203.0.113.10` |
| A | `admin` | `203.0.113.10` |
| A | `api` | `203.0.113.10` |
| A | `www` | `203.0.113.10` |

> Cloudflare သုံးရင် အရင်ဆုံး **proxy (မီးခိုးရောင် မိုးတိမ်) ပိတ်ထားပါ**။
> Certificate ရပြီးမှ ပြန်ဖွင့်ပါ။

DNS ပြန့်သွားပြီလား စစ်ရန် — `dig +short api.yourdomain.com`

## အဆင့် ၂ — VPS ကို ပြင်ဆင်ပါ

VPS ထဲ ဝင်ပြီး —

```bash
ssh root@203.0.113.10
```

Docker ထည့်ပါ (Ubuntu/Debian) —

```bash
curl -fsSL https://get.docker.com | sh
apt-get update && apt-get install -y git
```

Firewall မှာ port ၈၀ နဲ့ ၄၄၃ ဖွင့်ပါ —

```bash
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
```

> z.com control panel မှာလည်း packet filter ရှိရင် 80/443 ဖွင့်ပေးဖို့ မမေ့ပါနဲ့။

## အဆင့် ၃ — Code ကို VPS ပေါ် ယူပါ

```bash
git clone https://github.com/htetaungkyawmx/dia_shop_v2.git /opt/dia-shop
cd /opt/dia-shop
```

## အဆင့် ၄ — Secret တွေ ထည့်ပါ

```bash
cp deploy/env.example deploy/.env
nano deploy/.env
```

Password တွေကို **မိမိဘာသာ မတွေးဘဲ** ဒီ command နဲ့ ထုတ်ပါ —

```bash
echo "DB_PASSWORD=$(openssl rand -base64 24)"
echo "JWT_SECRET=$(openssl rand -base64 48)"
```

ဖြည့်ရမယ့်အရာများ —

```
DOMAIN=yourdomain.com
TLS_EMAIL=you@yourdomain.com
DB_PASSWORD=<အပေါ်က ထုတ်ထားတာ>
JWT_SECRET=<အပေါ်က ထုတ်ထားတာ>
ADMIN_EMAIL=you@yourdomain.com
ADMIN_PASSWORD=<ခိုင်တဲ့ password>
```

> `deploy/.env` ကို git ထဲ မတင်ပါနဲ့ — gitignore ထဲ ထည့်ထားပြီးပါပြီ။

## အဆင့် ၅ — Mac ကနေ deploy လုပ်ပါ

Mac ပေါ်မှာ ပြန်လာပြီး —

```bash
cd ~/Desktop/Claim/dia_shop_v2
cp scripts/deploy.env.example scripts/deploy.env
nano scripts/deploy.env      # VPS_HOST နဲ့ DOMAIN ဖြည့်ပါ
./scripts/deploy.sh
```

Script က အောက်ပါအတိုင်း လုပ်ပေးပါမယ် —

1. Web app ၂ ခုကို `https://api.yourdomain.com` ကို ညွှန်းပြီး build
2. VPS ပေါ် upload
3. VPS မှာ code အသစ် pull ပြီး container တွေ restart
4. API တက်လာတဲ့အထိ စောင့်ပြီး link တွေ ပြပေး

ပထမဆုံးအကြိမ်မှာ backend image ဆောက်တာ ၅-၁၀ မိနစ် ကြာပါမယ်။

## အဆင့် ၆ — အလုပ်လုပ်မလုပ် စစ်ပါ

```bash
./scripts/smoke-test.sh https://api.yourdomain.com you@yourdomain.com 'your-password'
```

၅၀ ခုလုံး ✓ ဖြစ်ရပါမယ်။

---

## နောက်ပိုင်း update လုပ်ရင်

Code ပြင်ပြီးရင် —

```bash
git add -A && git commit -m "…" && git push
./scripts/deploy.sh
```

ဒါပဲ။

---

## Backup (မဖြစ်မနေ လုပ်ပါ)

VPS ပေါ်မှာ နေ့စဉ် backup အလိုအလျောက် လုပ်အောင် —

```bash
crontab -e
```

ဒီစာကြောင်းကို ထည့်ပါ —

```
0 3 * * * /opt/dia-shop/scripts/backup.sh >> /var/log/dia-shop-backup.log 2>&1
```

Backup တွေက `/opt/dia-shop/deploy/backups/` ထဲ သွားပြီး ၁၄ ရက် သိမ်းထားပါတယ်။
တစ်ခါတစ်လေ ကိုယ့် Mac ဆီ ကူးထားပါ —

```bash
rsync -az root@203.0.113.10:/opt/dia-shop/deploy/backups/ ~/dia-shop-backups/
```

Restore လုပ်ရန် —

```bash
gunzip -c deploy/backups/dia_shop-20260916-030000.sql.gz | \
  docker compose --env-file deploy/.env -f deploy/docker-compose.prod.yml \
  exec -T postgres psql -U dia_shop dia_shop
```

---

## Live မတက်ခင် စစ်ရမယ့်စာရင်း

- [ ] `deploy/.env` ထဲ password တွေ အားလုံး အသစ် (default မကျန်စေရ)
- [ ] Admin panel → Settings မှာ **တကယ့် KPay/Wave account နံပါတ်** ထည့်ပြီး
- [ ] Seed လုပ်ထားတဲ့ ဈေးနှုန်းတွေကို ကိုယ့်ဈေးနဲ့ ပြန်ပြင်ပြီး
- [ ] Backup cron ထည့်ပြီး၊ တစ်ခါလောက် လက်နဲ့ စမ်း run ကြည့်ပြီး
- [ ] `https://yourdomain.com` ကို ဖုန်းနဲ့ ဖွင့်ပြီး Add to Home Screen စမ်းပြီး
- [ ] Smoke test ၅၀ ခုလုံး အောင်ပြီး

---

## ပြဿနာ ဖြေရှင်းနည်း

**Certificate မရဘူး** — DNS မပြန့်သေးတာ (သို့) port 80 ပိတ်နေတာ ဖြစ်တတ်တယ်။

```bash
ssh root@VPS 'cd /opt/dia-shop && docker compose -f deploy/docker-compose.prod.yml logs caddy | tail -40'
```

**API မတက်ဘူး**

```bash
ssh root@VPS 'cd /opt/dia-shop && docker compose -f deploy/docker-compose.prod.yml logs api | tail -60'
```

RAM နည်းလို့ ဖြစ်တတ်ပါတယ်။ VPS မှာ 1GB ပဲ ရှိရင် swap ထည့်ပါ —

```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

**Web app က API ကို မခေါ်နိုင်ဘူး** — `deploy/.env` ထဲ `DOMAIN` မှားနေတာ (သို့)
web build ဟောင်းကျန်နေတာ။ `./scripts/deploy.sh` ပြန်ဆွဲပါ။
