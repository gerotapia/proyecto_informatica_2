### Introducción:
Este repositorio contiene el código fuente del **SIEMF (Sistema Inteligente de Enriquecimiento y Monitoreo Felino)**, proyecto integrador de **Informática II (UTN FRM)**. El sistema automatiza la alimentación selectiva de tres gatos (separando la dieta especial de **Rufo** de la dieta común de **Rubia** y **Pelusa**), monitorea el nivel de alimento en ambas tolvas, activa un bebedero cascada por presencia y se vincula mediante comunicación Serie con un panel de control gráfico en **Processing**.

### Esquemático y Hardware Utilizado:
Las conexiones sobre **Arduino UNO** (sin usar `D0` y `D1` para mantener libre el puerto Serie USB) se organizan de la siguiente manera:
* **Servo Tolva A (Dieta Común):** Conectado al **Pin Digital 3 (PWM)**.
* **Servo Tolva B (Dieta Especial - Rufo):** Conectado al **Pin Digital 5 (PWM)**.
* **Sensor Ultrasónico 1 (Tolva A):** `Trig` en **Pin Digital 6** y `Echo` en **Pin Digital 7**.
* **Sensor Ultrasónico 2 (Tolva B):** `Trig` en **Pin Digital 8** y `Echo` en **Pin Digital 4**.
* **Lector RFID RC522 (Bus SPI):** `RST` en **Pin Digital 9**, `SDA (SS)` en **Pin Digital 10**, y `MOSI / MISO / SCK` en **Pines Digitales 11, 12 y 13**.
* **Sensor de Movimiento PIR (Bebedero):** Señal conectada a **Pin Analógico A0**.
* **Módulo Relé (Bomba de Agua):** Control conectado a **Pin Analógico A1**.
* **Indicadores LED:** LED Verde en **Pin Analógico A2** y LED Rojo en **Pin Analógico A3**.

### Lógica de Comunicación:
El intercambio de información entre la placa y la PC se realiza por puerto Serie mediante programación orientada a objetos y multitarea con `millis()` (clase `Timer`):

* **De Arduino a PC:**
Cada `500 ms`, el Arduino envía una trama de texto con **7 valores numéricos separados por comas**
  `distanciaTolvaA,distanciaTolvaB,ultimoGato,presenciaAgua,estadoTolvaA,estadoTolvaB,estadoBomba`
* **De PC a Arduino:**
Desde la interfaz gráfica en Processing, al interactuar con los controles se envían caracteres de control por USB:
  * Letra `A`: Dispara la apertura de la **Tolva A** (dieta común) por `3` segundos.
  * Letra `B`: Dispara la apertura de la **Tolva B** (dieta especial) por `3` segundos.
  * Letra `W`: Activa la **bomba de agua** del bebedero cascada durante `45` segundos.

### Interfaz Gráfica y Registro de Eventos:
El panel en Processing se divide en tres columnas con botones dibujados geométricamente (patitas para tolvas y gotas de agua para el bebedero), modo de prueba por teclado (`1`, `2`, `3`, `V`, `P`) cuando no hay placa conectada, y una **Lista Enlazada** simple en memoria RAM que registra cada evento con formato `[dd/mm/aaaa hh:mm:ss]`.

### Funcionalidades Completas del Sistema:
Además de la arquitectura POO, la identificación RFID/PIR y la interfaz de control en tiempo real, el proyecto integra procesamiento numérico mediante un **filtro de media móvil** en los sensores ultrasónicos (calibrados a `21.0 cm` según el armado real de las tolvas), alertas locales visuales y sonoras mediante **LED rojo intermitente y buzzer** y **persistencia de datos en archivo `.txt`** para exportar y recuperar el historial de la Lista Enlazada en Processing.
