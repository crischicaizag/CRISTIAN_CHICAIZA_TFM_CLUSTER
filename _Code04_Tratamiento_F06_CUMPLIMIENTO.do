/*==============================================================================
  PROYECTO   : TFM — Propuesta metodológica para la identificación y           *
               caracterización de patrones de resistencia fiscal en el IVA     *
               (caso ecuatoriano, período 2020–2025)                           *
  MÁSTER     : Análisis y Visualización de Datos Masivos (Visual Analytics     *
               and Big Data) — Universidad Internacionasal de La Rioja (UNIR)  *
  AUTOR      : Cristian Edelberto Chicaiza Gualoto                             *
                                                                               *
  DIRECTOR   : Jesús Cigales Canga                                             *
                                                                               *
  ENTORNO    : Procesamiento ejecutado en instalaciones del SRI, sobre         *
               microdatos administrativos anonimizados. Solo se extraen        *
               resultados agregados, conforme al Oficio de Respuesta           *
               No. 917012026OCEF0001725 emitido por la Dirección Nacional      *
               de Planificación y Gestión Estratégica del SRI.                 *
==============================================================================*/

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log07_F06_cumplimiento_codebook0.txt", text replace

/*******************************************************************************
FUENTE    : F06 — Cumplimiento de Obligaciones (Obligación de IVA)
OBJETIVO  : Construir el bloque de variables analíticas de F06 a nivel de
            contribuyente para el dataset de clustering y caracterización.
ENTRADA   : F06_cumplimiento*.txt
SALIDA    : AF06_perfil_contribuyente.dta 
          LOGS: Log07_F06_cumplimiento_codebook0
*******************************************************************************/

* 0. CONFIGURACION DE ENTORNO
*===============================================================================
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* 1. LECTURA F06 Y UNIFICACIÓN INICIAL
*===============================================================================

* 1.1 Lectura txt, transformación y unificación
*------------------------------------------------------------------------------

clear
local txt : dir . files "f06_*.txt"
foreach x of local txt {
dis "`x'"
import delimited "`x'", varnames(1) stringcols(_all) clear
cap ren numero_ruc ID0
destring tiempo_demora, replace dpcomma
save "t0`x'.dta", replace
}

clear
local dta1 : dir . files "t0f06_cum*.dta"
appen using `dta1'

*Variables inciales
describe

dis "Número de registros inicial"
dis "======================================================================="
count

* 1.2 Filtro al catastro de análisis primario
*------------------------------------------------------------------------------
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen  

dis "Número de registros luego de cruce con catastro primario"
dis "======================================================================="
count
* 1.3  Conversión de variables fecha
*------------------------------------------------------------------------------
gen aux = daily(fecha_cumplimiento, "YMD")
drop fecha_cumplimiento
rename aux fecha_cumplimiento
format fecha_cumplimiento %td

gen aux = daily(fechavencimiento, "YMD")
drop fechavencimiento
rename aux fechavencimiento
format fechavencimiento %td

* 1.3  Guardado inicial
*------------------------------------------------------------------------------
save t1f06_cumplimiento.dta, replace

local dta1 : dir . files "t0f06_cum*.dta"
foreach x of local dta1 { 
	cap erase "`x'"
}


* 2. AUDITORIA DE INCOSISTENCIAS
*===============================================================================
* Se identificaron obligaciones con cumplimiento duplicados
* La razón principal se debe a que existen obligaciones que contribuyentes no 
* estaban obligados a realizar y lo hicieron o el SRI los justificó creando
* registros duplicados
* Con este procedimiento se identifica mecanismo de identificación y eliminación

* 2.1 Identifican duplicados con auditoria manual para su depuración posterior
*-----------------------------------------------------------------------
/*
control de duplicados
use t1f06_cumplimiento, clear
codebook, compact
sort ID0 anio_fiscal mes_desde mes_hasta ///
	  codigo_obligacion_tributaria cumplimiento

*Control de consistencia
duplicates tag ID0 anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria ///
		    , gen(x)
tab x
br if x > 0
*Hay duplicados en la base, se retiran duplicados, debido a que los registros 
*muestran más de una obligación 
drop x
duplicates drop ID0 anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria ///
		   cumplimiento, force
duplicates tag ID0 anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria ///
			, gen(x)
tab x
br if x >0

* Persisten 73 registros con inconsistencia que se solicita revisar, no puede un
* contribuyente estar omiso y no omiso a la vez y justificado, debido a la 
* materiliadad de los registros se exlcuye a estos contribuyentes del análsis
keep if x>0
drop ID0 
save F06_duplicados_M, replace
*/

* 3. DEPURACIÓN DE INCONSISTENCIAS IDENTIFICADAS: DUPLICADOS y OBLIGACION REAL IVA
*===============================================================================
use t1f06_cumplimiento, clear

* 3.1. Identificar grupos duplicados y eliminación por criterio orden
*-------------------------------------------------------------------------------

bysort ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria: ///
    gen  dup = (_N > 1)

* Guardar orden original
gen  orden = _n

* Prioridad solo para resolver duplicados
gen     prioridad = 3
replace prioridad = 2 if cumplimiento == "No Omiso"
replace prioridad = 1 if cumplimiento == "Justificado"

* Ordenar
sort ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria prioridad orden

* En grupos duplicados conservar solo el registro correcto 
by ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria: ///
    drop if dup & _n > 1
	
dis "Número de registros luego de cruce con catastro primario y filtrado duplicados"
dis "======================================================================="
count	
drop dup prioridad orden

* 3.2 Depuración de justificados - base de obligaciones de IVA real
*-------------------------------------------------------------------------------
* Justificado comprende el estado en que el SRI determina que ese 
* periodo/ obligacion no se debía declarar, con esto obtenemos la base 
* obligación real del IVA
drop if cumplimiento == "Justificado"

*Correcciones adicionales, no se verifica inconsitencias adicionales
dis "Número de registros post catastro, post duplicados, post obligación real"
dis "======================================================================="
count	

*Guardado:
save t1f06_cumplimiento, replace
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log07_F06_cumplimiento_codebook1.txt", text replace

* 4 ANALISIS ESTADISTICO PREVIO PARA DETERMINAR VARIABLES PARA BASE ANALITICA
*===========================================================================
use t1f06_cumplimiento, clear

tab cumplimiento tardio
tabstat tiempo_demora, by(tardio ) s(min max mean p50 p90 sd ) f(%12.0fc)
tabstat tiempo_demora, by(cumplimiento ) s(min max mean p50 p90 sd ) f(%12.0fc)

table cumplimiento tardio, ///
    statistic(frequency) ///
    statistic(min tiempo_demora) ///
    statistic(max tiempo_demora) ///
    statistic(mean tiempo_demora) ///
    statistic(p50 tiempo_demora)
drop ID0
describe
codebook
codebook, compact
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

capture log close
log using "Log08_F06_Construccion_base_analitica_cumplimiento.txt", text replace

/*===========================================================================
FUENTE    : F06 — Cumplimiento de Obligaciones (t1f06_cumplimiento.dta)
OBJETIVO  : Construir el bloque de variables analíticas de F06 a nivel de
            contribuyente para el dataset de clustering y caracterización.
ENTRADA   : t1f06_cumplimiento.dta (base depurada — sin justificados, sin
            duplicados, cruzada con el catastro primario).
SALIDA    : AF06_perfil_contribuyente.dta — una fila por ID con las variables
            de comportamiento de cumplimiento.
CRITERIO  : Se construyen variables con aporte
            informativo diferencial para el clustering. Se descartan métricas
            redundantes (tasa de cumplimiento, conteos brutos espejo, etc.).
VARIABLES PARA CLUSTERING (núcleo):
   tasa_omision, tasa_tardio, promedio_dias_demora, p90_dias_demora
VARIABLES PARA CARACTERIZACIÓN POST-CLUSTERING:
   tasa_omision_reciente, tasa_tardio_reciente, n_periodos_demora_grave,
   flag_tiene_semestral, prop_periodos_mensuales, n_periodos_obligacion
===========================================================================*/

* 5 CONSTRUCCION DE BASE ANALITICA
*==============================================================================

* 5.0. Entorno
*-----------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

use t1f06_cumplimiento, clear
dis "Registros de partida (base depurada t1f06_cumplimiento)"
dis "======================================================================="

* 5.1. Conversión de tipos y construcción de banderas auxiliares
*-----------------------------------------------------------------------------
* anio_fiscal viene como string (str4) en la base; se convierte a numérico
* para construir una ventana reciente 2023–2025.
destring anio_fiscal, gen(anio_num)

* Banderas binarias por registro. Se usan para colapsar luego con (sum).
* La lógica es: cada flag captura una condición que será sumada por ID.

* Bandera unitaria para contar el total de períodos con obligación real.
* Cada registro de t1f06_cumplimiento equivale a un período con obligación
* declarable (los justificados ya fueron eliminados en la depuración previa).
gen byte f_periodo            = 1

gen byte f_omiso              = (cumplimiento == "Si Omiso")
gen byte f_no_omiso           = (cumplimiento == "No Omiso")
gen byte f_tardio_no_omiso    = (tardio == "SI" & cumplimiento == "No Omiso")
gen byte f_demora_grave       = (tiempo_demora > 90 & ///
                                 cumplimiento == "No Omiso")
gen byte f_mensual            = (codigo_obligacion_tributaria == "2")
gen byte f_semestral          = (codigo_obligacion_tributaria == "3")

* Ventana reciente: 2023–2025. Recoge si el comportamiento mejoró o empeoró
* hacia el final del período, lo relevante para la facultad determinadora.
gen byte f_reciente           = (anio_num >= 2023)
gen byte f_omiso_rec          = (f_omiso == 1           & f_reciente == 1)
gen byte f_no_omiso_rec       = (f_no_omiso == 1        & f_reciente == 1)
gen byte f_tardio_no_omiso_rec= (f_tardio_no_omiso == 1 & f_reciente == 1)

* tiempo_demora restringido a tardíos no omisos. Los demás registros quedan
* como missing y son ignorados por las funciones (mean) y (p90) del collapse.
* Decisión metodológica: los ceros se excluyen por construcción —
* f_tardio_no_omiso==1 implica tardio=="SI", que por definición tiene
* tiempo_demora > 0 (el log de exploración muestra mínimo .00001). Así, la
* media y el p90 reflejan únicamente la magnitud de la demora efectiva,
* sin diluirla con los registros puntuales.
gen double td_tno = tiempo_demora if f_tardio_no_omiso == 1

* Nota sobre semestrales: las tasas se calculan sobre el total de períodos
* sin distinción de tipo. Un período semestral cuenta igual que uno mensual
* en términos de cumplimiento formal — la obligación de declarar es el
* hecho relevante, no su frecuencia. El tipo de obligación se captura en
* variables de caracterización separadas (flag_tiene_semestral y
* prop_periodos_mensuales) para su uso post-clustering.

* 5.2. Colapso a nivel de contribuyente
*-----------------------------------------------------------------------------
* Una sola operación de collapse para minimizar pasadas sobre los 33.5 M de
* registros. (count) sobre cumplimiento da el total de períodos con
* obligación real, (sum) acumula las banderas, (mean) y (p90) operan sobre
* td_tno ignorando missings.

collapse                                                          ///
    (sum)   n_periodos_obligacion       = f_periodo               ///
            n_periodos_omisos           = f_omiso                 ///
            n_periodos_no_omisos        = f_no_omiso              ///
            n_periodos_tardios          = f_tardio_no_omiso       ///
            n_periodos_demora_grave     = f_demora_grave          ///
            n_periodos_mensuales        = f_mensual               ///
            n_periodos_semestrales      = f_semestral             ///
            n_periodos_recientes        = f_reciente              ///
            n_omisos_recientes          = f_omiso_rec             ///
            n_no_omisos_recientes       = f_no_omiso_rec          ///
            n_tardios_recientes         = f_tardio_no_omiso_rec   ///
    (mean)  promedio_dias_demora        = td_tno                  ///
    (p90)   p90_dias_demora             = td_tno                  ///
    , by(ID) fast

dis "Contribuyentes colapsados (una fila por ID)"
dis "======================================================================="
count

* 5.3. Construcción de tasas y variables derivadas
*-----------------------------------------------------------------------------
* Tasa de omisión: períodos omisos sobre el total de obligación real.
gen double tasa_omision = n_periodos_omisos / n_periodos_obligacion

* Tasa de tardanza: períodos tardíos sobre los efectivamente declarados.
* Si el contribuyente no tiene ningún período no omiso (caso extremo de
* omisión total), la tasa queda como missing — no se puede medir tardanza
* sobre lo que no se declaró.
gen double tasa_tardio = n_periodos_tardios / n_periodos_no_omisos
replace tasa_tardio = . if n_periodos_no_omisos == 0

* Ventana reciente 2023–2025: mismo tratamiento.
gen double tasa_omision_reciente = n_omisos_recientes / n_periodos_recientes
replace tasa_omision_reciente = . if n_periodos_recientes == 0

gen double tasa_tardio_reciente  = n_tardios_recientes / n_no_omisos_recientes
replace tasa_tardio_reciente = . if n_no_omisos_recientes == 0

* Promedio y p90 de días de demora: si el contribuyente no tuvo ningún
* período tardío no omiso, ambas quedan missing por construcción del collapse.
* Decisión: se mantiene el missing en lugar de imputar cero. Un cero
* significaría "demora baja" en el espacio del clustering, lo cual es
* incorrecto — el contribuyente simplemente no aporta información a esa
* dimensión. La imputación se resolverá en la etapa de preparación del
* dataset analítico final.

* Variables de caracterización del tipo de obligación.
gen byte flag_tiene_semestral = (n_periodos_semestrales > 0)
gen double prop_periodos_mensuales = n_periodos_mensuales / n_periodos_obligacion

* 5.4. Etiquetado de variables
*-----------------------------------------------------------------------------
label variable n_periodos_obligacion    "F06: total de períodos con obligación real 2020–2025"
label variable n_periodos_omisos        "F06: períodos con cumplimiento = Si Omiso"
label variable n_periodos_no_omisos     "F06: períodos con cumplimiento = No Omiso"
label variable n_periodos_tardios       "F06: períodos tardíos (excluye omisos)"
label variable n_periodos_demora_grave  "F06: períodos con demora > 90 días (excluye omisos)"
label variable n_periodos_mensuales     "F06: períodos de obligación mensual (código 2)"
label variable n_periodos_semestrales   "F06: períodos de obligación semestral (código 3)"
label variable n_periodos_recientes     "F06: períodos en ventana reciente 2023–2025"
label variable n_omisos_recientes       "F06: períodos omisos en ventana reciente"
label variable n_no_omisos_recientes    "F06: períodos no omisos en ventana reciente"
label variable n_tardios_recientes      "F06: períodos tardíos no omisos en ventana reciente"

label variable tasa_omision             "F06: tasa de omisión (períodos omisos / obligación)"
label variable tasa_tardio              "F06: tasa de tardanza (tardíos / no omisos)"
label variable promedio_dias_demora     "F06: media de días de demora en tardíos no omisos"
label variable p90_dias_demora          "F06: p90 de días de demora en tardíos no omisos"
label variable tasa_omision_reciente    "F06: tasa de omisión 2023–2025"
label variable tasa_tardio_reciente     "F06: tasa de tardanza 2023–2025"
label variable flag_tiene_semestral     "F06: 1 si tiene al menos un período semestral"
label variable prop_periodos_mensuales  "F06: proporción de períodos mensuales sobre total"

* 5.5. Auditoría de salida
*-----------------------------------------------------------------------------
dis "Resumen de variables de cumplimiento por contribuyente"
dis "======================================================================="
sum n_periodos_obligacion n_periodos_omisos n_periodos_no_omisos ///
    n_periodos_tardios n_periodos_demora_grave                   ///
    tasa_omision tasa_tardio                                     ///
    promedio_dias_demora p90_dias_demora                         ///
    tasa_omision_reciente tasa_tardio_reciente                   ///
    flag_tiene_semestral prop_periodos_mensuales                 ///
    , detail format

dis "Distribución de missings en variables clave"
dis "======================================================================="
misstable summarize tasa_omision tasa_tardio promedio_dias_demora ///
                    p90_dias_demora tasa_omision_reciente          ///
                    tasa_tardio_reciente

dis "Conteo de contribuyentes con omisión total (sin períodos declarados)"
count if n_periodos_no_omisos == 0

dis "Conteo de contribuyentes sin actividad en la ventana reciente"
count if n_periodos_recientes == 0

* 5.6. Guardado del perfil
*-----------------------------------------------------------------------------
order ID n_periodos_obligacion                                   ///
      n_periodos_omisos n_periodos_no_omisos tasa_omision        ///
      n_periodos_tardios tasa_tardio                             ///
      promedio_dias_demora p90_dias_demora n_periodos_demora_grave ///
      n_periodos_recientes n_omisos_recientes n_no_omisos_recientes ///
      n_tardios_recientes tasa_omision_reciente tasa_tardio_reciente ///
      flag_tiene_semestral prop_periodos_mensuales               ///
      n_periodos_mensuales n_periodos_semestrales

compress
save AF06_perfil_contribuyente.dta, replace
describe

*6. Validación cruzada final contra los totales de la base de origen
*==============================================================================
* Estas identidades deben cumplirse exactamente. Si alguna falla, hay un
* problema en el flujo del collapse o en las banderas binarias. Se imprime
* en el log para dejar constancia auditable.

dis _newline "VALIDACIÓN CRUZADA — totales agregados del perfil F06"
dis "==============================================================="

quietly summarize n_periodos_obligacion
local sum_obligacion = r(sum)
dis "Suma n_periodos_obligacion       = " %15.0fc `sum_obligacion'
dis "Total esperado (registros base)  =      33.528.148"
dis "Diferencia                       = " %15.0fc `sum_obligacion' - 33528148

quietly summarize n_periodos_omisos
local sum_omisos = r(sum)
dis _newline "Suma n_periodos_omisos           = " %15.0fc `sum_omisos'
dis "Total esperado (Si Omiso codebook1) =     376.404"
dis "Diferencia                       = " %15.0fc `sum_omisos' - 376404

quietly summarize n_periodos_tardios
local sum_tardios = r(sum)
dis _newline "Suma n_periodos_tardios          = " %15.0fc `sum_tardios'
dis "Total esperado (No Omiso & SI tardio) =15.720.379"
dis "Diferencia                       = " %15.0fc `sum_tardios' - 15720379

quietly summarize n_periodos_no_omisos
local sum_no_omisos = r(sum)
dis _newline "Suma n_periodos_no_omisos        = " %15.0fc `sum_no_omisos'
dis "Total esperado (No Omiso codebook1) =33.151.744"
dis "Diferencia                       = " %15.0fc `sum_no_omisos' - 33151744

* Identidad mensual + semestral = obligación
quietly summarize n_periodos_mensuales
local sum_mens = r(sum)
quietly summarize n_periodos_semestrales
local sum_sem = r(sum)
dis _newline "Suma mensuales + semestrales     = " %15.0fc `sum_mens' + `sum_sem'
dis "Debe igualar n_periodos_obligacion= " %15.0fc `sum_obligacion'

* Identidad omisos + no omisos = obligación
dis _newline "Suma omisos + no omisos          = " %15.0fc `sum_omisos' + `sum_no_omisos'
dis "Debe igualar n_periodos_obligacion= " %15.0fc `sum_obligacion'

* Cobertura de variables de demora
quietly count if !missing(promedio_dias_demora)
dis _newline "Contribuyentes con dato de demora= " %15.0fc r(N)
quietly count if missing(promedio_dias_demora)
dis "Contribuyentes sin tardanzas     = " %15.0fc r(N) "  (cumplimiento puntual íntegro)"

* Distribución de tasa_omision por tramos (caracterización rápida)
dis _newline "Distribución de la tasa de omisión por tramos"
dis "==============================================================="
gen byte _tramo_omision = .
replace _tramo_omision = 0 if tasa_omision == 0
replace _tramo_omision = 1 if tasa_omision > 0   & tasa_omision <= 0.10
replace _tramo_omision = 2 if tasa_omision > 0.10 & tasa_omision <= 0.30
replace _tramo_omision = 3 if tasa_omision > 0.30 & tasa_omision <= 0.50
replace _tramo_omision = 4 if tasa_omision > 0.50 & !missing(tasa_omision)
label define lbl_tramo 0 "0% (sin omisos)" 1 "(0%, 10%]" ///
                       2 "(10%, 30%]" 3 "(30%, 50%]" 4 ">50%"
label values _tramo_omision lbl_tramo
tab _tramo_omision, missing
drop _tramo_omision

* Distribución de tasa_tardio por tramos
dis _newline "Distribución de la tasa de tardanza por tramos"
dis "==============================================================="
gen byte _tramo_tardio = .
replace _tramo_tardio = 0 if tasa_tardio == 0
replace _tramo_tardio = 1 if tasa_tardio > 0   & tasa_tardio <= 0.25
replace _tramo_tardio = 2 if tasa_tardio > 0.25 & tasa_tardio <= 0.50
replace _tramo_tardio = 3 if tasa_tardio > 0.50 & tasa_tardio <= 0.75
replace _tramo_tardio = 4 if tasa_tardio > 0.75 & !missing(tasa_tardio)
label define lbl_tramot 0 "0% (siempre puntual)" 1 "(0%, 25%]" ///
                        2 "(25%, 50%]" 3 "(50%, 75%]" 4 ">75%"
label values _tramo_tardio lbl_tramot
tab _tramo_tardio, missing
drop _tramo_tardio

* Cruce de validación final con catastro primario
*-----------------------------------------------------------------------------
* Confirma que los 797.161 IDs del perfil coinciden con el catastro.
merge 1:1 ID using AF00_F01F03_seleccion1, generate(_match_catastro)
dis _newline "Cruce de IDs del perfil F06 contra el catastro primario"
dis "==============================================================="
tab _match_catastro
* Esperado: solo categoría 3 (matched). Cualquier 1 o 2 indica desfase.
drop _match_catastro

* Reguardado final con la validación incluida en el log
save AF06_perfil_contribuyente.dta, replace
dis _newline "Procesamiento de F06 cerrado. Archivo final: F06_perfil_contribuyente.dta"
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@



