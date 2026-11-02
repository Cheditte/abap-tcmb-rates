# Teknik başvuru

> [English](TECHNICAL.md) | **Türkçe** · [README](README.tr.md) · [Kurulum ve kullanım](WALKTHROUGH.tr.md)

## Yapı ve sürüm hedefi

`src/zche_tcmb_load.prog.abap` tek çalıştırılabilir rapordur. Türler, iş mantığı, seçim ekranı, yerel sınıflar ve SAP Unit testleri aynı dosyadadır. Özel DDIC nesnesi veya global sınıf oluşturmaz. `src/package.devc.xml` ve rapor XML'i yalnız isteğe bağlı abapGit aktarımı için metaveridir.

Sözdizimi hedefi **ABAP 7.00**'dır. Açık bildirimler, `CREATE OBJECT`, klasik Open SQL, `CONCATENATE`, packed sayılar ve `CL_AUNIT_ASSERT` kullanılır. `RISK LEVEL`/`DURATION` ekleri yerine `"#AU` yorumları vardır. Gerçek 7.00/7.01/7.02 sistemde API ve çalışma zamanı uyumluluğu henüz doğrulanmadı; 7.58'de etkinleşmesi bunu kanıtlamaz. [Doğrulama kaydı](docs/validation-v0.3.0.md).

Manuel kurulumda program özelliklerindeki **Fixed point arithmetic** açık olmalıdır. Satırları 72 karaktere zorlamayın; bütün kaynak ve testleri birlikte yükleyin. Seçim metinleri `SELECTION_TEXTS_MODIFY` ile, tarih listesi `VRM_SET_VALUES` ile hazırlanır. Metin tablosu tam olarak `STANDARD TABLE OF rsseltexts WITH DEFAULT KEY` olmalıdır. Bu arayüzler hedef eski sistemde ayrıca denenmelidir.

<a id="secim-alanlari"></a>

## Seçim alanları

Varyantlar bu standart seçimleri saklar. Özel profil tablosu yoktur.

| Alan | Anlamı / davranışı |
|---|---|
| `S_DATE` | TCMB bülten günü veya aralığı; cumartesi/pazar atlanır. |
| `P_TEST` | Varsayılan `X`; yazma BAPI'si ve commit çağrılmaz. Okuma, hesaplama, karşılaştırma ve exit'ler çalışır. |
| `P_FXBUY` | Döviz alış / `ForexBuying` için SAP kur tipi. |
| `P_FXSEL` | Döviz satış / `ForexSelling` için kur tipi. |
| `P_BNBUY` | Efektif alış / `BanknoteBuying` için kur tipi. |
| `P_BNSEL` | Efektif satış / `BanknoteSelling` için kur tipi. |
| `P_FXAVG` | Döviz alış/satış aritmetik ortalaması için kur tipi; iki değer de gerekir. |
| `P_BNAVG` | Efektif alış/satış aritmetik ortalaması için kur tipi; iki değer de gerekir. |
| `P_RULE` | Zorunlu tarih kuralı; başlangıçta boş. Listeden seçim yapılır. |
| `P_CAL` | `NEXT_WORKDAY` için gerçek SCAL fabrika takvimi. |
| `S_CURR` | TCMB kodları için dahil etme/dışlama. Boş = bütün kodları değerlendir. |
| `P_MAP` | `USD=USD2; XAU=GLD` biçiminde kod eşlemesi. TCMB kodu üç harf, SAP kodu en çok beş karakter. Değerler örnektir. |
| `P_TARG` | Yalnız boş veya `TRY` geçerli; başka hedef için çapraz kur hesabı yoktur. |
| `P_INV` | TRY → döviz yönünü ters kotasyonla ekler. |
| `R_UPD` / `R_KEEP` | Farklı mevcut kuru güncelle / koru. Varsayılan Güncelle; ilk denemede korumayı seçin. Eşit kur her durumda `UNCHANGED`. |
| `R_NBLOG` / `R_NBWRN` / `R_NBERR` | Eksik hafta içi HTTP bültenini listede göster / uyar / hata say. Varsayılan liste. |
| `R_HTTP` | Varsayılan HTTPS kaynağı. |
| `P_DEST` | İsteğe bağlı SM59 tip G HTTP hedefinin gerçek adı. Host `www.tcmb.gov.tr`, 443, SSL, boş path prefix. |
| `P_URL` | SM59 hedefi yokken özel kök adres. Normalde boş; varsayılan `https://www.tcmb.gov.tr/kurlar`. |
| `R_FILE` / `P_DIR` | Uygulama sunucusundaki klasörden okuma ve gerçek klasör yolu. |

En az bir TCMB alanına kur tipi girilmelidir. Bir kur tipini iki farklı TCMB alanına vermek reddedilir. Para birimi kod eşlemesi dövizi başka bir dövize dönüştürmez. SAP'de tanımlı olmayan kod `SKIPPED` olur. Eksik TCMB alış/satış alanı da atlanır; sağlanmış ama sıfır/negatif/geçersiz sayı ise ayrıştırma hatasıdır.

## Tarih ve oran hesabı

| Kural | Geçerlilik tarihi |
|---|---|
| `SAME_DAY` | Bülten günü. |
| `NEXT_DAY` | Ertesi takvim günü. |
| `NEXT_WORKDAY` | Seçilen takvimde bülten gününden sonraki ilk iş günü. |

Fabrika takvimi indirilecek günleri değil geçerlilik tarihini etkiler. Başlangıç/bitiş ve XML tarihi takvim geçerliliği açısından kontrol edilir. XML tarihi istenen günle eşleşmelidir.

Doğrudan kur: `TCMB değeri × FFACT / (Unit × TFACT)`. İlgili tarih için TCURF'tan en yeni geçerli oran alınır; Unit ve iki oran da pozitif olmalıdır. Ara hesap `TYPE p LENGTH 16 DECIMALS 10`, çıktı TCURR'ın beş ondalıklı alanıdır. Taşma veya sıfıra yuvarlama `ERROR` olur. Oranlar muhasebe/FI kararına göre hazırlanır; örnek oranı otomatik uygulamayın.

Ters kotasyonda aynı doğrudan çiftin oranları kullanılır, yön değiştirilirken faktörler terslenir. TCURR ters kotasyonu negatif işaretle saklar; hesaplanan büyüklük pozitiftir. Bu yönü ve çevrim tutarını hedef SAP'de `CONVERT_TO_LOCAL_CURRENCY` gibi standart geri okumayla doğrulayın. Eski sürümün geri okuma kanıtı güncel düzeltmeleri doğrulamaz.

## Kaynaklar

HTTPS, `YYYYMM/DDMMYYYY.xml` yolunu kullanır. Doğrudan bağlantı `ANONYM` SSL PSE'sini seçer. SM59 hedefi varsa `/kurlar/` yolu hedefe eklenir. Sertifika önerisinde sabit kök adına güvenmek yerine gerçek zinciri doğrulayın. HTTP 404 `NO_BULLETIN` olur; diğer bağlantı/HTTP/XML hataları hatadır.

Dosya kaynağı `P_DIR` altında `GGAAYYYY.xml` okur. Eksik, yetkisiz veya okunamayan dosya **`ERROR`** olur; tatil sayılmaz. Klasörün içindeki yinelenen boşluklar korunur. İndirme ve tamamlanan dosyayı okunan klasöre taşıma dış sürecin sorumluluğudur. Kaynaklar arasında otomatik geçiş yoktur.

Bağlantı düğmesi son yedi güne bakar, `S_DATE` seçimini kullanmaz ve yazmaz. Dosya kaynağında yalnız eski dosya hazırsa o tarihle normal test çalıştırması yapın.

<a id="yerel-siniflar-ve-genisletme"></a>

## Yerel sınıflar ve genişletme

| Nesne | Görevi |
|---|---|
| `LIF_TCMB`, `LCX_TCMB`, `LCL_FMT` | Ortak türler, hata ve metin biçimleri. |
| `LIF_SOURCE`, `LCL_SOURCE_HTTP`, `LCL_SOURCE_FILE` | Bülteni alma. |
| `LCL_PARSER` | XML, tarih, birim, pozitif sayılar ve tekil para birimi doğrulama. |
| `LCL_DATE_RULE` | Geçerlilik tarihi. |
| `LCL_CALC` | Verilen oranlarla hesaplama; veritabanına erişmez. |
| `LCL_WRITER` | TCURR karşılaştırması, standart BAPI, satır bazında commit. |
| `LCL_LOADER` | Tarih aralığı, kaynak, hesaplama ve yazma akışı. |
| `LCL_EXIT` | Kaynak içindeki boş genişletme metotları. |
| `LCL_APP` | Seçim ekranı, ALV, job özeti ve hata durumu. |

Yerel sınıflar başka bir rapordan global sınıf gibi çağrılamaz. Aynı rapor içindeki **`LCL_EXIT`** bölümünü değiştirin veya standart rapor/varyant çalıştırma yolunu kullanın. Eski global `ZCL_CHE_TCMB_LOADER` çağrıları bu sürümün API'si değildir.

`BEFORE_WRITE`, satırları karşılaştırmadan önce değiştirebilir; test bayrağı almaz, kalıcı kayıt veya dış yan etki üretmemelidir. `AFTER_WRITE`, `iv_test` alır; testte yazmayı/bildirim gibi dış etkileri engellemelidir. Başlangıçta ikisi de boştur. Yeni kaynak yüklerken özel kodunuzu koruyup yeniden uygulayın; test edin. Alt akış commit yaptığı için başka iş kayıtlarıyla tek atomik LUW beklenen bir çağrı içine gömmeyin.

<a id="hatalar-ve-yeniden-deneme"></a>

## Hatalar ve yeniden deneme

Tarih aralığı tek atomik işlem değildir. Yazma ve commit satır bazında kontrol edilir. BAPI hatasında satır `ERROR` olur ve rollback çağrılır. Commit hatası başarı gibi gösterilmez; OB08 ve SM13'le mutabakat gerekir. `R_KEEP`, BAPI'nin güncellemeye izin bayrağını da kapatır; eşzamanlı eklenen kayıt üzerine yazılmamalıdır. Kilit/yarış durumunu SAP'de ayrıca doğrulayın.

Sonraki gün kaynak/ayrıştırma hatası verirse önceki günlerin sonuçları ve hata satırı listede tutulur, sonraki günlere geçilmez. Başarısız veya Cancelled job önceki commit'leri geri almaz. Yeniden denemeden önce sonuç/spool ve OB08'i kontrol edin; commit sorunu varsa yetkili kişiyle SM13'ü inceleyin. Genel kurtarma yöntemi olarak kur silmeyin.

Test modu yazma BAPI'sini ve commit'i çağırmaz. Gerçek yetki, kilit ve kayıt başarısını kanıtlamaz. Arka planda özet job log'una, sonuç listesi spool'a gider; `ERROR` job'ı iptal eder.

<a id="eski-surumden-gecis"></a>

## Eski sürümden geçiş

1. DEV'de mevcut rapor kaynağını, özel eklemeleri, varyantları ve job tanımlarını koruyun.
2. Güncel tek dosyayı `ZCHE_TCMB_LOAD` olarak yükleyin; bu raporun eski sürümünün yerini alır. Yeni kaynakta eski özel tablolar/global sınıflar kullanılmaz.
3. Eski `P_PROF` alanını kullanan varyant/job'lar yeni ekranla uyumlu değildir. Eski profil kararlarını yeni alanlara elle aktarın, yeni varyantlar oluşturup test edin. Mevcut işleri doğrulamadan yeni rapora yönlendirmeyin.
4. Programı normal transport süreciyle taşıyın. Varyant taşıma/oluşturma ve bağlantı/FI/yetki kontrollerini hedefte tamamlayın.

SAP'deki eski nesneler ve ayar verileri otomatik silinmez. Silme veya paket/transport temizliği bu değişikliğin parçası değildir. Ayrı Z program adıyla denerseniz `REPORT` adını da uyarlayın; kur kayıtları yine ortak TCURR'a gider.

Eski çok nesneli kurulum abapGit ile izleniyorsa, bu sürüme Pull sırasında kaldırılan dosyalar SAP nesnesi silme farkları olarak görünebilir. Bu farkları DEV'de bağımlılıklarıyla inceleyin; eski nesneleri koruma kararını vermeden toplu silme adımını onaylamayın. Tek kaynak dosyayı SE38'e yüklemek bu silme işlemlerini yapmaz.

## Yerel kontroller

```sh
npm ci --ignore-scripts
npm run lint
npm run check:source
```

abaplint **2.120.92**, `v700` ayarı ve depodaki üç küçük standart sınıf/arayüz yer tutucusuyla çalışır. Standart SAP tür/API kapsamı eksiktir; lint aktivasyon veya eski sürüm desteği kanıtı değildir. Ek kaynak taraması bazı yeni sözdizimi yapılarını ve tek rapor paketini kontrol eder.

Eski `test:logic` yeni raporla denendi; seçim ekranı, ALV ve `CL_AUNIT_ASSERT` gibi bağımlılıklar çözülemedi. Eski testleri çalışmış gibi göstermemek için bu adım kaldırıldı. **44 gömülü test SAP'de çalıştırılmalıdır.** [Katkı ve kabul kontrol listesi](CONTRIBUTING.md) · [Değişiklikler](CHANGELOG.md).
