# Tek programla kurulum ve ilk kullanım

> [English](WALKTHROUGH.md) | **Türkçe** · [Proje özeti](README.tr.md) · [Teknik başvuru](TECHNICAL.tr.md)

## Önce büyük resim

SAP, TCMB'nin günlük kur bültenini okuyacak. Siz hangi kurları istediğinizi aynı programın ekranında seçeceksiniz. Önce sonucu kaydetmeden inceleyecek, sonra isterseniz kaydedip **OB08** üzerinden kontrol edeceksiniz.

![Tek program yolu: SE38'de kur, aynı ekranda seçimleri yap ve varyant kaydet, önce test edip sonra doğrula](docs/images/setup-tr.svg)

Bu rehber SE38'de program oluşturup çalıştırabilen bir ABAP geliştiricisi içindir. İlk denemeyi DEV/deneme sisteminde yapın. v0.3.0 birleşim adayının [SAP kabul kontrolleri](docs/validation-v0.3.0.md) henüz tamamlanmadı.

Sıra: [0 · Hazırlık](#hazirlik) → [1 · SE38](#kurulum) → [2 · Seçimler](#ayarlar) → [3 · Ön izleme](#onizleme) → [4 · Kayıt](#ilk-kayit) → [5 · Günlük kullanım](#gunluk-kullanim).

<a id="hazirlik"></a>

## 0. Üç hazırlığı tamamlayın

![SAP geliştirme erişimi, kur seçimleri ve SAP sunucusundan TCMB bağlantısı](docs/images/prepare-tr.svg)

- **SAP erişimi:** programı oluşturma/etkinleştirme yetkisi. Taşınabilir kurulum için kendi Z/Y paketinizi ve uygun Workbench alt görevinizi kullanın. Yalnız yerel deneme için `$TMP` seçebilirsiniz; bu nesne transport edilemez.
- **Kur seçimleri:** para birimlerini, hangi alış/satış alanını ve geçerlilik tarihini belirleyin. SAP kur tipi kullanım amacına göre seçilir; örnekteki `M` bir muhasebe önerisi değildir. Para birimleri ve kur tipi sistemde tanımlı olmalı. **OBBS**'de para çifti, kur tipi ve ilgili tarihteki dönüşüm oranlarını doğrulayın. TCMB, JPY'yi 100 birim üzerinden yayımlayabilir; rastgele `1:1` oran vermeyin.
- **Bağlantı:** SAP uygulama sunucusundan `www.tcmb.gov.tr:443` için HTTPS erişimi ve sertifika güveni. TCMB hesabı veya şifre gerekmez; sunucuya yardımcı uygulama kurmayacağız. Yetki sizdeyse kendiniz, değilse Basis/ağ sorumlusuyla hazırlayın. Bilgisayarınızdaki tarayıcı testi yeterli değildir.

<a id="kurulum"></a>

## 1. Tek dosyayı SE38'e yükleyin

1. [`src/zche_tcmb_load.prog.abap`](src/zche_tcmb_load.prog.abap) dosyasını açın. **Copy raw file** ile bütün kaynak metnini kopyalayın veya **Download raw file** ile `.abap` dosyasını kaydedin. GitHub HTML sayfasını yüklemeyin.
2. **SE38**'de **`ZCHE_TCMB_LOAD`** adıyla program oluşturun. Tipi **Executable program / Çalıştırılabilir program** olsun. Başlık olarak `TCMB exchange rates` kullanabilirsiniz. Kendi müşteri paketinize ve Workbench task'ınıza kaydedin; yerel deneme için Local Object / `$TMP` seçebilirsiniz.
3. Oluşturulan başlangıç kaynağının tamamını yeni kaynakla değiştirin. Alternatif olarak **Utilities → More Utilities → Upload/Download → Upload** menüsünden `.abap` dosyasını yükleyin.

![SE38 kaynak düzenleyicisinde Upload menüsü; bu sürümde yüklenecek dosya zche_tcmb_load.prog.abap](docs/images/sap-upload.png)

4. Sözdizimi kontrolünü yapıp **Ctrl+F3** ile etkinleştirin. Program özelliklerinde **Fixed point arithmetic / Sabit nokta aritmetiği** açık olmalı; kur hesabı için gereklidir. abapGit alternatifi bu özelliği metaveriden alır.
5. **Program → Execute → Unit Tests** üzerinden gömülü testleri çalıştırın. Güncel kaynakta **48 test** vardır; sayı, testlerin SAP'de geçtiği anlamına gelmez. Hata varsa ilk veri kaydına geçmeden inceleyin.

**Uzun satır hatası:** kaynakta 72 karakterden uzun satırlar vardır. Editör ayarlarındaki **Downwards-compatible line length (72)** ve Upload/Download menüsündeki **Force Line Length 72** seçeneklerini kontrol edin. 72 karaktere zorlamayı kapatıp dosyayı yeniden yükleyin; kodu kesmeyin. Menü adları SAP GUI sürümüne/diline göre değişebilir.

**Kontrol noktası:** `ZCHE_TCMB_LOAD` aktif ve F8 ile seçim ekranı açılıyor. Ayrı installer, ayar programı veya SE11/SE54/SM30 işlemi yoktur. Varsayılan **Otomatik / Logon language** dil seçimi Türkçe oturumda Türkçe, diğer oturumlarda İngilizce kullanır; **Dil / Language** alanından bunu değiştirebilirsiniz. Metin öğelerini elle doldurmanız gerekmez. Açılışta hata varsa tam mesajı kaydedin.

Mevcut programın eski sürümü varsa üzerine yüklemeden önce kaynağını, özel kodunu ve varyantlarını koruyun; [geçiş notunu](TECHNICAL.tr.md#eski-surumden-gecis) izleyin. Türkçe seçim ekranı ve başarılı bağlantı mesajı [kullanıcının paylaştığı ekranda](#turkce-ekran) görülüyor. Temiz kurulumun bütün adımları, dil değiştirme anı, varyant ve arka plan davranışı için kabul kontrolleri sürüyor. Yukarıdaki görsel yalnız genel SE38 yükleme menüsünü gösterir.

<a id="ayarlar"></a>

## 2. Aynı ekranda ilk seçimleri yapın

### 2.1. Önce ekranda ne yaptığımızı anlayalım

Bu ekran üç soruya cevap verir: **Hangi günün hangi kurlarını alacağız? SAP'de hangi kur tipi ve tarihle kullanacağız? Şimdilik yalnız sonucu mu göreceğiz, yoksa kaydedecek miyiz?**

**SE38 → `ZCHE_TCMB_LOAD` → F8** ile açılır. Programın alanlarını Türkçe görmek için **Dil / Language → Türkçe** seçin. SAP oturumundan çıkmanız gerekmez. SAP'nin kendi menüleri, pencere başlığı ve özgün sistem mesajları oturum dilinde kalabilir.

<a id="turkce-ekran"></a>

![Türkçe SAP seçim ekranı ve başarılı TCMB bağlantı mesajı; kur tipi ve tarih kuralı henüz doldurulmamış](docs/images/sap-tr-connection-success.png)

*Kullanıcının deneme sisteminden paylaştığı gerçek ekran. Türkçe alanlar ve bağlantı mesajı görülüyor. Bu, tamamlanmış bir kur seçimi veya OB08'e kayıt sonucu değildir.*

**Bu ekrandaysanız:** bilgi penceresinin sağ altındaki **yeşil onay işaretine** basıp pencereyi kapatın. Pencere açıkken arkadaki alanların soluk görünmesi normaldir; önce bu mesajı kapatmanız gerekir.

**Mesaj ne söylüyor?** Program 30.10.2026 tarihli, `2026/204` numaralı TCMB bültenini okuyup 22 para birimi bulmuş. Bu sayı SAP'ye kaydedilen kur sayısı değildir. Ekranda 29.10 seçiliyken mesajda 30.10 görünmesi de normaldir: bağlantı düğmesi seçilen tarihi değil, **son yedi gün içinde erişebildiği bir bülteni** sınar.

<a id="ilk-onizleme-secimleri"></a>

### 2.2. İlk ön izleme için ekranı doldurun

İlk denemeyi **tek gün ve tek para birimiyle** yapalım. Aşağıdaki `30.10.2026` tarihi, yukarıdaki gerçek bağlantı testinde okunan bültene aittir. Kendi kurulumunuzda erişebildiğiniz bir bülten tarihi kullanabilirsiniz. `M`, sisteminizde tanımlı ve deneme için uygun olması gereken örnek SAP kur tipidir.

| Sıra | Ekranda yapacağınız işlem |
|---|---|
| 1 | **Dil / Language:** Türkçe seçin. |
| 2 | **Bülten tarih(ler)i:** soldaki alana `30.10.2026` yazın; sağdaki bitiş alanını boş bırakın. |
| 3 | **Deneme (kur kaydedilmez):** işaretli kalsın. |
| 4 | **Döviz alış:** `M` yazın. Altındaki diğer beş kur alanını boş bırakın. |
| 5 | **Tarih kuralı:** listeden **Bülten ile aynı gün** seçin. Fabrika takvimini boş bırakın. |
| 6 | **TCMB döviz kodları:** `USD` yazın. Farklı SAP kodunu boş, para birimini `TRY`, ters yön seçimini işaretsiz bırakın. |
| 7 | **TCURR'da o gün için farklı bir kur varsa:** **Olduğu gibi bırak** seçin. Açılıştaki varsayılan Güncelle'dir; bunu değiştirin. |
| 8 | **TCMB bülteni olmayan iş günü:** **Yalnızca listede göster** seçili kalsın. |
| 9 | **Bülten nereden alınır:** **TCMB'den HTTPS ile** seçili kalsın. Bağlantı zaten bu ayarlarla başarılıysa SM59 hedefini, farklı adresi ve XML klasörünü boş bırakın. |

**Beklenen seçim:** 30.10.2026 bültenindeki USD döviz alış kuru → SAP'de `M`, USD → TRY, 30.10.2026 geçerlilik tarihi → **ön izleme; kayıt yok**. Alanları aşağıda tek tek açıkladık. Hazırsanız [3. adımdaki F8 ön izlemesine](#onizleme) geçin.

### 2.3. Çalıştırma: dil, tarih ve deneme

| Alan / düğme | Ne işe yarar? | Nasıl doldurulur? |
|---|---|---|
| **Dil / Language** | Bu programın alanlarını, kendi mesajlarını ve sonuç başlıklarını seçtiğiniz dilde gösterir. | **Türkçe** veya **English** seçin. **Otomatik / Logon language**, Türkçe SAP oturumunda Türkçe, diğer oturumlarda İngilizce kullanır. |
| **Bülten tarih(ler)i** | TCMB'den hangi günün bülteninin okunacağını belirler. | Tek gün için yalnız sol alanı doldurun. Aralık için sağa son günü girin; iki uç gün de aralığa dahildir. Cumartesi ve pazar atlanır. |
| **Deneme (kur kaydedilmez)** | Kurları okur, hesaplar ve SAP'deki mevcut kayıtlarla karşılaştırır; standart kur kaydı yapmaz. | İlk çalıştırmada **işaretli** bırakın. İşareti kaldırıp F8'e basmak gerçek kayıt yolunu çalıştırır. |
| **TCMB bağlantısını test et** | Seçilen kaynaktan yakın tarihli bir bültenin okunabildiğini sınar. | Düğmeye basın ve mesajı okuyun. Kur yazmaz; F8 ile yapılacak ön izlemenin yerine geçmez. |

### 2.4. Hangi TCMB kuru hangi SAP kur tipine yazılır?

**Bu altı kutuya `34,50` gibi bir kur tutarı yazmayın.** Tutarı program TCMB'den alır. Siz, o tutarın SAP'de kullanılacağı **kur tipini** yazarsınız. Kur tipi, SAP'nin farklı amaçlarla kullanılan kurları ayırdığı anahtardır.

Örneğin **Döviz alış** yanına `M` yazmak, “TCMB'nin döviz alış değerini SAP'de M kur tipine al” demektir. Bu seçim `M` tipinin her kurumda döviz alış için kullanıldığı anlamına gelmez. Kendi sisteminizdeki FI kullanımını esas alın.

| Alan | Programın alacağı değer | İlk denemede |
|---|---|---|
| **Döviz alış** | TCMB'nin döviz alış değeri. | Örnekte `M`. |
| **Döviz satış** | TCMB'nin döviz satış değeri. | Boş bırakın. |
| **Efektif alış** | TCMB'nin nakit döviz için ayrı yayımladığı alış değeri. | Boş bırakın. |
| **Efektif satış** | TCMB'nin nakit döviz için ayrı yayımladığı satış değeri. | Boş bırakın. |
| **Döviz ortalama (alış+satış)/2** | Program döviz alış ve satış değerlerinin aritmetik ortalamasını hesaplar; iki değerin de bulunması gerekir. | Boş bırakın. |
| **Efektif ortalama** | Program efektif alış ve satış değerlerinin aritmetik ortalamasını hesaplar; iki değerin de bulunması gerekir. | Boş bırakın. |

**Boş alan o kur türünü yüklememek demektir.** En az birini doldurun. Birden fazla tür alacaksanız her birine farklı, sisteminizde tanımlı ve amacınıza uygun kur tipi girin. Aynı `M` değerini iki satıra yazmayın; program bunu reddeder.

### 2.5. Kurlar hangi günden itibaren geçerli?

**Bülten tarihi**, veriyi aldığınız gündür. **Geçerlilik tarihi**, bu kurun SAP'de hangi günden itibaren kullanılacağıdır. Bu bölüm ikinci tarihi belirler; başka bir günün bültenini indirmez.

| Tarih kuralı | Ne yapar? | Örnek |
|---|---|---|
| **Bülten ile aynı gün** | SAP geçerlilik tarihi bülten tarihi olur. | 30.10.2026 bülteni → 30.10.2026 geçerlilik. İlk denemede bunu seçin. |
| **Ertesi takvim günü** | Geçerliliği bir sonraki güne alır; hafta sonu/tatil ayrımı yapmaz. | 30.10.2026 bülteni → 31.10.2026 geçerlilik. |
| **Sonraki iş günü (takvim)** | Bülten gününden sonraki ilk iş gününü seçtiğiniz SAP fabrika takviminden bulur. | Sonuç, takviminizde hangi günlerin iş günü olduğuna bağlıdır. |

**Fabrika takvimi (iş günü):** yalnız **Sonraki iş günü (takvim)** için doldurulur. SCAL'da tanımlı, sizin süreciniz için uygun takvimin kodunu kullanın. `TR` gibi bir kodun her sistemde hazır olduğunu varsaymayın. Diğer iki kuralda boş bırakın. Tarih kuralı başlangıçta boştur; listeden mutlaka seçin.

### 2.6. Para birimleri: hangi dövizler, hangi yön?

| Alan | Ne işe yarar? | Nasıl doldurulur? |
|---|---|---|
| **TCMB döviz kodları** | Bültendeki hangi dövizlerin işleneceğini seçer. | İlk denemede `USD`. Birkaç kod için sağdaki **çoklu seçim** düğmesini açın; tekil değerler bölümüne `USD` ve `JPY` gibi kodları ayrı satırlarda yazıp onaylayın. Aralık bölümüne yazmayın. |
| **Farklı SAP kodu (USD=USD2)** | TCMB kodu ile SAP'deki kod farklıysa eşleştirir. | Normalde **boş**. Yalnız SAP'de gerçekten bu kod tanımlıysa `USD=USD2` gibi eşleme girin. Birden fazla eşlemeyi `;` ile ayırın. Bu işlem döviz dönüşümü yapmaz. |
| **TCMB kurlarının para birimi** | Alınan kurların karşılığının Türk lirası olduğunu belirtir. | `TRY` bırakın. EUR gibi başka hedef girerek çapraz kur hesaplatamazsınız. |
| **Ters yönü de yaz (TRY→döviz)** | Döviz → TRY yönüne ek olarak TRY → döviz yönünü ters kotasyonla hazırlar. | İlk denemede **işaretsiz**. İki yönü de kullanmanız gerekiyorsa oranları ve SAP çevrim sonucunu ayrıca doğrulayın. |

**Döviz kodlarını boş bırakmak “hiçbir dövizi alma” değildir:** bültendeki bütün kodlar değerlendirilir. Çoklu seçimde hariç tutma da desteklenir. SAP'de tanımlı olmayan kodlar atlanır. İlk denemede kapsamı `USD` ile sınırlayın; daha sonra `JPY` eklediğinizde bültendeki 100 birim bilgisi ile OBBS oranlarını da inceleyin.

### 2.7. SAP'de o gün için zaten kur varsa

**TCURR**, SAP'nin standart döviz kuru tablosudur; kayıtları **OB08** üzerinden kontrol edebilirsiniz. Program aynı kur tipi, para çifti ve geçerlilik tarihindeki kayda bakar.

| Seçenek | Farklı bir mevcut kur bulunursa |
|---|---|
| **Güncelle** | Gerçek çalıştırmada eski değeri yenisiyle değiştirir. Denemede yalnız değişikliği gösterir. Programın açılış varsayılanıdır. |
| **Olduğu gibi bırak** | Mevcut farklı değeri korur; satırı gerekçesiyle atlar. İlk denemede bunu seçin. |

**Olduğu gibi bırak, bütün kaydı kapatmaz:** aynı anahtarda kayıt yoksa gerçek çalıştırmada yeni kayıt eklenebilir. Hiç kur kaydetmemek için üstteki **Deneme (kur kaydedilmez)** kutusu işaretli olmalıdır. Mevcut kayıt zaten eşitse iki seçimde de `UNCHANGED` görülür.

### 2.8. TCMB bülteni olmayan iş günü

Program hafta içi bir tarih için HTTPS kaynağından “bülten yok” yanıtı alırsa bu seçimi uygular. Örneğin tatil günü veya henüz yayımlanmamış bülten olabilir. Bu seçenek başka bir günün kurunu otomatik olarak kullanmaz.

| Seçenek | Ne olur? |
|---|---|
| **Yalnızca listede göster** | Bülten bulunamadığı sonuç listesinde belirtilir. İlk denemede bunu bırakın. |
| **Uyarı ver** | Sonuç kaydına ek olarak çalışma sonunda uyarı verilir. |
| **Hata (job iptal olur)** | Eksik bülten hata sayılır; arka plan işi hata ile sonlanır. |

Bu seçim ağ, sertifika, geçersiz XML veya okunamayan sunucu dosyası hatalarını yok saymaz. Tarih aralığındaki gerçek yazmalar satır satır yapılır; sonradan oluşan hata daha önce kaydedilmiş kurları geri almaz.

### 2.9. Bülten nereden alınır?

**Normal kullanımda TCMB'den HTTPS ile seçili olsun; altındaki üç metin alanını boş bırakın.** Program TCMB adresini zaten bilir. Ekrandaki başarılı bağlantı mesajı sizin bu yolu kullanabildiğinizi gösterir.

| Alan / seçenek | Ne işe yarar? | Ne zaman doldurulur? |
|---|---|---|
| **TCMB'den HTTPS ile** | SAP uygulama sunucusu bülteni doğrudan internetten okur. | İlk denemede seçili bırakın. TCMB hesabı veya parola gerekmez. |
| **SM59 hedefi (isteğe bağlı)** | SAP'de önceden hazırlanmış HTTP bağlantısının ayarlarını kullanır. | Kurumunuz bu yolu kullanıyorsa gerçek SM59 hedef **adını** yazın. Buraya internet adresi yazılmaz. Normal doğrudan bağlantıda boş bırakın. |
| **Farklı adres (isteğe bağlı)** | SM59 hedefi kullanılmadığında varsayılan bülten kök adresini değiştirir. | Normalde boş. Özel bir kaynak kullanıyorsanız beklenen günlük XML yapısını sunan kök adres gerekir. Klasör yolu veya tek güne ait XML bağlantısı girmeyin. |
| **Sunucudaki bir klasörden** | İnternetten almak yerine önceden hazırlanmış XML dosyalarını okur. | HTTPS yerine dosya yolunu kullanacaksanız seçin; otomatik bir yedek kaynak değildir. |
| **XML dosyalarının klasörü** | Dosya kaynağının bulunduğu SAP uygulama sunucusu klasörüdür. | Yalnız klasörden okumada gerçek sunucu yolunu girin. Kendi bilgisayarınızın İndirilenler klasörü değildir. [Dosya hazırlama adımları](#dosyadan-okuma). |

### 2.10. Seçimlerinizi varyant olarak saklayın

**Varyant**, bu ekrana girdiğiniz seçimlere verdiğiniz addır. Aynı alanları her seferinde tekrar doldurmanızı önler; kur kaydetmez.

1. Alanları tamamlayın. Seçim ekranında **Goto → Variants → Save as Variant** veya SAP GUI'nizdeki **Varyant olarak kaydet** komutunu kullanın; çoğu GUI'de Ctrl+S'dir. Menüler oturum dilinde kalabilir.
2. Örneğin `TCMB_DENEME` adı ve `USD döviz alış - kayıt yapmadan deneme` açıklamasını girin. Bunlar sizin oluşturacağınız örnek ad ve açıklamadır.
3. Kaydedin. Sonraki çalıştırmada varyantı yükleyip dil, tarih ve **Deneme (kur kaydedilmez)** seçiminin beklediğiniz gibi geldiğini kontrol edin.

**Kontrol noktası:** seçimler yeniden yüklenebiliyor. Bu varyantta tek bir geçmiş günü saklıyoruz; otomatik günlük kullanım için tarihi [5. adımda](#gunluk-kullanim) dinamik yapacağız.

<a id="onizleme"></a>

## 3. Bağlantıyı sınayın ve kaydetmeden çalıştırın

1. **TCMB bağlantısını test et** düğmesine basın. Son yedi gün içinde yakın tarihli bir bülteni alıp okuyabilirse seçtiğiniz dilde bağlantının başarılı olduğunu bildiren mesaj verir. Bu düğme seçtiğiniz tarih aralığını kullanmaz ve kur yazmaz.
2. Geçmiş tek gün seçiminizi kontrol edin. Bugünün bülteni henüz yayımlanmamış olabilir.
3. **Deneme (kur kaydedilmez) işaretli kalsın**, F8'e basın.
4. ALV sonuç listesinde bülten tarihi, geçerlilik tarihi (`VALID_FROM`), para çifti, kur tipi, oranlar, durum ve açıklamayı inceleyin. Başlıklar ve ek durum açıklaması seçtiğiniz dildedir; `NEW`, `ERROR` gibi teknik durum kodları aynı kalır. TCMB değeriyle karşılaştırırken JPY gibi birim/oran etkisini dikkate alın.

| Durum | Test çalıştırmasında anlamı |
|---|---|
| `NEW` | Gerçek çalıştırmada yeni kayıt planlanıyor. |
| `UPDATED` | Gerçek çalıştırmada mevcut kurun değişmesi planlanıyor. |
| `UNCHANGED` | Aynı anahtar ve tarihte eşit kayıt var. |
| `SKIPPED` | Satır atlandı; nedeni mesajdadır. Mevcut kuru koruma veya eksik TCMB alanı olabilir. |
| `NO_BULLETIN` | HTTP kaynağı o hafta içi gün için bülten bulunmadığını bildirdi. Seçtiğiniz politika bunu hata da sayabilir. |
| `ERROR` | Sorunu mesajdan inceleyin; gerçek kayda geçmeyin. |

<a id="turkce-sonuc"></a>

### Sonuç listesini gerçek bir örnekle okuyalım

![Türkçe sonuç listesinde 27.10.2026 tarihli USD TRY M kuru ve Aynı kayıt mevcut UNCHANGED durumu](docs/images/sap-tr-result-unchanged.png)

*Kullanıcının paylaştığı sonuç ekranı **27.10.2026** gününe aittir; yukarıdaki ilk seçim örneğindeki 30.10.2026'dan farklı bir çalıştırmadır. Seçim ekranı bu görüntüde olmadığı için Deneme kutusunun işaretli olup olmadığı buradan anlaşılmaz.*

Bu satırın anlamı: **27.10.2026 bültenindeki USD döviz alış değeri için, M kur tipinde ve 27.10.2026 geçerlilik tarihinde SAP'de aynı kur zaten bulunuyor.** `UNCHANGED` hata değildir; bu satır için yeni kayıt veya güncelleme yapılmaz.

| Sütun | Bu ekrandaki değer | Nasıl okunur? |
|---|---|---|
| **Bülten tarihi** | `27.10.2026` | Verinin ait olduğu TCMB bülten günü. |
| **TCMB kodu** | `USD` | Bültenden seçilen para birimi. |
| **TCMB kur alanı** | `FX_BUY` | Döviz alış seçilmiş. Bu teknik kod dil değişse de aynı kalır. |
| **SAP kur tipi** | `M` | Kurun SAP'de hangi tip altında değerlendirildiği. |
| **Kaynak para birimi** | `USD` | Dönüşümün başlangıç para birimi. |
| **Hedef para birimi** | `TRY` | Dönüşümün karşılık para birimi. |
| **Geçerlilik tarihi** | `27.10.2026` | Kurun SAP'de hangi günden itibaren geçerli olduğu. OB08'de bu tarihe bakın. |
| **Döviz kuru** | `49,69970` | Programın hesaplayıp SAP kaydıyla karşılaştırdığı değer. Bu örnekte doğrudan kotasyon ve 1:1 oranla **1 USD = 49,69970 TRY** anlamına gelir. |
| **Kaynak oranı / Hedef oranı** | `1 / 1` | Kurun kaç birim üzerinden uygulandığı. Başka bir dövizde, özellikle JPY'de, 1:1 olduğunu varsaymayın. |
| **Ters kotasyon** | Boş | Bu satır ters kotasyon kullanmıyor. |
| **Durum** | `Aynı kayıt mevcut` | Sonucun seçtiğiniz dilde açıklaması. |
| **Durum kodu** | `UNCHANGED` | SAP'deki mevcut kayıt hesaplanan kurla eşit. |
| **Açıklama** | Boş | Bu satırda ek açıklama yok. Atlanan veya hatalı satırlarda nedeni burada okuyun. |

Bazı sütun başlıkları dar oldukları için ekranda kısaltılmıştır; tablodaki adlar tam anlamlarını gösterir. Bu sonuç, kurun **bu çalıştırmada kaydedildiğini kanıtlamaz**. Yeni kayıt denemesi için aynı anahtarda kayıt bulunmayan bir bülten gününü önce deneme modunda değerlendirin; örnek üretmek için mevcut kuru silmeyin.

**Kontrol noktası:** sonuç listesini okuyabiliyorsunuz; testte `NEW` görmek OB08'e kayıt yapıldığı anlamına gelmez. Test modu gerçek yazma yetkisini veya commit başarısını doğrulamaz. Özel `LCL_EXIT` kodu eklediyseniz testte de çalışır; [yan etki kurallarını](TECHNICAL.tr.md#yerel-siniflar-ve-genisletme) uygulayın.

<details>
<summary>Bağlantı başarısızsa</summary>

Varsayılan adres `https://www.tcmb.gov.tr/kurlar` gerçek TCMB adresidir; kendi adresinizle değiştirmeyin.

- Doğrudan HTTPS, STRUST'taki SSL client **Anonymous** PSE'sini kullanır. Güncel ve gerçek sertifika zincirini doğrulayın; sabit bir sertifika adına dayanmayın.
- Kurumunuz SM59/proxy kullanıyorsa tip **G**, sunucu `www.tcmb.gov.tr`, port `443`, SSL etkin, path prefix boş bir HTTP hedefi hazırlayın. Proxy ve SSL PSE'sini ortamınıza göre ayarlayın. `P_DEST` alanına **sizin hedefinizin adını** girip varyantı yeniden kaydedin.
- Bu ayarlar sizde değilse Basis/ağ sorumlusuna SAP uygulama sunucusundan HTTPS erişimi ve sertifika güveni gerektiğini iletin.
- SAP internete çıkamıyorsa [dosyadan okuma](#dosyadan-okuma) yolunu kullanın.

</details>

<a id="ilk-kayit"></a>

## 4. Deneme sisteminde gerçek kaydı doğrulayın

**Kuru program kaydeder; OB08'de sonucu kontrol edersiniz.** OB08'e ayrıca tutar yazmanız veya orada Kaydet'e basmanız gerekmez. Program standart SAP kayıt işlemini ve kayıt kesinleştirmesini kendisi çağırır.

İzlenecek sıra: **mevcut kaydı kontrol et → deneme sonucunu incele → Deneme işaretini kaldır → F8 → OB08'de doğrula**.

### 4.1. Önce ortamı ve mevcut kaydı kontrol edin

1. DEV/deneme sisteminde ve doğru istemcide olduğunuzu kontrol edin. [1. adımdaki](#kurulum) 48 SAP Unit testini henüz çalıştırmadıysanız çalıştırın; başarısız testi çözmeden gerçek kayda geçmeyin. Deneme sonucu da hata veya açıklanamayan oran/kur içermemeli.
2. Sonuç listesindeki **kur tipi, kaynak/hedef para birimi ve geçerlilik tarihini** not edin. Örneğimiz `M`, `USD`, `TRY`, `30.10.2026` olacak. `M` sisteminizde bu kullanım için uygun ve tanımlı olmalıdır.
3. SAP komut alanına **`/oOB08`** yazıp Enter'a basın. OB08 yeni oturumda açılır; program ekranınız önceki oturumda kalır. Yeni oturum sınırına ulaştıysanız seçimlerinizi not edip aynı oturumda `/nOB08` ile açabilirsiniz.
4. OB08'in seçim, filtre veya konumlandırma alanlarıyla aynı kur tipini, para çiftini ve geçerlilik tarihini bulun. Alanların/düğmelerin konumu SAP sürümü ve oturum diline göre değişebilir. **Veri eklemeyin veya değiştirmeyin; yalnız mevcut kayda bakın.**
5. Aynı anahtarda kayıt varsa bunu not edin. Eşit değer için sonuç `UNCHANGED`, farklı değeri korumayı seçtiğinizde `SKIPPED` olur. Yeni kayıt denemesi için bülteni bulunan ve aynı anahtarda kayıt olmayan bir tarih kullanın. Mevcut kuru sırf deneme yapmak için silmeyin.

Önceki ekran örneğindeki **27.10.2026 / M / USD → TRY zaten UNCHANGED** idi. O satırı yeniden çalıştırmak yeni kayıt yaptığınızı göstermez. 30.10.2026 da sisteminizde kayıtlı olabilir; önce kontrol edin.

### 4.2. Yazmadan önce aynı seçimi deneyin

1. Programın seçim ekranına dönün; sonuç listesindeyseniz **F3** kullanın.
2. Şu seçimleri yapın:

| Alan | İlk gerçek kayıt denemesinden önce |
|---|---|
| Dil | Türkçe |
| Bülten tarihi | Örneğin `30.10.2026`; bitiş boş. Başka gün seçtiyseniz aşağıdaki bütün kontrolleri o güne göre yapın. |
| Döviz alış | `M`; diğer beş kur alanı boş. |
| Tarih kuralı | **Bülten ile aynı gün**; fabrika takvimi boş. |
| TCMB döviz kodları | Yalnız `USD`. |
| Farklı SAP kodu / Ters yönü de yaz | Boş / işaretsiz. |
| TCMB kurlarının para birimi | `TRY`. |
| Mevcut farklı kur | **Olduğu gibi bırak**. Bu seçim mevcut kuru korur, eksik yeni kaydın eklenmesini engellemez. |
| Kaynak | Başarılı bağlantı testinde kullandığınız HTTPS ayarları. |
| Deneme (kur kaydedilmez) | **İşaretli**. |

3. **F8** ile çalıştırın. Yeni kayıt denemesinde **Yeni kayıt planlanıyor / NEW** beklenir. Bu aşamada henüz kur kaydedilmez.
4. Kur tipi, USD → TRY yönü, geçerlilik tarihi, tutar ve oranları kontrol edin. `ERROR` varsa açıklamayı çözün. `UNCHANGED` veya `SKIPPED` varsa mevcut kaydı tekrar değerlendirin; sırf NEW sonucu almak için Güncelle'ye geçmeyin.

### 4.3. Gerçek kaydı çalıştırın

1. Hatasız ön izlemeden **F3** ile geri dönün. Tarih, para birimi, kur tipi ve diğer seçimler aynı kalsın.
2. **Deneme (kur kaydedilmez) kutusunun işaretini kaldırın.** `Olduğu gibi bırak` seçimini koruyun.
3. Seçim ekranının görüntüsünü alın: tarih, kur tipi, döviz kodu ve kaldırılmış Deneme işareti görünmeli.
4. **F8**'e basın. Bu kez program gerçek kayıt işlemini çalıştırır; ayrıca bir Kaydet düğmesine basmanız gerekmez. Ayrı bir onay penceresi beklemeyin.
5. Sonuç ekranını ve varsa mesajı inceleyip görüntüsünü alın.

| Gerçek çalıştırma sonucu | Anlamı / sonraki adım |
|---|---|
| **Yeni kayıt / NEW** | Program yeni kaydı başarıyla yazdığını bildiriyor. OB08'de bağımsız olarak doğrulayın. |
| **Aynı kayıt mevcut / UNCHANGED** | Aynı kur zaten vardı; bu satır için yeni yazma yapılmadı. |
| **Atlandı / SKIPPED** | Satır yazılmadı; açıklamayı okuyun. Koruma seçimiyle farklı mevcut kur atlanmış olabilir. |
| **Güncellendi / UPDATED** | Güncelleme seçimiyle mevcut değer değiştirilmiş. Bu örnekte koruma seçtiğimiz için beklenen sonuç değildir; seçimlerinizi kontrol edin. |
| **Bülten yok / NO_BULLETIN** | O gün için kur alınamadı; bu satırda kayıt oluşmaz. |
| **Hata / ERROR** | Açıklamayı okuyun. Özellikle kayıt kesinleştirme (commit) hatasında tekrar çalıştırmadan önce OB08 ve SM13'ü kontrol edin. |

### 4.4. OB08'de aynı kaydı bulun

1. OB08 oturumuna geçin. Önceden açık olan liste eski veriyi gösterebilir; listeyi yeniden okuyun veya işlemden çıkıp OB08'i tekrar açın.
2. **Aynı sistem ve istemcide**, programın sonuç satırındaki değerlerle aşağıdaki kaydı bulun:

| OB08'de karşılaştıracağınız bilgi | Bu örnekte |
|---|---|
| Kur tipi | `M` |
| Kaynak para birimi | `USD` |
| Hedef para birimi | `TRY` |
| Geçerlilik başlangıcı | `30.10.2026`; başka gün/kural seçtiyseniz sonuçtaki **Geçerlilik tarihi** |
| Kur ve oranlar | Programın **o çalıştırmada** gösterdiği değerler; 27.10.2026 ekranındaki `49,69970` değerini başka gün için kopyalamayın. |

3. Eşleşen satırın ekran görüntüsünü alın. Kur tipi, para çifti, geçerlilik tarihi, kur ve oranlar görünür olsun. Kontrol için OB08'de değişiklik yapıp Kaydet'e basmayın.
4. Kur tutarı/oranları farklı görünüyorsa kayıt doğrulandı demeyin; doğru tarih, kotasyon ve oranları karşılaştırın. SAP para çevrimiyle beklenen tutarı da doğrulayın; teknik geri okuma ayrıntıları [teknik başvuruda](TECHNICAL.tr.md#tarih-ve-oran-hesabı).

### 4.5. Tekrar çalıştırınca ne oluyor?

Programda aynı seçimleri koruyun, **Deneme (kur kaydedilmez)** kutusunu yeniden işaretleyin ve F8'e basın. Az önce kaydettiğiniz kur için **Aynı kayıt mevcut / UNCHANGED** beklenir. Böylece yeniden kontrol ederken yazma modunu açık bırakmamış olursunuz.

**Ekran görüntüsü sırası:** Deneme işareti kaldırılmış seçim ekranı → gerçek çalıştırma sonucu → OB08'de eşleşen satır → tekrar denemede UNCHANGED. Bu sürüm için gerçek kayıt/OB08 görüntüleri henüz sağlanmadı; yukarıdaki mevcut UNCHANGED görüntüsü yeni kayıt kanıtı olarak kullanılmaz.

**Gerçek kayıt standart TCURR tablosuna gider.** Programı başka Z adıyla kopyalamak, kur verilerini ayrı bir alana taşımaz. Gerçek yazma denemesini yalnız yetkili deneme ortamında yapın.

<a id="gunluk-kullanim"></a>

## 5. Kabulden sonra günlük iş planlayın

1. Programı kendi paketiniz ve normal transport sürecinizle taşıyın. Her hedefte bağlantı, FI ayarları ve çalışma kullanıcısının yetkilerini doğrulayın.
2. Günlük kullanım için ayrı varyant oluşturun. Varyant özniteliklerinde `S_DATE` için **D / Dinamik tarih → Güncel tarih** seçin; sabit bir geçmiş günü kaydetmeyin. Yazacak varyantta **Deneme (kur kaydedilmez)** seçimini ayrıca kontrol edin.
3. **SM36**'da `ZCHE_TCMB_LOAD` ve bu varyantla job oluşturun. Bültenin yayımlanmasından sonraya planlayın ve SAP/job saat dilimini doğrulayın.
4. Sınırlı yetkili çalışma kullanıcısıyla deneyin. **SM37**, job log'u ve spool üzerinden sonuçları izleyin. Hata job'ı `Cancelled` yapar; önceki başarılı kayıtlar geri alınmaz.

Varyantları hedef sistemde hazırlayın veya kurumunuzun standart varyant taşıma yolunu kullanın; özel profil tablosu transport'u yoktur. Türkçe job çıktısı için varyantta **Dil / Language → Türkçe** seçimini saklayın; **Otomatik / Logon language**, çalıştırma sırasında SAP'nin kullandığı dili izler. Cumartesi/pazar atlanır; hafta içi eksik HTTP bülteninin davranışını seçtiğiniz politika belirler. Kaydedilmiş dil seçimi, arka plan yerelleştirmesi ve dinamik tarihli SM36 yolu bu sürümde SAP kabul testi bekliyor.

## Dosyadan okuma

Yalnız SAP'nin TCMB'ye HTTPS erişimi yoksa kullanın. Program **SAP uygulama sunucusunun okuyabildiği klasörü** okur; kendi bilgisayarınızın İndirilenler klasörünü kullanmaz. Otomatik indirici projeye dahil değildir.

<details>
<summary>Sunucu dosyalarını hazırlama adımları</summary>

1. Yetkiniz varsa kurumunuzun izin verdiği RDP (Windows), SSH (Linux) veya yönetilen dosya aktarımıyla sunucuya erişin; yoksa sunucu sorumlusuyla hazırlayın.
2. Tam günlük XML'i `GGAAYYYY.xml` adıyla koyun. **30.10.2026 bir örnektir:** o günün dosyası `30102026.xml` olur. Kendi seçtiğiniz günün dosya adını kullanın; XML içindeki bülten tarihi de eşleşmeli. Okunan klasöre yalnız tamamlanmış dosyaları alın.
3. **Sunucudaki bir klasörden (`R_FILE`)** seçin; **XML dosyalarının klasörü (`P_DIR`)** alanına gerçek sunucu klasörünüzü girin. Sabit örnek klasör kopyalamayın.
4. İşletim sistemi ve SAP dosya okuma yetkilerini kontrol edin. Birden fazla uygulama sunucusunda job'ın aynı dosyalara ulaşabildiğini doğrulayın.
5. Dosyanın tarihiyle test çalıştırın. Bağlantı düğmesi son yedi güne bakar; yalnız eski bir dosyanız varsa o tarihte doğrudan test yapın.

**Eksik veya okunamayan dosya `ERROR` olur.** Bu, tatil kanıtı değildir. Kaynak değiştirme veya otomatik indirme yapılmaz.

</details>

## Bir adımda takılırsanız

| Belirti | İlk kontrol |
|---|---|
| Kaynak yapıştırılamıyor | 72 karaktere zorlama, tam kaynak ve doğru program adı. |
| Ekran açılışında hata | Tam hata mesajı; `SELECTION_TEXTS_MODIFY`/`VRM_SET_VALUES` ve sistem sürümü. |
| Kur tipi/tarih kuralı isteniyor | En az bir TCMB alanına kur tipi girin, tarih kuralını listeden seçin. |
| SSL veya bağlantı hatası | SAP sunucusu, ağ/proxy, STRUST ve SM59. |
| TCURF/oran hatası | OBBS'de doğru anahtar ve geçerlilik tarihindeki pozitif oranlar. |
| Dosya bulunamadı | Gerçek sunucu klasörü, dosya adı, tamamlanmış XML ve okuma izinleri. |
| Kayıt/job hatası | Sonuç, OB08, SM37 log/spool. Commit hatasında SM13 incelemesi. |

Çalışmayı doğrudan tekrarlamayın. Önce yazılmış olabilecek kurları kontrol edin; nedeni giderip etkilenen aralığı test modunda değerlendirin. [Kısmi yazma ve kurtarma](TECHNICAL.tr.md#hatalar-ve-yeniden-deneme).

<details>
<summary>İsteğe bağlı: abapGit ile kurulum</summary>

Depoyu müşteri paketinize alıp Pull/aktivasyon yapabilirsiniz. Çevrimdışı ZIP aktarımı da kullanılabilir. abapGit program özelliklerini ve metin öğelerini getirir; günlük çalışma ona bağlı değildir. Aynı programı iki yöntemle üst üste yüklemeyin.

</details>
