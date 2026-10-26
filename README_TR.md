# AdventureWorks | Müşteri Tutundurma ve Churn Analitiği

AdventureWorks2022 satış geçmişini kullanarak müşterilerin satın alma davranışlarını, tekrar satın alma eğilimlerini, elde tutulma oranlarını ve geçmiş dönemlerde yeniden alışveriş yapmama durumlarını inceleyen uçtan uca bir veri analitiği projesi. Çalışma; SQL Server şema keşfi ve veri kalitesi kontrollerinden doğrulanmış SQL metriklerine, Python ile istatistiksel analiz ve makine öğrenmesi uygulanabilirlik değerlendirmesine, ardından Power BI veri modeli ve dashboard tasarımına uzanır. Gözlemlenen sipariş dönemi **31 Mayıs 2011 – 30 Haziran 2014** tarihlerini kapsar. Bulgular betimseldir: gözlenen davranışlar varsayımlardan ayrılır ve geçmiş dönemde geri dönmeme durumu kesin, kalıcı müşteri kaybı olarak değerlendirilmez.

## Genel bakış

| Metrik                                             |                             Gözlenen sonuç | Tanım                                                                                                                      |
| -------------------------------------------------- | -------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------- |
| Kayıtlı müşteriler                             |                                       19.820 | İncelenen veri kümesindeki müşteri kayıtları                                                                          |
| Satın alan müşteriler                           |                                       19.119 | Gözlem döneminde en az bir sipariş verenler                                                                              |
| Gözlenen siparişi olmayan kayıtlı müşteriler |                                          701 | Veri kümesinde eşleşen siparişi olmayan kayıtlar                                                                       |
| Siparişler / sipariş kalemleri                   |                             31.465 / 121.317 | Sipariş başlıkları / sipariş detay satırları                                                                         |
| Tek seferlik / tekrarlı satın alanlar            |                               11.649 / 7.470 | Tam olarak bir / en az iki gözlenen sipariş verenler                                                                      |
| Tüm dönem tekrar satın alma oranı              |                                       %39,07 | 19.119 satın alan müşterinin 7.470'i; gözlem dönemiyle sınırlıdır                                                  |
| Ağırlıklı, tam ay bazlı cohort retention      | M1 %1,863; M3 %5,387; M6 %5,986; M12 %10,055 | Her oran yalnızca hedef ayı bütünüyle gözlemlenebilen cohort'ları kapsar; ilgili takvim ayındaki etkinliği ölçer |

Bu doğrulanmış sayılar sipariş başlıkları ve müşteri düzeyindeki popülasyonlara dayanır; sipariş kalemleri ayrı bir veri ayrıntı düzeyinde ele alınır. Veri kümesinde farklı para birimi bağlamları bulunduğu ve ortak dönüşüm yöntemi belirlenmediği için ciro ve ortalama sipariş tutarı (AOV), karşılaştırılabilir KPI'lar olarak sunulmaz.

## Temel bulgular

- **Satın alma davranışı:** Satın alan müşterilerin %39,07'si sınırlı gözlem dönemi içerisinde en az iki sipariş verdi. Tekrar satın alma durumu, gözlenen sipariş sıklığını ifade eder; churn sınıflandırması değildir. [Temel analiz raporu](reports/03_baseline_analysis.md) ve [müşteri davranışı raporu](reports/04_customer_behavior.md).
- **Cohort retention:** Belirli bir takvim ayına ilişkin ağırlıklı elde tutma oranı M1'de düşüktür ve ölçülen aya göre değişir. M12'nin M6'dan yüksek olması mümkündür; çünkü metrik kümülatif geri dönüşü değil, tam olarak ilgili ayda alışveriş yapmayı ölçer. [Cohort analizi](reports/05_retention_cohort_analysis.md).
- **RF segmentasyonu:** **30 Haziran 2014** itibarıyla yakın zamanda alışveriş yapma (recency) ve sipariş sıklığı (frequency) üzerinden altı betimsel müşteri grubu oluşturuldu. Parasal boyut dışarıda bırakıldığından bu çalışma tam RFM değil, RF segmentasyonudur. [Segmentasyon raporu](reports/06_rfm_customer_segmentation.md).
- **Gözlenen yapısal değişim:** Aylık sipariş sayısı Haziran 2013'te 719 iken Temmuz 2013'te 1.740'a yükseldi. Bu, kaydedilen zaman serisinde belirgin bir değişimdir; analiz değişimin nedenini kanıtlamaz. [Temmuz 2013 analizi](reports/07_5_july_2013_structural_break.md).
- **Tarihsel 365 günlük geri dönmeme:** İki farklı kesim tarihindeki gruplar arasında büyük fark vardır: A_2012 grubunda 2.799 müşterinin 2.342'si (%83,673), B_2013 grubunda 6.206 müşterinin 1.050'si (%16,919) takip eden 365 günde geri dönmedi. Gruplar farklı dönem koşullarını yansıtır; bu oranlar doğrudan karşılaştırılabilir nedensel churn tahminleri değildir. A_2012 grubundaki geri dönmeyen 2.342 kişinin 2.003'ü (%85,525) sonraki gözlemlenebilir yılda yeniden alışveriş yaptı. B için sonraki geri dönüş dönemi veri kümesinde gözlemlenemiyor. [Tanım analizi](reports/07_churn_definition_analysis.md) ve [etiket oluşturma raporu](reports/08_churn_label_construction.md).
- **İstatistiksel çıkarım ve modelleme:** İstatistiksel ilişkiler tarihsel kesitler arasında farklılık gösterdi; makine öğrenmesi modellerinin dönemler arası genelleme başarısı güvenilir bulunmadı. Bu çalışma kullanıma hazır bir churn modeli değil, daha fazla veri ve daha net iş tanımları gerektiğini gösteren uygulanabilirlik değerlendirmesidir. [İstatistiksel analiz](reports/09_statistical_analysis.md) ve [ML uygulanabilirlik raporu](reports/10_ml_feasibility.md).

## Araçlar ve iş akışı

**SQL Server / T-SQL → Python (pandas, istatistik, scikit-learn) → Power BI hazırlığı**

SQL sorguları kaynak veritabanının şemasını inceler; müşteri, KPI, cohort, RF, tarihsel etiket, istatistik ve raporlama veri kümelerini yeniden üretilebilir şekilde oluşturur. Python kodları istatistiksel testleri ve kesim tarihi sonrasındaki bilgiyi kullanmayan bir ML uygulanabilirlik deneyini destekler. Power BI dokümantasyonu anlamsal veri modelini, DAX ölçülerini, içe aktarma sırasını ve dashboard sayfalarını tanımlar. Bu depoda yayımlanmış bir dashboard çıktısı bulunmaz.

## Analizleri inceleyin

| Analiz                                    | Temel soru                                                                                                   | Başlıca sonuç                                                                                                                           | Rapor bağlantısı                                                                               |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------- |
| Veritabanı keşfi                        | Müşteri ve sipariş analizini hangi tablolar, anahtarlar ve ilişkiler destekliyor?                        | Şema ve birleştirme yolları AdventureWorks2022 meta verileriyle kontrol edildi.                                                         | [Keşif](reports/01_database_discovery.md)                                                         |
| Veri profilleme ve kalite                 | Hangi popülasyonlar, veri ayrıntı düzeyleri ve sorunlar analizi sınırlandırıyor?                     | Müşteri, sipariş başlığı ve kalemleri ayrıştırıldı; sınırlı tarih aralığı ve para birimi bağlamı dikkate alındı.     | [Veri kalitesi](reports/02_data_quality_report.md)                                                 |
| Temel KPI'lar                             | Gözlenen müşteri/sipariş hacmi ve tekrarlı müşteri oranı nedir?                                      | 19.119 satın alan müşteri; %39,07'si en az iki gözlenen sipariş verdi.                                                                | [KPI tanımları](reports/03_kpi_definitions.md) · [Temel analiz](reports/03_baseline_analysis.md) |
| Müşteri davranışı                    | Müşteriler ne sıklıkla sipariş verdi ve ne zaman geri döndü?                                          | Tekrarlı müşteriler arasında siparişler arası medyan süre 138 gündür; bu betimsel sonuç bir hareketsizlik kuralı değildir.     | [Müşteri davranışı](reports/04_customer_behavior.md)                                          |
| Cohort retention                          | İlk gözlenen satın alma grubundaki müşterilerin ne kadarı belirli bir sonraki takvim ayında aktiftir? | Ağırlıklı oranlar M1 %1,863, M3 %5,387, M6 %5,986, M12 %10,055; tam takip süresi olmayan gelecek aylar gözlemlenmemiş kabul edilir. | [Cohort retention](reports/05_retention_cohort_analysis.md)                                        |
| RF segmentasyonu                          | Son kesim tarihinde yakınlık ve sipariş sıklığına göre müşteriler nasıl gruplanır?               | 30 Haziran 2014 itibarıyla altı grup oluşturuldu; parasal değer puanlanmadı.                                                          | [RF segmentasyonu](reports/06_rfm_customer_segmentation.md)                                        |
| Temmuz 2013 yapısal değişimi           | Haziran–Temmuz 2013 civarında neler değişti?                                                             | Siparişler 719'dan 1.740'a çıktı; zamanlama ve neden konusunda yorum betimsel düzeydedir.                                             | [Yapısal değişim](reports/07_5_july_2013_structural_break.md)                                   |
| Tarihsel churn tanımı                   | 365 günlük hareketsizlik penceresi neyi gösterebilir?                                                     | Kesim tarihindeki uygunluk ve takip süresi koşullarını içeren gözlenen geri dönmeme göstergesi tanımlandı.                       | [Tanım analizi](reports/07_churn_definition_analysis.md)                                          |
| Tarihsel etiketler ve yeniden etkinleşme | Tam gözlemlenebilir iki ayrı 365 günlük takip penceresinde ne oldu?                                      | A_2012 grubunda geri dönmeme sonrasında yeniden etkinleşme yaygındı; B'nin sonraki yılı gözlemlenemiyor.                           | [Etiket oluşturma](reports/08_churn_label_construction.md)                                        |
| İstatistiksel testler                    | Geri dönen ve dönmeyen grupların müşteri özellikleri kesitler arasında değişiyor mu?                | İlişkiler dönemlere göre değişiyor; nedensel kanıt sunmuyor.                                                                        | [İstatistiksel analiz](reports/09_statistical_analysis.md)                                        |
| ML uygulanabilirliği                     | Bilgi sızıntısı önlenerek hazırlanan özellikler farklı tarihsel dönemlere genellenebiliyor mu?      | Dönemler arası performans güvenilir değildi; daha uzun veri geçmişi ve daha açık iş tanımları gerekli.                          | [ML uygulanabilirliği](reports/10_ml_feasibility.md)                                              |
| Power BI hazırlığı                    | Doğrulanmış SQL çıktıları nasıl modellenip raporlanmalı?                                            | Veri modeli, DAX ölçüleri, içe aktarma rehberi ve dashboard tanımı belgelendi.                                                       | [Hazırlık raporu](reports/11_powerbi_preparation.md)                                             |

### Teknik uygulama

- **SQL:** [şema keşfi](sql/01_exploration/01_database_structure.sql), [veri kalitesi](sql/02_data_quality/01_data_quality_checks.sql), [temel KPI&#39;lar](sql/03_kpi/01_baseline_kpis.sql), [müşteri davranışı](sql/04_customer_analysis/01_customer_behavior.sql), [cohort&#39;lar](sql/05_retention/02_cohort_retention.sql), [RF puanlama](sql/06_rfm/03_rf_scoring.sql), [tarihsel etiketler](sql/08_churn_labels/06_churn_labels.sql), [istatistiksel veri kümesi](sql/09_statistics/01_statistical_dataset.sql) ve [Power BI doğrulama/model veri çıkarımları](sql/11_powerbi/).
- **Python:** [istatistiksel analiz](src/analysis/churn_statistics.py), [ML uygulanabilirlik iş akışı](src/ml/churn_feasibility.py), [özellik hazırlama hattı](src/ml/feature_pipeline.py) ve [veritabanı bağlantı yardımcısı](src/database/connection.py).
- **Power BI dokümantasyonu:** [anlamsal model](powerbi/data_model.md), [DAX ölçüleri](powerbi/dax_measures.md), [dashboard tanımı](powerbi/dashboard_specification.md) ve [içe aktarma rehberi](powerbi/import_guide.md).

## Metodoloji ve yorumlama

- **Gözlem aralığı:** Sipariş geçmişi 31 Mayıs 2011'den 30 Haziran 2014'e kadar uzanır. Gözlenen siparişi olmayan müşteriler kayıtlı müşteri sayısına dahil edilir, ancak satın alma sonrası cohort veya satın almaya dayalı churn analizine uygun değildir.
- **İlk gözlenen satın alma grupları:** Cohort ayı, müşterinin bu veri kümesindeki ilk sipariş ayıdır; hayatındaki ilk sipariş ayı olmak zorunda değildir. Gözlem 31 Mayıs'ta başladığından ilk cohort ayı kısmi bir aydır.
- **Tam ay bazlı retention:** Payda, cohort'un başlangıçtaki büyüklüğüdür. Bir cohort yalnızca hedef takvim ayının tamamı Haziran 2014 sonuna kadar gözlemlenebiliyorsa ilgili hesaplamaya katılır. Gözlenen etkinlik yokluğu sıfırdır; veri kesiminden sonraki aylar sıfır değil NULL/boş olarak değerlendirilir. Oranlar uygun cohort'lar arasında ağırlıklandırılır ve belirli aydaki etkinliği ölçer; belirli bir gün aralığındaki kümülatif geri dönüşü değil.
- **Tarihsel 365 günlük geri dönmeme:** A_2012 için kesim tarihi 30 Haziran 2012, B_2013 için 30 Haziran 2013'tür. Her ikisinde de kesim tarihinden sonraki tam gözlemlenebilir yıl değerlendirilir; B'nin takip yılı veri kümesinin bitiş tarihinde sona erer. “Geri dönmeme”, tanımlanan takip penceresinde gözlenen sipariş bulunmaması anlamına gelir ve kalıcı churn'ü kanıtlamaz. A'nın daha sonraki yeniden etkinleşmesi gözlemlenebilir; B'ninki gözlemlenemez.
- **RF kesiti:** Yakınlık ve sıklık grupları, 30 Haziran 2014 itibarıyla satın alan müşteriler için sabittir. Parasal puanlama dışlandığı için çalışmaya tam RFM denmez.
- **Para birimi:** Kaydedilen parasal değerler farklı para birimi bağlamları içerir. Dönüşüm temeli netleşinceye kadar ciro ve AOV, karşılaştırılabilir KPI iddialarından ve Power BI raporlama modelinden çıkarılmıştır.
- **Temmuz 2013:** Sipariş hacmindeki artış gözlenen yapısal bir değişimdir. Analizler kampanya, platform değişikliği veya başka bir nedenin etkisini kanıtlamaz.

## Power BI durumu

GitHub deposundaki Power BI çıktıları **hazırlık ve dokümantasyon** aşamasındadır. Depoda SQL veri çıkarma ve doğrulama sorguları, anlamsal model tasarımı, DAX ölçüleri, içe aktarma rehberi ve dashboard tanımı yer alır. Depoda `.pbix` dosyası veya dashboard ekran görüntüsü bulunmadığından, tamamlanmış ya da yayımlanmış bir dashboard burada sunulmamaktadır.

## Depo yapısı

```text
.
├── queries/                 # Tablo keşif sorgusu
├── reports/                 # Analiz raporları, ML metrikleri ve kalibrasyon grafiği
│   └── figures/
├── sql/                     # Analiz aşamalarına göre salt okunur T-SQL sorguları
│   ├── 01_exploration/
│   ├── 02_data_quality/
│   ├── 03_kpi/
│   ├── 04_customer_analysis/
│   ├── 05_retention/
│   ├── 06_rfm/
│   ├── 07_5_structural_break/
│   ├── 07_churn_definition/
│   ├── 08_churn_labels/
│   ├── 09_statistics/
│   └── 11_powerbi/
├── src/                     # Python bağlantı, analiz ve ML kodları
├── scripts/                 # Ortam/sürücü kontrol betiği
├── notebooks/               # Klasör var; henüz takip edilen notebook dosyası yok
├── powerbi/                 # Model, DAX, dashboard ve içe aktarma dokümanları
├── requirements.txt         # Python bağımlılıkları
├── README.md                # İngilizce ana sayfa
└── README_TR.md             # Türkçe ana sayfa
```

## Yeniden üretilebilirlik

SQL dosyaları T-SQL kullanır ve yapılandırılmış AdventureWorks2022 veritabanıyla çalışmak üzere hazırlanmıştır. Projede bu kaynak veritabanı salt okunur olarak ele alınır. Python bağımlılıklarının adları [`requirements.txt`](requirements.txt) dosyasında listelenmiştir; depoda sürümleri sabitlenmiş bir ortam veya veri dışa aktarımı bulunmaz.

Yerel veritabanı yapılandırması bağlantı yardımcısı üzerinden yürütülür. Kimlik bilgilerini yerel ortam değişkenlerinde veya Git tarafından takip edilmeyen bir `.env` dosyasında tutun; `.env`, [`.gitignore`](.gitignore) içerisinde yer alır. Kimlik bilgilerini depoya göndermeyin, notebook'lara, raporlara veya Power BI sorgu metinlerine yapıştırmayın. Mevcut betiklerin ve analizlerin çalışması için uyumlu yerel SQL Server/ODBC kurulumu ve AdventureWorks veritabanına erişim gerekir.

## Kısıtlar

- Satış geçmişi sınırlıdır ve 2014'te sona erer; sonraki davranışlar mevcut değildir ve yakın tarihli müşterilerin izleme süreleri sağdan sansürleme sorununa tabidir.
- “İlk gözlenen” satın alma, müşterinin hayatındaki ilk satın alma olmayabilir. Siparişi olmayan müşteriler satın alma sonrası retention açısından değerlendirilemez.
- Sabit 365 günlük geri dönmeme etiketi tarihsel bir göstergedir; A_2012 grubunda görüldüğü gibi daha sonra yeniden alışveriş gerçekleşebilir.
- A_2012 ve B_2013 gruplarının müşteri bileşimleri ve gözlenen dönem koşulları farklıdır; oranları nedensel karşılaştırma değildir.
- ML değerlendirmesi tarihseldir ve dönemler arası genelleme güvenilir olmamıştır. Model, kullanıma hazır churn sistemi değil uygulanabilirlik çalışmasıdır.
- Müşteri yapısı ve ürün hiyerarşisi tarihsel geçerlilik aralıklarıyla tutulan kayıtlar yerine mevcut eşleştirmeleri kullanır; parasal karşılaştırılabilirlik çözülmemiştir.
- Gözlemsel örüntüler ve istatistiksel ilişkiler nedenleri ya da müdahale etkilerini kanıtlamaz.


### Power BI Dashboard

[Open the Power BI report (.pbix)](powerbi/AdventureWorks_Customer_Analytics.pbix)

![Executive Overview](assets\dashboard\01_executive_overview.png)

## Projenin değeri

Bu proje denetlenebilir bir analitik iş akışını gösterir: doğrulanmış kaynak ilişkileri, açıkça belirlenmiş veri ayrıntı düzeyleri ve paydalar, bağımsız KPI mutabakatı, kesim tarihi ve gözlemlenebilirlik koşullarını dikkate alan retention/etiket hesaplamaları ve sınırları dürüstçe belirtilmiş istatistiksel/ML yorumları. Verilerin izin verdiğinden daha güçlü iddialarda bulunmadan sonraki adımları da ortaya koyar: parasal metrik tanımlarını netleştirmek, daha uzun ve tutarlı bir veri geçmişi sağlamak ve gelecekteki tahminleri temsili bir ileriye dönük dönemde doğrulamak.
