//PROYECTO FINAL INTEGRADOR: SIEMF
//PINES ASIGNADOS HASTA EL MOMENTO:
//- D3:  Servomotor 1 PWM - Compuerta Tolva A (Dieta Común)
//- D4:  Pin Echo - Sensor Ultrasónico 2 (Tolva B)
//- D5:  Servomotor 2 PWM - Compuerta Tolva B (Dieta Especial)
//- D6:  Pin Trig - Sensor Ultrasónico 1 (Tolva A)
//- D7:  Pin Echo - Sensor Ultrasónico 1 (Tolva A)
//- D8:  Pin Trig - Sensor Ultrasónico 2 (Tolva B)
//- A2:  LED Verde (Hay comida disponible)
//- A3:  LED Rojo  (Alerta tolva vacía)
#include <Servo.h>//Librería para manejar los servomotores
//Jerarquía de sensores(clase padre y priemra clase hija)
class Sensor 
{
  protected: 
    float valor;
    String magnitud;
  public:
    Sensor(String mag) 
    {
      magnitud= mag;
      valor= 0.0;
    }
    virtual void generarMedicion() 
    {
      valor= 0.0;
    }
    float leerMedicion() 
    {
      return valor;
    }
    String getMagnitud() 
    {
      return magnitud;
    }
};
//Hija 1: Sensor de Ultrasonido(HC-SR04)
class SensorUltrasonido : public Sensor 
{
  private:
    int pinTrig;
    int pinEcho;
    float distanciaAlarma;
  public:
    SensorUltrasonido(int trig, int echo, float distAlarma) : Sensor("cm") 
    {
      pinTrig= trig;
      pinEcho= echo;
      distanciaAlarma= distAlarma;
      pinMode(pinTrig, OUTPUT);
      pinMode(pinEcho, INPUT);
    }
    void generarMedicion() override 
    {
      digitalWrite(pinTrig, LOW);
      delayMicroseconds(2);
      digitalWrite(pinTrig, HIGH);
      delayMicroseconds(10);
      digitalWrite(pinTrig, LOW);
      long duracion= pulseIn(pinEcho, HIGH, 30000);
      if ( duracion > 0 ) 
      {
        valor= duracion * 0.034 / 2.0;
      } 
      else 
      {
        valor= 0.0;
      }
    }
    bool tolvaVacia() 
    {
      return ( valor > distanciaAlarma );
    }
};
//Clases de actuadores(Leds Y Tolvas)
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
      digitalWrite(pin, LOW);
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
};
class Tolva 
{
  private:
    Servo motorServo;
    int pinServo;
    int anguloCerrado;
    int anguloAbierto;
    bool estaAbierta;
  public:
    Tolva(int pin, int angCerrado, int angAbierto) 
    {
      pinServo= pin;
      anguloCerrado= angCerrado;
      anguloAbierto= angAbierto;
      estaAbierta= false;
    }
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
//Instanciación de objetos globales
//Usé una medida provisoria, la medida final dependerá de cómo quede armada la maqueta
SensorUltrasonido ultrasonidoNormal(6, 7, 18.0);   
SensorUltrasonido ultrasonidoEspecial(8, 4, 18.0); 
Tolva tolvaNormal(3, 0, 90);                       
Tolva tolvaEspecial(5, 0, 90);                     
Led ledVerde(A2);                                  
Led ledRojo(A3);                                   
//Setup
void setup() 
{
  Serial.begin(9600);
  tolvaNormal.inicializar();
  tolvaEspecial.inicializar();
  Serial.println("SIEMF v0.3 - Prueba inicial de sensores y tolvas");
}
//Loop(es una prueba inicial y por eso uso delay, luego implementaré Millis)
void loop() 
{
  //Leemos ambos sensores ultrasónicos
  ultrasonidoNormal.generarMedicion();
  ultrasonidoEspecial.generarMedicion();
  //Control visual básico con LEDs según nivel de comida
  if ( ultrasonidoNormal.tolvaVacia() || ultrasonidoEspecial.tolvaVacia() ) 
  {
    ledVerde.apagar();
    ledRojo.encender();
  } 
  else 
  {
    ledRojo.apagar();
    ledVerde.encender();
  }
  //Impresión básica por Monitor Serie para verificar distancias
  Serial.print("Tolva A: ");
  Serial.print(ultrasonidoNormal.leerMedicion());
  Serial.print(" cm | Tolva B: ");
  Serial.print(ultrasonidoEspecial.leerMedicion());
  Serial.println(" cm");
  delay(500); //Temporal - reemplazar con millis()
}