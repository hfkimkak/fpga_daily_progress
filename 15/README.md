# DC Motor Speed Control System

Bu proje, FPGA tabanlı bir DC motor hız kontrol sistemi gerçekleştirmektedir. PID (Proportional-Integral-Derivative) kontrolcü kullanarak, motor hızını istenen değerde sabit tutmayı amaçlamaktadır.

## Proje Yapısı

Proje aşağıdaki VHDL modüllerinden oluşmaktadır:

1. **PID Kontrolcü** (`pid_controller.vhd`): Hız hatasını ölçerek motorun hızını düzenlemek için gereken kontrol sinyalini üreten modül.
2. **Motor Sürücü** (`motor_driver.vhd`): PWM (Pulse Width Modulation) sinyali ve yön kontrolü sağlayan, ayrıca encoder geri beslemesini işleyen modül.
3. **Ana Kontrol Sistemi** (`motor_control_system.vhd`): PID kontrolcü ve motor sürücü modüllerini entegre eden üst düzey modül.
4. **Test Düzeneği** (`motor_control_system_tb.vhd`): Sistemin doğru çalıştığını doğrulamak için encoder geri beslemesini simüle eden test düzeneği.

## Özellikler

### PID Kontrolcü
- Ayarlanabilir P, I ve D kazançları
- Anti-windup koruması
- Sabit noktalı aritmetik işlemler
- Ayarlanabilir örnekleme hızı
- Yapılandırılabilir çıkış sınırları
- Hız ve pozisyon modları

### Motor Sürücü
- PWM sinyali üretimi
- Enkoder arayüzü
- Yön kontrolü
- Frenleme kontrolü
- Hız hesaplaması
- Hata tespiti (örn. sıkışma durumu)

### Sistem Entegrasyonu
- Kullanıcı arayüzü (hız ayarı, yön, etkinleştirme)
- Hata durumu izleme
- Durum çıkışları (mevcut hız, PID hatası)
- Hata ayıklama desteği

## Kullanım

### Parametre Ayarları

Sistem, aşağıdaki parametreler üzerinden özelleştirilebilir:

- `CLK_FREQ_HZ_g`: Sistem saat frekansı
- `SAMPLE_FREQ_HZ_g`: PID örnekleme frekansı
- `PWM_FREQ_HZ_g`: PWM frekansı
- `DATA_WIDTH_g`: Veri genişliği
- `FRAC_WIDTH_g`: Kesirli kısım genişliği
- `KP_g`, `KI_g`, `KD_g`: PID kazanç değerleri
- `MAX_SPEED_RPM_g`: Maksimum motor hızı (RPM)
- `ENC_COUNTS_PER_REV_g`: Enkoder darbe sayısı/devir
- `DEADBAND_g`: PWM ölü bant değeri

### Arayüz Tanımı

#### Girişler
- `clk_i`: Sistem saati
- `reset_n_i`: Aktif düşük sıfırlama sinyali
- `speed_setpoint_i`: Hedef hız değeri
- `direction_i`: Yön kontrolü ('0' = CCW, '1' = CW)
- `enable_i`: Sistem etkinleştirme
- `encoder_a_i`, `encoder_b_i`: Enkoder sinyal girişleri

#### Çıkışlar
- `pwm_out_o`: PWM çıkışı
- `dir_out_o`: Motor yön çıkışı
- `brake_out_o`: Frenleme çıkışı
- `current_speed_o`: Mevcut hız ölçümü
- `speed_valid_o`: Hız ölçümü geçerlilik işareti
- `error_o`: Hata durumu işareti
- `pid_error_o`, `pid_output_o`, `encoder_count_o`: Hata ayıklama çıkışları

## Test Senaryoları

Testbench, aşağıdaki senaryoları doğrulamak için tasarlanmıştır:

1. **Temel Hız Kontrolü**: Motorun belirli bir hıza ulaşabilmesi
2. **Hız Değişikliği**: Motor hızı değişimlerine uyum sağlama
3. **Yön Değişikliği**: Motor dönüş yönünü değiştirme
4. **Durdurma ve Başlatma**: Motorun durdurulup yeniden başlatılması
5. **PID Yanıtı**: PID kontrolörünün bozucu etkilere karşı tepkisi

## Uygulama Alanları

- Hassas motor kontrolü gerektiren robotik sistemler
- CNC makineleri ve 3D yazıcılar
- Konveyör sistemleri
- Fan ve pompa kontrolü
- Hassas pozisyonlama sistemleri

## Geliştirme Önerileri

- Otomatik PID ayarlama özelliği eklenebilir
- Farklı motor tipleri için destek sağlanabilir
- Haberleşme arayüzü (SPI, I2C, UART) eklenebilir
- Durum makinesi monitörü eklenebilir
- Gelişmiş hata yönetimi ve raporlama eklenebilir

## Referanslar

1. PID Control Theory: https://en.wikipedia.org/wiki/PID_controller
2. DC Motor Control: https://www.electronics-tutorials.ws/io/io_7.html
3. Quadrature Encoders: https://www.dynapar.com/technology/encoder_basics/quadrature_encoder/
4. PWM Control: https://www.electronics-tutorials.ws/blog/pulse-width-modulation.html 