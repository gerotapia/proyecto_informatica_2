//PROYECTO FINAL: SIEMF - INTERFAZ GRÁFICA EN PROCESSING
//Variables para probar las barras en pantalla
float distanciaTolvaA= 5.0; //Distancia medida en Tolva A (cm)
float distanciaTolvaB= 5.0; //Distancia medida en Tolva B (cm)
//Configuración inicial de la ventana
void setup() 
{
  size(1150, 680); //Tamaño definitivo del Panel de Control
  smooth(8);       //Suavizado de bordes
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
////A continuación están las funciones para dibujar cada sección
//Funcio para dibujar el título superior "Panel de control"
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
  textSize(13);
  fill(160);
  text("SIEMF -Interfaz inicial", width / 2, 60);
}
//Funcion para dibujar la columna izquierda con las barras de nivel y botones provisorios
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

  //Cálculo de porcentaje (3 cm = 100% | 22 cm = 0%)
  float porcentajeA= constrain(map(distanciaTolvaA, 22.0, 3.0, 0, 100), 0, 100);
  float porcentajeB= constrain(map(distanciaTolvaB, 22.0, 3.0, 0, 100), 0, 100);
  //Barras de Tolva A y Tolva B
  dibujarBarraTolva(65, 185, 95, 210, porcentajeA, distanciaTolvaA, "Tolva A (Común)");
  dibujarBarraTolva(245, 185, 95, 210, porcentajeB, distanciaTolvaB, "Tolva B (Rufo)");
  //Botones (seguramente les voy a cambiar la forma)
  noStroke();
  fill(70, 85, 110);
  rect(55, 520, 115, 45, 8);
  rect(235, 520, 115, 45, 8);
  fill(220);
  textSize(13);
  text("Servir A", 112, 542);
  text("Servir B", 292, 542);
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
  //Umbral en 18.0 cm (que es la medida inicial, pero puede cambiar)
  if ( cm > 18.0 ) 
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
  if ( cm > 18.0 ) 
  {
    fill(255, 71, 87);
    textSize(12);
    text("¡VACÍA!", x + ancho / 2, y + alto + 15);
  }
}
//Funcion para el espacio reservado para la columna central (RFID y Bebedero)
void dibujarColumnaCentral() 
{
  stroke(45, 55, 75);
  strokeWeight(2);
  fill(32, 40, 58);
  rect(405, 105, 340, 550, 18);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("Identificación RFID", 575, 135);
  stroke(70, 90, 120);
  fill(20, 26, 38);
  rect(430, 160, 290, 95, 12);
  fill(130);
  textSize(14);
  text("Módulo RFID en desarrollo...", 575, 207);
  stroke(45, 55, 75);
  line(435, 280, 715, 280);
  fill(255);
  textSize(20);
  text("Bebedero Cascada", 575, 310);
  fill(130);
  textSize(14);
  text("Indicadores de agua pendientes...", 575, 440);//Debo agregar los indicadores de agua
}
//Funciom para el espacio reservado para la columna derecha (Lista Enlazada y Archivos)
void dibujarColumnaHistorial() 
{
  stroke(45, 55, 75);
  strokeWeight(2);
  fill(32, 40, 58);
  rect(765, 105, 360, 550, 18);
  fill(255);
  textAlign(CENTER, CENTER);
  textSize(20);
  text("Historial de Eventos", 945, 135);
  stroke(50, 65, 90);
  fill(22, 28, 42);
  rect(790, 180, 310, 445, 12);
  fill(140);
  textSize(14);
  text("Pendiente: Lista Enlazada", 945, 380);
  text("y guardado en archivo.", 945, 405);
}
//Purueba con teclado: Verificar cambio de color en las barras
//Se observa que al presionar "v" cambia de color la barra a rojo (indica que hay poca comida)
void keyPressed() 
{
  if ( key == 'v' || key == 'V' ) 
  {
    distanciaTolvaA= (distanciaTolvaA > 18.0) ? 5.0 : 20.0;
  }
}
//Me falta hacer: Conexión Serial, botones personalizados, la parte del bebedero, Lista Enlazada y los archivos en TXT
