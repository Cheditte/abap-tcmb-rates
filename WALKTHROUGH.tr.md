# Kurulumdan günlük kullanıma

> [English](WALKTHROUGH.md) | **Türkçe** · [Proje özeti](README.tr.md) · [Alanların açıklaması](SCREENS.tr.md)

## Önce hedefinizi seçin

Program TCMB bültenini okur, seçtiğiniz kurları SAP kayıtlarıyla karşılaştırır. **Deneme işaretliyse yalnız sonucu gösterir; işareti kaldırırsanız kur yazabilir.** OB08, kaydı kontrol edeceğiniz SAP ekranıdır.

![Ön izleme, gerçek kayıt ve günlük otomasyon](docs/images/goals-tr.svg)

| Hedef | Yol | Kontrol noktası |
|---|---|---|
| Programı kurmak | [Kurulum](#kurulum) | Kaynak aktif; seçim ekranı açılıyor. |
| Kaydetmeden görmek | [Yol A](#onizleme) | Deneme işaretli; kur ve durumlar listede. |
| OB08'e kur yazmak | [Yol B](#ilk-kayit) | Sonuç ile OB08'de aynı anahtar ve tarih eşleşiyor. |
| Her gün çalıştırmak | [Yol C](#gunluk-kullanim) | Dinamik tarihli varyant, job ve izleme hazır. |

Doğrulanmış ortamlar ve bekleyen kontroller [tek tabloda](docs/validation.md) yer alır. İlk kurulum ve kayıt denemesini DEV/test ortamında yapın.

<a id="hazirlik"></a>
## Başlamadan önce üç hazırlık

![SAP erişimi, kur kararları ve bağlantı](docs/images/prepare-tr.svg)

1. **SAP erişimi:** SE38'de program oluşturup etkinleştirebilen bir SAP geliştiricisi olun. Taşımak için kendi Z/Y paketinizi ve Workbench alt görevinizi hazırlayın. `$TMP` yalnız yerel deneme içindir, transport edilemez.
2. **Kur kararları:** para birimleri, SAP kur tipleri ve geçerlilik tarihi belirlenmeli. OBBS'de dönüşüm oranlarını kontrol edin. Örnek `M` değerinin kurumunuz için doğru olduğunu varsaymayın.
3. **Sunucu bağlantısı:** SAP uygulama sunucusu `www.tcmb.gov.tr:443` adresine erişmeli; STRUST'ta kullanılan SSL istemcisinin sertifika güveni hazır olmalı. Bilgisayarınızdan tarayıcıyla erişebilmeniz tek başına yeterli değildir. Sunucuya yardımcı yazılım kurmayacağız.

Yetki sizdeyse bağlantıyı kendiniz hazırlayın; değilse Basis/ağ ekibine yukarıdaki adresi ve SAP sunucusundan HTTPS gereksinimini iletin. Kurumunuz proxy veya iç ayna kullanıyorsa [SM59 yolunu](#kaynak-secimi) izleyin.

<a id="kurulum"></a>
## Kurulum — bir kez yapın

1. [Tek kaynak dosyayı](src/zche_tcmb_load.prog.abap) açın. **Copy raw file** ile bütün kodu kopyalayın veya **Download raw file** ile `.abap` dosyasını indirin. GitHub sayfasının HTML dosyasını yüklemeyin.
2. **SE38**'de `ZCHE_TCMB_LOAD` oluşturun. Tip **Executable program / Çalıştırılabilir program** olsun. Kendi paketinize ve uygun Workbench alt görevinize kaydedin.
3. Başlangıç kodunun tamamını dosyadaki kaynakla değiştirin. Dosyadan yüklemek için **Utilities → More Utilities → Upload/Download → Upload** menüsünü kullanabilirsiniz.
4. Program özelliklerinde **Fixed point arithmetic / Sabit nokta aritmetiği** açık olsun. Sözdizimini kontrol edip **Ctrl+F3** ile etkinleştirin.
5. **Program → Execute → Unit Tests** üzerinden **55 gömülü testi** çalıştırın. Başarısız test varsa gerçek kayda geçmeden çözün.
6. F8 ile seçim ekranını açın. **Dil / Language** alanından Türkçe veya English seçin; SAP menüleri oturum dilinde kalabilir.

**Uzun satır hatası:** editördeki **Downwards-compatible line length (72)** veya **Force Line Length 72** kısıtını kapatıp tam dosyayı yeniden yükleyin. Satırları kesmeyin.

Eski sürümünüz varsa önce özel kod ve varyantlarınızı koruyun; [geçiş adımlarını](TECHNICAL.tr.md#eski-surumden-gecis) okuyun. abapGit kullanıyorsanız depoyu kendi paketinize alıp Pull/aktivasyon yapabilirsiniz; ayrıca SE38 yüklemesi gerekmez.

<a id="onizleme"></a>
## Yol A — Kurları kaydetmeden görmek

![Ön izleme yolu](docs/images/preview-path-tr.svg)

### A1. Küçük bir seçim hazırlayın

SE38'den programı çalıştırın. Aşağıdaki tarih bir örnektir; siz erişilebilir bir bülten günü seçin.

| Alan | İlk denemede |
|---|---|
| Dil | Türkçe |
| Bülten tarih(ler)i | `30.10.2026`; bitiş boş |
| Deneme (kur kaydedilmez) | **İşaretli** |
| Döviz alış | Sisteminizde uygun kur tipi; örnekte `M` |
| Diğer beş kur alanı | Boş |
| Tarih kuralı | Bülten ile aynı gün; fabrika takvimi boş |
| TCMB döviz kodları | `USD` |
| Farklı SAP kodu / Ters yönü de yaz | Boş / işaretsiz |
| Mevcut farklı kur | **Olduğu gibi bırak** |
| Bülten olmayan iş günü | Yalnızca listede göster |
| Kaynak | TCMB'den HTTPS ile; diğer alanlar boş |

**Kur tutarı yazmıyorsunuz:** Döviz alış yanındaki `M`, SAP kur tipidir. Tutar TCMB'den gelir. Bütün kurlar TRY karşılığındadır. [Her alanın açıklaması](SCREENS.tr.md).

![Türkçe seçim ekranı; alan grupları aşağıda açıklanır](docs/images/sap-selection-tr.png)

### A2. Bağlantıyı sınayın

**TCMB bağlantısını test et** düğmesine basın. Başarı mesajını okuyup yeşil onayla kapatın. Düğme son yedi gün içinde erişilebilir bülteni arar; seçtiğiniz tarihi kullanmaz. Mesajdaki para birimi sayısı kayıt sayısı değildir.

![Bağlantı testinin başarı mesajı](docs/images/sap-tr-connection-success.png)

### A3. F8 ile sonucu alın

**Deneme işaretli kalsın.** F8'e basın; kur tipi, tarih, para çifti, tutar ve oranları inceleyin.

![Örnek: 27 Ekim için Türkçe deneme sonucu, aynı kayıt mevcut](docs/images/result-preview.png)

Bu sonuç görseli 27.10.2026 tarihli ayrı bir örnektir. Sizin listeniz seçtiğiniz günü gösterir.

| Durum | Denemede anlamı |
|---|---|
| `NEW` | Eksik kayıt; gerçek çalıştırmada eklenmesi planlanıyor. |
| `UPDATED` | Mevcut farklı değerin güncellenmesi planlanıyor. |
| `UNCHANGED` | Aynı kayıt var; yeniden yazılması gerekmiyor. |
| `SKIPPED` | Satır atlandı; Açıklama sütununu okuyun. |
| `NO_BULLETIN` | O günün bülteni bulunamadı. |
| `ERROR` | Hata var; çözmeden gerçek kayda geçmeyin. |

Tek günlük sonucu doğruladıktan sonra tarih aralığına veya başka dövizlere geçin. Çoklu seçim düğmesindeki **Select Single Values** sekmesine her kodu ayrı satırda yazın; boş seçim bütün kodları değerlendirir. Hafta sonları atlanır; ilk/son gün aralığa dahildir.

<a id="ilk-kayit"></a>
## Yol B — OB08'e kayıt eklemek veya güncellemek

![Kayıt ve doğrulama yolu](docs/images/write-path-tr.svg)

### B1. Mevcut kayıt davranışını seçin

| İstediğiniz sonuç | Seçim |
|---|---|
| Eksikleri ekle; mevcut farklı kurları koru | **Olduğu gibi bırak** |
| Eksikleri ekle; mevcut farklı kurları TCMB değeriyle değiştir | **Güncelle** |

Eşit değer her iki durumda da `UNCHANGED` olur. **Olduğu gibi bırak yazmayı kapatmaz**; yazmayı kapatan Deneme kutusudur.

### B2. Önce kontrol edin, sonra yazın

1. Yol A ile hatasız ön izleme alın. Kaydedilecek tarih, kur tipi ve para çiftini not edin.
2. OB08'de aynı anahtarı kontrol edin; ardından **OB08 bakım işleminden çıkın**. Başka oturumda açık bırakmak kilidi kaldırmaz.
3. Programa dönün. Seçimleri son kez kontrol edip **Deneme işaretini kaldırın**.
4. F8'e basın. Gerçek yazma başlar; ayrı bir Kaydet veya onay düğmesi beklemeyin.
5. Sonuçları okuyun. Gerçek çalıştırmada `NEW` ve `UPDATED`, başarılı yeni/güncellenen satırları gösterir. Hata varsa başarılı diğer satırlar otomatik geri alınmaz.

### B3. OB08'de doğrulayın

Program bittikten sonra OB08'i açın. Aynı sistem/istemcide **kur tipi + kaynak para birimi + hedef para birimi + geçerlilik tarihi** ile kaydı bulun; gerekirse **Position / Konumlandır** kullanın. Kur, oran ve kotasyonu sonuçla karşılaştırın. OB08'de ayrıca Kaydet'e basmanız gerekmez.

![OB08'de örnek EUR TRY kayıtları](docs/images/sap-ob08-eur-july.png)

Kontrol bitince OB08 bakımından çıkın. Programda Deneme'yi tekrar işaretleyip aynı seçimi çalıştırın; eşit kayıtlarda `UNCHANGED` beklenir. JPY veya ters kotasyonda standart SAP para çevrimiyle beklenen tutarı da doğrulayın.

<a id="gunluk-kullanim"></a>
## Yol C — Her gün otomatik çalıştırmak

**Akış:** seçimler → varyant → SM36 iş tanımı → SM37 log ve spool. Varyant ayarları saklar; job aynı programı bu ayarlarla çalıştırır. Önce kur yazmayan bir job ile sınayın.

### C1. Deneme varyantı oluşturun

1. Seçim ekranında dil, kur tipi ve dövizleri doldurun; **Deneme işaretli** olsun.
2. **Ctrl+S / Varyant olarak kaydet** ile kullanılmayan bir ad verin; örneğin `TCMB_PUB_TEST`. Açıklama yazın. Mevcut bir varyantın üzerine yazmayın.

![Varyant öznitelikleri](docs/images/sap-live-05-variant-attributes.png)

### C2. Tarihi dinamik yapın

1. Varyant özniteliklerinde **Fields of Selection Screen / Seçim ekranı alanları** tablosuna gelin.
2. Tarih satırını bulun. Ekran açıklaması görünüyorsa **Technical name / Teknik ad** ile `S_DATE` olduğunu kontrol edin.
3. Bu satırın **Type of Variable / Değişken türü** sütununa **D — Dynamic date calculation / Dinamik tarih hesabı** girin veya F4 listesinden seçin.
4. Aynı satırdaki değişken adı/seçenek hücresinde F4'e basın. **Current date / Güncel tarih** seçin; sabit tarih aralığını taşımayın.
5. Kaydedin. Varyantı tekrar çağırın: tarih bugüne hesaplanmalı, bitiş boş olmalı, Deneme işaretli kalmalı.

![Dinamik tarih türü D](docs/images/sap-dynamic-type.png)

![Current Date seçimi](docs/images/sap-dynamic-current-date.png)

![Varyant tekrar çağrıldığında güncel tarih ve Deneme seçimi](docs/images/sap-dynamic-loaded.png)

`DEFAULT sy-datum` tek başına günlük değişim sağlamaz; sabit tarih varyanta kaydedilebilir. Dinamik değişken her çalıştırmada yeniden hesaplanır. Menü/sütun adları SAP sürümü ve oturum diline göre değişebilir.

### C3. SM36'da program ve varyantı seçin

1. **/nSM36** açın. Örneğin `ZTCMB_PUB_DYNAMIC_TEST` gibi ayırt edici bir Job Name girin. Normal iş için **Job Class C** kullanın; kurumunuzun sunucu/sınıf kuralı varsa onu izleyin.
2. **Step / Adım** → **ABAP program** seçin. Program `ZCHE_TCMB_LOAD`, Variant alanı kaydettiğiniz varyantın adı olsun.
3. Çalışma kullanıcısının yetkilerini kontrol edin. Türkçe çıktı için varyantta açıkça **Türkçe** seçimini saklayın.
4. Disk simgesiyle adımı kaydedip F3 ile ana ekrana dönün; **1 Step(s) defined** görünmeli.

![Program ve varyantla job adımı](docs/images/sap-live-08-sm36-step.png)

### C4. İlk işi bir kez çalıştırın

**Start condition → Immediate** seçin; **Periodic Job işaretsiz** kalsın. Önce başlangıç penceresini, sonra ana işi kaydedin. Alt mesajda **Released** görmelisiniz.

![Tek seferlik başlangıç](docs/images/sap-live-10-sm36-immediate.png)

### C5. SM37'de sonucu izleyin

1. **/nSM37** açın. Kendi iş adınızı, ilgili kullanıcıyı ve çalışma gününü seçip F8'e basın. Released/Ready/Active/Finished/Canceled durumlarını dahil edin; iş yoksa Scheduled durumunu da arayın.
2. **Refresh** ile yenileyin. **Finished** görüldüğünde satırı seçip **Job log** açın; Deneme özeti ve hata sayısını okuyun.
3. Geri dönüp **Spool** açın; listede satırı seçip **Display contents / İçeriği göster** ile sonuç satırlarını okuyun. Yazdırmanız gerekmez.

![SM37'de tamamlanan iş](docs/images/sap-live-14-sm37-finished.png)

![Türkçe job özeti](docs/images/sap-live-15-sm37-job-log.png)

![Dinamik tarihle çalışan deneme job sonucunda 2 Kasım USD/TRY satırı](docs/images/sap-dynamic-spool.png)

**Finished, kur yazıldığı anlamına gelmez.** Deneme job'ı kurları yalnız karşılaştırır. Gerçek yazmayı OB08 ile doğrulayın.

### C6. Günlük gerçek işe geçin

Yol B kontrolünden sonra ayrı bir günlük varyant oluşturun. Dinamik güncel tarihi koruyun; **Deneme işaretini kaldırıp** uygun Keep/Update kararını kaydedin. SM36'da ayrı iş adıyla:

1. **Start condition → Date/Time:** ilk çalışma tarihini ve saatini girin.
2. **Periodic Job → Period values → Daily:** günlük tekrarı seçin.
3. Başlangıç koşulunu ve ana işi kaydedin; SM37'de Released durumunu kontrol edin.

Saati TCMB bülteninin yayımlanmasından sonraya planlayın; **SAP/job saat dilimini** doğrulayın. Hedef sistemde varyantı, bağlantıyı ve çalışma kullanıcısını ayrıca hazırlayın. İlk günlük işleri log/spool ve OB08 üzerinden izleyin.

<a id="yetkiler"></a>
## Kim hangi yetkiye ihtiyaç duyar?

| İşlem | Gerekli hazırlık |
|---|---|
| Programı kurmak | SE38 geliştirme/etkinleştirme; paket ve transport yetkileri. |
| Deneme | Programı çalıştırma, standart kur/tanım verilerini okuma ve seçilen kaynağa erişim. Kur yazma ön kontrolü testte yapılmaz. |
| Gerçek kayıt | `V_TCURR` değiştirme; genellikle `S_TABU_DIS`, yetki grubu `FB32`, `ACTVT=02`. TDDAT ve kurumunuzun rol tasarımı belirleyicidir. |
| Sunucudan dosya okumak | `S_DATASET` READ, program ve gerçek dosya yolu; ayrıca işletim sistemi okuma izni. |
| Job kurmak/çalıştırmak | İlgili `S_BTCH_JOB` işlemleri; başka kullanıcı adına iş kurmada uygun `S_BTCH_NAM`. Çalışma kullanıcısı da kaynağa/yazmaya yetkili olmalı. |

Basis/yetki ekibine program adını, okunacak sunucu klasörünü, `V_TCURR` değiştirme gereksinimini ve job çalışma kullanıcısını iletin; genel SAP_ALL istemeyin. Program gerçek yazmadan önce bir kez kontrol eder. **BAPI zaten kendi yetki kontrolünü yapar**; yeni ön kontrol yetkisiz çalışmayı her satırda hata üretmeden durdurur.

<a id="kaynak-secimi"></a>
## TCMB, SM59 veya dosya kaynağı

Normal HTTPS kullanımında **SM59 hedefi ve TCMB temel adresi boş** kalır; varsayılan adres `https://www.tcmb.gov.tr/kurlar` olur. Temel adres doldurulursa yalnız `https://www.tcmb.gov.tr` ve bu sunucunun alt yolları kabul edilir. Boşluk, `@`, sorgu/fragment ve farklı sunucu reddedilir; sondaki `/` temizlenir.

İç ayna veya proxy gerekiyorsa Basis'in yönettiği **SM59 tip G** hedefini kullanın. HTTPS/sertifika/proxy ayarını orada yapın; program hedefe `/kurlar/YYYYMM/GGAAYYYY.xml` yolunu gönderir. Ayna aynı yolu ve tam TCMB XML biçimini sunmalı. `P_URL` yerine gerçek **hedef adını** girin.

<a id="dosyadan-okuma"></a>
### SAP sunucusundaki XML dosyalarını okumak

1. Yetkiniz varsa kurumunuzun izin verdiği RDP/SSH veya dosya aktarımıyla **SAP uygulama sunucusuna** erişin; değilse sunucu sorumlusundan yardım alın.
2. Tam günlük XML'i `GGAAYYYY.xml` adıyla hazırlayın. Örnek: 30.10.2026 → `30102026.xml`. Dosyanın içindeki tarih de aynı gün olmalı.
3. **Sunucudaki bir klasörden** seçin; XML klasörü alanına gerçek sunucu yolunu yazın. Kendi bilgisayarınızın İndirilenler klasörü değildir. Yolda `..` kullanmayın; klasör adının içindeki boşluklar korunur.
4. SAP ve işletim sistemi okuma izinlerini kontrol edip ilgili günle Deneme çalıştırın. Birden fazla uygulama sunucusu varsa job'ın aynı klasöre erişebildiğini doğrulayın.

İndirme/klasöre koyma işlemi projeye dahil değildir. Eksik veya okunamayan dosya `ERROR` olur; tatil sayılmaz ve kaynak otomatik değiştirilmez.

<a id="kilit-ve-kismi-kayit"></a>
## Bazı satırlar hata verirse

1. Sonuç/spool ve hata mesajlarını saklayın. Tarih aralığı satır satır kaydedilir; önceki başarılı kayıtlar geri alınmaz.
2. OB08'de etkilenen anahtarları kontrol edin; sonra bakım işleminden çıkın. Açık bakım ekranları kilit oluşturabilir.
3. Kilit sürüyorsa sahibi/ilgili yönetici SM12'de nesneyi ve sahibini incelesin. Aktif kilidi genel çözüm olarak silmeyin.
4. Nedeni giderdikten sonra yalnız etkilenen tarih/dövizleri **Deneme + Olduğu gibi bırak** ile değerlendirin; eksikleri Yol B ile tamamlayın.
5. Commit hatasında tekrar denemeden önce OB08 ve SM13'le mutabakat yapın.

SSL hatasında STRUST ve sunucu ağ erişimine; oran hatasında OBBS'ye; yapılandırma hatasında [alan rehberine](SCREENS.tr.md) bakın. [Teknik hata davranışı](TECHNICAL.tr.md#hatalar-ve-yeniden-deneme).
