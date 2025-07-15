#include <Wire.h>
#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <ESP8266WebServer.h>
#include <ArduinoJson.h>

// Sensör ve röle pinleri
const int prob = A0;
const int rolePin = 2; // GPIO2 (D4) pinini kullanma
int olcum_sonucu = 0;

// Wi-Fi bilgileri
const char* ssid = "username";
const char* password = "password";

// OpenWeatherMap API bilgileri
const char* apiKey = "9b534c71ac5f5c1d8e420630b3f47cb6";
const float latitude = 40.137416;
const float longitude = 29.978222;

// Hava durumu verileri
String currentWeather = "";
float currentTemperature = 0.0;

// Web sunucusu portu
ESP8266WebServer server(80);

// Zamanlayıcılar
unsigned long lastMoistureUpdate = 0;
unsigned long lastWeatherUpdate = 0;
const unsigned long moistureUpdateInterval = 2000;
const unsigned long weatherUpdateInterval = 3600000;

// ---------- CORS HEADERS EKLEME FONKSİYONU(UYGULAMYI CHROME UZERINDEN ACINCA VERI GELMESI ICIN) ----------
void addCORSHeaders() {
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.sendHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  server.sendHeader("Access-Control-Allow-Headers", "Content-Type");
}

void setup() {
  Serial.begin(9600);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  Serial.println("\nWi-Fi bağlantısı kuruldu.");
  Serial.print("ESP8266 IP Adresi: ");
  Serial.println(WiFi.localIP());

  pinMode(rolePin, OUTPUT);
  digitalWrite(rolePin, HIGH);

  // OPTIONS istekleri için endpoint
  server.on("/data", HTTP_OPTIONS, []() {
    addCORSHeaders();
    server.send(204); // No Content
  });

  server.on("/pumpControl", HTTP_OPTIONS, []() {
    addCORSHeaders();
    server.send(204); // No Content
  });

  // /data endpoint - GET
  server.on("/data", HTTP_GET, []() {
    DynamicJsonDocument jsonDoc(512);
    jsonDoc["nem"] = getSoilMoisture();
    jsonDoc["sicaklik"] = currentTemperature;
    jsonDoc["hava"] = currentWeather;
    jsonDoc["pompa"] = (digitalRead(rolePin) == LOW) ? "Çalışıyor" : "Kapalı";

    String response;
    serializeJson(jsonDoc, response);

    addCORSHeaders();
    server.send(200, "application/json", response);
  });

  // /pumpControl endpoint - POST
server.on("/pumpControl", HTTP_POST, []() {
  addCORSHeaders();

  Serial.println("POST isteği alındı"); // ← Buraya eklenecek
  if (server.hasArg("status")) {
    String status = server.arg("status");
    Serial.println("Status arg: " + status); // ← ve buraya

    if (status == "ON") {
      digitalWrite(rolePin, LOW);
    } else if (status == "OFF") {
      digitalWrite(rolePin, HIGH);
    }
    server.send(200, "application/json", "{\"status\":\"success\"}");
  } else {
    server.send(400, "application/json", "{\"status\":\"error\",\"message\":\"Missing status\"}");
  }
});


  server.begin();
  Serial.println("Web server başlatıldı.");
}

void loop() {
  server.handleClient();
  unsigned long currentMillis = millis();

  if (currentMillis - lastMoistureUpdate >= moistureUpdateInterval) {
    lastMoistureUpdate = currentMillis;
    float nemOrani = getSoilMoisture();
    Serial.print("Nem Orani: ");
    Serial.println(nemOrani);
  }

  if (currentMillis - lastWeatherUpdate >= weatherUpdateInterval) {
    lastWeatherUpdate = currentMillis;
    getWeather();
  }
}

float getSoilMoisture() {
  olcum_sonucu = analogRead(prob);
  float nem_yuzde = (((1023 - olcum_sonucu) / 10.23) + 0.1) * 2;
  return min(nem_yuzde, 100.0f);
}

void getWeather() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    String url = String("http://api.openweathermap.org/data/2.5/weather?lat=") + latitude + "&lon=" + longitude + "&appid=" + apiKey + "&units=metric&lang=tr";

    WiFiClient client;
    http.begin(client, url);
    int httpResponseCode = http.GET();

    if (httpResponseCode > 0) {
      String jsonBuffer = http.getString();
      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, jsonBuffer);

      if (!error) {
        currentTemperature = doc["main"]["temp"] | 0.0;
        currentWeather = String(doc["weather"][0]["description"]);
      }
    }
    http.end();
  }
}
