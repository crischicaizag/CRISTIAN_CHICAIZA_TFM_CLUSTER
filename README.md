# CRISTIAN_CHICAIZA_TFM_CLUSTER
Este repositorio contiene los archivos que se pueden compartir sobre el trabajo de TFM realizado enmaracados a la normativa de protección de datos. TFM: Propuesta metodológica para la identificación y caracterización de patrones de resistencia fiscal en el Impuesto al Valor Agregado en el caso ecuatoriano 

## TFM — Clustering aplicado a la resistencia fiscal en el IVA (Ecuador, 2020-2025)
Código fuente del pipeline de aprendizaje no supervisado que segmenta a 797.161 contribuyentes ecuatorianos con obligación activa de declarar IVA en tres perfiles de cumplimiento tributario.
## Contexto
Procesamiento ejecutado en las instalaciones del Servicio de Rentas Internas del Ecuador (SRI) sobre microdatos administrativos anonimizados, bajo autorización del Oficio N.º 917012026OCEF0001725. Únicamente se publica el código; los datos y logs quedan cubiertos por reserva tributaria.
## Requisitos
•	Stata 18
•	Python 3.11 con pandas, numpy, scikit-learn, matplotlib, seaborn, pyarrow, jupyter
•	Memoria RAM ≥ 32 GB recomendada
## Configuración
Cada do-file abre con:
stata
local ruta "<CONFIGURAR: ruta local al directorio con las bases fuente>"
cd "`ruta'"
Reemplazar el placeholder por la ruta local antes de ejecutar. En los notebooks de Python la ruta base se define en 01_conversion_eda_inicial.ipynb.
## Orden de ejecución
Stata:
1.	_Code00 — Catastro primario (797.161 contribuyentes)
2.	_Code01 — F03 RUC
3.	_Code02 — F01 IVA (formulario 104)
4.	_Code03 — F02 Renta
5.	_Code04 — F06 Cumplimiento
6.	_Code05 — F05 Recaudación
7.	_Code06 — F07 Retenciones
8.	_Code07 — F04 Facturación electrónica
9.	_Code08 — Integración de las siete fuentes
Python:
10.	01_conversion_eda_inicial.ipynb — Conversión y verificación
11.	02_EDA.ipynb — Análisis exploratorio
12.	03_preparacion_clustering.ipynb — Preparación (68 variables)
13.	04_clustering.ipynb — K-means, Ward, DBSCAN y validación
14.	05_caracterizacion.ipynb — Perfiles y score de atipicidad
## Sobre los datos
No se publica ningún archivo .dta, .parquet, .csv ni los logs de Stata, conforme al oficio de autorización. _Code02 referencia F01_catastro_outliers_exclusion_M.dta, generado en auditoría manual previa; el código que lo construye se conserva comentado en la sección 4 de ese do-file.


