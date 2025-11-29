/**********************  Main Sketch (.ino)  ************************
 * ESP32 + 2x RS485 + W5500 + Firebase (SECURE)
 * - Net/NTP/Auto-heal ada di: net_time.h / net_time.cpp
 * - HTTPS (GET/PATCH/PUT) ada di: firebase_https.h / firebase_https.cpp
 *******************************************************************/

#include <Arduino.h>
#include <SPI.h>
#include <Ethernet.h>
#include <SSLClient.h>
#include <ModbusRTU.h>
#include <math.h>

// #include "trust_anchor.h"    // root CA bundle (trim kalau perlu)
#include "anchors_store.h"   // gantiin trust_anchor.h lama
#include "net_time.h"        // ensureTimeSynced(), updateConnectivityAndLED(), ethernetReinitSoft()
#include "firebase_https.h"  // firebaseGET/PATCH/PUT()

// ===================== CONFIG PINS =====================
// RS485 #1 : Modbus RTU (UART1)
#define RS485_MODBUS_RX   26
#define RS485_MODBUS_TX   27
// #define RS485_MODBUS_DE_RE 4   // uncomment kalau pakai manual DE/RE

// RS485 #2 : M800 datalog (UART2) — RX only
#define RS485_M800_RX     16
#define RS485_M800_TX     17

// Optocoupler inputs (aktif LOW)
#define PIN_BOILER   32
#define PIN_OFDA     33
#define PIN_CHILLER  25

#ifndef LED_BUILTIN
#define LED_BUILTIN 2
#endif

// ===================== FIREBASE (diekspor ke firebase_https) =====================
const char* FIREBASE_HOST = "monitoringutility-default-rtdb.firebaseio.com";
const char* FIREBASE_AUTH = "pW5XpVN4Pj48rATzykHF7o59eBrEsJjMYC9NgBu7";

// ===================== ETHERNET (W5500) (diekspor ke net_time) ===================
uint8_t W5500_CS = 5;
byte mac[] = {0x02,0xAA,0xBB,0xCC,0xDE,0x32};
IPAddress ip(10, 102, 14, 83);
IPAddress gateway(10, 102, 14, 1);
IPAddress subnet(255, 255, 255, 0);
IPAddress dns(8, 8, 8, 8);

// ===================== SSLClient (dipakai di firebase_https) =====================
EthernetClient ethClient;
const int ENTROPY_PIN = 34;
SSLClient sslClient(ethClient, TAs, (size_t)TAs_NUM, ENTROPY_PIN, 2048, SSLClient::SSL_NONE);

// ===================== UARTs ================================
HardwareSerial RS485Modbus(1); // UART1
HardwareSerial RS485M800(2);   // UART2

// ===================== MODBUS MASTER =======================
ModbusRTU mb;

// ===================== Data & Flags ========================
uint16_t slave1Data[2];
uint16_t tk201Slave2, tk202Slave3, tk103Slave4;
uint8_t  data1, data2;

bool UF=false, highSurface=false, faultPump=false, lowSurface=false;

// ===================== TIMERS ==============================
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 60000;  // 1 menit
unsigned long lastLoopTime = 0;
const unsigned long loopInterval = 5000;   // 5 detik

// ===================== M800 CACHE (shared) =================
struct M800Last {
  float toc= NAN, temp= NAN, cond= NAN, lamp= NAN;
} m800Last;

// proteksi akses antara task & loop
portMUX_TYPE m800Mux = portMUX_INITIALIZER_UNLOCKED;

// ===================== Utils M800 parsing ==================
static inline String trimCopy(const String& in){ String t=in; t.trim(); return t; }
static bool looksNumber(const String& s){
  if (!s.length()) return false;
  bool dot=false, sign=false;
  for (size_t i=0;i<s.length();++i){
    char c=s[i];
    if (c>='0' && c<='9') continue;
    if (c=='.'){ if (dot) return false; dot=true; continue; }
    if ((c=='-'||c=='+') && i==0){ if (sign) return false; sign=true; continue; }
    return false;
  }
  return true;
}
size_t splitTabs(const String& line, String* out, size_t maxParts){
  size_t cnt=0; int start=0;
  while (cnt<maxParts){
    int p=line.indexOf('\t', start);
    if (p<0){ out[cnt++]=line.substring(start); break; }
    out[cnt++]=line.substring(start,p);
    start=p+1;
  }
  return cnt;
}
static bool fetchAroundLabel(const String* p, size_t n, size_t iLabel, float& out){
  if (iLabel>0   && looksNumber(p[iLabel-1])) { out = p[iLabel-1].toFloat(); return true; }
  if (iLabel+1<n && looksNumber(p[iLabel+1])) { out = p[iLabel+1].toFloat(); return true; }
  return false;
}
static void handleM800Line(const String& rawLine){
  String row = rawLine;
  row.replace("\r",""); 
  row.replace("\n","");
  if (!row.length()) return;

  const size_t MAX_PARTS=32;
  String p[MAX_PARTS];
  size_t n = splitTabs(row, p, MAX_PARTS);
  for (size_t i=0;i<n;i++) p[i] = trimCopy(p[i]);

  float vTOC, vTemp, vCond, vLamp;
  bool hasTOC=false, hasTemp=false, hasCond=false, hasLamp=false;

  for (size_t i=0;i<n;i++){
    if (p[i].equalsIgnoreCase("ppbTOC"))      hasTOC  = fetchAroundLabel(p, n, i, vTOC);
    else if (p[i].equalsIgnoreCase("DegC"))   hasTemp = fetchAroundLabel(p, n, i, vTemp);
    else if (p[i].equalsIgnoreCase("uS/cm"))  hasCond = fetchAroundLabel(p, n, i, vCond);
    else if (p[i].equalsIgnoreCase("lamp h")) hasLamp = fetchAroundLabel(p, n, i, vLamp);
  }

  if (hasTOC || hasTemp || hasCond || hasLamp){
    Serial.print("[M800] ");
    if (hasTOC)  { Serial.print("TOC=");   Serial.print(vTOC, 3);  Serial.print(' '); }
    if (hasTemp) { Serial.print("Temp=");  Serial.print(vTemp, 2);  Serial.print(' '); }
    if (hasCond) { Serial.print("Cond=");  Serial.print(vCond, 3);  Serial.print(' '); }
    if (hasLamp) { Serial.print("LampH="); Serial.print(vLamp, 0);  Serial.print(' '); }
    Serial.println();
  }

  portENTER_CRITICAL(&m800Mux);
  if (hasTOC)  m800Last.toc  = vTOC;
  if (hasTemp) m800Last.temp = vTemp;
  if (hasCond) m800Last.cond = vCond;
  if (hasLamp) m800Last.lamp = vLamp;
  portEXIT_CRITICAL(&m800Mux);
}

// ===================== STRUKTUR UNIT2 ======================
struct ArtesisUnit {
  uint8_t slaveId; String firebaseKey;
  uint16_t pvRaw = 0, presetRaw = 0, lastPresetSent = 0;

  void read(ModbusRTU& mb) {
    if (!mb.slave()) {
      mb.readIreg(slaveId, 1003, &pvRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
      mb.readIreg(slaveId, 1006, &presetRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
    }
  }
  void pushToFirebase() {
    String json = String("{") +
      "\"" + firebaseKey + "_pv\":"     + String(pvRaw/10.0, 2) + "," +
      "\"" + firebaseKey + "_preset\":" + String(presetRaw/10.0, 2) + "}";
    (void)firebasePATCH("/sensor_data.json", json);
  }
  void checkAndSetPresetFromFirebase(ModbusRTU& mb) {
    String body; if (!firebaseGET("/commands/" + firebaseKey + "_preset_set.json", body)) return;
    int presetVal = body.toInt();
    if (presetVal>0 && presetVal!=lastPresetSent && !mb.slave()){
      if (mb.writeHreg(slaveId, 0, presetVal)) {
        while (mb.slave()) { mb.task(); delay(50); }
        mb.readIreg(slaveId, 1006, &presetRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
        mb.readIreg(slaveId, 1003, &pvRaw, 1);     while (mb.slave()) { mb.task(); delay(50); }
        lastPresetSent = presetVal;
        pushToFirebase();
      }
    }
  }
  void checkReset(ModbusRTU& mb) {
    String body; if (!firebaseGET("/commands/" + firebaseKey + "_reset.json", body)) return;
    body.trim();
    if (body=="1"){
      if (!mb.slave()){
        mb.writeCoil(slaveId, 0, true);  while (mb.slave()) { mb.task(); delay(50); }
        delay(200);
        mb.writeCoil(slaveId, 0, false); while (mb.slave()) { mb.task(); delay(50); }
      }
      mb.readIreg(slaveId, 1006, &presetRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
      mb.readIreg(slaveId, 1003, &pvRaw, 1);     while (mb.slave()) { mb.task(); delay(50); }
      (void)firebasePUT("/commands/" + firebaseKey + "_reset.json", "0");
      pushToFirebase();
    }
  }
};
ArtesisUnit artesis2 = {8, "artesis2"};
ArtesisUnit artesis3 = {9, "artesis3"};
ArtesisUnit artesis4 = {10,"artesis4"};

uint16_t fetchFirebaseFloatAsInt(String path) {
  String body; if (!firebaseGET(path, body)) return 0;
  body.trim(); float val = body.toFloat();
  return (uint16_t)val;
}

struct VentFilterUnit {
  uint8_t slaveId; String firebaseKey;
  uint16_t sv=0, lsv=0, hsv=0, lastSVSent=0;

  void readCurrentValues(ModbusRTU& mb){
    if (!mb.slave()){
      mb.readHreg(slaveId, 0, &sv, 1);      while (mb.slave()) { mb.task(); delay(50); }
      mb.readHreg(slaveId, 160, &lsv, 1);   while (mb.slave()) { mb.task(); delay(50); }
      mb.readHreg(slaveId, 161, &hsv, 1);   while (mb.slave()) { mb.task(); delay(50); }
    }
  }
  void checkAndSetLimitsFromFirebase(ModbusRTU& mb){
    uint16_t newLSV = fetchFirebaseFloatAsInt("/commands/" + firebaseKey + "_lsv_set.json");
    if (newLSV>0 && newLSV!=lsv && !mb.slave()){
      if (mb.writeHreg(slaveId, 0x00A0, newLSV)){ while (mb.slave()) { mb.task(); delay(50); } lsv = newLSV; }
    }
    uint16_t newHSV = fetchFirebaseFloatAsInt("/commands/" + firebaseKey + "_hsv_set.json");
    if (newHSV>0 && newHSV!=hsv && !mb.slave()){
      if (mb.writeHreg(slaveId, 0x00A1, newHSV)){ while (mb.slave()) { mb.task(); delay(50); } hsv = newHSV; }
    }
  }
  void checkAndSetSVFromFirebase(ModbusRTU& mb){
    readCurrentValues(mb);
    uint16_t newSV = fetchFirebaseFloatAsInt("/commands/" + firebaseKey + "_sv_set.json");
    if (newSV>0 && newSV!=lastSVSent && !mb.slave()){
      if (mb.writeHreg(slaveId, 0x0000, newSV)){
        while (mb.slave()) { mb.task(); delay(50); }
        sv=newSV; lastSVSent=newSV;
        pushToFirebase();
      }
    }
  }
  void pushToFirebase(){
    readCurrentValues(mb);
    String json = String("{") +
      "\"" + firebaseKey + "_sv\":"  + String(sv) + "," +
      "\"" + firebaseKey + "_lsv\":" + String(lsv) + "," +
      "\"" + firebaseKey + "_hsv\":" + String(hsv) + "}";
    (void)firebasePATCH("/sensor_data.json", json);
  }
};
VentFilterUnit tk201 = {2, "tk201"};
VentFilterUnit tk202 = {3, "tk202"};
VentFilterUnit tk103 = {4, "tk103"};

struct TF3Sensor {
  uint8_t slaveId; String firebaseKey;
  uint16_t pvRaw=0, svRaw=0; float lastSVSent=0.0;

  void read(ModbusRTU& mb){
    if (!mb.slave()){
      mb.readIreg(slaveId, 1000, &pvRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
      mb.readIreg(slaveId, 1001, &svRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
    }
  }
  void checkAndSetSVFromFirebase(ModbusRTU& mb){
    String body; if (!firebaseGET("/commands/" + firebaseKey + "_sv_set.json", body)) return;
    float newSV = body.toFloat();
    if (newSV>0 && fabs(newSV-lastSVSent) > 0.05 && !mb.slave()){
      uint16_t scaled = (uint16_t)(newSV*10.0);
      if (mb.writeHreg(slaveId, 0, scaled)){
        while (mb.slave()) { mb.task(); delay(50); }
        mb.readIreg(slaveId, 1000, &pvRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
        mb.readIreg(slaveId, 1001, &svRaw, 1); while (mb.slave()) { mb.task(); delay(50); }
        lastSVSent = svRaw/10.0;
        pushToFirebase();
      }
    }
  }
  void pushToFirebase(){
    String json = String("{") +
      "\"" + firebaseKey + "_pv\":" + String(pvRaw/10.0, 2) + "," +
      "\"" + firebaseKey + "_sv\":" + String(svRaw/10.0, 2) + "}";
    (void)firebasePATCH("/sensor_data.json", json);
  }
};
TF3Sensor tf3 = {7, "tf3"};

// ===================== FWD DECL ============================
void readDIFromWellpro();
bool sendDataToFirebase();
void printSummary60s();

// ===================== WELLPRO DO RAW HELPERS ==============
static const uint8_t WP_SLAVE = 5;

uint16_t calculateCRC(uint8_t *data, uint8_t length){
  uint16_t crc = 0xFFFF;
  for (int i=0; i<length; i++){
    crc ^= data[i];
    for (int j=0; j<8; j++){
      if (crc & 1) crc = (crc >> 1) ^ 0xA001;
      else         crc >>= 1;
    }
  }
  return crc;
}

bool wp_do_single(uint8_t slave, uint16_t coilAddr, bool on){
  uint8_t req[8];
  req[0]=slave; req[1]=0x05;
  req[2]=(coilAddr>>8)&0xFF; req[3]=coilAddr&0xFF;
  if (on){ req[4]=0xFF; req[5]=0x00; } else { req[4]=0x00; req[5]=0x00; }
  uint16_t crc = calculateCRC(req, 6);
  req[6]=crc&0xFF; req[7]=(crc>>8)&0xFF;

#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, HIGH);
#endif
  RS485Modbus.write(req, sizeof(req));
  RS485Modbus.flush();
#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, LOW);
#endif

  uint8_t resp[8]; int i=0; unsigned long t0=millis();
  while (millis()-t0<150 && i<8){ if (RS485Modbus.available()) resp[i++]=RS485Modbus.read(); }
  return (i>=6 && resp[0]==slave && resp[1]==0x05);
}

bool wellproWriteDO_raw(uint8_t ch1to4, bool on){
  if (ch1to4<1 || ch1to4>4) return false;
  return wp_do_single(WP_SLAVE, (uint16_t)(ch1to4-1), on);
}

bool wellproReadDO_raw(uint8_t& maskOut){
  maskOut=0;
  uint8_t req[8] = {WP_SLAVE, 0x01, 0x00, 0x00, 0x00, 0x04, 0, 0};
  uint16_t crc=calculateCRC(req,6); req[6]=crc&0xFF; req[7]=(crc>>8)&0xFF;

#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, HIGH);
#endif
  RS485Modbus.write(req, sizeof(req));
  RS485Modbus.flush();
#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, LOW);
#endif

  uint8_t resp[8]; int i=0; unsigned long t0=millis();
  while (millis()-t0<150 && i<8){ if (RS485Modbus.available()) resp[i++]=RS485Modbus.read(); }
  if (i>=5 && resp[0]==WP_SLAVE && resp[1]==0x01 && resp[2]==0x01){
    maskOut = resp[3] & 0x0F;
    return true;
  }
  return false;
}

// ====== DO control via Firebase (/commands/artesisX_manual) ======
struct DOChannel {
  uint8_t ch;           // 1..4
  const char* fbKey;    // "artesisX_manual"
  int8_t lastApplied;   // -1 unknown, 0 off, 1 on
  uint32_t lastWriteMs; // anti-spam
};

DOChannel g_do[] = {
  {1, "artesis1_manual", -1, 0},
  {2, "artesis2_manual", -1, 0},
  {3, "artesis3_manual", -1, 0},
  {4, "artesis4_manual", -1, 0},
};
uint8_t  g_do_rr = 0;
uint32_t g_lastMaskPublish = 0;
uint8_t  g_do_mask_cache = 0xFF;

void syncOneDOFromFirebase(){
  if (mb.slave()) return;

  DOChannel &d = g_do[g_do_rr];
  g_do_rr = (g_do_rr + 1) % (sizeof(g_do)/sizeof(g_do[0]));

  String body;
  if (!firebaseGET(String("/commands/") + d.fbKey + ".json", body)) {
    Serial.println("[DO] Firebase GET fail");
    return;
  }
  body.trim();
  Serial.print("[DO] "); Serial.print(d.fbKey);
  Serial.print(" raw val="); Serial.println(body);

  if (body != "0" && body != "1") {
    Serial.println("[DO] value invalid, skip");
    return;
  }

  int desired = (body == "1") ? 1 : 0;

  uint8_t mask;
  bool haveMask = wellproReadDO_raw(mask);
  if (haveMask) {
    g_do_mask_cache = mask;
    Serial.print("[DO] mask="); Serial.println(mask, BIN);
  }

  bool actualOn = haveMask ? ((mask >> (d.ch-1)) & 0x01) : (d.lastApplied==1);

  Serial.print("[DO] ch="); Serial.print(d.ch);
  Serial.print(" desired="); Serial.print(desired);
  Serial.print(" actual="); Serial.println(actualOn);

  uint32_t now = millis();
  bool needWrite = (d.lastApplied < 0) || (actualOn != (desired==1));
  bool rateOK    = (now - d.lastWriteMs) > 250;

  if (needWrite && rateOK){
    Serial.print("[DO] Writing coil "); Serial.print(d.ch);
    Serial.print(" -> "); Serial.println(desired);
    if (!mb.slave()){
      if (wellproWriteDO_raw(d.ch, desired==1)){
        d.lastApplied = desired;
        d.lastWriteMs = now;
        Serial.println("[DO] Write OK]");

        if (wellproReadDO_raw(mask)){
          g_do_mask_cache = mask;
          Serial.print("[DO] New mask="); Serial.println(mask, BIN);
        }

        String json = "{\"wp_do" + String(d.ch) + "\":" + String(desired) + "}";
        Serial.print("[DO] Firebase PATCH "); Serial.println(json);
        (void)firebasePATCH("/sensor_data.json", json);
      } else {
        Serial.println("[DO] Write FAIL");
      }
    }
  } else {
    Serial.println("[DO] No change, skip write");
  }
}

void publishDOMaskIfDue(){
  uint32_t now = millis();
  if (now - g_lastMaskPublish < 20000) return; // 20s
  if (mb.slave()) return;

  uint8_t mask;
  if (wellproReadDO_raw(mask)) g_do_mask_cache = mask;
  if (g_do_mask_cache != 0xFF){
    String json = String("{\"wp_do_mask\":") + String(g_do_mask_cache) + "}";
    (void)firebasePATCH("/sensor_data.json", json);
  }
  g_lastMaskPublish = now;
}

// ===================== M800 TASK ===========================
void taskM800(void*){
  RS485M800.begin(19200, SERIAL_7E1, RS485_M800_RX, RS485_M800_TX);
  Serial.println("\n[M800-TASK] start @19200 7E1 on RX=GPIO16 (TX=17, RX-only).");

  static uint8_t buf[256];
  static size_t  len = 0;
  unsigned long lastByteAt = millis();

  for(;;){
    while (RS485M800.available()){
      int b = RS485M800.read();
      if (len < sizeof(buf)) buf[len++] = (uint8_t)b;
      lastByteAt = millis();
    }

    if (len > 0 && (millis() - lastByteAt) > 200){
      String asc; asc.reserve(len);
      for (size_t i=0;i<len;i++){
        char c = (buf[i] >= 32 && buf[i] <= 126) ? (char)buf[i]
                 : ((buf[i]==9||buf[i]==10||buf[i]==13)?(char)buf[i]:'.');
        asc += c;
      }

      int i = 0, L = asc.length();
      while (i < L){
        int cr = asc.indexOf('\r', i);
        int lf = asc.indexOf('\n', i);
        int end;
        if (cr < 0 && lf < 0) end = L;
        else if (cr < 0)      end = lf;
        else if (lf < 0)      end = cr;
        else                  end = (cr < lf ? cr : lf);

        String line = asc.substring(i, end);
        if (line.length()) handleM800Line(line);

        int j = end;
        while (j < L && (asc[j]=='\r' || asc[j]=='\n')) j++;
        i = j;
      }
      len = 0;
    }
    vTaskDelay(5 / portTICK_PERIOD_MS);
  }
}

// ===================== SETUP ===============================
void setup(){
  Serial.begin(115200);
  delay(200);
  pinMode(LED_BUILTIN, OUTPUT);
  digitalWrite(LED_BUILTIN, HIGH); // active-LOW: HIGH=off (awal)

  pinMode(PIN_BOILER,  INPUT_PULLUP);
  pinMode(PIN_OFDA,    INPUT_PULLUP);
  pinMode(PIN_CHILLER, INPUT_PULLUP);

#ifdef RS485_MODBUS_DE_RE
  pinMode(RS485_MODBUS_DE_RE, OUTPUT);
  digitalWrite(RS485_MODBUS_DE_RE, LOW); // RX idle
#endif

  // UART1: Modbus RTU
  RS485Modbus.begin(9600, SERIAL_8N1, RS485_MODBUS_RX, RS485_MODBUS_TX);
  mb.begin(&RS485Modbus);
  mb.master();

  // Start M800 reader di core lain
  xTaskCreatePinnedToCore(taskM800, "taskM800", 4096, nullptr, 2, nullptr, 0);

  // Ethernet (W5500) – static IP
  SPI.begin();
  Ethernet.init(W5500_CS);
  Ethernet.begin(mac, ip, dns, gateway, subnet);

  // Tunggu link & IP (max 20s)
  unsigned long t0 = millis();
  while ((Ethernet.linkStatus() == LinkOFF || Ethernet.localIP() == IPAddress(0,0,0,0)) && millis() - t0 < 20000) {
    delay(300);
  }

  // Sync waktu sebelum TLS
  ensureTimeSynced();

  // Serial.println(pingHost(FIREBASE_HOST,443) ? "TCP firebase OK" : "TCP firebase FAIL");
  Serial.println(tcpPing(FIREBASE_HOST,443) ? "TCP firebase OK" : "TCP firebase FAIL");
  Serial.println("== Ready ==");
}

// ===================== LOOP ================================
void loop(){
  // LED status + auto heal
  updateConnectivityAndLED();

  // periodic NTP re-sync
  ensureTimeSynced();

  unsigned long now = millis();

  // ======== Periodic light loop (every 5s) ========
  if (now - lastLoopTime > loopInterval){
    lastLoopTime = now;

    readDIFromWellpro();           // Wellpro DI
    artesis2.checkAndSetPresetFromFirebase(mb);
    artesis2.checkReset(mb);

    tk201.checkAndSetSVFromFirebase(mb);
    tk202.checkAndSetSVFromFirebase(mb);
    tk103.checkAndSetSVFromFirebase(mb);

    tf3.checkAndSetSVFromFirebase(mb); // TF3

    // DO control (hemat polling): 1 key/5s + publish mask 20s
    syncOneDOFromFirebase();
    publishDOMaskIfDue();
  }

  // ======== Periodic send (every 60s) ========
  if (now - lastSendTime > sendInterval){
    lastSendTime = now;

    // AHU04 (2 ireg)
    if (!mb.slave()){
      if (mb.readIreg(1, 0x0000, slave1Data, 2)){
        while (mb.slave()) { mb.task(); delay(50); }
        data1 = slave1Data[0] / 100;
        data2 = slave1Data[1] / 100;
      }
    }
    while (mb.slave()) { mb.task(); delay(50); }

    // Vent Filter PVs
    if (!mb.slave()){
      mb.readIreg(2, 1000, &tk201Slave2, 1); while (mb.slave()) { mb.task(); delay(50); } delay(80);
      mb.readIreg(3, 1000, &tk202Slave3, 1); while (mb.slave()) { mb.task(); delay(50); } delay(80);
      mb.readIreg(4, 1000, &tk103Slave4, 1); while (mb.slave()) { mb.task(); delay(50); }
    }

    // Push per unit
    artesis2.read(mb);           artesis2.pushToFirebase();
    tk201.readCurrentValues(mb); tk201.pushToFirebase();
    tk202.readCurrentValues(mb); tk202.pushToFirebase();
    tk103.readCurrentValues(mb); tk103.pushToFirebase();
    tf3.read(mb);                tf3.pushToFirebase();

    if (Ethernet.linkStatus() == LinkON && Ethernet.localIP() != IPAddress(0,0,0,0)){
      bool sent = sendDataToFirebase();
      if (sent) {
        printSummary60s();
      } else {
        Serial.println("[PUSH] Firebase FAIL");
      }
    } else {
      Serial.println("ETH DISCONNECTED");
    }
  }

  // Modbus state machine
  mb.task();
}

// ===================== FUNCTIONS ============================
bool sendDataToFirebase(){
  int boilerStatus  = digitalRead(PIN_BOILER)  == LOW ? 1 : 0;
  int ofdaStatus    = digitalRead(PIN_OFDA)    == LOW ? 1 : 0;
  int chillerStatus = digitalRead(PIN_CHILLER) == LOW ? 1 : 0;

  // copy cache M800 sekali
  M800Last snap;
  portENTER_CRITICAL(&m800Mux);
  snap = m800Last;
  portEXIT_CRITICAL(&m800Mux);

  String json = "{";
  bool first = true;
  auto addKV = [&](const char* k, const String& v){
    if (!first) json += ",";
    first=false;
    json += "\""; json += k; json += "\":";
    json += v;
  };
  auto addKVi = [&](const char* k, int v){ addKV(k, String(v)); };
  auto addKVf = [&](const char* k, float v, unsigned int d){ addKV(k, String(v, d)); };

  addKVi("tk201", tk201Slave2);
  addKVi("tk202", tk202Slave3);
  addKVi("tk103", tk103Slave4);
  addKVi("temp_ahu04lb", data1);
  addKVi("rh_ahu04lb",   data2);
  addKVi("boiler",       boilerStatus);
  addKVi("ofda",         ofdaStatus);
  addKVi("chiller",      chillerStatus);
  addKVi("UF",           UF);
  addKVi("high_surface_tank", highSurface);
  addKVi("fault_pump",        faultPump);
  addKVi("low_surface_tank",  lowSurface);

  addKVf("artesis2_pv",     artesis2.pvRaw/10.0, 2);
  addKVf("artesis2_preset", artesis2.presetRaw/10.0, 2);

  if (!isnan(snap.toc))  addKVf("m800_toc",     snap.toc,  3);
  if (!isnan(snap.temp)) addKVf("m800_temp",    snap.temp, 2);
  if (!isnan(snap.cond)) addKVf("m800_conduct", snap.cond, 3);
  if (!isnan(snap.lamp)) addKVf("m800_lamp",    snap.lamp, 0);

  json += "}";
  return firebasePATCH("/sensor_data.json", json);
}

// Baca DI dari Wellpro (Slave ID 5) via UART1 (FC=0x02, start 0, qty 4)
void readDIFromWellpro(){
  if (mb.slave()) return;

  uint8_t req[] = { WP_SLAVE, 0x02, 0x00, 0x00, 0x00, 0x04, 0, 0 };
  uint16_t crc = calculateCRC(req, 6);
  req[6] = crc & 0xFF;
  req[7] = (crc >> 8) & 0xFF;

#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, HIGH); // TX enable
#endif
  RS485Modbus.write(req, sizeof(req));
  RS485Modbus.flush();
#ifdef RS485_MODBUS_DE_RE
  digitalWrite(RS485_MODBUS_DE_RE, LOW);  // back to RX
#endif

  delay(80);

  uint8_t resp[16]; int i=0;
  while (RS485Modbus.available() && i < (int)sizeof(resp)) {
    resp[i++] = RS485Modbus.read();
  }

  if (i >= 5 && resp[1] == 0x02){
    uint8_t di = (i>=5) ? resp[3] : 0;
    highSurface = (di >> 0) & 0x01;
    lowSurface  = (di >> 1) & 0x01;
    faultPump   = (di >> 2) & 0x01;
    UF          = (di >> 3) & 0x01;
  }
}

void printSummary60s() {
  M800Last snap;
  portENTER_CRITICAL(&m800Mux);
  snap = m800Last;
  portEXIT_CRITICAL(&m800Mux);

  Serial.print("[PUSH] ");
  Serial.print("AHU04 T:");   Serial.print(data1);
  Serial.print(" RH:");       Serial.print(data2);
  Serial.print(" | TK201:");  Serial.print(tk201Slave2);
  Serial.print(" TK202:");    Serial.print(tk202Slave3);
  Serial.print(" TK103:");    Serial.print(tk103Slave4);
  Serial.print(" | ART2 PV:");Serial.print(artesis2.pvRaw/10.0,1);
  Serial.print(" SP:");       Serial.print(artesis2.presetRaw/10.0,1);
  if (!isnan(snap.toc) || !isnan(snap.temp) || !isnan(snap.cond) || !isnan(snap.lamp)){
    Serial.print(" | M800 ");
    if (!isnan(snap.toc))  { Serial.print("TOC:");  Serial.print(snap.toc,3);  Serial.print(' '); }
    if (!isnan(snap.temp)) { Serial.print("T:");    Serial.print(snap.temp,2); Serial.print(' '); }
    if (!isnan(snap.cond)) { Serial.print("C:");    Serial.print(snap.cond,3); Serial.print(' '); }
    if (!isnan(snap.lamp)) { Serial.print("L:");    Serial.print(snap.lamp,0); }
  }
  Serial.print(" | DI UF:");  Serial.print(UF);
  Serial.print(" H:");        Serial.print(highSurface);
  Serial.print(" F:");        Serial.print(faultPump);
  Serial.print(" L:");        Serial.println(lowSurface);
}
