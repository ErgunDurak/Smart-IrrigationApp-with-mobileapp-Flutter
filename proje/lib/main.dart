import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        scaffoldBackgroundColor: Colors.grey[300],
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BosSayfa(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.water, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "RainDrop",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text("Hoş Geldiniz!", style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  final int wateringDuration;
  final double targetMoisture;
  final String? selectedFruit;

  const AnaSayfa({
    super.key,
    required this.wateringDuration,
    required this.targetMoisture,
    this.selectedFruit,
  });

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  bool isStarted = false;
  String systemStatus = "Sistem Beklemede";
  String weatherDescription = '';
  double temperature = 0.0;
  String weatherIcon = '';
  double soilMoisture = 0.0;
  Timer? _timer;

  final String apiKey = 'ad5da9d4e3bf4f159ab9eb4a324a3835';
  final double latitude = 40.137416; //enlem
  final double longitude = 29.978222; //boylam

  final Map<String, String> weatherTranslation = {
    "clear sky": "Açık hava",
    "few clouds": "Az bulutlu",
    "scattered clouds": "Parçalı bulutlu",
    "broken clouds": "Çok bulutlu",
    "overcast clouds": "Kapalı hava",
    "shower rain": "Sağanak yağış",
    "light rain": "Hafif yağmur",
    "moderate rain": "Orta şiddette yağmur",
    "heavy intensity rain": "Şiddetli yağmur",
    "thunderstorm": "Fırtına",
    "snow": "Kar yağışlı",
    "mist": "Sisli",
    "fog": "Sis",
    "haze": "Puslu hava",
    "drizzle": "Çiseleyen yağmur",
  };

  List<Map<String, dynamic>> forecastList = [];

  @override
  void initState() {
    super.initState();
    getWeatherData();
    getForecastData();
    getSensorData();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      getSensorData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> showNotification(String message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'soil_moisture_channel',
      'Soil Moisture Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Uyarı!',
      message,
      platformDetails,
    );
  }

  void getWeatherData() async {
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=tr');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String description = data['weather'][0]['description'];
        String iconCode = data['weather'][0]['icon'];

        setState(() {
          weatherDescription = weatherTranslation[description] ?? description;
          temperature = data['main']['temp'];
          weatherIcon = iconCode;
        });
      }
    } catch (e) {
      print('Hata: $e');
    }
  }

  void getForecastData() async {
    final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/forecast?lat=$latitude&lon=$longitude&appid=$apiKey&units=metric&lang=tr');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        List list = data['list'];
        Map<String, double> dailyMaxTemperatures = {};
        Map<String, String> dailyIcons = {};
        Map<String, bool> addedDates = {};
        List<Map<String, dynamic>> newForecast = [];
        DateTime now = DateTime.now();
        DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);

        for (var item in list) {
          String dtTxt = item['dt_txt'];
          DateTime forecastDate = DateTime.parse(dtTxt);
          String dateKey =
              "${forecastDate.year}-${forecastDate.month.toString().padLeft(2, '0')}-${forecastDate.day.toString().padLeft(2, '0')}";

          if (forecastDate.isAfter(now) &&
              forecastDate.isAfter(tomorrow.subtract(Duration(hours: 1)))) {
            double temp = item['main']['temp'].toDouble();
            String icon = item['weather'][0]['icon'];

            if (dailyMaxTemperatures.containsKey(dateKey)) {
              if (temp > dailyMaxTemperatures[dateKey]!) {
                dailyMaxTemperatures[dateKey] = temp;
                dailyIcons[dateKey] = icon;
              }
            } else {
              dailyMaxTemperatures[dateKey] = temp;
              dailyIcons[dateKey] = icon;
            }
          }
        }

        dailyMaxTemperatures.forEach((dateKey, maxTemp) {
          DateTime date = DateTime.parse(dateKey);
          if (date.isAfter(tomorrow.subtract(Duration(hours: 1))) &&
              newForecast.length < 3) {
            String day = getTurkishDayName(date.weekday);
            newForecast.add({
              'day': day,
              'temp': maxTemp,
              'icon': dailyIcons[dateKey],
            });
          }
        });

        newForecast.sort((a, b) {
          DateTime dateA = DateTime.parse(dailyMaxTemperatures.keys
              .firstWhere((k) => dailyMaxTemperatures[k] == a['temp']));
          DateTime dateB = DateTime.parse(dailyMaxTemperatures.keys
              .firstWhere((k) => dailyMaxTemperatures[k] == b['temp']));
          return dateA.compareTo(dateB);
        });

        if (newForecast.length > 3) {
          newForecast = newForecast.sublist(0, 3);
        }

        setState(() {
          forecastList = newForecast;
        });
      }
    } catch (e) {
      print('Tahmin verisi alınamadı: $e');
    }
  }

  String getTurkishDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Pazartesi';
      case 2:
        return 'Salı';
      case 3:
        return 'Çarşamba';
      case 4:
        return 'Perşembe';
      case 5:
        return 'Cuma';
      case 6:
        return 'Cumartesi';
      case 7:
        return 'Pazar';
      default:
        return '';
    }
  }

//nem sensoru ıcın esp ile baglantı ve espden gelen nem verılerı
  void getSensorData() async {
    final url = Uri.parse('http://192.168.240.115/data');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data.containsKey('nem')) {
          double newMoisture = data['nem'].toDouble();

          if (isStarted && newMoisture >= widget.targetMoisture) {
            //2 saniye bekleme ve otomatik durdurma kısmı
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && isStarted) {
                togglePump(false);
                showNotification(
                    'Toprak nem oranı hedefe ulaştı (%${widget.targetMoisture}). Motor durduruldu.');
              }
            });
          }

          if (newMoisture > 50 && soilMoisture <= 50) {
            showNotification(
                'Toprak nem oranı %${newMoisture.toStringAsFixed(2)} üzerine çıktı!');
          }

          setState(() {
            soilMoisture = newMoisture;
          });
        }
      }
    } catch (e) {
      print('Bağlantı hatası: $e');
    }
  }

  void togglePump(bool start) async {
    String status = start ? 'ON' : 'OFF';
    final url = Uri.parse('http://192.168.240.115/pumpControl');

    try {
      final response = await http.post(
        url,
        body: {'status': status},
      );

      if (response.statusCode == 200) {
        setState(() {
          isStarted = start;
          systemStatus = start ? "Motor Çalışıyor" : "Motor Kapalı";
        });

        if (start) {
          showNotification(
              'Sulama başladı. Hedef nem oranı: %${widget.targetMoisture}');

          Future.delayed(Duration(seconds: widget.wateringDuration), () {
            if (mounted && isStarted) {
              togglePump(false);
            }
          });
        } else {
          showNotification('Sulama durduruldu.');
        }
      }
    } catch (e) {
      print('Bağlantı hatası: $e');
    }
  }

  String getMoistureStatus(double value) {
    if (value < 40) return "Kuru";
    if (value < 60) return "Nemli";
    return "Islak";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[600],
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const SizedBox(width: 10),
            const Text(
              'RainDrop',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 247, 19, 3),
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[650],
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildSoilMoistureInfo(),
              const SizedBox(height: 20),
              buildMotorControl(),
              const SizedBox(height: 30),
              buildWeatherInfo(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSoilMoistureInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[200],
        border: Border.all(color: Colors.orange, width: 4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'Toprak Nem Oranı Bilgileri',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Nem Oranı: %${soilMoisture.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 5),
          Text(
            'Durum: ${getMoistureStatus(soilMoisture)}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: soilMoisture / 100,
            minHeight: 15,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              soilMoisture < 20
                  ? Colors.red
                  : soilMoisture < 50
                      ? Colors.orange
                      : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMotorControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[200],
        border: Border.all(color: Colors.blue, width: 4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text(
            'Motor Kontrolü',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            widget.selectedFruit != null
                ? '${widget.selectedFruit} Sulama Kontrolü'
                : 'Bahçe Sulama Kontrolü',
            style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => togglePump(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 105, 184, 107),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 25, color: Colors.black),
                ),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: () => togglePump(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 215, 12, 12),
                ),
                child: const Text(
                  'Stop',
                  style: TextStyle(fontSize: 25, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildWeatherInfo() {
    DateTime now = DateTime.now();
    String todayName = getTurkishDayName(now.weekday);
    String city = 'Bilecik';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[200],
        border: Border.all(color: Colors.green, width: 4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 8,
            right: 8,
            child: Text(
              city,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hava Durumu Bilgileri',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      todayName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    if (weatherIcon.isNotEmpty)
                      Image.network(
                        'https://openweathermap.org/img/wn/$weatherIcon@4x.png',
                        width: 50,
                        height: 50,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Hava Durumu: $weatherDescription',
                  style: const TextStyle(fontSize: 18),
                ),
                Text(
                  'Sıcaklık: ${temperature.toStringAsFixed(1)}°C',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 20),
                const Text(
                  '3 Günlük Tahmin:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                forecastList.isNotEmpty
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: forecastList.map((dayForecast) {
                          return Expanded(
                            child: Column(
                              children: [
                                Text(
                                  dayForecast['day'],
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                Image.network(
                                  'https://openweathermap.org/img/wn/${dayForecast['icon']}@2x.png',
                                  width: 40,
                                  height: 40,
                                ),
                                Text(
                                  '${dayForecast['temp'].toStringAsFixed(1)}°C',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BosSayfa extends StatelessWidget {
  const BosSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sulamak İstediğiniz Bahçeyi Seçiniz',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 30),
                buildGardenBox(
                  context,
                  label: 'Bahçe 1',
                  imageUrl:
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Cherry_Stella444.jpg/240px-Cherry_Stella444.jpg',
                  fruitName: 'Kiraz Bahçesi',
                  wateringDuration: 30,
                  targetMoisture: 60,
                ),
                const SizedBox(height: 20),
                buildGardenBox(
                  context,
                  label: 'Bahçe 2',
                  imageUrl:
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/PerfectStrawberry.jpg/240px-PerfectStrawberry.jpg',
                  fruitName: 'Çilek Bahçesi',
                  wateringDuration: 40,
                  targetMoisture: 50,
                  key: const ValueKey('cilek_bahcesi'),
                ),
              ],
            ),
            Positioned(
              bottom: 10,
              child: _buildPlusIcon(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlusIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey),
      ),
      child: const Center(
        child: Icon(Icons.add, size: 28, color: Colors.grey),
      ),
    );
  }

  Widget buildGardenBox(
    BuildContext context, {
    required String label,
    required String imageUrl,
    required String fruitName,
    required int wateringDuration,
    required double targetMoisture,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnaSayfa(
              wateringDuration: wateringDuration,
              targetMoisture: targetMoisture,
              selectedFruit: fruitName,
            ),
          ),
        );
      },
      child: Container(
        width: 240,
        height: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.red, width: 3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(fruitName,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
