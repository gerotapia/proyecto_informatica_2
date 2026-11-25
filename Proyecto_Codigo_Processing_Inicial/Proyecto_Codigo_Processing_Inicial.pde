//PROYECTO FINAL: SIEMF - INTERFAZ GRÁFICA EN PROCESSING
import processing.serial.*; //Librería para poder comunicar Processing con el Arduino por USB
//Estructura de la Lista Enlazada simple (para ir guardando el historial de eventos en la RAM)
//Cada NodoEvento es un renglón del historial con su texto y una referencia al siguiente nodo
class NodoEvento 
{
  String textoEvento;   //Guarda fecha, hora y lo que pasó (ej: "[22/11/2026 15:20:01] RFID: Se acercó RUFO")
  NodoEvento siguiente; //Apunta al próximo nodo de la cadena
  NodoEvento(String texto) 
  {
    textoEvento= texto;
    siguiente= null; //Cuando recién se crea no apunta a nada
  }
}
//Clase que administra toda la lista enlazada
class ListaEnlazada 
{
  NodoEvento cabeza; //Apunta siempre al evento más nuevo (así aparece arriba de todo)
  int cantidadNodos; //Contador para saber cuántos eventos se guardaron
  ListaEnlazada() 
  {
    cabeza= null;
    cantidadNodos= 0;
  }
  //Agrega un evento nuevo al principio de la lista (inserción por cabeza)
  void agregarEvento(String descripcion) 
  {
    //Uso nf(..., 2) para que día, mes y hora siempre tengan 2 dígitos (ej: 22/11/2026 a las 08:05)
    String fechaActual= nf(day(), 2) + "/" + nf(month(), 2) + "/" + year();
    String horaActual= nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
    String registroCompleto= "[" + fechaActual + " " + horaActual + "] " + descripcion;
    //Creo el nodo nuevo y lo engancho adelante de la cabeza anterior
    NodoEvento nuevoNodo= new NodoEvento(registroCompleto);
    nuevoNodo.siguiente= cabeza;
    cabeza= nuevoNodo;
    cantidadNodos= cantidadNodos + 1;
  }
}
//Variables para la conexión por puerto Serie con la placa
Serial puertoArduino;            //Objeto que representa el puerto COM del Arduino
boolean arduinoConectado= false; //Me avisa si encontró la placa o si está en modo simulación
//Variables para las barras en pantalla y los datos que llegan desde el Arduino (son 7 valores)
float distanciaTolvaA= 5.0; //Distancia medida en Tolva A (cm)
float distanciaTolvaB= 5.0; //Distancia medida en Tolva B (cm)
int ultimoGato= 0;          //0= Ninguno, 1= Rufo, 2= Rubia, 3= Pelusa
int presenciaAgua= 0;       //1= Gato cerca del PIR, 0= Sin movimiento
int estadoTolvaA= 0;        //1= Servo A abierto, 0= Cerrado
int estadoTolvaB= 0;        //1= Servo B abierto, 0= Cerrado
int estadoBomba= 0;         //1= Bomba encendida, 0= Apagada
//Variables del ciclo anterior para comparar y detectar cuándo cambia algo
//Si no comparo contra el estado anterior, cada 500 ms me anotaría el mismo evento repetido en la lista
int ultimoGatoAnterior= 0;
int estadoTolvaAAnterior= 0;
int estadoTolvaBAnterior= 0;
int estadoBombaAnterior= 0;
boolean alertaVacioAnterior= false;
//Bandera para desplegar u ocultar la consola de historial con el botón de la derecha
boolean mostrarHistorial= false;
//Instancia de la Lista Enlazada donde se va registrando todo en memoria
ListaEnlazada historialEventos= new ListaEnlazada();
//Configuración inicial de la ventana
void setup() 
{
  size(1150, 680); //Tamaño definitivo del Panel de Control
  smooth(8);       //Suavizado de bordes
  //Primer registro apenas se abre la interfaz
  historialEventos.agregarEvento("Sistema SIEMF iniciado en PC.");
  //Busco los puertos COM conectados en Windows para engancharme solo al Arduino
  String[] listaPuertos= Serial.list();
  if ( listaPuertos.length > 0 ) 
  {
    try 
    {
      //Abro el primer puerto encontrado a 9600 baudios (igual que Serial.begin en Arduino)
      puertoArduino= new Serial(this, listaPuertos[0], 9600);
      //Le indico que junte los datos hasta encontrar el salto de línea que manda Arduino con println
      puertoArduino.bufferUntil('\n');
      arduinoConectado= true;
      historialEventos.agregarEvento("Conectado a Arduino en " + listaPuertos[0]);
    } 
    catch (Exception e) 
    {
      //Si el puerto está ocupado (ej: quedó abierto el Monitor Serie) pasa a simulación sin crashear
      arduinoConectado= false;
      historialEventos.agregarEvento("Modo Simulación (Puerto ocupado o sin placa).");
    }
  } 
  else 
  {
    //Si no hay ningún Arduino enchufado, arranca en modo prueba para usar con el teclado
    arduinoConectado= false;
    historialEventos.agregarEvento("Modo Simulación activo (Arduino no detectado).");
  }
}
//Bucle de dibujo continuo
void draw() 
{
  //Color de fondo general: Azul petróleo oscuro
  background(24, 30, 44);
  //Dibujo del encabezado y las tres columnas principales
  dibujarEncabezado();
  dibujarColumnaAlimentacion();
  dibujarColumnaCentral();
  dibujarColumnaHistorial();
}
//A continuación están las funciones para dibujar cada sección
//Funcion para dibujar el título superior "Panel de control"
void dibujarEncabezado() 
{
  noStroke();
  fill(16, 20, 30);
  rect(0, 0, width, 85);
  stroke(0, 210, 211);
  strokeWeight(3);
  line(350, 75, width - 350, 75);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(34);
  text("Panel de control", width / 2, 32);
  //Subtítulo dinámico: avisa en verde si está conectado el Arduino o en naranja si estoy simulando
  textSize(13);
  if ( arduinoConectado == true ) 
  {
    fill(46, 213, 115);
    text("SIEMF - En línea con Arduino UNO", width / 2, 60);
  } 
  else 
  {
    fill(255, 165, 2);
    text("SIEMF - Modo Prueba sin placa (Teclas 1, 2, 3, V, P para simular)", width / 2, 60);
  }
}
//Funcion para dibujar la columna izquierda con las barras de nivel y los botones con forma de patita
void dibujarColumnaAlimentacion() 
{
  //Tarjeta contenedora izquierda
  stroke(45, 55, 75);
  strokeWeight(2);
  fill(32, 40, 58);
  rect(25, 105, 360, 550, 18);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("Control de Tolvas", 205, 135);
  //Cálculo de porcentaje útil ya calibrado a las tolvas reales (3.0 cm = 100% | 21.0 cm = 0%)
  //Dejé 3 cm arriba por el punto ciego del HC-SR04 y 21 cm donde empieza el embudo de reserva
  //Uso constrain para que el porcentaje nunca se pase de 0 ni de 100 si el sensor mide de más o de menos
  float porcentajeA= constrain(map(distanciaTolvaA, 21.0, 3.0, 0, 100), 0, 100);
  float porcentajeB= constrain(map(distanciaTolvaB, 21.0, 3.0, 0, 100), 0, 100);
  //Barras de Tolva A y Tolva B junto con el cartel de si la compuerta está abierta o cerrada
  dibujarBarraTolva(65, 185, 95, 210, porcentajeA, distanciaTolvaA, "Tolva A (Común)");
  dibujarEstadoCompuerta(112, 435, estadoTolvaA);
  //Cambié los botones rectangulares de antes por patitas de gato hechas con geometría
  //Calculo la distancia del mouse al centro de la patita (radio 48) para aclararla cuando paso por encima
  boolean mouseEnPataA= dist(mouseX, mouseY, 112, 545) < 48;
  color colorPataA= (mouseEnPataA == true) ? color(255, 140, 140) : color(255, 107, 107);
  dibujarPatitaGato(112, 545, 1.0, colorPataA);
  fill(255);
  textSize(13);
  text("Servir Común (A)", 112, 615);
  dibujarBarraTolva(245, 185, 95, 210, porcentajeB, distanciaTolvaB, "Tolva B (Rufo)");
  dibujarEstadoCompuerta(292, 435, estadoTolvaB);
  //Mismo efecto para el botón de la dieta especial de Rufo (en violeta)
  boolean mouseEnPataB= dist(mouseX, mouseY, 292, 545) < 48;
  color colorPataB= (mouseEnPataB == true) ? color(190, 160, 255) : color(162, 155, 254);
  dibujarPatitaGato(292, 545, 1.0, colorPataB);
  fill(255);
  textSize(13);
  text("Servir Especial (B)", 292, 615);
}
//Funcion para dibujar cada barra de nivel de alimento con cambio de color por alerta
void dibujarBarraTolva(float x, float y, float ancho, float alto, float porcentaje, float cm, String titulo) 
{
  fill(220);
  textAlign(CENTER, CENTER);
  textSize(14);
  text(titulo, x + ancho / 2, y - 18);
  stroke(80, 95, 120);
  strokeWeight(2);
  fill(20, 25, 36);
  rect(x, y, ancho, alto, 10);
  //Umbral calibrado en 21.0 cm (sincronizado con el Arduino para que salte la alerta al mismo tiempo)
  if ( cm > 21.0 ) 
  {
    fill(255, 71, 87); //Rojo: Alerta
  } 
  else 
  {
    fill(46, 213, 115); //Verde: Hay suficiente comida
  }
  noStroke();
  float alturaRelleno= map(porcentaje, 0, 100, 0, alto - 6);
  rect(x + 3, y + alto - alturaRelleno - 3, ancho - 6, alturaRelleno, 8);
  fill(255);
  textSize(20);
  text(int(porcentaje) + "%", x + ancho / 2, y + alto / 2 - 10);
  textSize(12);
  fill(200);
  text(nf(cm, 1, 1) + " cm", x + ancho / 2, y + alto / 2 + 15);
  if ( cm > 21.0 ) 
  {
    fill(255, 71, 87);
    textSize(12);
    text("¡VACÍA!", x + ancho / 2, y + alto + 15);
  }
}
//Funcion para dibujar el cartelito debajo de cada barra que avisa si el servo abrió la compuerta
void dibujarEstadoCompuerta(float x, float y, int abierta) 
{
  noStroke();
  if ( abierta == 1 ) 
  {
    fill(46, 213, 115); //Verde brillante cuando está dispensando
    rect(x - 50, y, 100, 26, 6);
    fill(20);
    textSize(12);
    text("ABIERTA", x, y + 13);
  } 
  else 
  {
    fill(55, 65, 85); //Gris oscuro en reposo
    rect(x - 50, y, 100, 26, 6);
    fill(190);
    textSize(12);
    text("CERRADA", x, y + 13);
  }
}
//Funcion para dibujar una patita de gato con elipses rotadas (así no dependo de imágenes externas)
void dibujarPatitaGato(float x, float y, float escala, color colorBase) 
{
  pushMatrix();    //Guardo el sistema de coordenadas original antes de moverlo
  translate(x, y); //Llevo el origen (0,0) al centro del botón para ubicar todo simétrico
  scale(escala);
  //Aro circular de fondo para que se entienda que toda esa zona es clickeable
  stroke(255, 80);
  strokeWeight(2);
  fill(22, 28, 42);
  ellipse(0, 0, 92, 92);

  noStroke();
  fill(colorBase);
  //Almohadilla central (la palma)
  ellipse(0, 12, 42, 34);
  //Los 4 deditos de arriba, cada uno con push/pop propio para rotarlo sin mover los demás
  pushMatrix();
  translate(-22, -6);
  rotate(radians(-25));
  ellipse(0, 0, 14, 20);
  popMatrix();

  pushMatrix();
  translate(-8, -16);
  rotate(radians(-8));
  ellipse(0, 0, 14, 22);
  popMatrix();

  pushMatrix();
  translate(8, -16);
  rotate(radians(8));
  ellipse(0, 0, 14, 22);
  popMatrix();

  pushMatrix();
  translate(22, -6);
  rotate(radians(25));
  ellipse(0, 0, 14, 20);
  popMatrix();

  popMatrix(); //Vuelvo las coordenadas a la normalidad
}
//Funcion para la columna central (ahora ya funcional con RFID y los indicadores del Bebedero)
void dibujarColumnaCentral() 
{
  stroke(45, 55, 75);
  strokeWeight(2);
  fill(32, 40, 58);
  rect(405, 105, 340, 550, 18);
  //Parte superior: Identificación por collar RFID
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("Identificación RFID", 575, 135);
  stroke(70, 90, 120);
  fill(20, 26, 38);
  rect(430, 160, 290, 95, 12);
  textSize(13);
  fill(170);
  text("ÚLTIMO COLLAR DETECTADO:", 575, 182);
  //Muestro el nombre y el tipo de dieta según el ID de gato que mandó el Arduino
  textSize(22);
  if ( ultimoGato == 1 ) 
  {
    fill(162, 155, 254); //Violeta para Rufo
    text("RUFO (Dieta Especial)", 575, 218);
  } 
  else if ( ultimoGato == 2 ) 
  {
    fill(255, 159, 67); //Naranja para Rubia
    text("RUBIA (Dieta Común)", 575, 218);
  } 
  else if ( ultimoGato == 3 ) 
  {
    fill(72, 219, 251); //Celeste para Pelusa
    text("PELUSA (Dieta Común)", 575, 218);
  } 
  else 
  {
    fill(130);
    text("Esperando lectura...", 575, 218);
  }
  //Línea divisoria entre la parte del RFID y la parte del agua
  stroke(45, 55, 75);
  line(435, 280, 715, 280);
  //Parte inferior: Bebedero Cascada (sensor PIR + estado de bomba + botón manual)
  fill(255);
  textSize(20);
  text("Bebedero Cascada", 575, 310);
  //Estado en tiempo real del sensor de movimiento PIR
  if ( presenciaAgua == 1 ) 
  {
    fill(46, 213, 115);
    textSize(14);
    text("Sensor PIR: ¡GATO EN EL AGUA!", 575, 342);
  } 
  else 
  {
    fill(160);
    textSize(14);
    text("Sensor PIR: Sin movimiento", 575, 342);
  }
  //Gota izquierda: solo indicador visual (se prende celeste cuando la bomba está activa)
  color colorIndicadorGota= (estadoBomba == 1) ? color(0, 210, 255) : color(65, 75, 95);
  dibujarGotaAgua(495, 465, 1.0, colorIndicadorGota, false);
  fill(220);
  textSize(13);
  text("Estado Bomba:", 495, 545);
  if ( estadoBomba == 1 ) 
  {
    fill(0, 210, 255);
    text("FUNCIONANDO", 495, 565);
  } 
  else 
  {
    fill(140);
    text("APAGADA", 495, 565);
  }
  //Gota derecha: botón interactivo para prender la cascada a mano durante 45 segundos
  boolean mouseEnGotaBoton= dist(mouseX, mouseY, 650, 465) < 48;
  color colorBotonGota= (mouseEnGotaBoton == true) ? color(80, 190, 255) : color(30, 144, 255);
  dibujarGotaAgua(650, 465, 1.0, colorBotonGota, true);
  fill(255);
  textSize(13);
  text("Activar Cascada", 650, 545);
  fill(170);
  text("(Click = 45 seg)", 650, 565);
}
//Funcion para dibujar una gota de agua con curva de Bézier para que se vea más natural sin cortes
void dibujarGotaAgua(float x, float y, float escala, color colorGota, boolean esBoton) 
{
  pushMatrix();
  translate(x, y);
  scale(escala);
  //Si es el botón manual, le agrego el círculo contenedor alrededor para diferenciarlo del indicador
  if ( esBoton == true ) 
  {
    stroke(255, 100);
    strokeWeight(2);
    fill(22, 28, 42);
    ellipse(0, 0, 96, 96);
  }
  noStroke();
  fill(colorGota);
  //Dibujo la gota en un solo trazo continuo para que la punta se funda suave con la parte redonda
  beginShape();
  vertex(0, -34); //Punta superior de la gota
  bezierVertex(14, -14, 24, 1, 24, 13);
  bezierVertex(24, 27, 13, 36, 0, 36);
  bezierVertex(-13, 36, -24, 27, -24, 13);
  bezierVertex(-24, 1, -14, -14, 0, -34);
  endShape(CLOSE);
  //Pequeño reflejo blanco semitransparente para darle volumen
  fill(255, 110);
  ellipse(-9, 13, 9, 17);
  popMatrix();
}
//Funcion para la columna derecha (Lista Enlazada en RAM + consola desplegable)
void dibujarColumnaHistorial() 
{
  stroke(45, 55, 75);
  strokeWeight(2);
  fill(32, 40, 58);
  rect(765, 105, 360, 550, 18);
  //Botón superior para abrir o cerrar la consola de eventos
  boolean mouseEnBotonConsola= (mouseX > 790 && mouseX < 1100 && mouseY > 125 && mouseY < 170);
  if ( mostrarHistorial == true ) 
  {
    fill(mouseEnBotonConsola ? color(255, 120, 90) : color(235, 95, 70)); //Rojo para ocultar
  } 
  else 
  {
    fill(mouseEnBotonConsola ? color(0, 210, 211) : color(0, 180, 185)); //Turquesa para ver
  }
  noStroke();
  rect(790, 125, 310, 45, 10);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(15);
  if ( mostrarHistorial == false ) 
  {
    text("Ver consola o historial", 945, 147);
  } 
  else 
  {
    text("Ocultar consola o historial", 945, 147);
  }
  //Si está oculto muestro cuántos eventos hay en RAM; si está abierto recorro la lista
  if ( mostrarHistorial == false ) 
  {
    stroke(50, 65, 90);
    fill(22, 28, 42);
    rect(790, 190, 310, 440, 12);
    fill(180);
    textSize(15);
    text("Historial oculto en pantalla", 945, 370);
    fill(110, 210, 160);
    textSize(13);
    text("Grabando en Lista Enlazada...", 945, 405);
    fill(150);
    text("Eventos en RAM: " + historialEventos.cantidadNodos, 945, 435);
  } 
  else 
  {
    //Caja negra estilo consola
    stroke(60, 80, 110);
    fill(14, 18, 26);
    rect(790, 185, 310, 390, 8);
    fill(120, 255, 160); //Letras verdes
    textAlign(LEFT, TOP);
    textSize(11); //Tamaño 11 para que entre bien la fecha dd/mm/aaaa y la hora sin pasarse del borde
    //Recorro la Lista Enlazada desde la cabeza hasta mostrar un máximo de 16 líneas para que no se salga
    NodoEvento actual= historialEventos.cabeza;
    int posY= 198;
    int contadorMostrados= 0;
    while ( actual != null && contadorMostrados < 16 ) 
    {
      text(actual.textoEvento, 800, posY);
      posY= posY + 23;
      actual= actual.siguiente;
      contadorMostrados= contadorMostrados + 1;
    }
    //Acá abajo después voy a poner los botones de Guardar y Cargar el archivo .txt
    textAlign(CENTER, CENTER);
    fill(140);
    textSize(12);
    text("Pendiente: guardado en archivo (.txt)", 945, 612);
  }
}
//Funcion para detectar los clics del mouse en los botones (patitas, gota y consola)
void mousePressed() 
{
  //Si hice clic en la Patita A, mando 'A' al Arduino para servir comida común
  if ( dist(mouseX, mouseY, 112, 545) < 48 ) 
  {
    enviarComandoArduino('A');
    historialEventos.agregarEvento("Orden PC: Abrir Tolva A (Común)");
  }

  //Si hice clic en la Patita B, mando 'B' al Arduino para servir la comida de Rufo
  if ( dist(mouseX, mouseY, 292, 545) < 48 ) 
  {
    enviarComandoArduino('B');
    historialEventos.agregarEvento("Orden PC: Abrir Tolva B (Rufo)");
  }
  //Si hice clic en la Gota de la derecha, mando 'W' para prender el bebedero 45 segundos
  if ( dist(mouseX, mouseY, 650, 465) < 48 ) 
  {
    enviarComandoArduino('W');
    historialEventos.agregarEvento("Orden PC: Cascada activada (45s)");
  }
  //Si hice clic en el botón de arriba a la derecha, muestro u oculto la consola
  if ( mouseX > 790 && mouseX < 1100 && mouseY > 125 && mouseY < 170 ) 
  {
    mostrarHistorial= !mostrarHistorial;
  }
}
//Envia la letra al Arduino por USB (y si estoy sin placa, actualiza la pantalla para poder probar)
void enviarComandoArduino(char letra) 
{
  if ( arduinoConectado == true && puertoArduino != null ) 
  {
    puertoArduino.write(letra);
  } 
  else 
  {
    if ( letra == 'A' ) estadoTolvaA= 1;
    if ( letra == 'B' ) estadoTolvaB= 1;
    if ( letra == 'W' ) estadoBomba= 1;
  }
}
//Funcion automática de Processing: se dispara cada vez que llega una línea completa ('\n') desde el Arduino
void serialEvent(Serial miPuerto) 
{
  String lineaRecibida= miPuerto.readStringUntil('\n');

  if ( lineaRecibida != null ) 
  {
    lineaRecibida= trim(lineaRecibida); //Limpio espacios o saltos de línea sobrantes
    String[] datos= split(lineaRecibida, ','); //Separo la trama usando las comas

    //Verifico que hayan llegado justo los 7 valores para no tener errores si una trama llegó cortada
    if ( datos.length == 7 ) 
    {
      distanciaTolvaA= float(datos[0]);
      distanciaTolvaB= float(datos[1]);
      ultimoGato= int(datos[2]);
      presenciaAgua= int(datos[3]);
      estadoTolvaA= int(datos[4]);
      estadoTolvaB= int(datos[5]);
      estadoBomba= int(datos[6]);
      //Apenas actualizo los datos, me fijo si hubo algún cambio para anotarlo en el historial
      verificarNuevosEventos();
    }
  }
}
//Revisa qué cambió respecto al ciclo anterior para grabar cada evento una sola vez en la Lista Enlazada
void verificarNuevosEventos() 
{
  //Anoto el gato solo cuando cambia el último collar leído
  if ( ultimoGato != ultimoGatoAnterior && ultimoGato > 0 ) 
  {
    if ( ultimoGato == 1 ) historialEventos.agregarEvento("RFID: Se acercó RUFO");
    if ( ultimoGato == 2 ) historialEventos.agregarEvento("RFID: Se acercó RUBIA");
    if ( ultimoGato == 3 ) historialEventos.agregarEvento("RFID: Se acercó PELUSA");
    ultimoGatoAnterior= ultimoGato;
  }
  //Anoto apertura de Tolva A solo en el momento que pasa de cerrada (0) a abierta (1)
  if ( estadoTolvaA == 1 && estadoTolvaAAnterior == 0 ) 
  {
    historialEventos.agregarEvento("Compuerta Tolva A ABIERTA");
  }
  estadoTolvaAAnterior= estadoTolvaA;
  //Lo mismo para la Tolva B
  if ( estadoTolvaB == 1 && estadoTolvaBAnterior == 0 ) 
  {
    historialEventos.agregarEvento("Compuerta Tolva B ABIERTA");
  }
  estadoTolvaBAnterior= estadoTolvaB;
  //Lo mismo cuando se enciende la bomba de agua
  if ( estadoBomba == 1 && estadoBombaAnterior == 0 ) 
  {
    historialEventos.agregarEvento("Bebedero: Cascada ENCENDIDA");
  }
  estadoBombaAnterior= estadoBomba;
  //Disparo la alerta de falta de comida una sola vez al superar el límite calibrado de 21.0 cm
  boolean hayAlertaAhora= (distanciaTolvaA > 21.0 || distanciaTolvaB > 21.0);
  if ( hayAlertaAhora == true && alertaVacioAnterior == false ) 
  {
    historialEventos.agregarEvento("¡ALERTA! Nivel bajo en tolva");
  }
  alertaVacioAnterior= hayAlertaAhora;
}
//Pruebas con teclado para simular sin la placa:
//1, 2 y 3 simulan collares RFID; "v" simula tolva vacía (cambia la barra a rojo); "p" simula el sensor PIR
void keyPressed() 
{
  if ( key == '1' ) { ultimoGato= 1; estadoTolvaB= 1; verificarNuevosEventos(); }
  if ( key == '2' ) { ultimoGato= 2; estadoTolvaA= 1; verificarNuevosEventos(); }
  if ( key == '3' ) { ultimoGato= 3; estadoTolvaA= 1; verificarNuevosEventos(); }
  if ( key == 'v' || key == 'V' ) 
  {
    //Alterno entre 6.0 cm (llena) y 22.5 cm (vacía, superando los 21.0 cm calibrados)
    distanciaTolvaA= (distanciaTolvaA > 21.0) ? 6.0 : 22.5;
    verificarNuevosEventos();
  }
  if ( key == 'p' || key == 'P' ) 
  {
    presenciaAgua= (presenciaAgua == 0) ? 1 : 0;
    estadoBomba= presenciaAgua;
    verificarNuevosEventos();
  }
}
//Me falta hacer: Guardar y cargar el historial en un archivo TXT
