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
| Görüşme bağlantısı imzalama | `functions/index.js` |
| İmzalı bağlantı istemcisi | `lib/data/meeting_link_repository.dart` |
| CLI hedefi | `firebase.json`, `.firebaserc` |

Firebase ayağa kalkmazsa uygulama çökmez: repository'ler boş veriye düşer,
yalnızca hesap gerektiren adımlar "bağlantı kurulamadı" der.

## Konsolda yapılması gerekenler

1. **Authentication → Sign-in method → Email/Password**'ü aç.
   (Kapalıyken kayıt `operation-not-allowed` döner.)
2. **Firestore Database**'i oluştur (production mode).
3. Authentication → Templates → **Email address verification** şablonundaki
   gönderen adını ve metni Türkçeleştir.
4. Faturalandırmayı **Blaze**'e geçir — Cloud Functions'ın şartı.

Kurallar artık konsola elle yapıştırılmıyor; `firebase.json` CLI'a nereye
bakacağını söylüyor:

```
firebase deploy --only firestore:rules
```

## Online görüşmeler

Görüşme odası **JaaS** (8x8'in barındırdığı Jitsi) üzerinde. Odaya girmek, kiracının
RSA özel anahtarıyla imzalanmış bir JWT sunmayı gerektiriyor — yani anahtar kapının
kendisi. Uygulamanın içine konulan bir anahtar, APK'yı açan herkesin kendine sınırsız
geçiş üretebileceği bir anahtardır; bu yüzden imzalama `functions/index.js` içindeki
`meetingJoinLink` fonksiyonunda.

Fonksiyonun asıl kazancı imzalama değil, **kimin girebileceği kararının uygulamanın
düzenleyemediği bir yerde alınması**: toplantı dokümanını okuyup çağıranın gerçekten
o toplantının iki tarafından biri olduğunu ve toplantının onaylandığını doğruladıktan
sonra imzalıyor. Token tek bir odaya kısıtlanıyor — `room: "*"` taşıyan bir token
kiracıdaki *her* toplantıyı elinde tutana açardı.

Her iki taraf da `moderator: "true"` alıyor. İki kişilik bir görüşmede yalnızca bir
tarafın moderatör olması, diğerinin lobide bekleyerek karşı tarafın önce girmesini
beklemesi demektir — halka açık `meet.jit.si` örneğini terk etme sebebimiz de tam
olarak buydu.

İlk kurulum (özel anahtar depoya **girmez**, Secret Manager'a girer):

```
firebase functions:secrets:set JAAS_KEY_ID
firebase functions:secrets:set JAAS_PRIVATE_KEY < jaas-anahtar.pk
firebase deploy --only functions
```

`JAAS_APP_ID` gizli değil — her katılım bağlantısının ilk yol parçası, dolayısıyla
`functions/index.js` içinde varsayılan olarak duruyor. Bölge `europe-west1`;
`FunctionsMeetingLinkRepository.region` ile aynı kalmalı, yoksa çağrı hiçbir şeyin
dinlemediği bir adrese gider ve `not-found` döner.

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
  "stage": "Kurumsal",
  "market": "Ulusal",
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

`stage` (aşama/seviye) ve `market` (hedef pazar) **her iki kart türünde** de
bulunur ve yatırımcının ana sayfasındaki sıralamayı besler: yatırımcı kayıt
olurken hangi aşamalara ve hangi hedef pazarlara baktığını seçer, eşleşen
kartlar üste çıkar. Girişimde üçü de zorunlu, kurumda isteğe bağlı — boş
bırakan kurum o listede hiç öne çıkmaz. Değerler `Taxonomy.stages` (Fikir →
Kurumsal) ve `Taxonomy.markets` (Yerel, Ulusal, Bölgesel, Global) listelerinden
gelir.

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

Ayrıca `stages` ve `markets` listeleri yatırımcının **sıralama ölçütüdür**:
ana sayfası, yayındaki kartları bu üç eksene göre puanlayıp sıralar — alan 4,
aşama 2, hedef pazar 1 puan (`lib/domain/card_match.dart`). Boş liste "tercih
yok" demektir: eski hesaplar kapıda kalmaz, sadece sıralama kazanmaz.

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
  "stages": ["Seed", "Seri A"],
  "markets": ["Ulusal"],
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

**`PERMISSION_DENIED` — `Write failed at meetings/...`, sadece online talepleri
onaylarken**

Yayındaki kural seti `roomName`'i tanımıyor. Online bir talep onaylanırken
`status` ile `roomName` **aynı** yazmada gidiyor — onaylanmış ama girilecek yeri
olmayan bir toplantı bir an için bile oluşmasın diye. `hasOnly(['status'])`
diyen eski kural ikinci alanı görünce yazmanın tamamını reddediyor. Ayırt etme
yolu: yüz yüze bir talebin onayı geçiyorsa sebep budur, çünkü orada `roomName`
null olduğundan haritaya hiç girmiyor.

Çözüm: `firebase deploy --only firestore:rules`.

**Görüşmeye katıl → "Görüşme bağlantısı alınamadı"**

Sırayla bak:

1. `firebase functions:log --only meetingJoinLink` — fonksiyon `secretOrPrivateKey`
   diye şikâyet ediyorsa özel anahtar Secret Manager'a satır sonları bozulmuş
   girmiş. Dosyadan yönlendirerek tekrar yaz: `... < jaas-anahtar.pk`.
2. `not-found` dönüyorsa bölge uyuşmuyor. Fonksiyon `europe-west1`'de,
   istemci de orayı aramalı.
3. 8x8 tarafında `invalid token` görünüyorsa `JAAS_KEY_ID`, JaaS konsolundaki
   anahtarın kimliği değil de başka bir şey olabilir; JWT başlığındaki `kid` bu
   değerden geliyor.

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

## Kayıt tanımlama ve yönetim paneli

Kayıt artık açık değil: bir adres uygulamaya ancak T3 panelinde tanımlıysa ve
**yalnızca tanımlandığı müşteri türünden** kayıt olabilir. Ziyaretçi olarak
tanımlanan bir adres yatırımcı kapısından denerse reddedilir.

### Nasıl çalışıyor

`invites/{e-posta}` — doküman kimliği adresin kendisi, küçük harfe indirilmiş
hâli. Bu katlama kararı Dart'ta tek bir yerde: `Invite.idFor`. Panel `Ahmet@x.com`
yazarken telefon `ahmet@x.com` arıyorsa davetli bir konuk kapıda reddedilir, bu
yüzden iki taraf da aynı fonksiyondan geçiyor; kural da `.lower()` ile aynısını
yapıyor.

Zorlama iki katmanlı ve ikisi farklı işler yapıyor:

- **Kural** (`firebase/firestore.rules`) — `users/{uid}` üzerinde `create`,
  yazılan `role` alanının davet listesinin verdiği rolle aynı olmasını şart
  koşuyor. Rol sonradan **donuyor**: aksi hâlde ziyaretçi olarak girip alanı
  sessizce yatırımcıya çevirmek mümkün olurdu. `organizations` üzerinde `create`
  de listeye bağlı — bu koleksiyonu tüm dünya okuyor (3D salon ve her QR), yani
  davetsiz bir hesap oraya sahte firma koyamamalı. **Güvenlik burada.**
- **Kayıt ekranı** (`_rejectUninvited`) — kuralın yapamadığı şeyi yapıyor:
  hangi kapıyı kullanacağını söylemek. Profil yazımı ateşle-ve-unut olduğu için
  kural bir yazıyı reddettiğinde uygulama bunu fark etmez; mesajı buradan veriyor.

Bu yüzden **davet listesi okunamazsa kayıt engellenmez** (`InviteUnknown`).
Kopan bir bağlantı "davetli değilsin" diye okunursa ilk ağ tıksırığında tüm
etkinlik kendi uygulamasından dışarıda kalır; yazının son sözü zaten kuralda.

Liste yalnızca **yeni** hesapları süzüyor. `users/{uid}` dokümanı olan bir hesap
daha önce kabul edilmiştir ve toplantıları, kartı, standı hep o uid'ye bağlıdır —
listeden çıkarmak onu kapı dışında bırakmaz, sadece o adresle yeni kayıt açılmasını
durdurur. Hesabı almak ayrı bir iş, kendi temizliğiyle (yukarıdaki bölüm).

### Paneli ayağa kaldırma

1. **Konsolda Web uygulaması kaydet** — Project settings → Your apps → Web.
   Çıkan `apiKey` ve `appId` değerlerini
   `lib/core/firebase/firebase_options.dart` içindeki `web` bloğuna yaz. Bu adım
   yapılmadan panel kendi "Panel yapılandırılmamış" ekranını gösterir.
2. **Yönetici hesabı** — panele girecek kişi için normal bir e-posta/şifre
   hesabı aç (Authentication → Add user), sonra Firestore'da
   `admins/{o hesabın uid'si}` diye bir doküman oluştur. İçeriği önemsiz.
   Koleksiyona kimse yazamıyor, tek giriş yolu konsol — kendi üyeliğini
   verebilen bir koleksiyon, davet listesini süs hâline getirirdi. Şifre koda
   gömülmüyor: web paketini açan herkes okur.
3. **Kuralları yayınla** — `firebase deploy --only firestore:rules`.
4. **Derle ve yayınla:**
   ```
   flutter build web -t lib/admin/main_admin.dart -o build/admin
   firebase deploy --only hosting
   ```

### Yayınlamadan önce yapılması gerekenler

- **Mevcut test hesaplarının adreslerini panelde tanımla**, doğru rolleriyle.
  Kural yalnızca `create`'i süzdüğü için kayıtlı hesaplar çalışmaya devam eder;
  ama bir kurum kartını silip yeniden yayınlamak isterse `organizations` create
  kuralına takılır.
- **Jüri kendi kendine kayıt olamaz.** Demoda bunu adım olarak kullan: panelde
  jürinin adresini canlı tanımla, telefonda o anda kayıt olsun.
- Paneldeki liste `createdAt` alanına göre sıralanıyor; konsoldan **elle**
  eklenen ve bu alanı olmayan bir satır sorguya hiç düşmez, yani panelde
  görünmez. Satırları panelden ekle.

### Kuralları test etme

Davet kapısının zorlaması kurallarda, yani uygulama testlerinin ulaşamadığı bir
yerde. Emülatöre karşı çalışan ayrı bir takım var:

```
cd firebase/rules_test && npm install && npm test
```

On senaryo: davetli ziyaretçinin geçmesi, aynı adresin yatırımcı rolüyle
reddedilmesi, listede olmayan adresin hiç profil açamaması, büyük/küçük harfin
eşleşmesi, rolün oluşturmadan sonra donması, doğrulanmamış hesabın reddi, kartın
yalnızca davetli kurum/girişim tarafından yayınlanabilmesi, konuğun sadece kendi
satırını okuyabilmesi, listeye yalnızca yöneticinin yazabilmesi ve kimsenin
kendine yöneticilik verememesi. Emülatör portu `firebase.json` içinde 8085
(8080 sistemde doluydu).

## Panelden etkinlik atma

Panelin ikinci sekmesi programı yönetiyor. Eklenen bir etkinlik **dört müşteri
türünün ana sayfasında ve yatırımcının ETKİNLİKLER sekmesinde birden** görünür —
uygulama koleksiyonun tamamını herkes için okuduğu için hedefleme yok, kopya yok.

Form: ad, yer, tarih, başlangıç–bitiş saati, tür (`SessionKind`), opsiyonel
konuşmacı/kurum ve opsiyonel sektörler. Sektörler süs değil: ziyaretçinin ana
sayfası ilgi alanı örtüşmesine göre sıralıyor, yatırımcının etkinlik ekranı
eşleşenleri yukarı alıyor.

`events` kuralı artık `allow create, update, delete: if isAdmin()` — daha önce
tamamen kapalıydı ve program yalnızca konsoldan elle giriliyordu. Okuma açık
kalıyor; ziyaretçi hesabı olmadan da programı görebilmeli.

**Silme hiçbir şeyi peşinden sürüklemiyor, kasıtlı olarak.** Kaydedilen etkinlik
kullanıcının kendi profil dokümanında yalnızca bir id olarak duruyor ve
`savedSessionsProvider` o id'leri canlı programa karşı çözüyor — silinen etkinlik
çözülmeyi bırakır ve ajandadan kendiliğinden düşer. Panelin kullanıcı
dokümanlarına yazma yetkisi yok, buna ihtiyacı da yok.

## Toplantı saatleri

Etkinlik günü tek bir yerde tanımlı: `SlotGrid.startHour` / `SlotGrid.endHour`
(`lib/domain/availability_slot.dart`). `endHour` dışlayıcı, yani son yarım saatlik
dilim ondan yarım saat önce başlıyor.

**2026-08-24'te gün 00:00'a kadar açıldı** (`endHour: 18 → 24`), yani ızgara
09:00–23:30 arası 30 dilim. Geri almak isteyince tüm iş o satıra `18` yazmak:
`MeetingSlots.forDay` artık kendi 9/18 kopyasını taşımıyor, varsayılanlarını
`SlotGrid`'den alıyor; testler de saatleri sabit yazmak yerine aynı sabitten
türetiyor. Daha önce üç test saatleri elle yazdığı için genişletme üç ayrı
başarısızlık üretmişti.

## Panelden hesap silme

Panelin **üçüncü ve son sekmesi** kayıtlı hesapları listeliyor ve tamamen
silebiliyor. En sonda olması kasıtlı: veriyi kimsenin geri koyamayacağı şekilde
yok eden tek bölüm o.

Tarayıcıdan yapılamayan iki şey var — Auth kullanıcısı silmek admin SDK
gerektiriyor, ve toplantı kuralları "yalnızca iki taraf dokunabilir" dediği için
silinen hesabın toplantılarını panel temizleyemez. Bu yüzden iş
`adminDeleteAccount` adlı callable Cloud Function'da (`functions/index.js`,
`europe-west1`).

Sıra, uygulamanın kendi `AccountDeletion`'ıyla aynı — **veri önce, hesap en son:**

1. İki taraftaki toplantılar (`requesterId` ve `organizationId` ayrı ayrı taranır)
2. O toplantılara verilmiş değerlendirmeler — `meetingId in [...]` ile, **her iki
   taraftan**. Sadece `authorId == uid` sorgulamak karşı tarafın satırını kaçırır:
   o satırda bu hesabı adlandıran hiçbir alan yok, bağlı olduğu toplantı dışında.
3. `stands` kilidi ve `organizations/{uid}` kartı
4. `users/{uid}`
5. Authentication kullanıcısı

Fonksiyonun kendi kapısı var: çağıranın `admins/{uid}` belgesi olmalı. Kurallar
bypass edildiği için bunu kendisi kontrol etmek zorunda. İki de koruma var —
operatör **kendi** hesabını ve **başka bir yöneticiyi** buradan silemiyor; tüm
yöneticileri panelden kilitlemek panelden geri alınamaz, tek yol konsol.

Auth'ta kullanıcı bulunamazsa fonksiyon durmuyor, devam ediyor: konsoldan daha
önce silinmiş bir hesabın geride bıraktığı artık, temizlemek için bu fonksiyonun
var olma sebebi.

**Davet listesi satırına dokunulmuyor.** Hesabı silmek ve daveti geri çekmek
farklı niyetler — yanlışlıkla silinen biri yeniden kayıt olabilmeli — ve davet
için ayrı bir düğme var.

Silme sonucu operatöre sayılarla dönüyor ("3 görüşme iptal edildi, kart
kaldırıldı"), çünkü sayısız bir "silindi" organizatörün doğrulayamayacağı bir şey.

### Fonksiyonu dağıtma

```
firebase deploy --only functions
```

Not: `firebase emulators:exec --only functions` bu makinede varsayılan 10 saniyelik
keşif süresine takılıyor. Kod sorunu değil — `FUNCTIONS_DISCOVERY_TIMEOUT=60`
verildiğinde iki fonksiyon da düzgün yükleniyor.

## Görüşmeyi bitirme

Bir toplantı, saatinin dolmasıyla değil, **içindeki iki kişiden biri "Görüşmeyi
bitir"e bastığında** biter. `MeetingStatus.completed` saklanan bir durum; saatten
türetilmiyor.

Eskiden `awaitsFeedbackAt(now) = confirmed && now.isAfter(end)` idi. Yani yarım
saat dolduğu anda katılma bağlantısı kaybolup yerine değerlendirme formu
geliyordu — beş dakika uzayan bir görüşme, iki tarafa da "bu toplantı bitti,
puanla" diye görünüyordu. Konuşma sürerken. Bildirilen hata buydu.

Yeni davranış:

- **Katılma bağlantısı, toplantı onaylı olduğu sürece durur** — rezerve edilen
  yarım saat geçse bile. Uzayan bir görüşme normal durum.
- **Bitir düğmesi başlangıç saatinden itibaren çıkar**, iki tarafta da. Öncesinde
  bitirilecek bir şey yok; başlamamış bir toplantıdan çıkmak *iptal*, ayrı bir iş.
- **Bitiren taraf ikisi için birden bitirir.** Biri çıkmışken diğerinin elinde
  canlı bir katılma düğmesi kalması, onay sorulmasından daha kötü.
- **Değerlendirme yalnızca bundan sonra gelir.** Süre dolsa bile düğmeye
  basılmadan gelmez.

Yüz yüze toplantıda katılınacak bir bağlantı yok, yani kartta tek şey bu düğme —
bu yüzden bitirme video çağrısına bağlanamazdı.

Kural tarafı: `meetings` üzerinde `update` artık iki kollu. Ev sahibi eskisi gibi
`status` ve `roomName`'i oynatabiliyor. Talep eden ise **tek bir geçişi** yazabiliyor:
`confirmed → completed`, yalnızca `status` anahtarına dokunarak. Bu kadar dar
tutulmasının sebebi: `from confirmed` şartı olmasa talep eden, cevaplanmamış bir
talebi "tamamlandı" yapıp hiç olmamış bir toplantıyı puanlayabilirdi; `hasOnly(['status'])`
olmasa da ev sahibinin stant ziyareti sandığı bir toplantıya kendi görüşme odasını
sokabilirdi. Dördü de `firebase/rules_test` içinde test edilmiş durumda.

## Devam eden yarım saat talep edilebilir

Bir dilim artık **başlarken değil, biterken** kapanıyor: saat 12:10'da 12:00–12:30
hâlâ boşsa istenebiliyor. Eskisi her saatin kullanılabilir yirmi dakikasını çöpe
atıyordu, ki fuarda toplantıların çoğu tam orada kuruluyor.

Aynı eşik üç yerde birden: talep ızgarası (`organizationSlotsProvider`), kurumun
saat açma sayfası, ve `MeetingsController.request`'in bağımsız yeniden kontrolü.
Üçü ayrışırsa ekranın sunduğu bir saati denetleyici reddeder — iki kuralın en
kötüsü.
