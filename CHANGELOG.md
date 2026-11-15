# Changelog

Cambios de FocusPulse AI por fase. La versión sigue el esquema *mayor.fase.parche*
(`AppInfo.VERSION`): la fase N es la 0.N.0 y la fase 12 cierra la 1.0.0. `AppInfo` existe
desde la fase 8; las versiones anteriores son la numeración retroactiva de cada fase.
Detalle de cada módulo en [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) y de lo verificado
en [docs/PENDIENTES.md](docs/PENDIENTES.md).

## 1.0.0 — Fase 12: pulido final (2026-11-15)

- **Sin datos del sensor**: tras más de 5 s sin lotes del acelerómetro con la guardia
  activa, la píldora pasa a "Sin datos del sensor" (ámbar) y se quita sola al volver los
  datos; la quietud vuelve a contar desde cero, así que un corte no dispara inactividad
  (`SensorWatchdog`, `DrowsinessDetector.onDataGap`).
- **Alerta sobre menús**: una alerta que llega con un menú o submenú abierto los cierra
  (`ViewUnwinder`, una vista cada 50 ms) y se abre sobre la esfera; al responder se vuelve a
  ella. La vibración arranca en el primer cuadro de la alerta para no pasar de 3 timers.
- **Anti quemado AMOLED**: la esfera se desplaza cada minuto por un ciclo de 9 posiciones
  (±2 px, media cero) con `PixelShift` y `RoundLayout.shiftTo`.
- Revisión de textos en 390×390 (es/en): "Glance at watch", "Long inactivity" y "max
  vibration" acortados en inglés. Pruebas de contraste ≥ 4,5:1 (mínimo 6,51:1).
- Sin código muerto; trazas solo en depuración; auxiliares de pruebas y pesos v1 fuera de
  release (`.prg` de release 88,6 → 86,9 kB).
- Material de tienda (`docs/STORE.md`, 20 capturas), guía de sustentación, README final y
  este changelog. Memoria pico 98,8 de 763,6 kB (fr165 y fr165m). 205 pruebas.

## 0.11.0 — Fase 11: ajustes y confirmación por IA (2026-11-14)

- Ajustes en el reloj y en Garmin Connect: sensibilidad (Baja/Media/Alta), vibración por
  pulsos (Apagada/Suave/Normal/Fuerte), sonido, animaciones reducidas, confirmación por IA y
  grabar actividad, aplicados sin reiniciar la guardia (`onSettingsChanged`).
- Aviso "Alerta solo visual" si no habría vibración ni sonido.
- **Confirmación del cabeceo por el modelo**: espera 2 lotes y exige p(Normal) < 0,35;
  falsos al mirar la hora 15 → 3 de 24 sin perder cabeceos (`ml/confirmation.py`).
- Transición suave entre escenarios de la demo. 194 pruebas.

## 0.10.0 — Fase 10: IA entrenada (2026-11-14)

- Pipeline en Python (`ml/`, `scripts\train.ps1`): dataset sintético de 48 usuarios con
  negativos difíciles, características idénticas al reloj, división por usuario y
  validación cruzada agrupada, regresión logística, informe v1/v2 y exportación a Monkey C.
- Pesos v2: exactitud 89,7 % → 93,3 %, falsos cabeceos 16 → 12 de 48.
- Pantalla *Modelo IA* y escenario *Mirar la hora*. 172 pruebas.

## 0.9.0 — Fase 9: escalamiento, fatiga e historial (2026-11-14)

- La alerta sin respuesta sube del nivel 1 al 3 (cada 10 s; 6 s en demo).
- Predictor de fatiga por reglas, aviso "Micro-sueños repetidos" y descanso guiado.
- Resumen de la guardia al pausar e historial de las 10 últimas en Storage, con borrado
  confirmado. Guion automático con escalamiento. 167 pruebas.

## 0.8.0 — Fase 8: modo demo (2026-11-13)

- Menú principal (mantener UP, también en release): modo demo, escenario, guion
  automático, probar alerta y acerca de. DOWN cambia de escenario con un aviso breve.
- Configuración de la demo persistente y `AppInfo.VERSION`. 142 pruebas.

## 0.7.0 — Fase 7: alerta háptica (2026-11-13)

- Alerta a pantalla completa "¡DESPIERTA!" con vibración por pulsos (el FR165 no cambia la
  fuerza), luz y tono; entrada, pulso < 1 Hz y sacudida sincronizada con el motor.
- "Estoy despierto" mide el tiempo de respuesta; BACK no la cierra. 124 pruebas.

## 0.6.0 — Fase 6: detector y clasificador v1 (2026-11-13)

- Inclinación por gravedad, detector de cabeceos (sacudida + quietud + inclinación) e
  inactividad, línea base adaptativa, refractario de 10 s.
- Clasificador softmax de 4 clases con pesos a mano (v1). 100 pruebas.

## 0.5.0 — Fase 5: orbe IA (2026-11-13)

- Orbe animado de 3 anillos y 16 partículas detrás de la hora, arco de escaneo y latido a
  ≈ 12 cuadros/s. 74 pruebas.

## 0.4.0 — Fase 4: esfera principal (2026-11-13)

- Anillo de nivel de alerta, batería, hora, fecha, porcentaje, píldora de estado y botón
  de guardia con hit-testing. 57 pruebas.

## 0.3.0 — Fase 3: telemetría (2026-11-13)

- Acelerómetro real a 25 Hz y fuente simulada con escenarios, búfer circular, ventana
  deslizante (varianza, sacudida, quietud), motor de telemetría y grabación de la guardia
  como actividad. 42 pruebas.

## 0.2.0 — Fase 2: sistema de diseño (2026-11-12)

- Paleta de tokens, tipografía, layout redondo en proporciones, utilidades de dibujo,
  textos es/en, ícono y guía de estilo oculta. 20 pruebas.

## 0.1.0 — Fase 1: base del proyecto (2026-11-12)

- Manifest (`watch-app`, fr165/fr165m), jungle, estructura, vista inicial, delegado,
  scripts de setup, build, run, test y export, y documentación inicial.
