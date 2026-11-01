# Kurulum ve kullanım rehberi

> [English](WALKTHROUGH.md) | **Türkçe** · [Proje özeti](README.tr.md) · [Teknik başvuru](TECHNICAL.tr.md)

Bu rehberin sonunda `ZCHE_TCMB_LOAD` programını çalıştırıp seçtiğiniz bir günün TCMB kurlarını önce kaydetmeden inceleyebileceksiniz. Ardından deneme sisteminde kayıt yapıp sonucu OB08'de kontrol edeceksiniz.

**Başlangıç noktası:** SAP geliştirme yetkisi olan bir ABAP geliştiricisisiniz. İlk kurulumu DEV/deneme sisteminde yapın. Proje ön sürümdür; güncel revizyonun temiz kurulum, bakım ekranı üretimi ve gerçek SAP çalıştırması henüz doğrulanmadı.

![Kurulum haritası: SAP nesnelerini kur, profil ve erişimi hazırla, önce dene sonra kaydet](docs/images/setup-tr.svg)

## Önce hazırlıkları ayırın

| Hazırlık | Nerede yapılır? | Ne için gerekir? |
|---|---|---|
| Projeyi içe aktarma ve ayar ekranları | SAP geliştirme sistemi | Programı çalıştırmak ve ayar girmek. Bunu siz yaparsınız. |
| Para birimi, kur tipi, oran ve tarih kararı | SAP FI ayarları ve kendi muhasebe süreciniz | Doğru kurun doğru tarih ve kur tipiyle kaydedilmesi. Gerekirse FI sorumlusuyla belirleyin. |
| TCMB bağlantısı | SAP uygulama sunucusunun ağ ve SSL ayarları | SAP'nin bültene ulaşması. Yetki sizdeyse siz, değilse Basis/ağ sorumlusu yapar. |

Normal HTTPS yolunda sunucuya RDP/SSH ile bağlanıp ek yazılım kurmanız gerekmez. SAP GUI içindeki bağlantı/sertifika ayarları ve ağ izinleri yeterli olabilir. Sunucu erişimi yalnızca alternatif dosya yolu gibi ortamınızın gerektirdiği durumlarda gerekir.

## 1. SAP nesnelerini kurun

### 1.1. abapGit ile projeyi içe alın

abapGit, GitHub'daki ABAP nesnelerini SAP'ye aktaran araçtır. Bu proje yalnızca tek bir rapordan oluşmaz; sınıflar ve tabloları da vardır. Bu yüzden sadece rapor kodunu SE38'e yapıştırmak kurulum için yeterli değildir.

abapGit yoksa resmi [kurulum rehberini](https://docs.abapgit.org/user-guide/getting-started/install.html) izleyin: standalone kaynağını SE38'de oluşturduğunuz `ZABAPGIT_STANDALONE` raporuna yükleyip etkinleştirin ve çalıştırın.

1. Proje için **transport edilebilir ayrı bir müşteri paketi** oluşturun. `ZCHE_TCMB` yalnızca örnek paket adıdır; kurumunuzdaki uygun adı seçin. Sistemler arasında taşıyacaksanız `$TMP` kullanmayın.
2. abapGit'te **New Online** ile aşağıdaki depo adresini ve kendi paketinizi seçin; depoyu oluşturup **Pull** yapın. Adres gerçek proje adresidir, değiştirmeniz gerekmez:

   `https://github.com/Cheditte/abap-tcmb-rates`

3. Nesneleri etkinleştirin. Aktivasyon hataları varsa ilerlemeden çözün. Paket için ABAP Unit ve uygun ATC kontrollerini çalıştırın.

**SAP GitHub'a erişemiyorsa:** bilgisayarınızdan depoyu **Code → Download ZIP** ile indirin. abapGit'te aynı amaçla **New Offline → Import zip → Pull zip** yolunu kullanın. Bu, kurulum dosyalarını SAP'ye taşır; günlük TCMB erişimini ayrıca hazırlamanız gerekir.

### 1.2. Ayar giriş ekranlarını bir kez oluşturun

Depoda üç ayar tablosu vardır; SM30 bakım ekranları hazır gelmez. **SM30**, bu tablolara ayar satırları gireceğiniz standart SAP işlemidir. Ekranları DEV'de bir kez üretirsiniz; her kullanımda yeniden üretmezsiniz.

| Tablo | Ne saklar? |
|---|---|
| `ZCHE_TCMB_PROF` | Profilin genel kuralları ve bağlantı seçimi. |
| `ZCHE_TCMB_MAP` | TCMB'deki hangi kurun, SAP'deki hangi kur tipine yazılacağı. |
| `ZCHE_TCMB_CURR` | Hangi para birimlerinin dahil edileceği veya dışarıda bırakılacağı. |

Her tablo için:

1. **SE11**'de tabloyu açın; **Utilities → Table Maintenance Generator** yoluna gidin. SE54'te **Generated Objects → Create/Change** alternatifidir; menü adları SAP diline/sürümüne göre değişebilir.
2. Uygun yetki grubunu, müşteri fonksiyon grubunu, tek adımlı bakım tipini, ekran numarasını ve standart kayıt rutinini seçin. Fonksiyon grubu örnekleri: `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`. Bunlar oluşturacağınız örnek adlardır; önce kullanılmadıklarını kontrol edin. Ayrı gruplarda ekran numarası `0001` olabilir.
3. **Generate** ile üretin; nesneleri proje paketine ve uygun transport talebine kaydedin. Bakım engelliyse SE11'de tablonun bakım ayarını inceleyin.
4. SM30'da her tabloyu açabildiğinizi doğrulayın. Henüz veri girmeden bir sonraki adımdaki kararları netleştirin.

**Bu bölümün sonucu:** program aktif, üç tablonun bakım ekranları kullanılabilir olmalı. Üretimi ve taşımayı DEV'de yapın; canlı sistemde ekran üretmeyin. Temiz kurulum ve ekran üretimi için [kabul kontrol listesi](CONTRIBUTING.md#sap-acceptance-checklist) henüz tamamlanmayı bekliyor.

## 2. İlk profilinizi ve bağlantıyı hazırlayın

### 2.1. Önce hangi kuru alacağınızı seçin

Bu rehberdeki **`DEMO`**, sizin oluşturacağınız örnek profil adıdır; kurulumla otomatik gelmez. Örnek, USD ve JPY için döviz alış kurunu aynı gün geçerli olacak şekilde inceler. **`M`, `FX_BUY` ve `SAME_DAY` iş kuralı önerisi değildir**; kendi FI sürecinize göre seçin.

- **Kur tipi:** SAP'de farklı amaçlarla tuttuğunuz kur grubudur. Örnekte `M` kullanılır; sisteminizde tanımlı ve uygun olmalıdır.
- **TCMB alanı:** döviz alış, döviz satış, efektif alış/satış veya ortalama. Örnekte döviz alış için `FX_BUY` kullanılır. [Bütün seçenekler](TECHNICAL.tr.md#tcmb-alanları).
- **Geçerlilik tarihi:** bültenin tarihiyle aynı gün, ertesi gün veya fabrika takvimine göre sonraki iş günü olabilir. İlk örnekte `SAME_DAY` kullanılır.
- **Dönüşüm oranı:** SAP'nin kuru kaç birim üzerinden kullandığını belirler. Örneğin TCMB, JPY'yi 100 birim üzerinden yayımlayabilir. İlgili para çifti/kur tipi için OBBS'deki oranların geçerlilik tarihini de kapsadığını doğrulayın; rastgele `1:1` girmeyin.

### 2.2. Üç tabloya örnek ayarları girin

Doğru SAP istemcisinde **SM30** kullanın. Üç tablo da istemciye bağlıdır; başka istemcideki kayıtlar burada görünmez.

**A — Önce `ZCHE_TCMB_PROF`: bir profil satırı**

| Alan | İlk denemede girilecek değer | Açıklama |
|---|---|---|
| `PROFILE` | `DEMO` | Örnek profil adı; diğer iki tabloda da aynı adı kullanın. |
| `DESCRIPTION` | Kendi açıklamanız | Örneğin “TCMB ilk deneme”. |
| `DATE_RULE` | `SAME_DAY` | Kur, bülten tarihinde geçerli olur. |
| `TARGET_CURRENCY` | `TRY` | Desteklenen karşılık para birimi. |
| `EXISTING_RATE` | `S` | Aynı anahtar/tarihte farklı kayıt varsa onu korur. |
| `NO_BULLETIN` | `I` | Bülten yoksa sonuçta bildirir. |

İlk HTTPS denemesinde diğer alanları boş bırakın: `FACTORY_CALENDAR`, `WRITE_INVERSE`, `SOURCE_CLASS`, `RFC_DESTINATION`, `BASE_URL`, `FILE_FOLDER`, `EXIT_CLASS`. Boş kaynak sınıfı hazır HTTPS kaynağını seçer. Kurumunuz SM59 hedefi kullanıyorsa aşağıdaki bağlantı bölümüne göre yalnız ilgili alanı doldurun.

**Önemli:** `EXISTING_RATE` alanını boş bırakmak koruma sağlamaz; boş veya `U` güncellemeye izin verir. İlk örnekte bu yüzden açıkça `S` seçiyoruz. [Bütün alanların açıklamaları](TECHNICAL.tr.md#profil-ayarları).

**B — `ZCHE_TCMB_MAP`: bir eşleme satırı**

| `PROFILE` | `RATE_TYPE` | `SOURCE` |
|---|---|---|
| `DEMO` | `M` | `FX_BUY` |

Anlamı: “DEMO çalıştığında TCMB döviz alış değerini SAP'nin M kur tipinde kullan.” Farklı bir kur tipi seçtiyseniz `M` yerine kendi kur tipinizi girin ve OBBS ayarını da ona göre kontrol edin.

**C — `ZCHE_TCMB_CURR`: iki para birimi satırı**

| `PROFILE` | `TCMB_CODE` | `SAP_CURRENCY` | `EXCLUDE` |
|---|---|---|---|
| `DEMO` | `USD` | Boş bırakın | Boş bırakın |
| `DEMO` | `JPY` | Boş bırakın | Boş bırakın |

Boş bırakın yazan hücrelere bu metni yazmayın; alan gerçekten boş kalsın. Bu iki satır yalnız USD ve JPY'nin değerlendirilmesini sağlar. SAP para birimi kodunuz farklıysa `SAP_CURRENCY` alanına kendi kodunuzu girersiniz.

**Para birimi tablosunu boş bırakmayın:** dahil etme satırı yoksa program, bültendeki dışlanmamış bütün para birimlerini değerlendirir.

### 2.3. SAP'nin bültene ulaşmasını sağlayın

Varsayılan kaynak adresi `https://www.tcmb.gov.tr/kurlar`'dır; kendinize ait bir adresle değiştirmeniz gerekmez. Bu yol için TCMB kullanıcı adı, şifre veya API anahtarı girilmez.

| Durum | Yapılacak işlem |
|---|---|
| SAP doğrudan internete çıkabiliyor | Profilde bağlantı alanları boş kalabilir. SAP'nin HTTPS ve sertifika güvenini doğrulayın. Doğrudan yol STRUST'taki SSL client **Anonymous** PSE'sini kullanır. |
| Kurum SM59 bağlantısı/proxy kullanıyor | SM59'da TCMB'ye HTTP hedefi (tip G), sunucu `www.tcmb.gov.tr`, port `443`, SSL etkin ve path prefix boş olacak şekilde hazırlayın. Profilin `RFC_DESTINATION` alanına **sizin oluşturduğunuz hedefin adını** girin. Ağ/proxy ve hedefin SSL PSE'si ortamınıza göre ayarlanır. |
| Bağlantı ayarlarını siz yönetmiyorsunuz | Basis/ağ sorumlusuna “SAP uygulama sunucusundan www.tcmb.gov.tr:443 için HTTPS erişimi ve sertifika güveni gerekiyor” bilgisini iletin. |
| SAP internet erişimine kapalı | Aşağıdaki [dosyadan okuma](#dosyadan-okuma) yolunu kullanın. |

Sertifika hatasında gerçek sertifika zincirini ve doğru PSE'yi kontrol edin. Bilgisayardaki tarayıcıyla erişim testi tek başına yeterli değildir.

**Bu bölümün sonucu:** profil ve iki para birimi kayıtlı; seçtiğiniz kaynak SAP'den erişilebilir olmalı.

## 3. Önce deneyin, sonra kaydedin

### 3.1. Yazmadan ilk kontrol

1. **SE38 → `ZCHE_TCMB_LOAD` → Execute (F8)** ile seçim ekranını açın.
2. **Rate profile / `P_PROF`** alanına `DEMO` girin.
3. **Test the connection to TCMB** düğmesine basın. Yakın tarihteki bir bülteni alıp okuyabilmesi kaynak bağlantısını doğrular; SAP'ye kur yazmaz. Bu test son yedi gün içinde bülten arar ve seçtiğiniz tarih aralığını kullanmaz.
4. **Bulletin date(s) / `S_DATE`** alanına bülteni yayımlanmış geçmiş bir hafta içi günü girin. İlk denemede tek gün seçin. Varsayılan bugün, henüz yayımlanmamış bir bülten olabilir.
5. **Date rule / `P_RULE`** boş kalsın; profilin kuralı kullanılır. **Test run, write nothing / `P_TEST` işaretli kalsın.**
6. F8 ile çalıştırın. Sonuçtaki bülten tarihi, `VALID_FROM`, USD/JPY, kur tipi, oranlar ve açıklamaları kontrol edin. Bülten değeriyle SAP kurunu birim/oran etkisini dikkate alarak karşılaştırın.

| Sonuç | Nasıl okuyacaksınız? |
|---|---|
| `NEW` | Testte: yeni kayıt oluşturulacak. Gerçek çalıştırmada: yazma ve commit başarılıysa yeni kayıt oluştu. |
| `UPDATED` | Testte: mevcut kayıt değiştirilecek. Gerçek çalıştırmada: yazma ve commit başarılıysa güncellendi. |
| `UNCHANGED` | Aynı anahtar/tarihte eşit kur zaten var. |
| `SKIPPED` | Satır atlandı; nedenini mesajda okuyun. Mevcut kaydı koruma veya eksik kaynak alanı olabilir. |
| `NO_BULLETIN` | Seçilen hafta içi gün için bülten alınamadı; örneğin tatil veya henüz yayınlanmama. Profil politikası hata da üretebilir. |
| `ERROR` | Sorun var; mesajı inceleyip çözün. |

**Testte `NEW` görmeniz OB08'e kayıt yapıldığı anlamına gelmez.** Bu mod yazma yetkisini veya gerçek kaydın başarısını da doğrulamaz. Kendi exit sınıfınızı eklerseniz testte de çalışır; [test kurallarına](TECHNICAL.tr.md#mimari-ve-genişletme) uymalıdır.

### 3.2. Deneme sisteminde gerçek kayıt

1. Beklenmeyen hata/atlamaları çözün. Kur tipi, geçerlilik tarihi ve beklenen çevrim tutarını doğrulayın.
2. Aynı sınırlı seçimle, **yalnızca kayıt yapmak istediğinizde** Test run işaretini kaldırıp çalıştırın.
3. **OB08**'de aynı kur tipi, para çifti ve geçerlilik tarihiyle kaydı bulun. SAP para çevrimiyle beklenen tutarı da kontrol edin.
4. Aynı günü tekrar çalıştırın: kaydedilmiş eşit kurların `UNCHANGED` olması beklenir.

### 3.3. Günlük çalışmayı planlayın

Kurulum ve gerçek yazma kabulü tamamlandıktan sonra nesneleri/bakım ekranlarını ve profil verilerini normal transport sürecinizle taşıyın. Her hedef sistemde istemci, bağlantı, yetki ve FI ayarlarını ayrıca doğrulayın.

**SM36**'da `ZCHE_TCMB_LOAD` için onayladığınız seçimlerle bir varyant ve job hazırlayın. Günlük bülten için tarih alanını sabit bir gün olarak kaydetmeyin; **güncel tarih seçim değişkeni** kullanın. Yazması gereken varyantta Test run işaretini ayrıca kontrol edin. Önce test kullanıcısıyla arka plan çalışmasını doğrulayın; ardından yetkileri uygun çalışma kullanıcısını seçin.

TCMB, gösterge kurlarını iş günlerinde saat 15.30'da ilan eder; job'ı yayın sonrası uygun bir saate planlayın ve SAP/job saat dilimini doğrulayın. [TCMB açıklaması](https://tcmb.gov.tr/wps/wcm/connect/TR/TCMB%2BTR/Main%2BMenu/Banka%2BHakkinda/Sikca%2BSorulan%2BSorular/Doviz%2BKuru%2BPolitikasi%2Bve%2BRezerv%2BYonetimi/).

Program cumartesi/pazarı atlar. Tatil veya yayınlanmamış günün davranışı profil ayarına bağlıdır. **SM37**, job log'u ve spool üzerinden sonuçları izleyin; hatalı job önceki başarılı kayıtları geri almaz.

## Dosyadan okuma

Bu bölüm yalnız SAP'nin TCMB'ye HTTPS erişimi yoksa gerekir. Program bilgisayarınızdaki İndirilenler klasörünü değil, **SAP uygulama sunucusunun okuyabildiği klasörü** kullanır. Otomatik indirici bu projeye dahil değildir.

1. Yetkiniz varsa sunucuya kurumunuzun izin verdiği yöntemle (Windows'ta RDP, Linux'ta SSH veya yönetilen dosya aktarımı) erişin; yoksa sunucu sorumlusuyla klasör ve dosya hazırlığını yapın.
2. Tam TCMB günlük XML'ini bu klasöre `GGAAYYYY.xml` adıyla koyun. Örneğin **30.10.2026 için** `30102026.xml`; kendi seçtiğiniz tarihe göre dosya adı değişir. XML içindeki bülten tarihi de aynı olmalıdır. Dosya tamamlandıktan sonra okunacak klasöre alın.
3. Profilde `SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` yapın. `FILE_FOLDER` alanına **sizin sisteminizdeki gerçek sunucu klasörünü** girin. Birden fazla uygulama sunucusu varsa çalıştırmanın/job'ın aynı dosyalara erişebildiğini doğrulayın.
4. SAP çalışma kullanıcısının dosya yetkisini ve sunucudaki okuma iznini kontrol edin. Tek günlük test çalıştırmasını seçtiğiniz dosyanın tarihiyle yapın.

Bağlantı düğmesi dosya kaynağında da son yedi güne bakar. Sadece daha eski bir dosya hazırladıysanız düğme yerine o tarihte test çalıştırması yapın. Eksik/okunamayan dosya `ERROR` olur; program bunu “TCMB o gün yayın yapmadı” diye kabul etmez ve başka kaynağa otomatik geçmez.

## Bir şey ters giderse

| Belirti | İlk kontrol |
|---|---|
| Profil bulunamıyor | Doğru istemci, profil adı ve üç ayar tablosu. |
| SM30 açılmıyor | Bakım ekranı üretimi ve tablo bakım yetkisi. |
| SSL / bağlantı hatası | SAP sunucusunun erişimi, STRUST/SM59, ağ ve proxy. |
| Oran / TCURF hatası | OBBS'de doğru para çifti, kur tipi ve geçerlilik tarihindeki oranlar. |
| Beklediğiniz kur atlandı | Satır mesajı, para birimi listesi, kaynak alanı ve mevcut kayıt politikası. |
| Job hata verdi | SM37 log/spool ve OB08. Daha önce yazılmış kayıtlar kalmış olabilir. |

**Hata alan çalıştırmayı körlemesine tekrarlamayın.** Başarılı önceki günler ve satırlar kaydedilmiş olabilir. Önce sonuçları ve OB08'i inceleyin; nedeni giderip etkilenen aralığı test modunda tekrar değerlendirin. Commit hatasında yeniden denemeden önce SM13'teki başarısız/bekleyen güncellemeleri yetkili kişiyle kontrol edin. [Kısmi yazma ve kurtarma ayrıntıları](TECHNICAL.tr.md#hatalar-kısmi-yazma-ve-yeniden-çalıştırma).
