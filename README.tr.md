# TCMB kurlarını tek bir SAP programıyla alın

> [English](README.md) | **Türkçe**

Türkiye Cumhuriyet Merkez Bankasının (TCMB) günlük döviz kurlarını SAP'ye almak istiyorsanız bu projeyi kullanabilirsiniz. Hangi para birimlerini alacağınızı, alış veya satış kurunu ve geçerlilik tarihini siz seçersiniz.

**Tek dosyayı SE38'e yapıştırın, etkinleştirin ve çalıştırın.** Bütün ayarlar aynı programın seçim ekranındadır. Tekrar kullanacağınız seçimleri SAP'nin standart **varyant** özelliğiyle saklarsınız.

**İngilizce SAP oturumunda da Türkçe kullanabilirsiniz.** Programdaki **Dil / Language (`P_LANG`)** alanından **Türkçe** seçin; oturumdan çıkmanız gerekmez. Dil seçimi varyantla birlikte saklanır. Varsayılan **Otomatik / Logon language**, Türkçe oturumda Türkçe, diğer oturumlarda İngilizce kullanır.

![TCMB bülteninden seçim ekranına, kaydetmeden ön izlemeye ve kontrollü OB08 kaydına giden kullanım akışı](docs/images/overview-tr.svg)

## Başlamak için gerekenler

Kurulumu yapacak kişinin SE38'de program oluşturup çalıştırabilen bir **ABAP geliştiricisi** olduğunu varsayıyoruz. FI ve bağlantı işlemlerini yetkiniz varsa kendiniz, gerektiğinde ilgili sorumluyla tamamlayabilirsiniz.

![SAP geliştirme erişimi, kur seçimleri ve SAP sunucusundan TCMB bağlantısı](docs/images/prepare-tr.svg)

SAP uygulama sunucusundan **`www.tcmb.gov.tr:443`** adresine HTTPS erişimi ve güncel sertifika zincirine güven gerekir. Kendi bilgisayarınızdan siteyi açmanız yeterli değildir. Normal HTTPS yolunda sunucuya ek yazılım kurulmaz; TCMB hesabı, şifre veya API anahtarı gerekmez.

## Kurulumdan ilk kullanıma

| Adım | Yapacağınız işlem | Sonuç |
|---|---|---|
| 1 · Kurun | Tek kaynak dosyayı SE38'de `ZCHE_TCMB_LOAD` programına yükleyip etkinleştirin. | Tek çalıştırılabilir program. |
| 2 · Seçin | Aynı ekranda para birimlerini, kur tipini ve tarih kuralını belirleyin; isterseniz varyant kaydedin. | Tekrar kullanılabilen seçimler. |
| 3 · Deneyin | Tek gün ve birkaç para birimiyle test modunda çalıştırın. | Kaydetmeden görebileceğiniz sonuç listesi. |
| 4 · Doğrulayın | Kontrol ettikten sonra test işaretini kaldırın; kaydı OB08'de doğrulayın. | SAP'nin standart döviz kuru kayıtları. |

**[Ekran görüntüsü ve diyagramlarla adım adım rehber →](WALKTHROUGH.tr.md)**

**[Tek programın kaynak dosyasını açın / kaydedin](src/zche_tcmb_load.prog.abap)**

**Varyant**, seçim ekranındaki değerleri saklar; günlük iş için de kullanılabilir. **OB08**, SAP'de döviz kurlarını görüntüleyip bakımını yaptığınız işlemdir. Varyant kaydetmek döviz kuru yazmaz.

## Kapsam ve doğrulama durumu

- Kurların karşılığı **TRY**'dir; çapraz kur veya muhasebe belgesi oluşturulmaz.
- Test modu varsayılan olarak açıktır. `NEW` / `UPDATED`, testte yapılması planlanan işlemi gösterir.
- Yeni kurulum için özel tablo, domain, data element, global sınıf veya ayrı installer gerekmez. abapGit isteğe bağlıdır.
- **v0.3.0 birleşim adayıdır.** Kodun sözdizimi hedefi ABAP 7.00'dır. Gerçek 7.00/7.01/7.02 sistemlerde çalışması henüz doğrulanmadı.
- Devir notunda A4H deneme sisteminde 34 test ve sınırlı gerçek kur yazma sonuçları bildirildi. Birleştirme ve dil değişiklikleriyle 48 teste ulaşan güncel sürüm SAP'de tekrar doğrulanmayı bekliyor. Yenilenen ekran, dil seçiminin varyantla yüklenmesi ve arka plan dili henüz kabul testi bekliyor. [Doğrulama kaydı](docs/validation-v0.3.0.md).

Türkçe seçimi programın ekran etiketleri, tarih listesi, kendi mesajları ve sonuç listesi başlıklarını kapsar. `NEW` / `ERROR` gibi teknik durum kodları korunur; yanlarında seçilen dilde açıklama gösterilir. SAP GUI menüleri ve SAP/BAPI/işletim sisteminden gelen özgün teknik mesajlar kendi sistem/oturum dilinde kalabilir.

SAP'nin internet erişimi yoksa [sunucu klasöründeki XML dosyalarını okuma](WALKTHROUGH.tr.md#dosyadan-okuma) seçeneği vardır. Dosyaları indirme/hazırlama işlemi projeye dahil değildir.

Önceki çok nesneli sürüm kuruluysa [geçiş notunu](TECHNICAL.tr.md#eski-surumden-gecis) okuyun. SAP'deki eski nesneler otomatik silinmez; eski profil tabloları bu program tarafından kullanılmaz.

## Belgeler

| İhtiyacınız | Belge |
|---|---|
| Kurulum, ilk kullanım, varyant ve günlük iş | [Adım adım rehber](WALKTHROUGH.tr.md) |
| Alanlar, yerel sınıflar, genişletme ve hata davranışı | [Teknik başvuru](TECHNICAL.tr.md) |
| Kontroller ve SAP kabul testleri | [CONTRIBUTING.md](CONTRIBUTING.md) — İngilizce |
| Değişiklikler | [CHANGELOG.md](CHANGELOG.md) — İngilizce |

MIT lisanslıdır. [Lisans](LICENSE) · [Hata bildirimi](https://github.com/Cheditte/abap-tcmb-rates/issues)
