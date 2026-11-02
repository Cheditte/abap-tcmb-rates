# Verification / Doğrulama

Checks performed on 2 November 2026 for v0.3.0. “Current” includes the write-authorization, URL and folder checks; earlier write results are identified separately. / Kontroller v0.3.0 için 2 Kasım 2026 tarihindedir. “Güncel”, yazma yetkisi, adres ve klasör kontrollerini içeren kaynağı belirtir; önceki kayıt sonuçları ayrıca işaretlidir.

| Check / Kontrol | System and revision / Sistem ve revizyon | Date / Tarih | Result / Sonuç |
|---|---|---|---|
| Static checks / Statik kontroller | Current; abaplint 2.120.92, v700 | 2026-11-02 | 0 lint issues; source checks and manual classic-syntax scan passed. / Lint, kaynak kontrolü ve elle eski sözdizimi taraması geçti. |
| Activation / Etkinleştirme | SAP ABAP Platform 2023, SAP_BASIS 7.58; current | 2026-11-02 | Active without warnings. / Uyarısız etkinleşti. |
| ABAP Unit | SAP_BASIS 7.58; current | 2026-11-02 | **55/55 passed**, 8 test classes. / 8 test sınıfında **55/55 geçti**. |
| Connection / Bağlantı | SAP_BASIS 7.58; current | 2026-11-02 | Bulletin 2026/205 dated 2026-11-02 read; 22 currencies. / 2 Kasım bülteni ve 22 para birimi okundu. |
| Selection validation / Seçim kontrolü | SAP_BASIS 7.58; current | 2026-11-02 | External HTTPS URL and a folder containing `..` rejected before execution. / Dış adres ve `..` içeren klasör seçim ekranında reddedildi. |
| Preview day/period / Günlük ve dönem denemesi | SAP_BASIS 7.58 | 2026-11-02 | Current: 2026-10-30 USD, 1 UNCHANGED, 0 errors, no writes. Earlier revision: July USD/EUR period, 0 errors. / Güncel: tek gün USD, 1 UNCHANGED, 0 hata; kayıt yapılmadı. Önceki revizyon: Temmuz USD/EUR dönemi, 0 hata. |
| Actual write + OB08 / Gerçek kayıt + OB08 | SAP_BASIS 7.58; earlier v0.3.0 revision | 2026-11-02 | Limited EUR records checked in OB08; range included partial lock failures. Not repeated with the new preflight. / Sınırlı EUR kaydı OB08'de görüldü; dönemde kısmi kilit hataları vardı. Yeni ön kontrolle tekrar yapılmadı. |
| Equal rerun / Aynı kayıtla tekrar | SAP_BASIS 7.58; current | 2026-11-02 | UNCHANGED observed in one-day preview. / Tek günlük denemede UNCHANGED görüldü. |
| Background job / Arka plan işi | SAP_BASIS 7.58; current | 2026-11-02 | One-off preview Finished; 0 errors. Turkish log and spool: 2026-11-02 USD/TRY, 1 planned NEW row; no writes. / Tek seferlik deneme tamamlandı; 0 hata. Türkçe log/spool, güncel tarih, 1 planlanan yeni kayıt; kur yazılmadı. |
| Dynamic-date variant / Dinamik tarihli varyant | SAP_BASIS 7.58; current | 2026-11-02 | D → Current Date saved; reload changed 2026-10-30 to 2026-11-02. Job spool confirmed current date. / D → Current Date kaydedildi; yeniden çağırmada tarih bugüne döndü, job spool'unda doğrulandı. |
| Restricted user / Yetkisiz kullanıcı | Current | — | Pending. BAPI checks remain; new write preflight and dataset denial require tests with restricted users. / Bekliyor. Yeni yazma ön kontrolü ve dosya yetki reddi kısıtlı kullanıcıyla denenmeli. |
| SAP_BASIS 7.00–7.02 | ECC 6.0 | — | Not yet tested on these systems. / Bu sistemlerde henüz denenmedi. |

## Known limits / Bilinen sınırlar

- `P_INV` has only been exercised on the S/4HANA 2023 test environment. / Yalnız S/4HANA 2023 deneme ortamında görüldü.
- A range is not atomic; commits happen per row. / Tarih aralığı atomik değildir; commit satır satır yapılır.
- Turkish text may display incorrectly on non-Unicode systems without a Turkish code page; choose English. / Türkçe kod sayfası olmayan Unicode dışı sistemlerde English seçilebilir.
- Updating the source replaces local `LCL_EXIT` changes; preserve and reapply them. / Güncelleme, yerel `LCL_EXIT` değişikliklerini ezer; koruyup yeniden uygulayın.
