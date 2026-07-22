
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
log using "Log09_F05_recaudación_codebook0.txt", text replace

/*******************************************************************************
FUENTE    : F05 — Estadísiticas de recaudación y tipos de pago
OBJETIVO  : Construir el bloque de variables analíticas de F05 a nivel de
            contribuyente para el dataset de clustering y caracterización.
ENTRADA   : F05_RECA*.txt
SALIDA    : AF05_perfil_contribuyente.dta
*******************************************************************************/

* 0. ENTORNO
*===============================================================================
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* 1: LECTURA Y TRANSFORMACION DE BASE FUENTE Y ANEXOS
*===============================================================================

* 1.1. Catálogo de periodos 
*----------------------------------------------------------------------------
* Base estilo diccionario de interpretación de la base de recaudación
import excel using "Catálogos.xlsx", firstrow clear sheet("PERIODO_PK")
gen m = string(month(DPR_FECHA_FINAL), "%02.0f")
replace DPR_MES_PK = m if missing(DPR_MES_PK)
keep DPR_PERIODO_PK DPR_ANIO_PK DPR_MES_PK
rename (DPR_PERIODO_PK DPR_ANIO_PK DPR_MES_PK) (periodo_pk anio_fiscal mes_fiscal)
tostring anio_fiscal, replace
save dic_pk, replace

* 1.2. Globales de códigos IVA
*----------------------------------------------------------------------------
* Base de recaudación contempla todos los impuestos
* EL IVA (local e importaciones) de acuerdo al codigo de impuesto pk 
* son los siguientes:
global IVA1 `"388","27","23","26","28","29","31","32""'
global IVA2 `"33","763","25","24","30""'

* 1.3. Programa de lectura unificada
*----------------------------------------------------------------------------
*    El TIPO de recaudación se determina ÚNICAMENTE por el nombre del archivo:
*       f05_reca_nc_*  -> NC  (NC son notas de crédito)
*       otros f05_reca*-> EF_COM (efectivo o compensación,
*                                 desagregado por mar_fuente)
capture program drop _leer_f05
program define _leer_f05
    args archivo tipo

    import delimited "`archivo'", varnames(1) clear stringcols(_all)

    capture rename ańo anio_recauda
	capture rename año anio_recauda
		cap ren mes mes_recauda
    rename numero_identificacion ID0
    if "`tipo'" == "EFCOM" {
        capture rename efectivo recaudado
    }

    destring recaudado, replace dpcomma
    destring periodo_pk, replace

    * Filtro al universo IVA antes de los merges
    keep if inlist(impuesto_pk,"388","27","23","26","28","29","31","32","33") ///
          | inlist(impuesto_pk,"763","25","24","30")

    merge m:1 periodo_pk using dic_pk, keep(1 3) nogen

    if "`tipo'" == "EFCOM" {
        gen formapago = "EF_COM"
        gen double recaudado_EFECTIVO = cond(!inlist(mar_fuente,"N","E"), recaudado, 0)
        gen double recaudado_COMPENSA = cond( inlist(mar_fuente,"N","E"), recaudado, 0)
        gen double recaudado_NC       = 0
    }
    else {
        gen formapago = "NC"
        gen double recaudado_EFECTIVO = 0
        gen double recaudado_COMPENSA = 0
        gen double recaudado_NC       = recaudado
    }

    rename recaudado recaudado_total
    keep  impuesto_pk ID0 anio_recauda mes_recauda  anio_fiscal mes_fiscal ///
          recaudado_total recaudado_EFECTIVO recaudado_COMPENSA recaudado_NC formapago
    order impuesto_pk ID0  anio_recauda mes_recauda  anio_fiscal mes_fiscal ///
          recaudado_total recaudado_EFECTIVO recaudado_COMPENSA recaudado_NC formapago
end

* 1.4. Procesar archivos
*----------------------------------------------------------------------------
tempfile acumulado
local primero = 1

* --- 4a. Notas de crédito ---
local txt_nc : dir . files "f05_reca_nc_*.txt"
foreach x of local txt_nc {
    display as txt "Procesando NC : `x'"
    _leer_f05 "`x'" "NC"
    if `primero' {
        save `"`acumulado'"', replace
        local primero = 0
    }
    else {
        append using `"`acumulado'"'
        save `"`acumulado'"', replace
    }
}

* --- 4b. Efectivo / compensaciones (excluir los _nc_) ---
local txt_ef : dir . files "f05_reca*.txt"
foreach x of local txt_ef {
    if strpos("`x'", "f05_reca_nc_") continue
    display as txt "Procesando EF/COM: `x'"
    _leer_f05 "`x'" "EFCOM"
    if `primero' {
        save `"`acumulado'"', replace
        local primero = 0
    }
    else {
        append using `"`acumulado'"'
        save `"`acumulado'"', replace
    }
}

use `"`acumulado'"', clear

* 1.5. Agregación por contribuyente / impuesto / periodo
*----------------------------------------------------------------------------
collapse (sum) recaudado_total recaudado_EFECTIVO recaudado_COMPENSA recaudado_NC, ///
    by(ID0 impuesto_pk  anio_reca mes_reca anio_fiscal mes_fiscal) fast

* Control por código de impuesto
tabstat recaudado_total, by(impuesto_pk) s(sum N) f(%16.0fc)

* 1.6. Categorización IVA importaciones vs IVA local
*----------------------------------------------------------------------------
*    Importaciones : impuesto_pk in ("32","33")
*    Local         : resto del universo IVA
*    Las variables recaudadoM_* y recaudadoL_* son mutuamente excluyentes; 
*    su suma reproduce recaudado_*.

foreach v in total EFECTIVO COMPENSA NC {
    gen double recaudadoM_`v' = cond(inlist(impuesto_pk,"32","33"), recaudado_`v', 0)
    gen double recaudadoL_`v' = cond(inlist(impuesto_pk,"32","33"), 0, recaudado_`v')
}

* 1.7 Creación ide ID mensual o semestral en término de meses 
gen     mes_desde = "01" if mes_fiscal == "06" & inlist(impuesto_pk,"26","27")
replace mes_desde = "07" if mes_fiscal == "12" & inlist(impuesto_pk,"26","27")
replace mes_desde =  mes_fiscal if mes_desde == ""

gen mes_hasta = mes_fiscal 

* 1.8 Agregación final a nivel contribuyente-periodo (sin impuesto_pk)
collapse (sum) recaudado* , ///
    by(ID0  anio_recaud mes_recaud anio_fiscal mes_fiscal mes_desde mes_hasta) fast

* 1.9 Verificación de consistencia: M + L == total
gen double _chk = recaudadoM_total + recaudadoL_total - recaudado_total
assert abs(_chk) < 1e-6
drop _chk

* Eliminar registros sin recaudación efectiva solo por conveniencias
* si el contribuyente paga con cualqueir forma de pago debería aparecer en la
* base de recaudacion (esta fuente) caso contrario si sus declaraciones arrojan
* impueesto a pagar cero no deberían aparecer en esta fuente
drop if recaudado_total == 0

save t0F05, replace
cap erase "dic_pk.dta"
* 1.10. Filtro al universo de análisis
*-------------------------------------------------------------------------------------------------------------------------------------------------AQUI REVISAR
* Del catastro inicial
display as txt "Registros antes del filtro: " c(N)
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen
display as txt "Registros después del filtro: " c(N)

* Del catálogo de obligaciones reales F06 que se generó en el do inicial 00
* En este caso, se elimina los pagos donde hayan habido pagos sin que existan label
* obligación real
* Se imputa con cero los periodos que teniendo la obligación no pago, sea porque 
* no tuvo que pagar o no lo hizo 
merge m:1 ID0 mes_desde mes_hasta anio_fiscal using F00_CUMPLIMIENTO_ID ///
		   , keep(3 2) nogen
display as txt "Registros después del filtro: " c(N)

order ID, after(ID0)
compress
save t1F05, replace
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log09_F05_recaudación_codebook1.txt", text replace

* 2: ESTADISTICAS PARA DECISIÓN DE CONTRUCCION DE VARIABLES ANALITICAS
*===============================================================================

*2.1. Análisis estadístico previo para toma de decisiones de agregación
*----------------------------------------------------------------------------

use t1F05, clear
drop ID0
inspect
describe
codebook 
codebook, compact
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log10_F05_variables_analiticas.txt", text replace

/*******************************************************************************
* OBJETIVO  : Construir el perfil de comportamiento de pago de IVA por
*             contribuyente, sobre t1F05 (universo filtrado, obligación F06
*             validada, período 2020-2025).
* SALIDA    : AF05_perfil_contribuyente.dta  (una fila por ID)
*
* PRINCIPIO METODOLÓGICO 
*   Por simetría conceptual con el tratamiento de F01, todas las variables
*   del perfil F05 se construyen exclusivamente sobre registros que cumplen
*   tres condiciones simultáneas:
*     (i)   pertenecen al universo AF00_F01F03_seleccion1 (797.161 contribu-
*           yentes con obligación activa de declarar IVA);
*     (ii)  el período fiscal coincide con un período en que F06 registra
*           obligación efectiva del contribuyente;
*     (iii) corresponden al período de análisis 2020-2025.
*   Los pagos por obligaciones fuera de esta ventana (períodos anteriores a
*   2020, períodos sin obligación según F06) fueron descartados en el doble
*   merge del bloque 1.10 y no se reincorporan: hacerlo introduciría una
*   dimensión sin contraparte en F01 ni en F06, distorsionando el espacio
*   de comparación entre contribuyentes.
******************************************************************************/

* 3: CONSTRUCCIÓN DE VARIABLES ANALÍTICAS A NIVEL CONTRIBUYENTE
*==============================================================================

use t1F05, clear

* 3.1 Preparación de variables temporales y de rezago
*----------------------------------------------------------------------------
destring     anio_recauda mes_recauda anio_fiscal mes_fiscal, ///
         gen (anio_r      mes_r       anio_f      mes_f)

* Rezago en meses entre el período fiscal y el período de recaudación
gen long rezago_meses = (anio_r*12 + mes_r) - (anio_f*12 + mes_f)
label var rezago_meses "MESES ENTRE EL PERÍODO FISCAL Y EL DE RECAUDACIÓN"

* DECISIÓN METODOLÓGICA — UMBRAL APROXIMADO DE PAGO TARDÍO
* Se clasifica como tardío todo registro con rezago_meses > 1. El mes natural
* de declaración del IVA es el siguiente al período fiscal, por lo que rezagos
* de 0 ó 1 mes se consideran oportunos. Esta es la versión aproximada del
* indicador. .
gen byte _es_tardio = (rezago_meses > 1) if !missing(rezago_meses)

* 3.2 Sub-bloque A+B — magnitud y estructura por contribuyente
*----------------------------------------------------------------------------
* DIMENSIONES CONSTRUIDAS EN ESTE SUB-BLOQUE
*   A. MAGNITUD          - volumen total recaudado de IVA local
*   B. ESTRUCTURA DE PAGO - efectivo, NC, compensaciones (valores absolutos)
*   X. IMPORTACIONES      - IVA importaciones para caracterización ex post
*   D. OPORTUNIDAD (parcial) - máximo rezago observado por contribuyente
* Las variables n_pagos_tardios_f05 y monto_pagos_tardios_f05 se construyen
* en el sub-bloque 3.3 con granularidad de período fiscal (no de registro)
* para mantener la consistencia aritmética con n_periodos_pagados_f05.

preserve
    collapse (sum) reca_total_f05         = recaudadoL_total      ///
                   reca_efectivo_f05      = recaudadoL_EFECTIVO   ///
                   reca_compensa_f05      = recaudadoL_COMPENSA   ///
                   reca_nc_f05            = recaudadoL_NC         ///
                   reca_importaciones_f05 = recaudadoM_total      ///
             (max) rezago_max_f05         = rezago_meses          ///
             , by(ID) fast
    tempfile bloque_AB
    save `bloque_AB'
restore


* 3.3 Sub-bloque de tardanza con granularidad de período fiscal
*----------------------------------------------------------------------------
* DECISIÓN METODOLÓGICA — GRANULARIDAD DEL PAGO TARDÍO
* Un período fiscal se considera tardío si al menos un pago imputable a ese
* período se efectuó con rezago > 1 mes. La unidad de cuenta es el período
* fiscal, no el registro de recaudación, para mantener la consistencia con
* n_periodos_pagados_f05 (que también cuenta períodos únicos).
* El monto asociado a un período tardío es la suma total recaudada de ese
* período (interpretación: "monto recaudado en períodos clasificados como
* tardíos"). Esto preserva que prop_pagos_tardios_f05 ∈ [0, 1].

preserve
    keep if recaudadoL_total > 0 & !missing(rezago_meses)

    * Identificación del período fiscal como tardío si al menos un pago lo fue
    bysort ID anio_fiscal mes_fiscal: egen byte _periodo_tardio = max(_es_tardio)

    * Suma de la recaudación del período fiscal completo
    bysort ID anio_fiscal mes_fiscal: egen double _monto_periodo = total(recaudadoL_total)

    * Una fila por período fiscal único
    bysort ID anio_fiscal mes_fiscal: keep if _n == 1

    * Monto solo si el período es tardío
    gen double _monto_periodo_tardio = _monto_periodo * _periodo_tardio

    collapse (sum) n_pagos_tardios_f05     = _periodo_tardio        ///
                   monto_pagos_tardios_f05 = _monto_periodo_tardio  ///
             , by(ID) fast
    tempfile bloque_tardio
    save `bloque_tardio'
restore


* 3.4 Sub-bloque C — cobertura temporal
*----------------------------------------------------------------------------
* C. COBERTURA TEMPORAL   - n° de períodos fiscales y años con pago efectivo

preserve
    keep if recaudadoL_total > 0
    bysort ID anio_fiscal mes_fiscal: keep if _n == 1
    gen anio_num = real(anio_fiscal)
    collapse (count) n_periodos_pagados_f05 = anio_num, by(ID) fast
    tempfile bloque_C1
    save `bloque_C1'
restore

preserve
    keep if recaudadoL_total > 0
    bysort ID anio_fiscal: keep if _n == 1
    gen anio_num = real(anio_fiscal)
    collapse (count) n_anios_pagados_f05 = anio_num, by(ID) fast
    tempfile bloque_C2
    save `bloque_C2'
restore


* 3.5 Sub-bloque D — rezago medio ponderado por monto
*----------------------------------------------------------------------------
preserve
    keep if recaudadoL_total > 0 & !missing(rezago_meses)
    gen double _num = rezago_meses * recaudadoL_total
    collapse (sum) _num (sum) _den = recaudadoL_total, by(ID) fast
    gen double rezago_medio_f05 = _num / _den
    keep ID rezago_medio_f05
    tempfile bloque_D
    save `bloque_D'
restore


* 3.6 Sub-bloque E — variabilidad mensual y concentración HHI
*----------------------------------------------------------------------------
* E. VARIABILIDAD         - CV de la recaudación mensual y concentración HHI
* CV: dispersión de la recaudación entre los meses con pago efectivo.
* HHI: concentración de la recaudación del contribuyente entre los meses
*      calendario con pago. Valores cercanos a 1/n indican distribución
*      uniforme; valores cercanos a 1 indican concentración en pocos meses.

preserve
    collapse (sum) reca_mes = recaudadoL_total, ///
             by(ID anio_recauda mes_recauda) fast
    keep if reca_mes > 0

    bysort ID: egen double _media = mean(reca_mes)
    bysort ID: egen double _sd    = sd(reca_mes)
    gen double cv_aux = _sd / _media

    bysort ID: egen double _total_id = total(reca_mes)
    gen double _share2 = (reca_mes / _total_id)^2

    collapse (mean) cv_reca_mensual_f05 = cv_aux       ///
             (sum)  hhi_reca_f05         = _share2     ///
             , by(ID) fast
    tempfile bloque_E
    save `bloque_E'
restore


* 3.7 Integración de sub-bloques al perfil del contribuyente
*----------------------------------------------------------------------------

use `bloque_AB', clear
merge 1:1 ID using `bloque_tardio', keep(1 3) nogen
merge 1:1 ID using `bloque_C1'    , keep(1 3) nogen
merge 1:1 ID using `bloque_C2'    , keep(1 3) nogen
merge 1:1 ID using `bloque_D'     , keep(1 3) nogen
merge 1:1 ID using `bloque_E'     , keep(1 3) nogen

* Imputación de ceros para contribuyentes sin períodos válidos de IVA local
* (contribuyentes presentes solo en IVA importaciones)
foreach v in n_periodos_pagados_f05 n_anios_pagados_f05         ///
             n_pagos_tardios_f05 monto_pagos_tardios_f05 {
    replace `v' = 0 if missing(`v')
}


* 3.8 Construcción de ratios y flags de estructura de pago
*----------------------------------------------------------------------------
* DECISIÓN METODOLÓGICA — RATIOS Y FLAGS DE ESTRUCTURA DE PAGO
* Las proporciones se calculan solo cuando reca_total_f05 > 0; en caso
* contrario quedan como missing (no definidas). Los flags binarios capturan
* el uso al menos una vez de NC o compensaciones, dado que su mediana y p75
* son cero (uso muy minoritario en la población).

foreach v in efectivo compensa nc {
    gen double prop_`v'_f05 = reca_`v'_f05 / reca_total_f05 ///
        if reca_total_f05 > 0
}

gen byte flag_usa_compensa_f05 = (reca_compensa_f05 > 0)
gen byte flag_usa_nc_f05       = (reca_nc_f05       > 0)

gen double prop_pagos_tardios_f05 = n_pagos_tardios_f05 / n_periodos_pagados_f05 ///
    if n_periodos_pagados_f05 > 0

* DECISIÓN METODOLÓGICA — NO SE APLICAN TRANSFORMACIONES DE ESCALA EN ESTA ETAPA
* Todas las magnitudes se mantienen en su unidad original (USD). Las
* decisiones de transformación de escala (logarítmica, z-score, Min-Max,
* winsorización) se posponen al Análisis Exploratorio del dataset analítico
* integrado, en Python, donde se resolverán de forma unificada para todas
* las fuentes según el algoritmo de clustering que se aplique. La variable
* reca_total_f05 conserva la recaudación total en dólares como magnitud
* cruda del perfil.


* 3.9 Integración al universo completo (797.161 contribuyentes)
*----------------------------------------------------------------------------
* DECISIÓN METODOLÓGICA — TRATAMIENTO DE CONTRIBUYENTES SIN RECAUDACIÓN
* El universo de análisis (AF00_F01F03_seleccion1) tiene 797.161 contribuyentes.
* En t1F05 (post filtros) hay 505.178 con recaudación efectiva por períodos
* con obligación validada por F06 (63,4% del universo). Los 291.983 restantes
* (36,6%) no son missing en sentido estadístico: son la observación informativa
* de "tuvo obligación pero no registra pago dentro de la ventana validada".
* Se hace outer merge contra el universo y se activa flag_sin_recaudacion_f05.
* Las magnitudes se imputan a cero; los ratios y los indicadores de
* variabilidad se conservan como missing porque no están definidos.

merge 1:1 ID using AF00_F01F03_seleccion1, keep(2 3) keepusing(ID)
gen byte flag_sin_recaudacion_f05 = (_merge == 2)
label var flag_sin_recaudacion_f05 ///
    "=1 SI EL CONTRIBUYENTE NO REGISTRA RECAUDACIÓN EN PERÍODOS CON OBLIGACIÓN F06"
drop _merge

* Imputación de ceros para variables de magnitud
foreach v in reca_total_f05 reca_efectivo_f05 reca_compensa_f05 reca_nc_f05  ///
             reca_importaciones_f05                                          ///
             n_periodos_pagados_f05 n_anios_pagados_f05                      ///
             n_pagos_tardios_f05 monto_pagos_tardios_f05 {
    replace `v' = 0 if missing(`v') & flag_sin_recaudacion_f05 == 1
}
foreach v in flag_usa_compensa_f05 flag_usa_nc_f05 {
    replace `v' = 0 if missing(`v') & flag_sin_recaudacion_f05 == 1
}


* 3.10 Etiquetado de variables
*----------------------------------------------------------------------------

label var reca_total_f05            "IVA LOCAL RECAUDADO ACUMULADO 2020-25 (USD)"
label var reca_efectivo_f05         "IVA LOCAL RECAUDADO EN EFECTIVO (USD)"
label var reca_compensa_f05         "IVA LOCAL RECAUDADO CON COMPENSACIONES (USD)"
label var reca_nc_f05               "IVA LOCAL RECAUDADO CON NOTAS DE CRÉDITO (USD)"
label var reca_importaciones_f05    "IVA IMPORTACIONES RECAUDADO (USD) — CARACTERIZACIÓN EX POST"
label var prop_efectivo_f05         "PROPORCIÓN DEL IVA RECAUDADO PAGADA EN EFECTIVO"
label var prop_compensa_f05         "PROPORCIÓN DEL IVA RECAUDADO VÍA COMPENSACIONES"
label var prop_nc_f05               "PROPORCIÓN DEL IVA RECAUDADO VÍA NOTAS DE CRÉDITO"
label var flag_usa_compensa_f05     "=1 SI USÓ COMPENSACIONES AL MENOS UNA VEZ"
label var flag_usa_nc_f05           "=1 SI USÓ NOTAS DE CRÉDITO AL MENOS UNA VEZ"
label var n_periodos_pagados_f05    "N° DE PERÍODOS FISCALES 2020-25 CON PAGO > 0"
label var n_anios_pagados_f05       "N° DE AÑOS FISCALES DISTINTOS CON PAGO > 0"
label var rezago_medio_f05          "MESES DE REZAGO PROMEDIO PONDERADO POR MONTO"
label var rezago_max_f05            "MÁXIMO REZAGO EN MESES OBSERVADO"
label var n_pagos_tardios_f05       "N° DE PERÍODOS FISCALES CON AL MENOS UN PAGO TARDÍO"
label var prop_pagos_tardios_f05    "PROPORCIÓN DE PERÍODOS FISCALES CLASIFICADOS COMO TARDÍOS"
label var monto_pagos_tardios_f05   "MONTO TOTAL RECAUDADO EN PERÍODOS TARDÍOS (USD)"
label var cv_reca_mensual_f05       "COEF. DE VARIACIÓN DE LA RECAUDACIÓN MENSUAL"
label var hhi_reca_f05              "ÍNDICE HHI DE CONCENTRACIÓN MENSUAL DE PAGOS"


* 3.11 Verificaciones y guardado
*----------------------------------------------------------------------------

isid ID
compress

save AF05_perfil_contribuyente, replace

display as txt _newline ///
    "Perfil F05 generado: " c(N) " contribuyentes, " c(k) " variables."

* Reporte agregado de cobertura para extracción al TFM
tab flag_sin_recaudacion_f05, missing

estpost summarize reca_total_f05                                       ///
                  prop_efectivo_f05 prop_pagos_tardios_f05             ///
                  rezago_medio_f05 cv_reca_mensual_f05 hhi_reca_f05    ///
                  , detail

log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@