//PROYECTO FINAL INTEGRADOR: SIEMF
//PINES ASIGNADOS HASTA EL MOMENTO:
//- D0, D1: USB Serie con la PC
//- D2:  Buzzer (Alarma sonora tolva vacía)
//- D3:  Servomotor 1 PWM - Compuerta Tolva A (Dieta Común)
//- D4:  Pin Echo - Sensor Ultrasónico 2 (Tolva B)
//- D5:  Servomotor 2 PWM - Compuerta Tolva B (Dieta Especial)
//- D6:  Pin Trig - Sensor Ultrasónico 1 (Tolva A)
//- D7:  Pin Echo - Sensor Ultrasónico 1 (Tolva A)
//- D8:  Pin Trig - Sensor Ultrasónico 2 (Tolva B)
//- A2:  LED Verde (Hay comida disponible)
//- A3:  LED Rojo  (Alerta tolva vacía)
//- D9:  RST del RFID
//- D10: SDA (SS) del RFID
//- D11: MOSI del RFID (SPI)
//- D12: MISO del RFID (SPI)
//- D13: SCK del RFID (SPI)
//- A0: Señal del sensor PIR
//- A1: Relé de la minibomba de agua
#include <SPI.h>     //Bus SPI para comunicar el Arduino con el lector RFID
#include <MFRC522.h> //Librería del lector RC522
#include <Servo.h>   //Librería para manejar los servos SG90
//Clases de sensores
//Clase padre: Agrupa lo que tienen en común todos los sensores (un valor y su unidad)
class Sensor 
{
  protected: //Uso protected para que las clases hijas puedan modificar 'valor' directo
    float valor;
    String magnitud;
  public:
    //Cuando nace cualquier sensor, le guardo la unidad y arranco su valor en 0
    Sensor(String mag) 
    {
      magnitud= mag;
      valor= 0.0;
    }
    //Virtual para que cada hijo escriba su propia lógica de lectura física
    virtual void generarMedicion() 
    {
      valor= 0.0;
    }
    //Getter para consultar el último dato leído sin tocar la variable desde afuera
    float leerMedicion() 
    {
      return valor;
    }
    String getMagnitud() 
    {
      return magnitud;
    }
};
//Clase de sensor ultrasónico HC-SR04 para medir qué tan vacía está cada tolva
//Ahora incluye un filtro de media móvil de 5 muestras para limpiar picos de ruido
class SensorUltrasonido : public Sensor 
{
  private:
    int pinTrig;           //Pin que manda el pulso ultrasónico
    int pinEcho;           //Pin que mide cuánto tarda en volver el rebote
    float distanciaAlarma; //Distancia máxima antes de avisar que falta comida
    //Variables del filtro de media móvil (buffer circular de 5 posiciones)
    //Lo agregué porque el ultrasonido a veces tira saltos raros cuando la onda rebota en las croquetas
    float historial[5];    //Arreglo donde voy guardando las últimas 5 lecturas crudas
    int indice;            //Me dice en qué posición del arreglo toca pisar el dato más viejo
    float suma;            //Llevo la suma acumulada de las 5 muestras para no recorrer todo en un for cada vez
  public:
    //Llamo al constructor del padre pasándole "cm", configuro los pines e inicializo el filtro en 0
    SensorUltrasonido(int trig, int echo, float distAlarma) : Sensor("cm") 
    {
      pinTrig= trig;
      pinEcho= echo;
      distanciaAlarma= distAlarma;
      pinMode(pinTrig, OUTPUT);
      pinMode(pinEcho, INPUT);
      indice= 0;
      suma= 0.0;
      //Limpio las 5 posiciones del arreglo en 0.0 para no arrancar promediando basura de memoria
      for (int i= 0; i < 5; i++) 
      {
        historial[i]= 0.0;
      }
    }
    //Toma la lectura física del HC-SR04 y la pasa por el filtro de media móvil antes de guardarla en 'valor'
    void generarMedicion() override 
    {
      //1) Disparo el pulso de 10 microsegundos que pide la hoja de datos del HC-SR04
      digitalWrite(pinTrig, LOW);
      delayMicroseconds(2);
      digitalWrite(pinTrig, HIGH);
      delayMicroseconds(10);
      digitalWrite(pinTrig, LOW);
      //Le pongo un timeout de 30000 us (30ms) para que si no vuelve eco no me cuelgue el programa
      long duracion= pulseIn(pinEcho, HIGH, 30000);
      float lecturaCruda= 0.0;
      if ( duracion > 0 ) 
      {
        //Velocidad del sonido aprox 0.034 cm/us; divido por 2 porque la onda va y vuelve
        lecturaCruda= duracion * 0.034 / 2.0;
      }
      //2) Aplico el filtro de media móvil (buffer circular)
      suma= suma - historial[indice];  //Resto del total la lectura más vieja que voy a reemplazar
      historial[indice]= lecturaCruda; //Guardo la medición recién tomada en ese casillero
      suma= suma + historial[indice];  //Sumo el dato nuevo al acumulado
      //Avanzo el índice al siguiente casillero; si llegué al final (5), doy la vuelta a 0
      indice= indice + 1;
      if ( indice >= 5 ) 
      {
        indice= 0;
      }
      //3) Guardo el promedio final en 'valor' (la variable heredada de Sensor)
      valor= suma / 5.0;
    }
    //Me devuelve true si la distancia filtrada superó el límite real de la tolva (21.0 cm)
    bool tolvaVacia() 
    {
      return ( valor > distanciaAlarma );
    }
};
//Clase sensor infrarrojo PIR para detectar cuando un gato se acerca al bebedero
class SensorPIR : public Sensor 
{
  private:
    int pinDatos;
  public:
    SensorPIR(int pin) : Sensor("Presencia") 
    {
      pinDatos= pin;
      pinMode(pinDatos, INPUT);
    }
    //Lee directamente el pin digital: 1 si detectó movimiento, 0 si no hay nadie
    void generarMedicion() override 
    {
      valor= digitalRead(pinDatos);
    }
    //Para que los if del loop se lean más claros
    bool hayGatoCerca() 
    {
      return ( valor == 1.0 );
    }
};
//Clase lector RFID RC522 para distinguir a Rufo de Rubia y Pelusa
class SensorRFID : public Sensor 
{
  private:
    MFRC522 lectorFisico;// Objeto interno de la librería que controla el hardware del lector
    //UIDs reales (en hexa) que saqué probando mis 3 llaveros antes
    const byte uidRufo[4]= {0xE3, 0x20, 0x4C, 0x06};   //ID 1 -> Rufo (dieta especial)
    const byte uidRubia[4]= {0x54, 0xA0, 0x9F, 0xDA};  //ID 2 -> Rubia (comida común)
    const byte uidPelusa[4]= {0x54, 0xAF, 0x8C, 0xDA}; //ID 3 -> Pelusa (comida común)
    //Recorre los 4 bytes del llavero leído y los compara con uno de los arrays de arriba
    bool compararUID(const byte uidLeido[], const byte uidEsperado[]) 
    {
      for (byte i= 0; i < 4; i++) 
      {
        if ( uidLeido[i] != uidEsperado[i] ) 
        {
          return false; //Con que un solo byte sea distinto ya descarto ese gato
        }
      }
      return true;
    }
  public:
    //Inicializo lectorFisico en la lista de inicialización porque necesita SS y RST al crearse
    SensorRFID(int pinSS, int pinRST) : Sensor("ID_Gato"), lectorFisico(pinSS, pinRST) 
    {
      valor= 0.0; //Arranca en 0 (ningún gato detectado)
    }
    //Esto lo llamo recién en setup() para arrancar SPI y el chip RC522 de forma segura
    void inicializar() 
    {
      SPI.begin();
      lectorFisico.PCD_Init();
    }
    //Revisa si acercaron un llavero y guarda qué número de gato corresponde
    void generarMedicion() override 
    {
      //Si hay una tarjeta cerca Y se pudo leer su código sin error:
      if ( lectorFisico.PICC_IsNewCardPresent() && lectorFisico.PICC_ReadCardSerial() ) 
      {
        if ( compararUID(lectorFisico.uid.uidByte, uidRufo) ) 
        {
          valor= 1.0; //Rufo
        } 
        else if ( compararUID(lectorFisico.uid.uidByte, uidRubia) ) 
        {
          valor= 2.0; //Rubia
        } 
        else if ( compararUID(lectorFisico.uid.uidByte, uidPelusa) ) 
        {
          valor= 3.0; //Pelusa
        } 
        else 
        {
          valor= 0.0; //Cualquier otra tarjeta/SUBE que acerquen se ignora
        }
        //Cierro la lectura de esta tarjeta para que el módulo quede libre para la próxima
        lectorFisico.PICC_HaltA();
        lectorFisico.PCD_StopCrypto1();
      }
    }
    //Sirve cuando aprieto un botón manual en Processing: le inyecto el ID como si hubiera pasado el gato
    void forzarGatoDesdePC(int idGato) 
    {
      valor= idGato;
    }
    //Reseteo a 0 apenas termino de abrir la tolva, así no la intenta abrir mil veces por segundo
    void limpiarLectura() 
    {
      valor= 0.0;
    }
};
//CLASE TIMER (Para sacar el delay() y manejar varios tiempos a la vez)
//Cada Timer funciona como un cronómetro independiente usando el reloj interno millis()
class Timer 
{
  private:
    unsigned long tiempoInicio;    //En qué milisegundo empezó a contar
    unsigned long tiempoAcumulado; //Por si lo freno y quiero saber cuánto llevó
    bool estaCorriendo;            //Si está contando o parado
  public:
    Timer() 
    {
      tiempoInicio= 0;
      tiempoAcumulado= 0;
      estaCorriendo= false;
    }
    void iniciar() 
    {
      if ( !estaCorriendo ) 
      {
        tiempoInicio= millis() - tiempoAcumulado;
        estaCorriendo= true;
      }
    }
    void detener() 
    {
      if ( estaCorriendo ) 
      {
        tiempoAcumulado= millis() - tiempoInicio;
        estaCorriendo= false;
      }
    }
    //Lo pone en 0 y arranca al toque (lo uso cada vez que se dispara una tolva, el agua o un reporte)
    void reiniciarYArrancar() 
    {
      tiempoAcumulado= 0;
      tiempoInicio= millis();
      estaCorriendo= true;
    }
    //Devuelve cuántos milisegundos pasaron desde que arrancó este timer
    unsigned long obtenerTiempo() 
    {
      if ( estaCorriendo ) 
      {
        return millis() - tiempoInicio;
      } 
      else 
      {
        return tiempoAcumulado;
      }
    }
};
//Clases de Actuadores (LEDs, Buzzer, Servos de las Tolvas y Bomba de agua)
//Control básico de un LED (encendido, apagado o parpadeo sin delay)
class Led 
{
  private:
    int pin;
    bool estado;
  public:
    Led(int p) 
    {
      pin= p;
      estado= false;
      pinMode(pin, OUTPUT);
      digitalWrite(pin, LOW); //Siempre arranca apagado
    }
    void encender() 
    {
      estado= true;
      digitalWrite(pin, HIGH);
    }
    void apagar() 
    {
      estado= false;
      digitalWrite(pin, LOW);
    }
    //Invierte el estado actual del LED (si estaba prendido lo apaga y viceversa)
    //Al llamarlo cada 500ms dentro del ciclo de reporte, logro el parpadeo de alerta sin usar delay()
    void alternar() 
    {
      if ( estado == true ) 
      {
        apagar();
      } 
      else 
      {
        encender();
      }
    }
};
//Clase para manejar el buzzer de alerta sonora cuando alguna tolva se queda sin alimento
class Buzzer 
{
  private:
    int pin;
    bool sonando;
  public:
    Buzzer(int p) 
    {
      pin= p;
      sonando= false;
      pinMode(pin, OUTPUT);
      noTone(pin); //Me aseguro de que arranque en silencio
    }
    //Emite un tono de 1000 Hz (funciona tanto con buzzer pasivo como activo en modo pulso)
    void encender() 
    {
      sonando= true;
      tone(pin, 1000);
    }
    void apagar() 
    {
      sonando= false;
      noTone(pin);
    }
    //Alterna entre pitido y silencio cada 500ms para ir sincronizado con el parpadeo del LED rojo
    void alternar() 
    {
      if ( sonando == true ) 
      {
        apagar();
      } 
      else 
      {
        encender();
      }
    }
};
//Maneja la compuerta de cada tolva con su servomotor
class Tolva 
{
  private:
    Servo motorServo;
    int pinServo;
    int anguloCerrado; //Posición donde frena el alimento (0°)
    int anguloAbierto; //Posición donde deja caer la porción (90°)
    bool estaAbierta;  //Bandera para saber si ya está abierta y no mandarle órdenes repetidas
  public:
    Tolva(int pin, int angCerrado, int angAbierto) 
    {
      pinServo= pin;
      anguloCerrado= angCerrado;
      anguloAbierto= angAbierto;
      estaAbierta= false;
    }
    //El attach() va en setup() y cierro de entrada para que no tire comida al enchufar el Arduino
    void inicializar() 
    {
      motorServo.attach(pinServo);
      cerrar();
    }
    void abrir() 
    {
      if ( !estaAbierta ) 
      {
        motorServo.write(anguloAbierto);
        estaAbierta= true;
      }
    }
    void cerrar() 
    {
      motorServo.write(anguloCerrado);
      estaAbierta= false;
    }
    bool abierta() 
    {
      return estaAbierta;
    }
};
//Maneja el relé que enciende/apaga la minibomba sumergible del bebedero
class BombaAgua 
{
  private:
    int pinRele;
    bool encendida;
  public:
    BombaAgua(int pin) 
    {
      pinRele= pin;
      encendida= false;
      pinMode(pinRele, OUTPUT);
      digitalWrite(pinRele, LOW); // Arranca cortada
    }
    void activar() 
    {
      encendida= true;
      digitalWrite(pinRele, HIGH);
    }
    void desactivar() 
    {
      encendida= false;
      digitalWrite(pinRele, LOW);
    }
    bool estaActiva() 
    {
      return encendida;
    }
};
//Instanciación de todos los objetos del sistema
//Calibración real de las tolvas a 21.0 cm:
//Dejo 3 cm arriba por el punto ciego del sensor + 18 cm de depósito recto = 21.0 cm.
//Los últimos 4 cm son el embudo inferior, así que al pasar los 21.0 cm ya avisa tolva vacía con reserva.
SensorUltrasonido ultrasonidoNormal(6, 7, 21.0);   //Tolva A: Trig D6, Echo D7
SensorUltrasonido ultrasonidoEspecial(8, 4, 21.0); //Tolva B: Trig D8, Echo D4
SensorPIR sensorPresenciaAgua(A0); //PIR en A0
SensorRFID lectorCollar(10, 9);    //RFID: SS en D10, RST en D9
Tolva tolvaNormal(3, 0, 90);       //Servo Tolva A en D3 (0° cerrada, 90° abierta)
Tolva tolvaEspecial(5, 0, 90);     //Servo Tolva B en D5 (0° cerrada, 90° abierta)
BombaAgua fuenteAgua(A1);          //Relé de la bomba en A1
Led ledVerde(A2);                  //Verde en A2
Led ledRojo(A3);                   //Rojo en A3
Buzzer alarmaSonora(2);            //Buzzer de alarma en D2
//Creo 4 cronómetros separados para que ninguna espera frene a otra
Timer timerTolvaNormal;
Timer timerTolvaEspecial;
Timer timerFuenteAgua;
Timer timerReporteSerial;
//Tiempos de operación en milisegundos
const unsigned long TIEMPO_DISPENSADO= 3000; //3 segundos de comida por ración
const unsigned long TIEMPO_AGUA= 45000;      //45 segundos corriendo la cascada
const unsigned long TIEMPO_REPORTE= 500;     //Mando datos a Processing cada medio segundo
//Guardo aparte el último gato que pasó para seguir mostrándolo en la PC aunque ya se haya ido
int ultimoGatoRegistrado= 0;
//SETUP
void setup() 
{
  Serial.begin(9600);           //Misma velocidad que uso en Processing
  lectorCollar.inicializar();   //Arranco SPI y lector RC522
  tolvaNormal.inicializar();    //Conecto servo A cerrado
  tolvaEspecial.inicializar();  //Conecto servo B cerrado
  timerReporteSerial.reiniciarYArrancar(); //Empiezo a contar para el primer envío Serial
}
//LOOP
void loop() 
{
  //Recibimos comandos manuales desde processing
  if ( Serial.available() > 0 ) 
  {
    char comando= Serial.read();
    //Si desde la PC piden servir comida común ('A') o especial ('B'), uso el mismo
    //camino lógico que el RFID para reutilizar los timers de cierre de 3 segundos
    if ( comando == 'A' || comando == 'a' ) 
    {
      lectorCollar.forzarGatoDesdePC(2); //Simulo Rubia -> abre Tolva A
    } 
    else if ( comando == 'B' || comando == 'b' ) 
    {
      lectorCollar.forzarGatoDesdePC(1); //Simulo Rufo -> abre Tolva B
    } 
    else if ( comando == 'W' || comando == 'w' ) 
    {
      //'W' prende la cascada de agua y reinicia sus 45 segundos
      fuenteAgua.activar();
      timerFuenteAgua.reiniciarYArrancar();
    }
  }
  //Chequear collar RFID y abrir la tolva que corresponde
  lectorCollar.generarMedicion();
  int gatoDetectado= (int)lectorCollar.leerMedicion();
  if ( gatoDetectado > 0 ) 
  {
    ultimoGatoRegistrado= gatoDetectado; //Actualizo quién fue el último para la pantalla
    //Si es Rufo (1) le abro únicamente la Tolva B(dieta especial)
    if ( gatoDetectado == 1 && !tolvaEspecial.abierta() ) 
    {
      tolvaEspecial.abrir();
      timerTolvaEspecial.reiniciarYArrancar();
    }
    //Si es Rubia (2) o Pelusa (3) les abro la Tolva A (dieta común)
    else if ( (gatoDetectado == 2 || gatoDetectado == 3) && !tolvaNormal.abierta() ) 
    {
      tolvaNormal.abrir();
      timerTolvaNormal.reiniciarYArrancar();
    }
    //Limpio el valor del RFID así no vuelve a entrar acá en la próxima iteración del loop
    lectorCollar.limpiarLectura();
  }
  //Cerramos las compuertas cuando pasaron 3 segundos
  if ( tolvaNormal.abierta() && timerTolvaNormal.obtenerTiempo() >= TIEMPO_DISPENSADO ) 
  {
    tolvaNormal.cerrar();
    timerTolvaNormal.detener();
  }
  if ( tolvaEspecial.abierta() && timerTolvaEspecial.obtenerTiempo() >= TIEMPO_DISPENSADO ) 
  {
    tolvaEspecial.cerrar();
    timerTolvaEspecial.detener();
  }
  //Control del bebedero con el sensor PIR
  sensorPresenciaAgua.generarMedicion();
  //Si detecta movimiento y la bomba estaba apagada, la prendo y arranco la cuenta de 45s
  if ( sensorPresenciaAgua.hayGatoCerca() && !fuenteAgua.estaActiva() ) 
  {
    fuenteAgua.activar();
    timerFuenteAgua.reiniciarYArrancar();
  }
  //Cuando pasan los 45 segundos la apago sola
  if ( fuenteAgua.estaActiva() && timerFuenteAgua.obtenerTiempo() >= TIEMPO_AGUA ) 
  {
    fuenteAgua.desactivar();
    timerFuenteAgua.detener();
  }
  //Cada 500ms medimos las tolvas (ya con filtro de media móvil), actualizamos alertas y mandamos la trama a la PC
  if ( timerReporteSerial.obtenerTiempo() >= TIEMPO_REPORTE ) 
  {
    timerReporteSerial.reiniciarYArrancar();
    //Actualizo las dos distancias filtradas
    ultrasonidoNormal.generarMedicion();
    ultrasonidoEspecial.generarMedicion();
    //Alerta local completa: si alguna tolva supera los 21.0 cm, parpadea el LED rojo y suena el buzzer cada 500ms
    if ( ultrasonidoNormal.tolvaVacia() || ultrasonidoEspecial.tolvaVacia() ) 
    {
      ledVerde.apagar();
      ledRojo.alternar();      //Parpadeo no bloqueante aprovechando el ciclo de 500ms
      alarmaSonora.alternar(); //Pitido intermitente sincronizado con el LED rojo
    } 
    else 
    {
      ledRojo.apagar();
      alarmaSonora.apagar();
      ledVerde.encender();
    }
    //Mando los 7 valores separados por comas y un println al final para que Processing los corte fácil:
    //distA,distB,ultimoGato,pir,tolvaA,tolvaB,bomba
    Serial.print(ultrasonidoNormal.leerMedicion());
    Serial.print(",");
    Serial.print(ultrasonidoEspecial.leerMedicion());
    Serial.print(",");
    Serial.print(ultimoGatoRegistrado);
    Serial.print(",");
    Serial.print((int)sensorPresenciaAgua.leerMedicion());
    Serial.print(",");
    Serial.print(tolvaNormal.abierta() ? 1 : 0);
    Serial.print(",");
    Serial.print(tolvaEspecial.abierta() ? 1 : 0);
    Serial.print(",");
    Serial.println(fuenteAgua.estaActiva() ? 1 : 0);
  }
}