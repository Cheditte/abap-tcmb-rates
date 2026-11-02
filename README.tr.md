# TCMB kurlarını SAP'ye aktarın

> [English](README.md) | **Türkçe**

Türkiye Cumhuriyet Merkez Bankasının (TCMB) yayımladığı günlük döviz kurlarını SAP'ye almak istiyorsanız bu projeyi kullanabilirsiniz. Hangi para birimlerinin alınacağını, alış veya satış kurunun kullanılacağını ve kurların hangi tarihten itibaren geçerli olacağını siz seçersiniz.

**Akış basit:** SAP, TCMB'nin günlük bültenini okur. Seçimlerinize göre hazırladığı sonucu önce kaydetmeden gösterir. Kontrol ettikten sonra kayıt yaparsınız; oluşan döviz kurlarını SAP'de **OB08** işleminden doğrularsınız.

![TCMB günlük bülteni ve profil seçimlerinden ön izlemeye, ardından kullanıcının kararıyla OB08 kaydına giden akış](docs/images/overview-tr.svg)

## Başlamak için ne gerekiyor?

Kurulumu yapacak kişinin SE38'de program oluşturup çalıştırabilen bir **ABAP geliştiricisi** olduğunu varsayıyoruz. Aşağıdaki hazırlıklardan hepsini, yetkiniz ve erişiminiz varsa kendiniz tamamlayabilirsiniz. Gerektiğinde FI veya Basis/ağ sorumlusuyla ilerleyebilirsiniz.

![Başlamak için üç hazırlık: SAP geliştirme erişimi, hangi kurların alınacağına ilişkin kararlar ve SAP'den TCMB'ye HTTPS bağlantısı](docs/images/prepare-tr.svg)

Normal HTTPS kullanımında SAP sunucusuna yardımcı uygulama kurmanız gerekmez. **TCMB hesabı, şifre veya API anahtarı da gerekmez.** SAP uygulama sunucusunun `www.tcmb.gov.tr:443` adresine erişimi ve sertifika güveni gerekir. Bilgisayarınızdan siteyi açabilmeniz, SAP'nin de erişebildiğini göstermez.

## Kurulumdan ilk kullanıma

abapGit kullanmadan, **tek bir dosyayı SE38'e yükleyerek** başlayabilirsiniz. Üç programın görevi farklıdır:

| Sıra | SE38'de açacağınız program | Yapacağınız işlem |
|---|---|---|
| 1 · Kurun | `ZCHE_TCMB_INSTALL` | İndirdiğiniz tek dosyayla SAP nesnelerini kendi paketinize oluşturun. |
| 2 · Ayarlayın | `ZCHE_TCMB_CONFIG` | Para birimi, kur tipi ve tarih seçimlerinizi bir profile kaydedin. |
| 3 · Kullanın | `ZCHE_TCMB_LOAD` | Profili ve bülten tarihini seçin; önce test edin, sonra isterseniz kaydedin. |

**Profil**, her seferinde yeniden girmemek için kaydettiğiniz ayar grubudur. İlk profilinizi kendiniz oluşturursunuz; hazır profil gelmez. Kurulum ve profil kaydı, döviz kuru kaydetmez. Kurlar üçüncü programdan, test işaretini kaldırdığınızda yazılır.

**[Ekran görüntüleriyle adım adım kurulum ve kullanım →](WALKTHROUGH.tr.md)**

[Tek dosyalı kurulum dosyasını açın / kaydedin](https://raw.githubusercontent.com/Cheditte/abap-tcmb-rates/main/installer/zche_tcmb_install.prog.abap). SE38'de oluşturacağınız programın adı `ZCHE_TCMB_INSTALL` olmalı; dosyayı yüklemek ve ilk kontrolleri yapmak için rehberi izleyin.

İlk denemeyi DEV/deneme sisteminde, **tek gün ve az sayıda para birimiyle** yapın. Sonucu doğruladıktan sonra günlük kullanımı bir SAP arka plan işi olarak planlayabilirsiniz.

## Kapsam ve mevcut durum

- Kurların karşılığı **TRY**'dir. Farklı para birimleri arasında çapraz kur üretmez; muhasebe belgesi oluşturmaz. SAP'nin standart döviz kuru kayıtlarını BAPI ile yükler.
- Test modu varsayılan olarak açıktır. Testte `NEW` / `UPDATED` görmek, kayıt yapıldığı anlamına gelmez.
- Installer **temiz ilk kurulum** içindir. Aynı isimli nesne varsa durur; üzerine yazmaz veya güncelleme yapmaz. Sonraki sistemlere normal transport süreciyle taşıyın.
- **Ön sürüm: v0.1.** Ayrı test adlarıyla SAP kurulumu tamamlandı; son ayar kaydı, transport ve uçtan uca kabul kontrolleri bekliyor. 7.40 SP08 ve 7.58 statik kontrolleri, bu sürümlerde çalışma garantisi değildir. [Test kapsamı ve açık kontroller](docs/validation-2026-11-02.md).

SAP'nin internet erişimi yoksa, önceden SAP sunucusundaki klasöre konulan XML dosyalarını okuyan [alternatif yol](WALKTHROUGH.tr.md#dosyadan-okuma) vardır. Dosyaları indirme/hazırlama işlemi projeye dahil değildir.

## Hangi belgeyi okuyayım?

| İhtiyacınız | Belge |
|---|---|
| Kurmak, ayarlamak ve ilk çalıştırmayı yapmak | [Kurulum ve kullanım rehberi](WALKTHROUGH.tr.md) |
| Bütün alanlar, kendi ABAP kodunuzdan çağırma ve genişletme | [Teknik başvuru](TECHNICAL.tr.md) |
| Test çalıştırmak veya katkı vermek | [CONTRIBUTING.md](CONTRIBUTING.md) — İngilizce |
| Değişiklikleri görmek | [CHANGELOG.md](CHANGELOG.md) — İngilizce |

MIT lisanslıdır. [Lisans](LICENSE) · [Hata bildirimi / öneri](https://github.com/Cheditte/abap-tcmb-rates/issues)
