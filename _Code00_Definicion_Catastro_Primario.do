
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

cap log close 
log using "Log00_SeleccionInicial.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Procesamiento inicial de la fuente F01 — Formulario 104
               (declaraciones mensuales/semestrales del IVA). y RUC para 
			   determinar catastro inicial de contribuyentes a analizar. Esto es
			   Tengan al menos 12 declaraciones en el periodo 2020-2025
			   No sean del sector público ni ONG por su naturaleza excluyentes
			   del análisis.
  FUENTES    : F01 — F01_F104*.txt   (declaraciones de IVA, 2020–2025)
               F03 — F03_RUC_FULL_20260605.txt  (catastro de RUC)
			   F06 - F06_C*.txt (cumplimiento o gestión de obligaciones)
  SALIDA     : AF00_F01F03_seleccion1.dta
			   F00_RUC_auxiliar, F00_CUMPLIMIENTO_ID 
               Logs: Log00_SeleccionInicial.txt
*******************************************************************************/

* 0. CONFIGURACIÓN DEL ENTORNO
*------------------------------------------------------------------------------
* Se limpia memoria, se desactiva la paginación de resultados y se fijan tipos
* y rutas

clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* 1. Lectura del ruc con variables ID0 y codigo_opera_area 
* Archivos: F03_RUC_FULL_20260605.txt
*-----------------------------------------------------------

import delimited "F03_RUC_FULL_20260605.txt",  varnames(1) stringcol(_all)
ren numero_ruc ID0
keep ID0 codigo_opera_area
dis "numero de registros: " c(N)
tempfile rucparcial
sort ID0
gen ID = _n
save "`rucparcial'", replace
* Base de todos los rucs para otros cruces en F05
keep ID0 ID codigo_opera_area
save F00_RUC_auxiliar, replace

* 2. Lectura F01  para definir número de declaraciones 2020-225 F104
*-----------------------------------------------------------

*--- Listado de archivos que coinciden con el patrón
local archivos : dir "." files "F01_F104_*.txt"

tempfile acumulado
local primero = 1

foreach f of local archivos {
    import delimited using "`f'", ///
        delimiter(tab) ///
        colrange(5:17) ///
        varnames(1) ///
        stringcols(_all) ///
        encoding("UTF-8") ///
        clear
	keep numero_identificacion anio_fiscal mes_fiscal ///
	periodo_fiscal_desde periodo_fiscal_hasta
	gen mes_desde = substr(periodo_fiscal_desde,5,2)
	gen mes_hasta = substr(periodo_fiscal_hasta,5,2)		 
	drop periodo_fiscal_desde periodo_fiscal_hasta
    gen archivo_origen = "`f'"

    if `primero' == 1 {
        save "`acumulado'", replace
        local primero = 0
    }
    else {
        append using "`acumulado'"
        save "`acumulado'", replace
    }
}

* 3. Lectura de base de obligaciones F06 para definir obligaciones reales
*-----------------------------------------------------------
clear
local txt : dir . files "f06_*.txt"
tempfile base
local primero 1
foreach x of local txt {
    di "`x'"
    import delimited using "`x'", ///
        varnames(1) ///
        stringcols(_all) ///
        clear
    cap rename numero_ruc ID0
    keep ID0 cumplimiento anio_fiscal mes_desde mes_hasta ///
         codigo_obligacion_tributaria
    if `primero' {
        save `base', replace
        local primero 0
    }
    else {
        append using `base'
        save "`base'", replace
    }
}
 *Depuración de duplicados identificados
use "`base'", clear
bysort ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria: ///
    gen byte dup = (_N > 1)
gen long orden = _n
gen byte prioridad = 3
replace prioridad = 1 if cumplimiento == "Justificado"
replace prioridad = 2 if cumplimiento == "No Omiso"
sort ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria prioridad orden
by ID anio_fiscal mes_desde mes_hasta codigo_obligacion_tributaria: ///
    drop if dup & _n > 1
* Justificados no entran porque no era su obligacion presentar
drop if cumplimiento == "Justificado"
keep ID0 mes_desde mes_hasta anio_fiscal
tempfile base_f06
save "`base_f06'", replace
* Base para filtro de obligaciones reales
save "F00_CUMPLIMIENTO_ID.dta", replace

*Conteo de obligados IVA en el periodo 2020-2025
bysort ID0: gen d = _N
tab d
bysort ID0 : gen num = 1 if _n == 1
gen numt = 1
dis "=============================================================="
dis "Número de sujetos y obligaciones reales F06: "
dis "=============================================================="
tabstat num numt , by(d) s(sum) f(%12.0fc)


* 4. Lectura de Facturación F04 electrónica para definir los que estan en CEL
*-----------------------------------------------------------
use F04_CEL2024_EMISORBYTIPOCLIENTE, clear
ren ID0_emisor ID0
keep ID0
duplicates drop
tempfile cel
dis "=============================================================="
dis "Número de sujetos en facturación electronica F04 "
dis "=============================================================="
count
save "`cel'", replace

* 5. Unificación F104 con F06 
*-----------------------------------------------------------
use "`acumulado'", clear
ren numero_identificacion ID0

*Conteo de F104
bysort ID0: gen d = _N
tab d
bysort ID0 : gen num = 1 if _n == 1
gen numt = 1
dis "=============================================================="
dis "Número de sujetos y obligaciones reales F01 antes de cruce con F06: "
dis "=============================================================="
tabstat num numt , by(d) s(sum) f(%12.0fc)

* 6. Cruce con la base de obligaciones y F104
*---------------------------------------------------------------------
*Estadísitica de cruce y 
* selección solo de los que debian haber cumplido y han cumplido F104
* los merge 1 son las declaraciones que sin tener que hacerlas la hicieron
* los merge 2 son los que tenian que haber declarado y no lo hicieron
* los merge 3 son los que efectivamente lo hicieron
drop d numt num
merge 1:1 ID0 mes_desde mes_hasta anio_fiscal using "`base_f06'" , keepusing(ID0)
keep if _merge == 3

*Conteo de casos unicos y registros que quedarían luego en F104
bysort ID0: gen d = _N
tab d
bysort ID0 : gen num = 1 if _n == 1
gen numt = 1
dis "=============================================================="
dis "Número de sujetos y obligaciones reales F01 luego de cruce con F06: "
dis "=============================================================="
tabstat num numt , by(d) s(sum) f(%12.0fc)

* 7. Cruce con RUC y aplicación de filtros ruc sp ong y 12 declaraciones
*-----------------------------------------------------------
merge m:1 ID0 using "`rucparcial'", keep(1 3) gen(mruc)
*Elimino lo que no son ruc
drop if mruc!=3 
*Elimino los que son ONG o SP
drop if substr(codigo_opera_area,1,2) == "23" | substr(codigo_opera_area,1,2) == "22"
*Elimino los que tienen menos de 12 declaraciones en el periodo de análisis
drop if d<12 
*Estadísticos luego de la eliminación
drop d numt num
bysort ID0: gen d = _N
tab d
bysort ID0 : gen num = 1 if _n == 1
gen numt = 1
dis "=============================================================="
dis "Número de sujetos y obligaciones reales F01 luego de cruce con F06 y RUC" 
dis " y 12 declaraciones: "
dis "=============================================================="
tabstat num numt , by(d) s(sum) f(%12.0fc)

* 8. Cruce con cel y filtro que esten en él
*-----------------------------------------------------------
merge m:1 ID0 using "`cel'", keep(3) nogen
drop d numt num
bysort ID0: gen d = _N
tab d
bysort ID0 : gen num = 1 if _n == 1
gen numt = 1
dis "=============================================================="
dis "Número de sujetos y obligaciones reales F01 luego de cruce con F06 y RUC" 
dis " y 12 declaraciones y declaran F04 facturación electrónica: "
dis "=============================================================="
tabstat num numt , by(d) s(sum) f(%12.0fc)

* 9. Guardado del catastro depurado de contribuyentes
*-----------------------------------------------------------
keep ID0 ID
duplicates drop
codebook ID
dis "Número de contribuyentes final: " c(N)
save "AF00_F01F03_seleccion1.dta", replace

log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

