# Teknik başvuru

> [English](TECHNICAL.md) | **Türkçe** · [README](README.tr.md) · [Kurulum ve kullanım](WALKTHROUGH.tr.md)

Alan ayrıntıları, sınıf kullanımı, genişletme noktaları ve operasyon davranışı bu dosyada tutulur. İlk kurulum için kullanım rehberinden başlayın.

## Ne yapar?

`ZCHE_TCMB_LOAD`, pazartesi–cuma bültenlerini HTTPS veya uygulama sunucusundaki klasörden alır. TCMB alanlarını SAP kur tipleriyle eşler, TCURF oranlarıyla hesaplar, TCURR ile karşılaştırır ve BAPI ile yazar. Sonuçlar açıklamalarıyla birlikte `NEW`, `UPDATED`, `UNCHANGED`, `SKIPPED`, `NO_BULLETIN` veya `ERROR` olur.

**Test run varsayılan olarak işaretlidir.** Bülteni alır, hesaplar ve karşılaştırır; yazma BAPI'sini çağırmaz. Yazma yetkisi, kilit davranışı ve commit başarısını kanıtlamaz. Özel exit'ler yine çalışır ve test moduna uymalıdır.

Kurların karşılığı **TRY**'dir. `TARGET_CURRENCY` boş veya `TRY` olmalıdır; çapraz kur hesaplanmaz. İstenirse `TRY → döviz` yönü ters kotasyonla eklenir.

## Destek ve gereksinimler

| Konu | Mevcut durum |
|---|---|
| Dil | On-premise/private sistemler için standart ABAP; **ABAP Cloud uygulaması değildir**. |
| Statik hedefler | abaplint ile 7.40 SP08 ve 7.58 kontrol edilir; çalışma zamanı garantisi değildir. |
| Çalışma zamanı kanıtı | Ayrı test adlarıyla temiz kurulum tamamlandı; son ayar ekranı kabulü kısmi. [Test kaydı](docs/validation-2026-11-02.md). |
| Kurulum | Tek dosyalı SE38 installer ve basit ayar programı; abapGit isteğe bağlıdır. Hazır SM30 ekranı veya profil verisi yok. |
| Bağlantı | SAP uygulama sunucusundan `www.tcmb.gov.tr:443` erişimi veya hazırlanmış dosyalar. Gerçek sertifika zinciri ve STRUST PSE'sini Basis doğrulamalı. |
| SAP ayarları | Para birimleri, kur tipleri, OBBS'de TCURF oranları; `NEXT_WORKDAY` için fabrika takvimi. |
| Yetkiler | Kurulumda geliştirme/içe aktarma ve profil bakımı; çalışma kullanıcısının BAPI, tablo ve dosya yetkileri ayrıca test edilmeli. |

Kaynak alanı, SAP kur tipi, geçerlilik ve üzerine yazma kuralını muhasebe belirlemelidir. Proje mevzuata göre muhasebe veya vergi uygulaması seçmez.

## Tek dosyalı kurulum ve ayar programı

`installer/zche_tcmb_install.prog.abap`, `src/` ve `installer/template.abap` dosyalarından `npm run build:installer` ile üretilir. 7.40 SP08 sözdizimi hedefi korunur. abapGit veya GitHub bağlantısına ihtiyaç duymadan gömülü metaveriyi, sınıf/arayüz kaynaklarını ve ABAP Unit include'larını kurar. Paket oluşturmaz; mevcut Z/Y paketini ve kullanıcının değiştirilebilir Workbench task'ını ister. `$TMP` için task boş olmalıdır.

Ön kontrol mevcut nesneleri hem TADIR hem yerel kataloglarda arar. Mevcut aktif/pasif nesneler engeldir; DDIC şeması güncellenmez. Gerçek kurulumda CTS kayıtları, DDIC oluşturma/aktivasyon, OO kaynak kaydı ve toplu aktivasyon yapılır. DDIC aktivasyon dönüş kodları kontrol edilir. Dinamik `CL_OO_FACTORY` kaynak API'si, bulunmadığı durumda klasik `CL_OO_SOURCE` yolu kullanılır. SAP'nin iç repository API'leri sürüme göre değişebilir; yerel lint bunları doğrulamaz. Ayrı test adlarıyla temiz kurulum tamamlandı; son profil kaydı ve transport kabulü test kaydında açık kalan maddelerdir. Yarıda kalmış kurulum otomatik geri alınmaz veya devam ettirilmez.

`ZCHE_TCMB_CONFIG` tek eşleme ve açık para birimi listesi için sade editördür. Üç tablo aynı LUW içinde kaydedilir; hata halinde rollback ve profil kilidi temizliği yapılır. S_TABU_NAM, SCC4 ve CTS kontrolleri uygulanır. Mevcut profil önce yüklenmelidir; son okunan profil/eşleme/para birimleri değişmişse kayıt reddedilir. İleri profil yapıları sessizce daraltılmaz. Transport anahtarları istemci + 20 karakter profil anahtarıyla sınırlandırılır; MAP/CURR alt satırları için generic son ek kullanılır. SAP kabulünde silinen satırların hedefteki etkisini de doğrulayın. Doğrudan SQL bakımının tablo loglaması/ortamınızdaki izleme gereksinimlerini ayrıca değerlendirin.

İstemci kontrolü CCCORACTIV değerlerini kullanır: boş = elle kayıt, 1 = otomatik kayıt, 2 = değişiklik yasak, 3 = yalnız yerel değişiklik. Yerel kayıtta task boş ve durum boş/3 olmalıdır; transportlu kayıtta task gerekir ve durum boş/1 olmalıdır. Bilinmeyen durumlar reddedilir. SCC4 ayarı değiştirilmez.

<a id="advanced-profile-maintenance"></a>

Tarih kuralı alanı CHAR12'dir. `NEXT_WORKDAY`, klasik DD07V sabit değer anahtarına sığmadığından domain'de kesilmiş sabit değerler tutulmaz. Basit ayar ekranı F4 seçenekleri ve uygulama doğrulaması sağlar. İleri bakımda tam kural adını yazın; `NEXT_WORKD` geçersizdir.

## İleri profil bakımı

Birden fazla kur tipi eşlemesi, dışlama, farklı SAP para birimi kodu veya özel kaynak için üç tabloyu SM30 ile yönetin. Bu **isteğe bağlı** yolun ekranları depoda yoktur. DEV'de SE11 → Utilities → Table Maintenance Generator (veya SE54 → Generated Objects → Create/Change) ile her tablo için uygun yetki grubu, müşteri fonksiyon grubu, tek adımlı ekran ve standart kayıt rutinini seçip üretin. Örnek fonksiyon grupları `ZCHE_TCMB_PROF_M`, `ZCHE_TCMB_MAP_M`, `ZCHE_TCMB_CURR_M`'dir; adları kurumunuza göre seçin. Ayrı gruplarda ekran 0001 olabilir. Bakım engelliyse SE11 bakım ayarını inceleyin. Nesne/ayarları normal transportla taşıyın; canlıda ekran üretmeyin. Bu üretim yolu henüz SAP'de doğrulanmadı. Basit kullanım için bunları yapmanız gerekmez.

## Profil ayarları

Üç tablo istemciye bağlıdır. Aşağıdaki değerler örnektir; hazır profil verisi sağlanmaz. İlk kurulum ve basit ayar ekranı için [kullanım rehberine](WALKTHROUGH.tr.md) bakın.

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

## Tarih kuralları

| Kural | Geçerlilik tarihi |
|---|---|
| `SAME_DAY` | Bülten tarihi. |
| `NEXT_DAY` | Ertesi takvim günü. |
| `NEXT_WORKDAY` | Seçilen fabrika takvimindeki sonraki iş günü; SCAL takvimi gerekir. |

Program cumartesi/pazarı indirmez. Fabrika takvimi indirilecek günleri değil, geçerlilik tarihini değiştirir. Raporun `P_RULE` alanı doluysa profilin tarih kuralını bu çalıştırma için geçersiz kılar.

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

## Kendi ABAP kodunuzdan çağırma

Aşağıdaki örnek, önceden oluşturduğunuz DEMO profilini kullanır; ayar oluşturmaz. Raporla aynı yükleme akışını **test modunda** çağırır. Tarihi, bülteni bulunan bir günle değiştirin.

```abap
TRY.
    DATA(lo_loader) = NEW zcl_che_tcmb_loader( iv_profile = 'DEMO' ).
    DATA(lt_results) = lo_loader->run(
      iv_from = '20261030'
      iv_to   = '20261030'
      iv_test = abap_true ).
    " Inspect every result STATUS and MESSAGE before using the results.
  CATCH zcx_che_tcmb INTO DATA(lx_error).
    DATA(lv_error) = lx_error->get_text( ).
    " Handle the configuration or loading error in your application.
ENDTRY.
```

Bu kod raporunuzun yürütme bloğu veya bir metodu içindir. `iv_test = abap_false` gerçek yazmayı ve commit işlemini etkinleştirir. `run` içindeki hata satırları her zaman exception olarak dışarı çıkmaz; `lt_results` içindeki `ERROR`, `SKIPPED` ve `NO_BULLETIN` sonuçlarını ayrıca değerlendirin. Alt katmanın commit yaptığı bu akışı, başka iş kayıtlarının tek transaction olarak tamamlanmasını beklediğiniz bir LUW içine eklemeyin.

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
npm run build:installer
npm run check:installer
npm run lint
npm run test:logic
```

`npm run lint:740` ve `npm run lint:758` hedefleri ayrı çalıştırır. SAP tanımları sabit `abaplint/deps` revizyonuyla yok sayılan `.abaplint-deps/` içine alınır; npm sürümü kilitlidir. GitHub Actions aynı kontrolleri çalıştırır. Eksik bağımlılık tanımları; SAP aktivasyonu, ATC, ABAP Unit ve entegrasyon testlerinin yerine geçmez.

`test:logic`, hesaplayıcı, ayar doğrulayıcısı, çalıştırıcı ve yazıcının seçilmiş testlerini basitleştirilmiş DDIC tanımları ve sahte kalıcılık katmanıyla JavaScript'e çevirir. Çevirici/çalışma zamanı ve `open-abap-core` revizyonu sabittir. SAP aktivasyonu, gerçek BAPI/veritabanı/commit, yetki, fabrika takvimi, girdi entegrasyonu ve SAP ondalık/taşma davranışlarını doğrulamaz.

**Geçmiş kanıt:** 1 Kasım 2026'da dışa aktarılan önceki revizyonda ABAP Platform 2023 üzerinde 26 testin geçtiği; USD/EUR/JPY yazma ve geri okuma, ters kotasyon, dosya ve job testlerinin yapıldığı raporlandı. Bu sonuçlar **sonraki değişiklikleri doğrulamaz**. Boş kurulum, kısıtlı kullanıcı, SM59, bakım ekranı üretimi ve eski sürümler kabul testi bekliyor.

[CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md) ve yayımlanmamış [SAP Community yazar taslağına](docs/sap-community-draft.md) bakın.

## Lisans

MIT. Bkz. [LICENSE](LICENSE). Copyright (c) 2026 Ali Emre Altuntaş.
