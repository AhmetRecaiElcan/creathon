# Firebase kurulumu

Proje: **creathon-9488f** · Android paketi: **com.company.creathon**

## Uygulama tarafında hazır olanlar

| Parça | Yer |
| --- | --- |
| `google-services.json` | `android/app/google-services.json` |
| Gradle eklentisi | `android/settings.gradle.kts`, `android/app/build.gradle.kts` |
| Dart yapılandırması | `lib/core/firebase/firebase_options.dart` |
| Başlatma (hata toleranslı) | `lib/core/firebase/firebase_boot.dart`, `lib/main.dart` |
| Kimlik doğrulama | `lib/data/auth_repository.dart` |
| Profil dokümanı | `lib/data/profile_repository.dart` |
| Etkinlik programı | `lib/data/event_repository.dart` |
| Fuar standları | `lib/data/expo_repository.dart` |
| Güvenlik kuralları | `firebase/firestore.rules` |

Firebase ayağa kalkmazsa uygulama çökmez: repository'ler boş veriye düşer,
yalnızca hesap gerektiren adımlar "bağlantı kurulamadı" der.

## Konsolda yapılması gerekenler

1. **Authentication → Sign-in method → Email/Password**'ü aç.
   (Kapalıyken kayıt `operation-not-allowed` döner.)
2. **Firestore Database**'i oluştur (production mode).
3. `firebase/firestore.rules` içeriğini **Rules** sekmesine yapıştır ve yayınla.
4. Authentication → Templates → **Email address verification** şablonundaki
   gönderen adını ve metni Türkçeleştir.

## Koleksiyon şemaları

### `events/{id}` — ana sayfadaki program

```json
{
  "title": "Yapay Zekâ ile Üretim Optimizasyonu",
  "speaker": "Mert Soylu",
  "org": "Marmara Holding Teknoloji",
  "kind": "workshop",
  "venue": "Salon B",
  "start": "<Timestamp>",
  "end": "<Timestamp>",
  "sectors": ["Yapay Zekâ", "Veri & Analitik"]
}
```

`kind` şu değerlerden biri: `keynote`, `panel`, `workshop`, `pitch`,
`networking`. Okunamayan bir doküman tüm programı bozmaz, sadece atlanır.

### `organizations/{uid}` — bilgilendirme kartları (kurum + girişim)

Uygulama yazar; kurum ve girişimci portföyleri kaydolurken oluşturulur. **İki
kart aynı koleksiyonda durur**, `kind` alanıyla ayrılır:

| `kind` | kim | zorunlu alanlar | farkı |
| --- | --- | --- | --- |
| `corporate` (varsayılan) | Kurum / Partner | ad, e-posta, adres, açıklama, `standCode` | stant tutar, sahne sunumu alabilir |
| `startup` | Girişimci | ad, e-posta, açıklama, `stage` | stant yok, `stage` (aşama) var |

`kind` alanı olmayan eski dokümanlar `corporate` sayılır.

```json
{
  "kind": "corporate",
  "name": "Nexora Robotik",
  "email": "iletisim@nexora.com",
  "address": "Teknopark, Pendik / İstanbul",
  "description": "İnsansız kara araçları için otonom seyir yazılımı.",
  "brand": "azure",
  "color": "#3B9BFF",
  "logoBase64": "…",
  "standCode": "A3",
  "sector": "Robotik & Otonom Sistemler",
  "stage": null,
  "website": "nexora.com",
  "instagram": "@nexora",
  "linkedin": "nexora",
  "phone": "+90 5xx xxx xx xx",
  "panelDay": 2,
  "panelTime": "14:00",
  "availability": [
    { "time": "10:00", "mode": "inPerson", "note": "Stant görüşmesi" },
    { "time": "14:30", "mode": "online" }
  ]
}
```

`panelDay` (1–3) ve `panelTime` (09:00–17:00) sahne sunumudur; ikisi de isteğe
bağlı ve ziyaretçinin ana sayfasında **SAHNE SUNUMLARI** başlığı altında
listelenir. Stant gibi kilitli değil — sahnede çakışma organizatörün
çözebileceği bir şey, ve bir sunum yeniden planlanabilmeli.

3D fuar alanı doluluk bilgisini **bu** koleksiyondan alır: `standCode` alanı
bir kutuya denk gelen her kurum, kutuyu kendi rengi, adı ve logosuyla boyar.
Karşılığı olmayan her stant kodu gri kalır.

`standCode` yayına alındıktan sonra kurallarla kilitlenir — güncelleme isteği
aynı değeri taşımıyorsa reddedilir.

**Girişim kartı** (`kind: "startup"`) stant tutmaz: `standCode` `null` kalır,
`stands` koleksiyonuna hiç dokunmaz ve yayına alma tek bir yazma olur — kilit
alınmadığı için "stant kapılmış" hatası da yaşanmaz. Yerine `stage` alanı
zorunludur (`Fikir`, `Prototip`, `Pre-seed`, `Seed`, `Seri A`, `Seri B+`) ve
kartın ilk satırında `GİRİŞİM · Seed · Yapay Zekâ` olarak görünür. Sahne sunumu
alanları (`panelDay`, `panelTime`) girişim kartlarında kullanılmaz.

Girişimler de `availability` açar: yatırımcılar ancak açılan saatler için
görüşme talebi gönderebilir. Yani `meetings` koleksiyonu artık iki yönde de
çalışır — girişimci bir kuruma, yatırımcı bir girişime talep gönderir.

### `stands/{standKodu}` — stant rezervasyon kilidi

Doküman kimliği stant kodudur: `A1`…`A8`, `B1`…`B4`
(`lib/data/expo_layout.dart`). İçinde yalnızca `{ "orgId": "<uid>" }` durur.

Firestore var olan bir dokümana `create` yapılmasını reddettiği için bu kilit,
"onaylayan ilk kurum standı alır" kuralını işlem (transaction) kullanmadan
garanti eder. Güvenlik kuralları bir koleksiyon içinde teklik denetleyemez;
bu yüzden teklik doküman kimliğine, yani stant koduna taşındı.

Kurallar bu koleksiyonda `update` ve `delete`'i tamamen kapatır — stant
ataması kalıcıdır.

### `meetings/{kurumId}__{başlangıçISO}` — toplantı talepleri

Uygulama yazar. Kurumun **Profil → TOPLANTI SAATLERİM** ızgarasından açtığı
yarım saatlik dilimler `organizations` dokümanının `availability` alanında
tutulur: her dilimin saati, türü (`inPerson` / `online`) ve isteğe bağlı
açıklaması vardır. Ziyaretçi yalnızca bu dilimler için talep gönderebilir.

Eski `availableSlots: ["10:00"]` düz listesi de okunmaya devam eder; yüz yüze
ve açıklamasız kabul edilir.

```json
{
  "organizationId": "<kurum uid>",
  "organizationName": "Nexora Robotik",
  "requesterId": "<ziyaretçi uid>",
  "requesterName": "Elif Tunca",
  "requesterEmail": "elif@ornek.com",
  "requesterCompany": "Ada Ventures",
  "requesterKind": "angel",
  "start": "2026-08-21T10:00:00.000",
  "end": "2026-08-21T10:30:00.000",
  "location": "Stand A1",
  "status": "requested",
  "note": "…"
}
```

Doküman kimliği kurum + başlangıç saati olduğu için bir dilim yalnızca bir kez
alınabilir — stant kilidiyle aynı mantık. `status` yalnızca kurum tarafından
güncellenebilir; **reddetmek dokümanı siler**, böylece dilim yeniden açılır.
Talebi iki taraf da geri çekebilir.

Her iki tarafın adı dokümana kopyalanır: ajanda ikinci bir okuma beklemeden
toplantıyı çizebilsin, ve karşı taraf profilini değiştirse bile kayıt okunabilir
kalsın diye.

`requesterCompany` ve `requesterKind` (`angel` / `institutional`) yatırımcı
talepleri için doldurulur; kurum talebi kabul edip etmeyeceğine bunlara bakarak
karar verir. Kurallar `users` dokümanını karşı tarafa okutmadığı için bu bilgi
de talebin üzerine kopyalanmak zorunda. Kendi adına gelen bir ziyaretçide iki
alan da `null` kalır.

### `users/{uid}` — hesap kaydı (her rol için)

**Her hesap** — ziyaretçi olsun kurum olsun — Firebase Authentication'a düşer ve
buraya bir doküman yazar. Kurum hesabı ayrıca `organizations/{uid}` altında
kartını tutar; ikisi de **aynı uid** ile anahtarlanır, yani bir kurumun hesap
kaydı ile kartı hep eşleşir.

Kurum hesabında `firstName` alanı kurumun adını taşır, `lastName` boş kalır.
Rol bilgisi (`role: "corporate"`) burada durduğu için uygulama yeniden
açıldığında hangi deneyimin yükleneceği bu dokümandan okunur.

Girişimci hesabı (`role: "entrepreneur"`) da `organizations/{uid}` altında bir
kart tutar — `kind: "startup"` olanı. Kurum hesabından farkı, `firstName` /
`lastName` alanlarının kurucunun adını taşıması: kart girişimin, hesap kişinin.
Girişimin seçtiği alan `sectors` alanına da yazılır, ana sayfadaki program buna
göre sıralanır.

Yatırımcı hesabı (`role: "investor"`) kart yayınlamaz — `organizations` altında
dokümanı olmaz. Bunun yerine kayıt sırasında `companyName` (şirket / fon adı) ve
`investorKind` (`angel` = melek, `institutional` = kurumsal) alanları doldurulur;
ikisi de zorunludur ve gönderdiği her görüşme talebinin üzerine kopyalanır.

Uygulama yazar, elle doldurmaya gerek yok:

```json
{
  "role": "visitor",
  "firstName": "…", "lastName": "…", "email": "…",
  "emailVerified": true,
  "companyName": "Ada Ventures",
  "investorKind": "angel",
  "wallpaper": "aurora",
  "photoBase64": "…",
  "sectors": ["…"],
  "savedEventIds": ["…"],
  "likedOrgIds": ["…"]
}
```

Profil fotoğrafı ayrı bir Storage kovasına değil, doğrudan bu dokümana base64
JPEG olarak yazılır. Seçici 512px / kalite 80'e küçülttüğü için dosya ~40 KB
civarında kalıyor; Firestore'un 1 MiB doküman sınırının çok altında. Böylece
Storage kurmaya, kova kuralı yazmaya ve profil için ikinci bir istek atmaya
gerek kalmıyor.

Oturum açıkken uygulama kapatılıp açılırsa `restoreSession` bu dokümanı okuyup
kullanıcıyı doğrudan ana sayfaya alır — karşılama ekranı görünmez.

## Sorun giderme

**`PERMISSION_DENIED` — `Write failed at organizations/...`**

İki olası sebep var:

1. **Kurallar güncel değil.** `organizations` bölümü eklenmeden önceki kural
   setiyle bu koleksiyona hiçbir yazma geçmez. `firebase/firestore.rules`
   dosyasının tamamını Rules sekmesine yapıştırıp yayınla.
2. **Token bayat.** ID token `email_verified` bilgisini bir iddia (claim)
   olarak taşır ve `user.reload()` bu token'ı yenilemez. Kurallar token'a
   baktığı için doğrulamadan hemen sonraki ilk yazma reddedilirdi.
   `FirebaseAuthRepository.refreshVerification` artık doğrulama görüldüğü anda
   `getIdToken(true)` ile token'ı zorla yeniliyor; bu sınıfa dokunurken o
   çağrıyı kaldırmayın.

Uygulama bu iki durumu artık "stant kapıldı" ile karıştırmıyor: reddedilen bir
yazmada önce `stands/{kod}` kilidinin gerçekten var olup olmadığına bakıp
`StandTakenFailure` ile `PublishFailure` arasında karar veriyor.

## Hesap silme

**Konsoldan bir kullanıcıyı silmek Firestore'a dokunmaz.** Authentication'dan
silinen bir hesabın `organizations` dokümanı ve `stands` kilidi yerinde kalır —
yani fuar planında artık var olmayan bir kurumun standı renkli durmaya devam
eder. İstemcinin görebileceği bir kanca yok; bunu otomatikleştirmenin tek yolu
`auth.user().onDelete` üzerine bir Cloud Function yazmak, o da Blaze planı
gerektirir.

Bu yüzden temizliği uygulama üstleniyor:

- **Ziyaretçi:** Profil → *Hesabımı sil* → `users/{uid}` silinir, ardından hesap.
- **Kurum:** Profil → *Kurumu ve standı sil* → `organizations/{uid}` ve
  `stands/{kod}` tek batch'te silinir (stant anında boşalır), sonra
  `users/{uid}`, en son hesap.

Sıra kasıtlı: önce veri, en son hesap. Tersi olsaydı bir hata, arkasında
temizleyecek kimsenin kalmadığı yetim dokümanlar bırakırdı.

Konsoldan sildiğin bir hesabın artığını elle temizlemek için: Firestore'dan
`organizations/{uid}` ve o kurumun `standCode`'una karşılık gelen
`stands/{kod}` dokümanlarını sil.

Not: `stands` üzerinde `update` hâlâ tamamen kapalı — stant başka bir kuruma
devredilemez ve kurum kendi standını değiştiremez. Yalnızca sahibi
**bırakabilir**, o da kartı tümden silmek demek. Yani stant değiştirmenin
bedeli kartı, toplantıları ve kimliği kaybetmek; sessiz bir düzenleme değil.
