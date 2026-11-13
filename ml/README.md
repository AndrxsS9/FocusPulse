# /ml — Entrenamiento del modelo de detección

Esta carpeta está reservada para el trabajo de *machine learning* de FocusPulse AI.
**No forma parte del paquete que se instala en el reloj**: el compilador de Connect IQ
solo usa `source/`, `tests/` y `resources*/` (ver `monkey.jungle`).

## Qué irá aquí

1. **Captura de datos**: sesiones de acelerómetro grabadas desde el reloj (modo de
   registro de la app) y etiquetadas como *despierto*, *cabeceo* o *micro-sueño*.
2. **Extracción de características**: las mismas que calcula `source/core` en el reloj
   (ángulo de inclinación de la cabeza/muñeca, varianza, *jerk*, cambios bruscos), para
   que el modelo entrenado y el detector embebido hablen el mismo idioma.
3. **Entrenamiento y evaluación**: modelos ligeros (umbrales calibrados, regresión
   logística, árboles pequeños) que quepan en la memoria y el presupuesto de CPU de un
   Forerunner 165.
4. **Exportación**: un script que convierta los parámetros entrenados en constantes de
   Monkey C, ya que Connect IQ no ejecuta modelos de ML de forma nativa. El destino ya
   existe: `source/core/ClassifierWeights.mc` (fase 6) espera `StandardScaler.mean_` y
   `.scale_`, y `coef_` e `intercept_` de una `LogisticRegression` multinomial con las 5
   características y las 4 clases de `StateClassifier` (ver
   [docs/DETECTOR.md](../docs/DETECTOR.md) §5).

## Entorno

Se usará Python con un entorno virtual local (`.venv/`, ignorado por git):

```powershell
cd ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Las dependencias (`requirements.txt`) y los notebooks se agregarán en la fase de ML.
Los datos crudos grandes no deben versionarse.
