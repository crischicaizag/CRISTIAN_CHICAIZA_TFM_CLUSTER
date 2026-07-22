
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
log using "Log11_F07_retenciones_codebook0.txt", text replace


/*******************************************************************************
FUENTE    : F07 — Consolidado de retenciones entre pares
OBJETIVO  : Construir el bloque de variables analíticas de F07 a nivel de
            contribuyente para el dataset de clustering y caracterización.
ENTRADA   : F07_consolida_retenc_2024.txt
SALIDA    : AF07_perfil_contribuyente.dta
*******************************************************************************/

* 0. CONFIGURACION DEL ENTORNO
*===============================================================================
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

*1. LECTURA Y PROCESAMIENTO PREVIO
*===============================================================================
*La base es del año 2024, provisto por tiempos de extración represados.
*La base es completa de todas las retenciones incluido IVA
*La base contiene todos los sujetos agentes de retención y agentes retenidos 
*declarados por el agente de retención

import delimited "F07_consolida_retenc_2024.csv", varnames(1) ///
stringcols(_all) clear
ren anio_emision anio_fiscal
ren mes_emision	mes_fiscal
destring base_imponible	valor_retenido, replace
tab marca_medio_emision
replace mes_fiscal = string(real(mes_fiscal), "%02.0f")

 *Corrección de informado, pertenece a la base bruta sin purgar informado
replace informado = ustrregexra(informado,"[^\p{L}\p{N} ]","")
replace informado = trim(itrim(informado))

collapse (sum) base_imponible valor_retenido  , ///
 by(informante informado anio_fiscal mes_fiscal codigo_retencion ///
 descripcion_concepto clasificacion )
 
* Filtro de rucs que son agentes de retención como rucs (no podrian ser no 
*ruc es el plano local)
 ren informante ID0
 merge m:1 ID0 using F00_RUC_auxiliar, keepusing(ID0 ID) keep(3) nogen
 *Marca del catastro de seleccion primaria
 merge m:1 ID  using AF00_F01F03_seleccion1, keep(1 3) 
 gen marca_seleccion_agenretencion = _merge == 3
 drop _merge
 ren ID0 ID0_informante
 ren ID ID_informante

* Filtro de rucs que son agentes retenidos 
 ren informado ID0
 merge m:1 ID0 using F00_RUC_auxiliar, keepusing(ID0 ID) keep(1 3)
 gen marca_retenido = _merge == 3
 drop _merge
 *Marca del catastro de seleccion primaria como agente retenido
 merge m:1 ID  using AF00_F01F03_seleccion1, keep(1 3) 
 gen marca_seleccion_agenretenido = _merge == 3
 drop _merge
 ren ID0 ID0_informado
 ren ID ID_informado // solo existe para los casos que son ruc
save t0f07, replace
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log11_F07_retenciones_codebook1_estadisticas.txt", text replace

/*******************************************************************************
Estadísticas descriptivas para tomar decisiones, con
            evidencia empírica, las cinco decisiones metodológicas
ENTRADA   : t0f07.dta  (49.780.039 obs tras colapso y cruces previos)
            AF00_F01F03_seleccion1.dta  (catastro primario, 797.161 obs)
SALIDA    : Log12_F07_retenciones_codebook1.txt
*******************************************************************************/
*2. ANÁLISIS ESTADÍTICO PREVIO
*===============================================================================

* 2.0. ENTORNO
*----------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"
global f07 t0f07

*Agregados generales
use $f07, clear
gen num = 1 
collapse (sum) num base_imponible valor_retenido, by(codigo_retencion descripcion_concepto clasificacion)
export excel using "F07_statagr.xlsx", firstrow(variables) sheetreplace sheet("agrf07") 

*Otros agregados generales
use $f07, clear
tab anio_fiscal mes_fiscal

*General
table marca_seleccion_agenretencion, ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)

table marca_retenido , ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)

table marca_seleccion_agenretenido, ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)

*con IVA retencionestable marca_seleccion_agenretencion, ///
table marca_seleccion_agenretencion if clasificacion == "IVA RETENCION ",  ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)

table marca_retenido if clasificacion == "IVA RETENCION " , ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)

table marca_seleccion_agenretenido if clasificacion == "IVA RETENCION ", ///
    statistic(sum base_imponible) ///
    statistic(sum valor_retenido) ///
    statistic(count base_imponible) ///
    nformat(%14.0fc)
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log12_F07_perfil_construccion.txt", text replace


/*******************************************************************************
FUENTE    : F07 — Consolidado de retenciones entre pares
OBJETIVO  : Perfil de retenciones por contribuyente, una fila por ID del
            catastro primario, con variables desde la perspectiva del
            agente de retención y del agente retenido. Núcleo IVA entra al
            clustering. Actividad económica (renta) se reserva para
            caracterización post-clustering.
ENTRADA   : t0f07.dta
SALIDA    : AF07_perfil_contribuyente.dta
*******************************************************************************/

*3. CONSTRUCCION DE VARIABLES DESDE LADO DEL AGENTE DE RETENCION y RETENIDO
*===============================================================================

* 3.0. Entorno
*----------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

*3.1. Estadistico adicional para agentes retenedores de IVA
*------------------------------------------------------------------------------
use t0f07, clear
table marca_seleccion_agenretencion if clasificacion=="IVA RETENCION " & inlist(codigo_retencion,"1","2","3","4","5","6","9","10","11"), statistic(sum valor_retenido) nformat(%14.0fc)


*3.2. Filtrado temático y marcado de tarifa IVA
*----------------------------------------------------------------------------
use t0f07, clear

* Solo IVA con códigos económicos y ACTIVIDAD ECONOMICA, el resto se descarta.
* Los presuntivos 4, 5, 6 se asimilan a tarifa 100% (retencion al total).
keep if (clasificacion == "IVA RETENCION " & ///
         inlist(codigo_retencion,"1","2","3","4","5","6","9","10","11")) ///
      | (clasificacion == "ACTIVIDAD ECONOMICA")

gen byte es_iva   = clasificacion == "IVA RETENCION "
gen byte es_renta = clasificacion == "ACTIVIDAD ECONOMICA"

gen tarifa_iva = .
replace tarifa_iva = 10  if codigo_retencion == "9"
replace tarifa_iva = 20  if codigo_retencion == "10"
replace tarifa_iva = 30  if codigo_retencion == "1"
replace tarifa_iva = 50  if codigo_retencion == "11"
replace tarifa_iva = 70  if codigo_retencion == "2"
replace tarifa_iva = 100 if inlist(codigo_retencion,"3","4","5","6")
destring mes_fiscal, gen(mes_n)

save _tmp_f07_filtrado, replace


*3.3. Perfil como AGENTE DE RETENCION (sufijo _agr)
*----------------------------------------------------------------------------
* Universo amplio en este paso. El recorte al catastro se hace en la 
* integracion final.

*3.3.1. Sumas, conteos y retenido por tarifa
use _tmp_f07_filtrado, clear

gen base_iva_agr   = base_imponible if es_iva == 1
gen ret_iva_agr    = valor_retenido if es_iva == 1
gen base_renta_agr = base_imponible if es_renta == 1
gen ret_renta_agr  = valor_retenido if es_renta == 1

foreach t in 10 20 30 50 70 100 {
   gen ret_iva_t`t'_agr = valor_retenido if tarifa_iva == `t'
}

gen byte n_lin_iva_agr   = es_iva
gen byte n_lin_renta_agr = es_renta

collapse (sum) base_iva_agr ret_iva_agr base_renta_agr ret_renta_agr ///
               ret_iva_t10_agr ret_iva_t20_agr ret_iva_t30_agr ///
               ret_iva_t50_agr ret_iva_t70_agr ret_iva_t100_agr ///
               n_lin_iva_agr n_lin_renta_agr ///
       , by(ID_informante)

save _tmp_agr_sum, replace

*3.3.2. HHI y contrapartes en IVA, mas marcas de naturaleza de la contraparte
use _tmp_f07_filtrado, clear
keep if es_iva == 1

collapse (sum) ret_par = valor_retenido, ///
         by(ID_informante ID0_informado marca_retenido marca_seleccion_agenretenido)
bysort ID_informante: egen ret_tot = total(ret_par)
gen share2 = (ret_par/ret_tot)^2 if ret_tot > 0

gen ret_ruc = ret_par if marca_retenido == 1
gen ret_cat = ret_par if marca_seleccion_agenretenido == 1

gen byte uno = 1

collapse (sum) hhi_iva_agr = share2 ret_ruc ret_cat ///
         (sum) n_contrap_iva_agr = uno ///
         , by(ID_informante)

save _tmp_agr_red_iva, replace

*3.3.3. HHI y contrapartes en renta
use _tmp_f07_filtrado, clear
keep if es_renta == 1

collapse (sum) ret_par = valor_retenido, by(ID_informante ID0_informado)
bysort ID_informante: egen ret_tot = total(ret_par)
gen share2 = (ret_par/ret_tot)^2 if ret_tot > 0

gen byte uno = 1

collapse (sum) hhi_renta_agr = share2 ///
         (sum) n_contrap_renta_agr = uno ///
         , by(ID_informante)

save _tmp_agr_renta, replace

*3.3.4. Meses activos en IVA
use _tmp_f07_filtrado, clear
keep if es_iva == 1
bysort ID_informante mes_n: keep if _n == 1
collapse (count) n_meses_iva_agr = mes_n, by(ID_informante)
save _tmp_agr_meses, replace

*3.3.5. Ensamblaje del perfil agr y construccion de derivadas
use _tmp_agr_sum, clear
merge 1:1 ID_informante using _tmp_agr_red_iva,  nogen
merge 1:1 ID_informante using _tmp_agr_renta,    nogen
merge 1:1 ID_informante using _tmp_agr_meses,    nogen

* Tasa efectiva ponderada
gen tasa_efe_iva_agr = ret_iva_agr / base_iva_agr if base_iva_agr > 0

* Estructura por tarifa: proporcion del retenido IVA en cada tramo
foreach t in 10 20 30 50 70 100 {
   gen p_t`t'_agr = ret_iva_t`t'_agr / ret_iva_agr if ret_iva_agr > 0
   drop ret_iva_t`t'_agr
}

* Proporcion del retenido contra contrapartes con RUC y dentro del catastro
gen prop_ruc_iva_agr = ret_ruc / ret_iva_agr if ret_iva_agr > 0
gen prop_cat_iva_agr = ret_cat / ret_iva_agr if ret_iva_agr > 0
drop ret_ruc ret_cat

ren ID_informante ID
save _tmp_perfil_agr, replace


*3.4. Perfil como AGENTE RETENIDO (sufijo _ard)
*----------------------------------------------------------------------------
* Solo informados con RUC (sin RUC no hay forma de cruzar con catastro).

*3.4.1. Sumas, conteos y retenido por tarifa
use _tmp_f07_filtrado, clear
keep if marca_retenido == 1

gen base_iva_ard   = base_imponible if es_iva == 1
gen ret_iva_ard    = valor_retenido if es_iva == 1
gen base_renta_ard = base_imponible if es_renta == 1
gen ret_renta_ard  = valor_retenido if es_renta == 1

foreach t in 10 20 30 50 70 100 {
   gen ret_iva_t`t'_ard = valor_retenido if tarifa_iva == `t'
}

gen byte n_lin_iva_ard   = es_iva
gen byte n_lin_renta_ard = es_renta

collapse (sum) base_iva_ard ret_iva_ard base_renta_ard ret_renta_ard ///
               ret_iva_t10_ard ret_iva_t20_ard ret_iva_t30_ard ///
               ret_iva_t50_ard ret_iva_t70_ard ret_iva_t100_ard ///
               n_lin_iva_ard n_lin_renta_ard ///
       , by(ID_informado)

save _tmp_ard_sum, replace

*3.4.2. HHI y contrapartes en IVA, marca de agente retenedor en catastro
use _tmp_f07_filtrado, clear
keep if es_iva == 1 & marca_retenido == 1

collapse (sum) ret_par = valor_retenido, ///
         by(ID_informado ID0_informante marca_seleccion_agenretencion)
bysort ID_informado: egen ret_tot = total(ret_par)
gen share2 = (ret_par/ret_tot)^2 if ret_tot > 0

gen ret_agr_cat = ret_par if marca_seleccion_agenretencion == 1

gen uno =  1

collapse (sum) hhi_iva_ard = share2 ret_agr_cat ///
         (count) n_contrap_iva_ard = uno ///
         , by(ID_informado)

save _tmp_ard_red_iva, replace

*3.4.3. HHI y contrapartes en renta
use _tmp_f07_filtrado, clear
keep if es_renta == 1 & marca_retenido == 1

collapse (sum) ret_par = valor_retenido, by(ID_informado ID0_informante)
bysort ID_informado: egen ret_tot = total(ret_par)
gen share2 = (ret_par/ret_tot)^2 if ret_tot > 0
gen uno =  1
collapse (sum) hhi_renta_ard = share2 ///
         (count) n_contrap_renta_ard = uno ///
         , by(ID_informado)

save _tmp_ard_renta, replace

*3.4.4. Meses activos en IVA
use _tmp_f07_filtrado, clear
keep if es_iva == 1 & marca_retenido == 1
bysort ID_informado mes_n: keep if _n == 1
collapse (count) n_meses_iva_ard = mes_n, by(ID_informado)
save _tmp_ard_meses, replace

*3.4.5. Ensamblaje del perfil ard y derivadas
use _tmp_ard_sum, clear
merge 1:1 ID_informado using _tmp_ard_red_iva,  nogen
merge 1:1 ID_informado using _tmp_ard_renta,    nogen
merge 1:1 ID_informado using _tmp_ard_meses,    nogen

gen tasa_efe_iva_ard = ret_iva_ard / base_iva_ard if base_iva_ard > 0

foreach t in 10 20 30 50 70 100 {
   gen p_t`t'_ard = ret_iva_t`t'_ard / ret_iva_ard if ret_iva_ard > 0
   drop ret_iva_t`t'_ard
}

* En la perspectiva retenido, prop_cat = fraccion del IVA retenido que
* proviene de agentes retenedores del catastro
gen prop_cat_iva_ard = ret_agr_cat / ret_iva_ard if ret_iva_ard > 0
drop ret_agr_cat

ren ID_informado ID
save _tmp_perfil_ard, replace


*3.5. Integracion con el catastro primario
*----------------------------------------------------------------------------
* Una fila por contribuyente del catastro. Quien no aparece en F07 queda
* en cero para conteos y montos, y en missing para tasas y proporciones.

use AF00_F01F03_seleccion1, clear
keep ID
duplicates drop ID, force

merge 1:1 ID using _tmp_perfil_agr, keep(1 3) nogen
merge 1:1 ID using _tmp_perfil_ard, keep(1 3) nogen

* Conteos y montos a cero cuando el contribuyente no aparecio en F07
foreach v of varlist n_lin_iva_agr n_lin_renta_agr n_contrap_iva_agr ///
                     n_contrap_renta_agr n_meses_iva_agr ///
                     n_lin_iva_ard n_lin_renta_ard n_contrap_iva_ard ///
                     n_contrap_renta_ard n_meses_iva_ard ///
                     base_iva_agr ret_iva_agr base_renta_agr ret_renta_agr ///
                     base_iva_ard ret_iva_ard base_renta_ard ret_renta_ard {
   replace `v' = 0 if missing(`v')
}

* Banderas de presencia en F07
gen byte flg_es_retenedor = (n_lin_iva_agr > 0 | n_lin_renta_agr > 0)
gen byte flg_es_retenido  = (n_lin_iva_ard > 0 | n_lin_renta_ard > 0)

* Orden de variables: nucleo de clustering primero, caracterizacion despues
order ID ///
      n_lin_iva_agr   n_contrap_iva_agr   n_meses_iva_agr ///
      base_iva_agr    ret_iva_agr         tasa_efe_iva_agr ///
      p_t10_agr p_t20_agr p_t30_agr p_t50_agr p_t70_agr p_t100_agr ///
      hhi_iva_agr     prop_ruc_iva_agr    prop_cat_iva_agr ///
      n_lin_iva_ard   n_contrap_iva_ard   n_meses_iva_ard ///
      base_iva_ard    ret_iva_ard         tasa_efe_iva_ard ///
      p_t10_ard p_t20_ard p_t30_ard p_t50_ard p_t70_ard p_t100_ard ///
      hhi_iva_ard     prop_cat_iva_ard ///
      n_lin_renta_agr n_contrap_renta_agr base_renta_agr  ret_renta_agr  hhi_renta_agr ///
      n_lin_renta_ard n_contrap_renta_ard base_renta_ard  ret_renta_ard  hhi_renta_ard ///
      flg_es_retenedor flg_es_retenido


* 4. VALIDACION POSTERIOR
*===============================================================================
* Distribuciones de las variables nucleo y cierre macro contra Log11.

display _newline "== Tamaño del perfil =="
count

display _newline "== Cobertura en F07 (catastro) =="
tab flg_es_retenedor flg_es_retenido, missing

display _newline "== Nucleo IVA — perspectiva agente de retencion =="
summarize n_lin_iva_agr n_contrap_iva_agr n_meses_iva_agr ///
          base_iva_agr ret_iva_agr tasa_efe_iva_agr ///
          hhi_iva_agr prop_ruc_iva_agr prop_cat_iva_agr, detail

display _newline "== Nucleo IVA — perspectiva agente retenido =="
summarize n_lin_iva_ard n_contrap_iva_ard n_meses_iva_ard ///
          base_iva_ard ret_iva_ard tasa_efe_iva_ard ///
          hhi_iva_ard prop_cat_iva_ard, detail

display _newline "== Estructura por tarifa — retenedor =="
summarize p_t10_agr p_t20_agr p_t30_agr p_t50_agr p_t70_agr p_t100_agr, detail
display _newline "== Estructura por tarifa — retenido =="
summarize p_t10_ard p_t20_ard p_t30_ard p_t50_ard p_t70_ard p_t100_ard, detail

display _newline "== Renta (caracterizacion) — retenedor =="
summarize n_lin_renta_agr n_contrap_renta_agr base_renta_agr ret_renta_agr hhi_renta_agr, detail
display _newline "== Renta (caracterizacion) — retenido =="
summarize n_lin_renta_ard n_contrap_renta_ard base_renta_ard ret_renta_ard hhi_renta_ard, detail

* Cierre macro: el IVA retenido sobre catastro como retenido en el perfil
* debe coincidir con 3.971.937.339 reportado en Log11 (marca_seleccion_agenretenido==1).
display _newline "== Cierre macro IVA retenido — catastro como retenido =="
total ret_iva_ard if flg_es_retenido == 1

* La perspectiva retenedor sobre catastro no tiene cifra directa en Log11
* (no se ejecuto la tabla por marca_seleccion_agenretencion en clasificacion IVA),
* se reporta solo como referencia.
display _newline "== Total IVA retenido por agentes del catastro (referencia) =="
total ret_iva_agr if flg_es_retenedor == 1


* 4. GUARDADO Y LIMPIEZA
*===============================================================================

*4.1. Etiquetado de variables
*-------------------------------------------------------------------------------
* Identificador
label var ID                   "Identificador anónimo del contribuyente (catastro primario)"

* Núcleo IVA — perspectiva agente de retención (sufijo _agr)
label var n_lin_iva_agr        "IVA agr: número de líneas de retención emitidas en 2024"
label var n_contrap_iva_agr    "IVA agr: número de contrapartes únicas retenidas en 2024"
label var n_meses_iva_agr      "IVA agr: meses con actividad como retenedor en 2024 (0-12)"
label var base_iva_agr         "IVA agr: base imponible total sobre la que retuvo (USD, 2024)"
label var ret_iva_agr          "IVA agr: valor total retenido emitido como agente (USD, 2024)"
label var tasa_efe_iva_agr     "IVA agr: tasa efectiva ponderada (ret_iva_agr / base_iva_agr)"
label var p_t10_agr            "IVA agr: proporción del retenido emitido a tarifa 10%"
label var p_t20_agr            "IVA agr: proporción del retenido emitido a tarifa 20%"
label var p_t30_agr            "IVA agr: proporción del retenido emitido a tarifa 30%"
label var p_t50_agr            "IVA agr: proporción del retenido emitido a tarifa 50%"
label var p_t70_agr            "IVA agr: proporción del retenido emitido a tarifa 70%"
label var p_t100_agr           "IVA agr: proporción del retenido emitido a tarifa 100%"
label var hhi_iva_agr          "IVA agr: HHI de concentración del retenido por contraparte"
label var prop_ruc_iva_agr     "IVA agr: proporción del retenido contra contrapartes con RUC"
label var prop_cat_iva_agr     "IVA agr: proporción del retenido contra contrapartes del catastro"

* Núcleo IVA — perspectiva agente retenido (sufijo _ard)
label var n_lin_iva_ard        "IVA ard: número de líneas de retención recibidas en 2024"
label var n_contrap_iva_ard    "IVA ard: número de contrapartes únicas que le retuvieron en 2024"
label var n_meses_iva_ard      "IVA ard: meses con retenciones recibidas en 2024 (0-12)"
label var base_iva_ard         "IVA ard: base imponible total sobre la que le retuvieron (USD, 2024)"
label var ret_iva_ard          "IVA ard: valor total que le fue retenido (USD, 2024)"
label var tasa_efe_iva_ard     "IVA ard: tasa efectiva ponderada (ret_iva_ard / base_iva_ard)"
label var p_t10_ard            "IVA ard: proporción del retenido recibido a tarifa 10%"
label var p_t20_ard            "IVA ard: proporción del retenido recibido a tarifa 20%"
label var p_t30_ard            "IVA ard: proporción del retenido recibido a tarifa 30%"
label var p_t50_ard            "IVA ard: proporción del retenido recibido a tarifa 50%"
label var p_t70_ard            "IVA ard: proporción del retenido recibido a tarifa 70%"
label var p_t100_ard           "IVA ard: proporción del retenido recibido a tarifa 100%"
label var hhi_iva_ard          "IVA ard: HHI de concentración del retenido por contraparte"
label var prop_cat_iva_ard     "IVA ard: proporción del retenido proveniente de agentes del catastro"

* Caracterización Renta — perspectiva retenedor
label var n_lin_renta_agr      "Renta agr: número de líneas en ACTIVIDAD ECONOMICA en 2024"
label var n_contrap_renta_agr  "Renta agr: número de contrapartes únicas retenidas en 2024"
label var base_renta_agr       "Renta agr: base imponible total sobre la que retuvo (USD, 2024)"
label var ret_renta_agr        "Renta agr: valor total retenido emitido (USD, 2024)"
label var hhi_renta_agr        "Renta agr: HHI de concentración por contraparte"

* Caracterización Renta — perspectiva retenido
label var n_lin_renta_ard      "Renta ard: número de líneas en ACTIVIDAD ECONOMICA en 2024"
label var n_contrap_renta_ard  "Renta ard: número de contrapartes únicas que le retuvieron en 2024"
label var base_renta_ard       "Renta ard: base imponible total sobre la que le retuvieron (USD, 2024)"
label var ret_renta_ard        "Renta ard: valor total que le fue retenido (USD, 2024)"
label var hhi_renta_ard        "Renta ard: HHI de concentración por contraparte"

* Banderas de presencia
label var flg_es_retenedor     "Flag: actuó como agente de retención en F07 durante 2024 (1=sí)"
label var flg_es_retenido      "Flag: sufrió retenciones en F07 durante 2024 (1=sí)"

* Etiqueta del dataset
label data "F07 perfil de retenciones por contribuyente — IVA núcleo + Renta caracterización (2024)"

*Guardado
save AF07_perfil_contribuyente, replace

*Limpieza
cap erase _tmp_f07_filtrado.dta
cap erase _tmp_agr_sum.dta
cap erase _tmp_agr_red_iva.dta
cap erase _tmp_agr_renta.dta
cap erase _tmp_agr_meses.dta
cap erase _tmp_perfil_agr.dta
cap erase _tmp_ard_sum.dta
cap erase _tmp_ard_red_iva.dta
cap erase _tmp_ard_renta.dta
cap erase _tmp_ard_meses.dta
cap erase _tmp_perfil_ard.dta

* Verificación
describe
codebook, compact

log close
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@




