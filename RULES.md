# RULES.md: Minimalist Tasarım ve Mühendislik Prensipleri

Bu belge; geliştirilen herhangi bir yazılım, sistem veya kullanıcı arayüzü için geçerli olan temel tasarım, mimari ve etkileşim anayasasıdır. Her kural bağlayıcıdır ve tavizsiz uygulanır.

---

## 1. Varlık Nedeni ve Özcülük (Essentialism)

### Radikal Eleme (Less, but better)
- Çekirdek amaca doğrudan hizmet etmeyen hiçbir özellik, bileşen veya ayar sisteme dahil edilemez.
- Bir özelliğin "kullanışlı olabilme ihtimali", var olması için geçerli bir gerekçe değildir.
- Mükemmellik; eklenecek bir şey kalmadığında değil, çıkarılacak hiçbir şey kalmadığında elde edilir.

### Sıfır Sürtünme ve Bilişsel Ekonomi (Hick's Law)
- Kullanıcının karar verme süresi ve bilişsel yükü asgari düzeyde tutulmalıdır.
- Aynı amaca çıkan birden fazla yol veya birbiriyle anlamsal olarak çelişen parametreler sunulmaz. Karşılıklı dışlayıcı durumlar sistem tarafından otomatik yönetilir.

---

## 2. Bilgi Tasarımı ve Görsel Disiplin

### Katı 3 Renk Disiplini (Strict 3-Color Rule)
- Renk paleti tavizsiz olarak yalnızca 3 ton ile sınırlandırılır: **Siyah**, **Gri** ve **Beyaz**.
- Dördüncü bir renge (renkli butonlar, kırmızı uyarılar, mavi vurgular, sarı rozetler) kesinlikle izin verilmez.
- Renk bir süs değil, 3 kademeli bir durum makinesidir (state machine):
  - **Zemin (Negatif Alan):** Arayüzün var olduğu taban.
  - **Ön Plan (Aktif Durum):** En yüksek kontrastı taşıyan aktif veri, odak ve birincil eylemler.
  - **Nötr Ton (Meta/Pasif Durum):** İkincil bilgiler, meta-veriler, devre dışı veya arka plandaki durumlar.
- Vurgu veya hiyerarşi renk değiştirerek değil; yalnızca doluluk oranı, opaklık, font ağırlığı ve kontrast ile ifade edilir.

### Maksimum Veri-Mürekkep Oranı (Data-Ink Ratio)
- Ekrandaki her piksel ve her karakter doğrudan bir durum (state) veya veri taşımalıdır.
- Sırf boşluk doldurmak veya ayrıştırmak için dekoratif kutular, süsleyici çerçeveler, gölgeler veya yapay çizgiler kullanılmaz.
- Ayrıştırma; negatif alan, tipografik hiyerarşi ve kontrast ile sağlanır.

### Katı Izgara ve Geometrik Hizalama (Grid Discipline)
- Görsel öğeler rastgele yerleştirilemez. Tüm bileşenler matematiksel olarak tanımlanmış, kilitli eksen koordinatlarına oturmalıdır.
- Elemanların birbiriyle olan mesafeleri önceden belirlenmiş sabit katsayılar üzerinden türetilir.

### Tipografik ve Geometrik Saflık
- Anlamsal belirsizlik yaratan piktogramlar ve süslü ikon kütüphaneleri yerine, evrensel geometrik ilkel formlar ve saf tipografi kullanılır.
- Tipografi yalnızca metin okutmak için değil, arayüzün kendisini inşa eden birincil yapı taşıdır.

### Doğal Malzeme Derinliği (Material Physics)
- Yapay arka plan renk katmanları yerine ortamın doğal malzemesi ve derinliği (saydamlık, ışık yansıması, mikro-kontur) kullanılır.

---

## 3. Etkileşim ve Durum Geçişleri

### Modal ve Kesinti Yasağı
- Kullanıcının akışını kesen, odağını zorla gasp eden açılır onay pencereleri (modal dialogs / alerts) yasaktır.
- Kritik işlemler geri alınabilir (reversible) tasarlanmalı veya iki aşamalı yerinde doğrulama (in-place confirmation) ile akış bozulmadan çözülmelidir.

### Sıfır Yerleşim Kayması (Zero Layout Shift)
- Dinamik olarak beliren veya fare hareketiyle ortaya çıkan eylemler için önceden sabit alan rezerve edilir.
- Hiçbir etkileşim komşu elemanların fiziksel koordinatlarını zıplatamaz veya kaydıramaz.

### Doğal ve Fiziksel Tepkisellik
- Durum değişimleri doğrusal (linear) değil; fizik tabanlı yaylanma (spring physics) dinamikleriyle hissettirilir.
- Animasyonlar kullanıcıyı bekleten bir gösteri değil, işlemin gerçekleştiğini bildiren mikro-geri bildirimlerdir (150ms – 250ms aralığı).

---

## 4. Yazılım Mimarisi ve Mühendislik Standartları

### Sıfır Gereksiz Bağımlılık (Zero External Dependencies)
- Sistemin çekirdek yetenekleri için harici paket veya kütüphane eklenmez.
- Öncelikle çalışma ortamının ve platformun yerel (native) yetenekleri kullanılır. Her harici bağımlılık bir bakım, güvenlik ve performans borcudur.

### Tüy Sıklet Çıktı (Featherweight Footprint)
- Derleme çıktısı, bellek kullanımı ve kaynak tüketimi milisaniyelik açılış ve anında tepki verecek şekilde en alt düzeyde tutulmalıdır.

### Yerel Öncelikli Mimari (Local-First Architecture)
- Sistem hiçbir zaman ağ gecikmesine veya dış servislerin yanıt süresine bağımlı olarak bloke olamaz.
- Okuma ve yazma işlemleri anında yerel katmanda gerçekleşir; dış senkronizasyonlar arka planda asenkron yürütülür.

### Tekil Doğruluk Kaynağı ve Tek Yönlü Akış (Single Source of Truth)
- Durum yönetimi merkezi, deterministik ve reaktif olmalıdır.
- Görünüm katmanı durumu doğrudan değiştiremez; değişiklikler açık niyetler (intent / action) üzerinden merkezi servise iletilir.

### Tahribatsız Mutasyon (Non-Destructive Operations)
- Kullanıcı verisi varsayılan olarak geri dönüşsüz şekilde anında imha edilmez.
- "Silme" işlemleri bir arşivleme/durum gizleme adımıdır; geri yüklenebilirlik her zaman ilk savunma hattıdır.

---

## 5. Veri Mülkiyeti ve Birlikte Çalışabilirlik

### Kullanıcı Egemenliği (No Vendor Lock-in)
- Kullanıcının ürettiği veri hiçbir zaman kapalı, özel veya tescilli bir yapıya hapsedilmez.
- Veri; standart, insan tarafından okunabilir ve evrensel açık formatlarda tutulmalı; tek hamlede kopyalanabilir ve dışa aktarılabilir olmalıdır.
