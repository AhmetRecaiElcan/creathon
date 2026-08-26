# Take Off

T3 Creathon için geliştirilen etkinlik uygulaması. Bir teknoloji fuarına gelen
dört farklı kitleyi — **girişimci, yatırımcı, kurum/partner ve ziyaretçi** — aynı
uygulamada, her birine kendi ekranlarını vererek karşılıyor: kim kiminle
görüşmeli, hangi standa gitmeli, hangi oturumu kaçırmamalı.

Flutter (Android) + Firebase. Yönetim paneli aynı kod tabanından çıkan ayrı bir
web hedefi.

---

## Demo hesapları

Denemek isteyen doğrudan aşağıdaki hesaplarla girebilir. **Hepsinin şifresi
`123456`.**

| E-posta | Rol | Ne görür |
| --- | --- | --- |
| `ahmetrecaielcan@gmail.com` | Girişimci | Kendi girişim kartı, gelen görüşme talepleri, yatırımcı/kurum eşleşmeleri |
| `tstr1apps@gmail.com` | Yatırımcı | Teze uyan girişim sıralaması, etkinlikler sekmesi, talep gönderme |
| `tstr4apps@gmail.com` | Yatırımcı | İkinci yatırımcı — iki tarafı aynı anda denemek için |
| `tstr2apps@gmail.com` | Kurum / Partner | Stant, bilgilendirme kartı, saat açma, gelen talepler |
| `tstr3apps@gmail.com` | Ziyaretçi | İlgi alanına göre program, 3D fuar alanı, ajanda |

Bir görüşme akışını uçtan uca görmek için iki cihaz (ya da emülatör + telefon)
gerekiyor: bir tarafta yatırımcı talebi gönderir, öbür tarafta kurum onaylar,
ikisinde birden katılma bağlantısı çıkar.

> Kayıt **davetle** çalışıyor: listede olmayan bir adres kayıt olamaz, tanımlandığı
> müşteri türünden başka bir kapıdan da giremez. Yeni bir hesap denemek istersen
> önce paneldeki davet listesine ekle.

## Yönetim paneli

| | |
| --- | --- |
| Adres | `https://creathon-9488f.web.app` |
| E-posta | `admin@gmail.com` |
| Şifre | `123456` |

Üç sekmesi var:

1. **Davetler** — kimin, hangi rolle kayıt olabileceğini tanımlar. Jüri demoda
   kendi adresini burada canlı tanımlayıp telefondan o an kayıt olabilir.
2. **Etkinlikler** — programa oturum ekler/siler. Eklenen oturum dört rolün de
   ana sayfasında anında görünür.
3. **Hesaplar** — kayıtlı hesabı toplantıları, kartı, standı ve Auth kaydıyla
   birlikte siler. En sonda olması kasıtlı: geri alınamayan tek bölüm o.

## Öne çıkan akışlar

- **Yapay zekâ ile eşleştirme** — ana sayfadaki sıralamayı Gemini üretiyor.
  Deterministik `CardMatcher` etiket örtüşmesine bakar; model kartın *ne
  anlattığını* okuyup 0–100 puan ve tek cümlelik gerekçe verir. Aynı veri için
  iki kez model çağrılmaz, sonuç imzasıyla birlikte önbelleğe yazılır.
- **Görüşme brifingi** — onaylanmış her görüşmede "Brifing al": neden değerli,
  sorulacak üç soru, karşı tarafın isteyeceği şey, elinin altında olması gereken
  tek şey. Bakan kişiye özel — aynı yarım saat iki taraf için iki ayrı brifing.
- **Online görüşme** — oda JaaS (8x8 Jitsi) üzerinde; katılım JWT'si Cloud
  Function içinde imzalanıyor, iki taraf da moderatör giriyor. Kimse lobide
  beklemiyor.
- **3D fuar alanı** — salon planı; stantlar rezervasyon anında doluyor.
- **QR kart ve tarama** — her kurum/girişim kartının QR'ı var, `TARA` sekmesinden
  okutulunca karşı tarafın kartı açılıyor.
- **Ajanda** — kaydedilen oturumlar ve onaylanmış görüşmeler tek günlük akışta.
- **Görüşmeyi bitirme ve değerlendirme** — toplantı saati dolduğunda değil, iki
  taraftan biri "Görüşmeyi bitir"e bastığında biter; değerlendirme ondan sonra
  gelir.

## Kurulum

```
flutter pub get
flutter run
```

Firebase projesi: **creathon-9488f** · Android paketi: **com.company.creathon**.
`google-services.json` depoda hazır; ayrı bir yapılandırma gerekmiyor.

Firebase ayağa kalkmazsa uygulama çökmüyor — repository'ler boş veriye düşüyor,
yalnızca hesap gerektiren adımlar uyarı veriyor.

### Yönetim panelini derleme

```
flutter build web -t lib/admin/main_admin.dart -o build/admin
firebase deploy --only hosting
```

### Testler

```
flutter test
```

Davet kapısının zorlaması Firestore kurallarında, yani widget testlerinin
ulaşamadığı yerde. Onun için emülatöre karşı çalışan ayrı bir takım var:

```
cd firebase/rules_test && npm install && npm test
```

## Klasör düzeni

```
lib/
  admin/      Web yönetim paneli (ayrı giriş noktası: main_admin.dart)
  core/       Tema, tipografi, router, ortak widget'lar, Firebase açılışı
  data/       Firestore/Functions repository'leri
  domain/     Modeller ve iş kuralları (eşleştirme motoru, saat ızgarası, roller)
  features/   Ekranlar — home, expo, meetings, organization, agenda, scan, profile
functions/    Cloud Functions: görüşme bağlantısı, AI eşleştirme, brifing, hesap silme
firebase/     Firestore kuralları ve kural testleri
test/         Dart testleri
```

## Daha fazlası

Koleksiyon şemaları, güvenlik kuralları, Cloud Functions dağıtımı, gizli anahtar
yönetimi ve sorun giderme adımları için: **[FIREBASE.md](FIREBASE.md)**.

---

Yukarıdaki hesaplar yalnızca **demo** içindir; etkinlik sonrası panelin
"Hesaplar" sekmesinden silinmeli ve panel şifresi değiştirilmelidir.
