# Kurulumdan ilk kur kaydına

> [English](WALKTHROUGH.md) | **Türkçe** · [Proje özeti](README.tr.md) · [Teknik başvuru](TECHNICAL.tr.md)

## Önce büyük resim

Yapacağımız iş şu: **SAP, TCMB'nin günlük kur bültenini okuyacak; seçtiğiniz kurları önce kaydetmeden gösterecek.** Siz sonucu doğruladıktan sonra SAP'ye kayıt yapabileceksiniz. Sonucu OB08'den, yani SAP'nin döviz kuru bakım işleminden kontrol edeceksiniz.

Bunun için önce projeyi kuracağız, sonra hangi kurları istediğimizi kaydedeceğiz. Sonraki kullanımlarda yalnız yükleme programını çalıştıracağız:

![SE38 yolu: ilk kurulumda ZCHE_TCMB_INSTALL, ayarlar için ZCHE_TCMB_CONFIG, her kullanımda ZCHE_TCMB_LOAD](docs/images/setup-tr.svg)

**Bu rehber kimin için?** SE38'de program oluşturup çalıştırabilen bir ABAP geliştiricisi için. İlk kurulum ve gerçek kayıt denemesini DEV/deneme sisteminde yapın. Proje ön sürümdür: ayrı adlarla kurulum tamamlandı; son ayar kaydı ve uçtan uca kabul kontrolleri bekliyor. [Doğrulama kaydı](docs/validation-2026-11-02.md).

İlerleyeceğimiz sıra: [0 · Hazırlık](#hazirlik) → [1 · Kurulum](#kurulum) → [2 · Profil](#profil) → [3 · Bağlantı ve ön izleme](#onizleme) → [4 · İlk kayıt](#ilk-kayit) → [5 · Günlük kullanım](#gunluk-kullanim).

<a id="hazirlik"></a>

## 0. Başlamadan önce neleri hazırlayacağız?

![Üç hazırlık: SAP geliştirme erişimi, kur seçimleri ve SAP sunucusundan TCMB bağlantısı](docs/images/prepare-tr.svg)

**SAP tarafı:** geliştirme sisteminizde nesne oluşturma ve transport yetkiniz olmalı. Proje için bir müşteri paketi ve kendi transport alt görevinizi hazırlayacağız. Kurulum adımında nasıl seçeceğiniz açıklanıyor.

**Kur seçimleri:** hangi para birimlerini alacağınızı, alış ya da satış kurundan hangisini kullanacağınızı ve kurların hangi tarihten itibaren geçerli olacağını belirleyin. SAP'deki **kur tipi**, kurları kullanım amacına göre ayırır. **OBBS dönüşüm oranları**, SAP'nin kuru kaç birim üzerinden kullandığını belirler; örneğin TCMB, JPY'yi 100 birim üzerinden yayımlayabilir. Para birimi/kur tipi tanımlarını ve ilgili tarihte geçerli oranları doğrulayın; rastgele `1:1` oran girmeyin. FI sürecini siz yönetmiyorsanız bu seçimleri FI sorumlusuyla netleştirin.

**Bağlantı:** SAP uygulama sunucusundan `www.tcmb.gov.tr:443` için HTTPS erişimi ve sertifika güveni gerekir. Normal kullanımda sunucuya RDP/SSH ile bağlanıp ek yazılım kurmayacağız. TCMB kullanıcı adı, şifre veya API anahtarı da gerekmiyor. Bağlantı yetkisi sizdeyse işlemi kendiniz yapabilirsiniz; değilse Basis/ağ sorumlusuyla tamamlayın. Bağlantıyı 3. adımda SAP içinden sınayacağız.

<a id="kurulum"></a>

## 1. Projeyi SAP'ye kurun

Bu adımı **SAP geliştirme sisteminde, SE80/SE09 ve SE38'de** yapacağız. Sonunda ayar ve yükleme programları hazır olacak; henüz profil veya döviz kuru oluşmayacak. abapGit kurmanız veya sınıfları tek tek oluşturmanız gerekmez.

### 1.1. Kendi paketinizi ve alt görevinizi seçin

1. **SE80**'de transport edilebilir bir müşteri paketi oluşturun veya uygun mevcut paketi seçin. `ZCHE_TCMB` yalnız örnek addır; kendi **Z/Y paketinizi** kullanabilirsiniz.
2. **SE09**'da değiştirilebilir bir Workbench request altında **kendi kullanıcınıza ait task'ı** seçin/hazırlayın. Task, ana request'in altındaki görevdir. Installer'a ana request'i değil, bu alt görevin numarasını gireceksiniz.

Yalnız kendi sisteminizde yerel bir deneme yapıyorsanız `$TMP` seçebilirsiniz; bu durumda task boş kalır ve nesneler transport edilemez. Diğer sistemlere taşıyacaksanız müşteri paketiyle ilerleyin. Paket ve görev numaraları size aittir; ekran görüntülerindeki örnekleri kopyalamayın.

### 1.2. Tek dosyayı indirin ve SE38'e yükleyin

1. **[Kurulum dosyasını açıp bilgisayarınıza kaydedin](https://raw.githubusercontent.com/Cheditte/abap-tcmb-rates/main/installer/zche_tcmb_install.prog.abap).** Dosya adı `zche_tcmb_install.prog.abap` olmalı. GitHub'ın HTML sayfasını veya kaynak klasöründen tek bir sınıfı değil, bu dosyanın tamamını kullanın.
2. **SE38**'de `ZCHE_TCMB_INSTALL` adlı **çalıştırılabilir program** oluşturun. Kendi paketinize ve uygun Workbench task'ınıza kaydedin.
3. Kaynak düzenleyicisinde **Utilities → More Utilities → Upload/Download → Upload** yoluyla indirdiğiniz dosyayı seçin. Menü dili değişebilir; alternatif olarak kaynak metninin tamamını yapıştırabilirsiniz.

![SE38 kaynak düzenleyicisinde kurulum dosyasını yüklemek için Upload menüsü](docs/images/sap-upload.png)

4. Kaynağı kaydedin, sözdizimi kontrolünü yapın ve programı etkinleştirin. Bu kurulum programı, projedeki diğer nesneler henüz yokken etkinleştirilebilir.

### 1.3. Önce kurulumun ön kontrolünü yapın

1. `ZCHE_TCMB_INSTALL` programını **F8** ile açın.
2. **Existing target package (`P_PACK`)** alanına 1.1'de seçtiğiniz paketi girin.
3. **Your Workbench task (`P_TASK`)** alanına kendi Workbench alt görevinizi girin. Yalnız `$TMP` denemesinde boş bırakın.
4. **Check only - create nothing (`P_TEST`) işaretli kalsın.** F8'e basın.

![Paket, Workbench alt görevi ve işaretli Check only alanıyla kurulum ön kontrolü](docs/images/sap-installer.png)

**Kontrol noktası:** `READY` satırlarını ve `Preflight passed` sonucunu görmelisiniz. Henüz hiçbir nesne, profil veya kur oluşturulmaz. Bu, gerçek kurulumun tamamlandığı anlamına gelmez.

### 1.4. Nesneleri oluşturun

1. Ön kontrol başarılıysa seçim ekranına dönün.
2. **Kurulumu başlatmak için Check only işaretini kaldırıp F8'e basın.**
3. Sonuçta **`Installation completed`** satırını arayın. `ZCHE_TCMB_CONFIG` ve `ZCHE_TCMB_LOAD` programlarının aktif olduğunu doğrulayın; paket ABAP Unit ve uygun ATC kontrollerini çalıştırın.

![Ayrı test adlarıyla yapılan SAP kurulumunda Installation completed sonucu](docs/images/sap-install-complete.png)

Bu gerçek SAP görüntüsündeki **`ZTS8` adları test kopyasına aittir**. Siz rehberdeki `ZCHE_TCMB_*` adlarıyla devam edin. SAP teması ve menü dili sisteminizde farklı olabilir.

**Mevcut nesne veya yarım kurulum varsa:** installer temiz ilk kurulum içindir; aktif/pasif mevcut nesnenin üzerine yazmaz, güncelleme veya otomatik onarım yapmaz. Yarıda durursa önceki nesneler oluşmuş olabilir. Log, aktivasyon durumları ve transport listesini inceleyin; nesne silerek veya korumayı kaldırarak tekrar denemeyin. [Kurulum davranışı ve kurtarma ayrıntıları](TECHNICAL.tr.md#tek-dosyalı-kurulum-ve-ayar-programı).

<a id="profil"></a>

## 2. Hangi kurları alacağınızı bir profile kaydedin

**SE38 → `ZCHE_TCMB_CONFIG`** programında seçimlerinizi kaydedeceğiz. **Profil**, bu ayar grubunun adıdır; aynı seçimleri her seferinde yeniden girmenizi önler. Bu adım yalnız ayar kaydeder, döviz kuru yazmaz.

### 2.1. Ayar ekranını doldurun

1. **SE38 → `ZCHE_TCMB_CONFIG` → F8** ile ekranı açın.
2. İlk deneme için aşağıdaki alanları doldurun. `DEMO` hazır gelmez; şimdi oluşturacağınız profilin örnek adıdır. `M`, `FX_BUY` ve `SAME_DAY` seçimleri de örnektir; kendi FI sürecinize göre doğrulayın.

| Ekranda göreceğiniz alan | Ne gireceksiniz? |
|---|---|
| Profile name (`P_PROF`) | Örneğin `DEMO`: daha sonra yükleme programında seçeceğiniz ad. |
| Description (`P_DESC`) | Bu profilin ne için olduğunu anlatan kendi açıklamanız. |
| Valid-from date rule (`P_RULE`) | Örnekte `SAME_DAY`: kur, bültenin tarihiyle geçerli olur. |
| SAP rate type (`P_TYPE`) | Örnekte `M`; SAP'de tanımlı ve sürecinize uygun kur tipi. |
| TCMB rate field (`P_SRC`) | Örnekte `FX_BUY`: TCMB döviz alış kuru. |
| Currency codes (`S_CURR`) | Örnekte `USD` ve `JPY`; bir sonraki adımda ayrı satırlara gireceğiz. |
| Existing: S keep/U update (`P_KEEP`) | `S`: aynı tarihte farklı bir kur zaten varsa onu korur. `U` değişikliğe izin verir. |
| No bulletin (I/W/E) (`P_NONE`) | Örnekte `I`: bülten yoksa bilgi olarak bildirir. `W` uyarı, `E` hata davranışıdır. |

3. İlk HTTPS denemesinde fabrika takvimi, ters yön, dosya kaynağı, SM59 hedefi, özel URL, sunucu klasörü ve exit alanlarını boş/işaretsiz bırakın. Kurumunuzda SM59 zorunluysa [3.1'deki bağlantı seçeneğini](#baglanti) uygulayın. Karşılık para birimi `TRY`'dir. [Diğer tarih kuralları](TECHNICAL.tr.md#tarih-kuralları) · [Diğer TCMB alanları](TECHNICAL.tr.md#tcmb-alanları).

Aşağıdaki görüntü **kaydetmeden önce doldurulmuş ekranı** gösterir. Görseldeki transport numarasını kopyalamayın; kendi görevinizi 2.3'te seçeceksiniz. Görüntüden sonra uzun alan etiketleri kısaltıldı; alanlar ve seçimler aynıdır.

![DEMO profilinin örnek seçimlerle doldurulmuş ayar ekranı; henüz kayıt başarısını göstermez](docs/images/sap-settings.png)

### 2.2. Para birimlerini ayrı satırlara girin

1. **Currency codes** alanının sağındaki **çoklu seçim** düğmesine basın.
2. **Select Single Values** sekmesinde `USD` ve `JPY` değerlerini ayrı satırlara yazın. İlk denemede aralık ve dışlama kullanmayın.
3. Seçimleri aktararak ana ekrana dönün.

![Çoklu seçim penceresinde USD ve JPY'nin Select Single Values altında ayrı satırlara girilmesi](docs/images/sap-currencies.png)

### 2.3. Ayarları kaydedin

1. **Your transport task (`P_TASK`)** alanına SE09/SE10'daki **kendi değiştirilebilir Customizing veya Workbench alt görevinizi** girin. Ana request numarası girmeyin. Bu, ayar verilerini taşıma görevidir; kurulumda kullanılan Workbench göreviyle aynı olmak zorunda değildir.
2. **Save settings when executing (`P_SAVE`)** kutusunu işaretleyin ve F8'e basın.
3. **`Settings saved`** sonucunu arayın; ayar anahtarlarının görevinize kaydedildiğini kontrol edin.

Yerel kayda izin veren bir deneme istemcisinde **Local settings, no transport (`P_LOCAL`)** seçilip task boş bırakılabilir. Bu durumda ayarlar taşınmaz. Kayıt için üç ayar tablosunda `S_TABU_NAM` görüntüleme/değiştirme yetkileri gerekir. Kapalı veya bu kayıt türüne izin vermeyen istemcide işlem engellenir; istemci kuralını aşmak için SCC4 değiştirmeyin. [İstemci ve transport kuralları](TECHNICAL.tr.md#tek-dosyalı-kurulum-ve-ayar-programı).

**Kontrol noktası:** profiliniz kayıtlı olmalı; henüz OB08'e kur yazılmadı. Mevcut bir profili yeniden açıyorsanız adını girip **Load existing profile into this screen** düğmesini kullanın. Başkası değiştirdiyse yeniden yükleyin. Birden fazla eşleme, dışlama veya farklı SAP para birimi kodları için [ileri bakım](TECHNICAL.tr.md#advanced-profile-maintenance) gerekir.

<a id="onizleme"></a>

## 3. SAP bağlantısını sınayın ve ilk sonucu kaydetmeden görün

<a id="baglanti"></a>

### 3.1. Yükleme ekranını açıp bağlantıyı deneyin

1. **SE38 → `ZCHE_TCMB_LOAD` → F8** ile ekranı açın.
2. **Rate profile (`P_PROF`)** alanına oluşturduğunuz profil adını girin; örneğimizde `DEMO`.
3. **Test the connection to TCMB** düğmesine basın.

Program yakın tarihteki bir bülteni alıp okuyabilmeli. Düğme **son yedi günde** bülten arar; seçtiğiniz tarih alanını kullanmaz ve döviz kuru kaydetmez.

Varsayılan kaynak **`https://www.tcmb.gov.tr/kurlar`** adresidir. Bu gerçek kaynak adresidir; kendinize ait bir adresle değiştirmeyin. Doğrudan erişim çalışıyorsa profilin bağlantı alanlarını boş bırakabilirsiniz.

<details>
<summary>Bağlantı çalışmıyorsa: doğrudan HTTPS, SM59 veya interneti kapalı SAP</summary>

- **Doğrudan HTTPS:** SAP uygulama sunucusunun dış erişimini ve STRUST'taki SSL client **Anonymous** PSE'sinde gerçek sertifika zincirine güveni kontrol edin. Kendi bilgisayarınızdaki tarayıcı testi yeterli değildir.
- **SM59/proxy gerekiyorsa:** tip **G** HTTP hedefi oluşturun; sunucu `www.tcmb.gov.tr`, port `443`, SSL etkin, path prefix boş olsun. Proxy ve hedefin SSL PSE'sini kurumunuza göre ayarlayın. Ayar programındaki SM59 alanına **sizin oluşturduğunuz hedefin adını** girin; teknik alan adı `RFC_DESTINATION`'dır. Profili yeniden kaydedip bağlantıyı deneyin.
- **Yetki sizde değilse:** Basis/ağ sorumlusuna “SAP uygulama sunucusundan www.tcmb.gov.tr:443 için HTTPS erişimi ve sertifika güveni gerekiyor” bilgisini iletin.
- **SAP internete çıkamıyorsa:** [sunucu dosyasından okuma](#dosyadan-okuma) seçeneğine geçin.

</details>

### 3.2. Tek günü test modunda çalıştırın

1. **Bulletin date(s) (`S_DATE`)** alanına **bülteni yayımlanmış geçmiş bir hafta içi günü** girin. İlk denemede tek gün kullanın. Bugünün bülteni henüz yayımlanmamış olabilir.
2. **Date rule (`P_RULE`)** boş kalsın; profilin tarih kuralı kullanılır.
3. **Test run, write nothing (`P_TEST`) işaretli kalsın.** F8'e basın.
4. Sonuçtaki para birimlerini, kur tipini, bülten tarihini, **`VALID_FROM` geçerlilik tarihini**, oranları ve açıklamaları kontrol edin. TCMB değeriyle SAP kurunu karşılaştırırken birim ve dönüşüm oranlarını dikkate alın.

| Sonuç | Test çalıştırmasında anlamı |
|---|---|
| `NEW` | Gerçek kayıt yapılırsa yeni kur oluşturulacak. |
| `UPDATED` | Gerçek kayıt yapılırsa mevcut kur değiştirilecek. |
| `UNCHANGED` | Aynı anahtar/tarihte eşit kur zaten var. |
| `SKIPPED` | Satır atlandı; nedenini mesajda okuyun. |
| `NO_BULLETIN` | O hafta içi gün için bülten alınamadı; tatil veya henüz yayımlanmamış gün olabilir. Profil bunu hata da sayabilir. |
| `ERROR` | Bir sorun var; mesajdaki nedeni çözün. |

**Kontrol noktası:** sonuçları görebiliyorsunuz; **testte `NEW` görseniz bile OB08'e kayıt yapılmadı.** Bu deneme gerçek yazma yetkisini veya commit başarısını doğrulamaz. Özel exit kullanıyorsanız [test kuralları](TECHNICAL.tr.md#mimari-ve-genişletme) da geçerlidir.

<a id="ilk-kayit"></a>

## 4. Deneme sisteminde ilk gerçek kaydı yapın

1. Beklenmeyen hata/atlamaları çözün. Kur tipi, geçerlilik tarihi ve beklenen para çevrimi tutarını doğrulayın.
2. Aynı tek gün ve az sayıda para birimiyle devam edin. **Kaydetmek istediğinizde Test run işaretini kaldırıp F8'e basın.**
3. Sonuç mesajlarını kontrol edin. Gerçek çalıştırmada `NEW` / `UPDATED`, yazma ve commit başarılıysa kaydın oluştuğunu/değiştiğini bildirir.
4. **OB08**'de aynı kur tipi, para çifti ve geçerlilik tarihindeki kaydı bulun. SAP para çevrimiyle beklenen tutarı da doğrulayın.
5. Aynı günü yeniden çalıştırın: eşit kayıtların `UNCHANGED` olması beklenir.

**Kontrol noktası:** SAP'deki kur kaydı ve çevrim sonucu beklentinizle uyuşuyor. Yalnız başarılı ön izlemeye dayanarak günlük kullanıma geçmeyin.

<a id="gunluk-kullanim"></a>

## 5. Doğruladıktan sonra günlük kullanımı planlayın

1. Nesneleri ve profil ayarlarını normal transport sürecinizle taşıyın. **Installer'ı her hedef sistemde yeniden çalıştırmayın.** Hedefte bağlantı, istemci, yetki ve FI ayarlarını doğrulayın.
2. `ZCHE_TCMB_LOAD` için onayladığınız seçimlerle bir **varyant** kaydedin. Günlük kullanımda sabit geçmiş tarih yerine **güncel tarih seçim değişkeni** kullanın. Gerçek kayıt yapacak varyantta Test run işaretini ayrıca kontrol edin.
3. **SM36**'da bu varyantla arka plan işi oluşturun. Bültenin yayımlanmasından sonraya planlayın; SAP/job saat dilimini doğrulayın.
4. Önce deneme kullanıcısıyla arka plan çalışmasını sınayın; sonra yetkileri uygun çalışma kullanıcısını seçin. **SM37**, job log'u ve spool üzerinden sonuçları izleyin.

Program cumartesi/pazarı atlar. Diğer yayımlanmayan günlerde profilin bülten yok kuralı uygulanır. Bir job'ın hata vermesi, daha önce başarılı kaydedilen kurları geri almaz.

<details>
<summary>Alternatif kurulum: zaten abapGit kullanıyorsanız</summary>

`https://github.com/Cheditte/abap-tcmb-rates` deposunu müşteri paketinize alıp Pull/aktivasyon yapabilirsiniz. Çevrimdışı aktarım için New Offline → Import zip → Pull zip yolu vardır. Aynı nesneleri iki yöntemle üst üste kurmayın. Ayarlar yine `ZCHE_TCMB_CONFIG` ile girilebilir; SM30 ileri bakım için isteğe bağlıdır. [abapGit kurulum rehberi](https://docs.abapgit.org/user-guide/getting-started/install.html).

</details>

## Dosyadan okuma

Bu alternatif yalnız SAP'nin TCMB'ye HTTPS erişimi yoksa gerekir. Okunan yer **SAP uygulama sunucusunun erişebildiği klasördür**; kendi bilgisayarınızın İndirilenler klasörü değildir. Projeye otomatik indirici dahil değildir.

<details>
<summary>İnternete çıkamayan SAP için dosya hazırlama adımları</summary>

1. Yetkiniz varsa kurumunuzun izin verdiği yöntemle sunucuya erişin: Windows'ta RDP, Linux'ta SSH veya yönetilen dosya aktarımı. Yetkiniz yoksa sunucu sorumlusuyla klasör ve dosyaları hazırlayın.
2. Tam TCMB günlük XML'ini `GGAAYYYY.xml` adıyla klasöre koyun. **30.10.2026 yalnız örnek tarihtir:** o gün için ad `30102026.xml` olur. Kendi seçtiğiniz tarihe göre adı değiştirin; XML içindeki bülten tarihi de eşleşmeli. Yalnız tamamlanmış dosyaları okunan klasöre alın.
3. Basit ayar ekranında **Read from server files** seçeneğini işaretleyin; **Server folder** alanına kendi gerçek sunucu klasörünüzü girin ve profili kaydedin. Teknik karşılıkları `SOURCE_CLASS = ZCL_CHE_TCMB_SOURCE_FILE` ve `FILE_FOLDER`'dır.
4. SAP çalışma kullanıcısının dosya yetkisini ve işletim sistemi okuma iznini kontrol edin. Birden fazla uygulama sunucusunda, çalıştırmanın/job'ın aynı dosyalara ulaşabildiğini doğrulayın.
5. Yükleme programını dosyanın tarihiyle **test modunda** çalıştırın. Bağlantı düğmesi son yedi güne bakar; yalnız eski bir dosya hazırladıysanız o tarihte doğrudan test yapın.

Eksik/okunamayan dosya `ERROR` olur. Program bunu tatil saymaz veya başka kaynağa otomatik geçmez. [Teknik ayrıntılar](TECHNICAL.tr.md#dosya-kaynağı-ve-sorun-giderme).

</details>

## Bir adımda takılırsanız

| Nerede takıldınız? | İlk bakacağınız yer |
|---|---|
| Kurulum mevcut nesne nedeniyle durdu | Aynı isimli aktif/pasif nesneler, log ve aktivasyon durumu. Installer güncelleme aracı değildir. |
| Profil kaydedilemiyor | Kendi alt göreviniz, istemci kuralı, tablo yetkileri; mevcut profili önce yüklediğinizden emin olun. |
| Profil bulunamıyor | Aynı istemcide misiniz, profil adı doğru mu, kayıt başarılı mı? |
| TCMB bağlantısı çalışmıyor | SAP sunucusunun erişimi, STRUST/SM59, ağ ve proxy. |
| Oran / TCURF hatası var | OBBS'de para çifti, kur tipi ve ilgili tarihte geçerli dönüşüm oranları. |
| Beklenen kur atlandı | Satır mesajı, para birimi listesi, TCMB alanı ve mevcut kaydı koruma seçimi. |
| Gerçek kayıt veya job hata verdi | Sonuç, OB08 ve SM37 log/spool. Daha önce başarılı yazılan kayıtlar kalmış olabilir. |

Hata alan çalıştırmayı doğrudan tekrarlamayın. Önce sonuçları ve OB08'i inceleyin, nedeni giderip ilgili aralığı test modunda değerlendirin. Commit hatasında yeniden denemeden önce SM13'teki başarısız/bekleyen güncellemeleri yetkili kişiyle kontrol edin. [Kısmi yazma ve kurtarma](TECHNICAL.tr.md#hatalar-kısmi-yazma-ve-yeniden-çalıştırma).
