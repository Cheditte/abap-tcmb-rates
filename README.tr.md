# abap-tcmb-rates

> [English](README.md) | **Türkçe**

TCMB'nin günlük kur bültenlerini ABAP, ayarlanabilir profiller ve `BAPI_EXCHANGERATE_CREATE` ile SAP döviz kurlarına yükler.

TCMB kurlarını tekrarlanabilir bir süreçle yüklemek isteyen ABAP geliştiricileri ve SAP FI ekipleri için hazırlanmıştır. Para birimleri, kur tipleri ve geçerlilik kuralları profille belirlenir; önce test çıktısı incelenir, ardından onaylanan yükleme SAP job'ı olarak planlanabilir. Hazır HTTPS kaynağı SAP içinde çalışır; dış bağlantısı olmayan sistemler için dosya kaynağı bulunur.

**Başlangıç:** [DEV sistemine kurun](#geliştirme-sistemine-kurulum), [küçük bir profil oluşturun](#küçük-bir-ilk-profil) ve [ilk çalıştırma adımlarını](#güvenli-ilk-çalıştırma) izleyin. Kaynak kod MIT lisanslıdır; geri bildirim ve tekrarlanabilir test sonuçlarıyla katkı verebilirsiniz.

**Ön sürüm: v0.1.** Önce geliştirme veya deneme sisteminde kullanın. Bu revizyondaki değişiklikler **SAP'te çalıştırılmadı**. Önceki revizyon SAP ABAP Platform 2023 deneme sisteminde test edildi. Boş kurulum ve bakım ekranı üretimi kabul testi bekliyor.

## Ne yapar?

`ZCHE_TCMB_LOAD`, pazartesi–cuma bültenlerini HTTPS veya uygulama sunucusundaki klasörden alır. TCMB alanlarını SAP kur tipleriyle eşler, TCURF oranlarıyla hesaplar, TCURR ile karşılaştırır ve BAPI ile yazar. Sonuçlar açıklamalarıyla birlikte `NEW`, `UPDATED`, `UNCHANGED`, `SKIPPED`, `NO_BULLETIN` veya `ERROR` olur.

**Test run varsayılan olarak işaretlidir.** Bülteni alır, hesaplar ve karşılaştırır; yazma BAPI'sini çağırmaz. Yazma yetkisi, kilit davranışı ve commit başarısını kanıtlamaz. Özel exit'ler yine çalışır ve test moduna uymalıdır.

Kurların karşılığı **TRY**'dir. `TARGET_CURRENCY` boş veya `TRY` olmalıdır; çapraz kur hesaplanmaz. İstenirse `TRY → döviz` yönü ters kotasyonla eklenir.

## Destek ve gereksinimler

| Konu | Mevcut durum |
|---|---|
| Dil | On-premise/private sistemler için standart ABAP; **ABAP Cloud uygulaması değildir**. |
| Statik hedefler | abaplint ile 7.40 SP08 ve 7.58 kontrol edilir; çalışma zamanı garantisi değildir. |
| Çalışma zamanı kanıtı | Yalnızca önceki revizyonun ABAP Platform 2023 testleri; güncel değişiklikler SAP doğrulaması bekliyor. |
| Kurulum | abapGit nesneleri `src/` altında; hazır SM30 ekranı veya profil verisi yok. |
| Bağlantı | SAP uygulama sunucusundan `www.tcmb.gov.tr:443` erişimi veya hazırlanmış dosyalar. Gerçek sertifika zinciri ve STRUST PSE'sini Basis doğrulamalı. |
| SAP ayarları | Para birimleri, kur tipleri, OBBS'de TCURF oranları; `NEXT_WORKDAY` için fabrika takvimi. |
| Yetkiler | Kurulumda geliştirme/içe aktarma ve profil bakımı; çalışma kullanıcısının BAPI, tablo ve dosya yetkileri ayrıca test edilmeli. |

Kaynak alanı, SAP kur tipi, geçerlilik ve üzerine yazma kuralını muhasebe belirlemelidir. Proje mevzuata göre muhasebe veya vergi uygulaması seçmez.

## Geliştirme sistemine kurulum

1. Gerekirse [abapGit'i kurun](https://docs.abapgit.org/user-guide/getting-started/install). `ZCHE_TCMB` gibi ayrı bir paketi kendi transport ayarlarınızla oluşturun.
2. `https://github.com/Cheditte/abap-tcmb-rates` için online depo oluşturup pakete pull yapın. Çevrimdışı sistemde offline depo oluşturun, depo ZIP'ini içe aktarın ve **Pull zip** seçin.
3. Nesneleri etkinleştirin, hataları giderin. Statik sürüm hedefi bütün SAP bağımlılıklarının varlığını garanti etmez.
4. Paketin bütün ABAP Unit testlerini ve sisteminize uygun ATC kontrollerini çalıştırın; [SAP kabul testlerini](CONTRIBUTING.md#sap-acceptance-checklist) tamamlayın.

### Bir defalık SM30 hazırlığı

Ayar tabloları depoda var; **üretilmiş tablo bakım ekranları yok**. Yetkili ABAP geliştiricisi bunları DEV sisteminde üretmelidir:

1. **SE54**'te her tablo için **Generated Objects → Create/Change** seçin. SE11 → Utilities → Table Maintenance Generator da kullanılabilir.
2. Uygun yetki grubu, müşteri fonksiyon grubu, tek adımlı ekran ve standart kayıt rutinini seçin. Örnek gruplar: `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`; ayrı gruplarda ekran `0001` olabilir. Adların uygunluğunu kontrol edin.
3. Üretip transport edilebilir pakete kaydedin. Bakım kapalıysa geliştirici SE11 ayarını incelemeli.
4. Nesneleri ve ayarları normal transport süreciyle taşıyın; doğru istemcide **SM30** kullanın. Canlıda ekran üretmeyin.

SAP'nin [bakım ekranı oluşturma açıklamasına](https://help.sap.com/docs/SAP_NETWEAVER_AS_ABAP_FOR_SOH_740/c0d47b1c53ee451f847c21d4ba5be6e6/48d59095982b424be10000000a421937.html) bakın. Bu yol güncel revizyonla henüz denenmedi.

## Küçük bir ilk profil

Ekranlar hazır olunca SM30 kullanın. Üç tablo da istemciye bağlıdır. Önce profil, sonra eşleme ve para birimi satırlarını oluşturun.

**`ZCHE_TCMB_PROF`: bir profil**

| Alan | İlk deneme değeri veya anlamı |
|---|---|
| `PROFILE` | `DEMO` |
| `DESCRIPTION` | Açıklamanız |
| `DATE_RULE` | Örnekte `SAME_DAY`; muhasebeyle doğrulayın |
| `FACTORY_CALENDAR` | `NEXT_WORKDAY` dışında boş; gerekiyorsa SCAL'da tanımlı takvim |
| `TARGET_CURRENCY` | `TRY` veya boş |
| `WRITE_INVERSE` | Başlangıçta boş; `X` ters yönü ekler |
| `EXISTING_RATE` | Başlangıçta `S`, farklı mevcut kuru korur; `U` veya boş güncellemeye izin verir |
| `NO_BULLETIN` | `I`: yalnız sonuç; `W`: uyarı; `E`: hata |
| `SOURCE_CLASS` | HTTPS için boş; dosya için `ZCL_CHE_TCMB_SOURCE_FILE` |
| `RFC_DESTINATION` | İsteğe bağlı SM59 HTTP hedefi: TCMB sunucusu, 443, SSL, path prefix boş |
| `BASE_URL` | Normalde boş; SM59 hedefi yoksa özel bülten kök adresi |
| `FILE_FOLDER` | Dosya kaynağında zorunlu; uygulama sunucusu klasörü |
| `EXIT_CLASS` | Başlangıçta boş |

**`ZCHE_TCMB_MAP`: örnek eşleme**

| `PROFILE` | `RATE_TYPE` | `SOURCE` |
|---|---|---|
| `DEMO` | `M` | `FX_BUY` |

Bu yalnızca örnektir, muhasebe önerisi değildir. Profil/kur tipi başına tek TCMB alanı eşlenir; aynı alan birden fazla kur tipinde kullanılabilir.

**`ZCHE_TCMB_CURR`: ilk çalıştırmayı sınırlandırın**

| `PROFILE` | `TCMB_CODE` | `SAP_CURRENCY` | `EXCLUDE` |
|---|---|---|---|
| `DEMO` | `USD` | boş | boş |
| `DEMO` | `JPY` | boş | boş |

Önce ilgili TCURF oranlarını hazırlayın. `EXCLUDE` boş satırlar dahil etme listesidir; `X` satırlar dışarıda kalır. Dahil etme satırı yoksa dışlanmamış bütün bülten para birimleri değerlendirilir. `SAP_CURRENCY`, yabancı kodu SAP'deki karşılığına eşler; kuru başka para birimine dönüştürmez.

## Güvenli ilk çalıştırma

1. Test istemcisinde `ZCHE_TCMB_LOAD` programını `DEMO` ile açın. **Test the connection to TCMB**, dosya dahil seçilmiş kaynaktan yakın bir bülteni alır.
2. Bülteni olduğunu bildiğiniz geçmiş bir hafta içi günü seçin; **Test run** işaretli kalsın. Bülten tarihi, `VALID_FROM`, para birimleri, kur tipi, oranlar ve mesajları inceleyin. TCMB'nin 100 birimlik kotasyonunu SAP oranlarıyla karşılaştırmak için JPY'yi dahil edin.
3. Beklenmeyen `ERROR` ve `SKIPPED` sonuçlarını çözün. Beklenen çevrim tutarlarını XML ve SAP ayarlarıyla karşılaştırın.
4. Deneme sisteminde **Test run** işaretini kaldırıp bir kez yazın. OB08 ve SAP para çevrimini kontrol edin. Aynı çalıştırmayı tekrarlayın: eşit kaydedilmiş değerler `UNCHANGED` olmalı.
5. Kabulden ve transporttan sonra SM36 varyantını planlayın. Tarih için güncel tarih seçim değişkeni, yayın sonrası zaman kullanın. Job saat dilimini doğrulayın; SM37, job log'u ve spool'u izleyin.

Cumartesi ve pazar atlanır. HTTP kaynağında bülteni olmayan hafta içi gün `NO_BULLETIN` olabilir; profil uyarı/hata davranışını belirler. Fabrika takvimi indirilecek günleri değil, geçerlilik tarihini değiştirir.

| Tarih kuralı | Anlamı |
|---|---|
| `SAME_DAY` | Bülten tarihi |
| `NEXT_DAY` | Ertesi takvim günü |
| `NEXT_WORKDAY` | Seçilen fabrika takvimindeki sonraki iş günü |

## TCMB alanları

| `SOURCE` | XML değeri |
|---|---|
| `FX_BUY` | `ForexBuying` — döviz alış |
| `FX_SELL` | `ForexSelling` — döviz satış |
| `BN_BUY` | `BanknoteBuying` — efektif alış |
| `BN_SELL` | `BanknoteSelling` — efektif satış |
| `FX_AVG` | Döviz alış/satış ortalaması |
| `BN_AVG` | Efektif alış/satış ortalaması |

Kaynak değeri yoksa `SKIPPED` olur; örneğin XDR satış veya efektif alanları boş olabilir. Ortalama için iki değer gerekir. Sistemde tanımlı kur tiplerini seçin.

## Dosya kaynağı ve sorun giderme

`SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` ve uygulama sunucusundaki `FILE_FOLDER` klasörünü ayarlayın. Seçilecek günün tam XML'ini önceden `GGAAYYYY.xml`, örneğin `30102026.xml`, adıyla yerleştirin. XML tarihi istenen tarihle aynı olmalıdır. İndirme ve dosya tamamlandıktan sonra klasöre taşıma dış sürecin sorumluluğudur; indirici kurulmaz.

**Değişen davranış:** eksik dosya dahil her açma başarısızlığı `ERROR` olur. Eksik dosya, yayımlanmayan bülten ile aktarım/erişim sorununu güvenilir biçimde ayıramaz. Dosyaları hazırlayın, aralığı buna göre seçin. Özel kaynak bültenin olmadığını doğrulayabiliyorsa açıkça `NO_BULLETIN` üretebilir.

| Belirti | Kontrol |
|---|---|
| TLS/SSL hatası | Basis: gerçek sertifika zinciri, STRUST PSE, SM59 SSL ve proxy |
| Bağlantı hatası | Ağ ekibi: uygulama sunucusunun yönlendirme, firewall ve proxy ayarları |
| HTTP hedefi hatası | Basis: hedef sunucu, SSL ve yol |
| Dosya hatası | Dosya varlığı/içeriği, işletim sistemi ve SAP dosya yetkileri |
| TCURF hatası | FI ekibi: OBBS'de çift, kur tipi, oran ve geçerlilik tarihi |

## Hatalar, kısmi yazma ve yeniden çalıştırma

**Tarih aralığı tek bir atomik işlem değildir.** Sonraki satır/gün hata verdiğinde önceki başarılı kayıtlar commit edilmiş olabilir. Başarısız/Cancelled job bunları geri almaz. Yeniden denemeden önce sonuç, spool ve OB08'i inceleyin. Kaynak/ayrıştırma gibi durdurucu hatalarda sonraki tarihler işlenmez; önceki sonuçlar ve hata satırı korunur.

Nedeni düzeltip etkilenen aralığı test modunda çalıştırın. Eşit kayıtlar `UNCHANGED` olur. `EXISTING_RATE = S`, farklı mevcut kayıtları `SKIPPED` olarak korur; `U` veya boş değiştirmeye izin verir. Yalnızca üzerine yazmak istiyorsanız `U` kullanın. Commit hatasında önce kaydedilmiş kurlarla mutabakat yapın. Genel kurtarma yöntemi olarak kur silmeyin.

Commit hatasında yeniden çalıştırmadan veya bir güncelleme isteğini tekrar işlemeden önce Basis ekibinden **SM13** üzerindeki başarısız/bekleyen güncellemeleri incelemesini isteyin.

## Mimari ve genişletme

| Nesne | Görevi |
|---|---|
| `ZCHE_TCMB_LOAD` | Seçim, sonuçlar, job sonucu |
| `ZCL_CHE_TCMB_LOADER` | Profil, tarih ve akış |
| `ZCL_CHE_TCMB_RUNNER` | Tarih aralığı ve durdurucu hata sonrasında sonuçları koruma |
| `ZCL_CHE_TCMB_SOURCE_HTTP`, `_FILE` | Bülten alma |
| `ZCL_CHE_TCMB_PARSER` | XML ayrıştırma/doğrulama |
| `ZCL_CHE_TCMB_DATE_RULE` | Geçerlilik tarihi |
| `ZCL_CHE_TCMB_CALC` | Veritabanına erişmeden hesaplama |
| `ZCL_CHE_TCMB_WRITER` | TCURR karşılaştırması ve BAPI ile yazma |
| `ZCL_CHE_TCMB_RATE_STORE` | Yazıcının kullandığı SAP kalıcılık adaptörü |

Özel kaynaklar `ZIF_CHE_TCMB_SOURCE`, exit'ler `ZIF_CHE_TCMB_EXIT` arayüzünü uygular. `BEFORE_WRITE` satırları değiştirebilir; `AFTER_WRITE` sonuçları ve test bayrağını alır. `BEFORE_WRITE` test bayrağı almaz; yalnızca verilen satırları değiştirmelidir. `AFTER_WRITE`, `iv_test` alır ve test modunda yazma/dış yan etkileri engellemelidir. Uzantıları SAP'te doğrulayın.

## Doğrulama ve katkı

Node.js 22+ ve Git ile:

```sh
npm ci --ignore-scripts
npm run lint
npm run test:logic
```

`npm run lint:740` ve `npm run lint:758` hedefleri ayrı çalıştırır. SAP tanımları sabit `abaplint/deps` revizyonuyla yok sayılan `.abaplint-deps/` içine alınır; npm sürümü kilitlidir. GitHub Actions aynı kontrolleri çalıştırır. Eksik bağımlılık tanımları; SAP aktivasyonu, ATC, ABAP Unit ve entegrasyon testlerinin yerine geçmez.

`test:logic`, hesaplayıcı, çalıştırıcı ve yazıcının seçilmiş testlerini basitleştirilmiş DDIC tanımları ve sahte kalıcılık katmanıyla JavaScript'e çevirir. Çevirici/çalışma zamanı ve `open-abap-core` revizyonu sabittir. SAP aktivasyonu, gerçek BAPI/veritabanı/commit, yetki, fabrika takvimi, girdi entegrasyonu ve SAP ondalık/taşma davranışlarını doğrulamaz.

**Geçmiş kanıt:** 1 Kasım 2026'da dışa aktarılan önceki revizyonda ABAP Platform 2023 üzerinde 26 testin geçtiği; USD/EUR/JPY yazma ve geri okuma, ters kotasyon, dosya ve job testlerinin yapıldığı raporlandı. Bu sonuçlar **sonraki değişiklikleri doğrulamaz**. Boş kurulum, kısıtlı kullanıcı, SM59, bakım ekranı üretimi ve eski sürümler kabul testi bekliyor.

[CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) ve yayımlanmamış [SAP Community yazar taslağına](docs/sap-community-draft.md) bakın.

## Lisans

MIT. Bkz. [LICENSE](LICENSE). Copyright (c) 2026 Ali Emre Altuntaş.
