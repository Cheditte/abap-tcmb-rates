# TCMB kurlarını SAP'de görün, kontrol edin ve kaydedin

> [English](README.md) | **Türkçe**

TCMB'nin günlük döviz kurlarını SAP'de görmek veya standart kur kayıtlarını beslemek istiyorsanız bu projeyi kullanabilirsiniz. **Tek programla önce sonucu kaydetmeden inceleyebilir, ardından eksik kurları ekleyebilir veya mevcut farklı kurları güncelleyebilirsiniz.** Kayıtları OB08'de kontrol edersiniz.

![Hedefinize göre üç yol: deneme, OB08 kaydı, günlük otomatik çalışma](docs/images/goals-tr.svg)

## Ne yapmak istiyorsunuz?

| Hedef | Başlangıç |
|---|---|
| Henüz kurmadım | [SE38'de tek dosyalı kurulum](WALKTHROUGH.tr.md#kurulum) |
| Önce veriyi görmek istiyorum | [Yol A: kaydetmeden deneme](WALKTHROUGH.tr.md#onizleme) |
| OB08'e eksik kurları eklemek istiyorum | [Yol B: Olduğu gibi bırak ile ekleme](WALKTHROUGH.tr.md#ilk-kayit) |
| Mevcut kurları TCMB değeriyle güncellemek istiyorum | [Yol B: Güncelle seçimi ve OB08 kontrolü](WALKTHROUGH.tr.md#ilk-kayit) |
| Her gün otomatik çalışsın istiyorum | [Yol C: varyant ve günlük iş](WALKTHROUGH.tr.md#gunluk-kullanim) |
| Bir alanı veya sonucu anlamadım | [Ekran rehberi](EKRAN_REHBERI.tr.md) |
| Bazı satırlar kilit hatası aldı | [Kısmi kayıt ve yeniden deneme](WALKTHROUGH.tr.md#kilit-ve-kismi-kayit) |

## Başlamak için üç şey gerekir

![SAP geliştirme erişimi, kur seçimleri ve SAP sunucusundan TCMB bağlantısı](docs/images/prepare-tr.svg)

1. **SAP erişimi:** SE38'de program oluşturup etkinleştirebilen bir ABAP geliştiricisi olun. [Tek kaynak dosyayı](src/zche_tcmb_load.prog.abap) `ZCHE_TCMB_LOAD` olarak yükleyin. Ayrı installer veya abapGit zorunluluğu yoktur.
2. **Kur seçimleri:** hangi dövizler, hangi SAP kur tipi ve hangi geçerlilik tarihi? FI ayarları ve dönüşüm oranlarını sisteminize göre doğrulayın.
3. **Bağlantı:** SAP uygulama sunucusundan `www.tcmb.gov.tr:443` HTTPS erişimi ve sertifika güveni. Ek sunucu yazılımı, TCMB hesabı veya parola gerekmez. Kendi bilgisayarınızdan siteyi açabilmeniz tek başına yeterli değildir.

**Dil / Language → Türkçe** ile İngilizce SAP oturumunda da programı Türkçe kullanabilirsiniz. SAP'nin standart ekranları kendi oturum dilinde kalabilir.

**Varyant**, aynı seçimleri tekrar kullanmak için sakladığınız ayarlardır. **OB08**, SAP'nin kur bakım ekranıdır; program kaydı yapar, siz burada kontrol edersiniz. İlk denemeyi DEV/deneme sisteminde yapın.

## Kapsam ve doğrulama durumu

- Kurların karşılığı **TRY**'dir; çapraz kur veya muhasebe belgesi oluşturulmaz.
- Test modu varsayılan olarak açıktır. `NEW` / `UPDATED`, testte yapılması planlanan işlemi gösterir.
- Yeni kurulum için özel tablo, domain, data element, global sınıf veya ayrı installer gerekmez. abapGit isteğe bağlıdır.
- **v0.3.0 birleşim adayıdır.** Kodun sözdizimi hedefi ABAP 7.00'dır. Gerçek 7.00/7.01/7.02 sistemlerde çalışması henüz doğrulanmadı.
- **A4H üzerinde görüldü:** TCMB bağlantısı, Türkçe sonuçlar, OB08’de bazı kur kayıtları ve Türkçe varyantla tamamlanan tek seferlik deneme job’ı. [Ekranlarla job kurulumu](WALKTHROUGH.tr.md#gunluk-kullanim).
- **Doğrulaması sürenler:** güncel 48 SAP Unit testi, eski SAP sürümleri, günlük dinamik tarih ve gerçek yazma job’ı. Önceki kilit hatalı dört kayıt hâlâ eksik; son deneme bunları yazmadı. [Doğrulama kaydı](docs/validation-v0.3.0.md).

Türkçe seçimi programın ekran etiketleri, tarih listesi, kendi mesajları ve sonuç listesi başlıklarını kapsar. `NEW` / `ERROR` gibi teknik durum kodları korunur; yanlarında seçilen dilde açıklama gösterilir. SAP GUI menüleri ve SAP/BAPI/işletim sisteminden gelen özgün teknik mesajlar kendi sistem/oturum dilinde kalabilir.

SAP'nin internet erişimi yoksa [sunucu klasöründeki XML dosyalarını okuma](WALKTHROUGH.tr.md#dosyadan-okuma) seçeneği vardır. Dosyaları indirme/hazırlama işlemi projeye dahil değildir.

Önceki çok nesneli sürüm kuruluysa [geçiş notunu](TECHNICAL.tr.md#eski-surumden-gecis) okuyun. SAP'deki eski nesneler otomatik silinmez; eski profil tabloları bu program tarafından kullanılmaz.

## Belgeler

| İhtiyacınız | Belge |
|---|---|
| Kurulum, ilk kullanım, varyant ve günlük iş | [Adım adım rehber](WALKTHROUGH.tr.md) |
| Ekrandaki her alan ve sonuç sütunu | [Ekran rehberi](EKRAN_REHBERI.tr.md) |
| Yerel sınıflar, genişletme ve hata davranışı | [Teknik başvuru](TECHNICAL.tr.md) |
| Kontroller ve SAP kabul testleri | [CONTRIBUTING.md](CONTRIBUTING.md) — İngilizce |
| Değişiklikler | [CHANGELOG.md](CHANGELOG.md) — İngilizce |

MIT lisanslıdır. [Lisans](LICENSE) · [Hata bildirimi](https://github.com/Cheditte/abap-tcmb-rates/issues)
