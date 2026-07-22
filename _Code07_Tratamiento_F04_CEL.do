
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
log using "Log13_F04_CEL_codebook0.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Procesamiento inicial de la fuente F04 cruda a F04 
  FUENTES    : CEL

  SALIDA     : Inicial: t_cel.dta
               Logs: Log03_F01_F104_codebook.txt
*******************************************************************************/

* 1. LECTURA INICIAL DE BASE CRUDA
*===============================================================================

*1.0 Preprocesameinto de base cruda de CEL en dta
*----------------------------------------------------------------------------
*La base se encuentra a nivel anual agregado por cliente emisor y tipo de 
*comprobante
*Para el caso de cliente se identifica si es o no un ruc

clear all
set more off, permanently
set type double, permanently
use "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER\t_cel.dta", clear

dis "Registros y variables inicial en esta sección"
dis "---------------------------------------------"
count
describe

keep if inlist(cod_ope_tipo_documento_adm,"1","4","5")
gen byte marca_notacredito = (cod_ope_tipo_documento_adm=="4")
destring ///
    sub_total_12 ///
    sub_total_0 ///
    sub_total_no_objeto_iva ///
    sub_total_exento_iva ///
    valor_retencion_iva ///
    valor_retencion_renta ///
    total_subsidio ///
    numero_comprobantes, replace

foreach v of varlist ///
    sub_total_12 ///
    sub_total_0 ///
    sub_total_no_objeto_iva ///
    sub_total_exento_iva ///
    valor_retencion_iva ///
    valor_retencion_renta ///
    total_subsidio ///
    numero_comprobantes {
    
    replace `v' = 0 if missing(`v')
}

compress

collapse (sum) ///
    sub_total_12 ///
    sub_total_0 ///
    sub_total_no_objeto_iva ///
    sub_total_exento_iva ///
    valor_retencion_iva ///
    valor_retencion_renta ///
    total_subsidio ///
    numero_comprobantes, ///
    by(marca_notacredito ruc_vendedor ruc anio_emision)

ren ruc_vendedor ID0
merge m:1 ID0 using F00_RUC_auxiliar, keep(3) nogen
ren ID0 ID0_emisor
ren ID ID_emisor

ren ruc ID0
merge m:1 ID0 using F00_RUC_auxiliar, keep(1 3) 
ren ID0 ID0_cliente
ren ID ID_cliente
gen marca_cliente_ruc = _merge == 3
drop _merge

dis "Rergistros y variables final en esta sección"
dis "---------------------------------------------"
count
describe

save F04_CEL2024FULL_ANUAL, replace
gen long numero_cliente_total = 1

collapse (sum) ///
    numero_cliente_total ///
    sub_total_12 ///
    sub_total_0 ///
    sub_total_no_objeto_iva ///
    sub_total_exento_iva ///
    valor_retencion_iva ///
    valor_retencion_renta ///
    total_subsidio ///
    numero_comprobantes, ///
    by(ID0_emisor ID_emisor marca_cliente_ruc anio_emision)
save F04_CEL2024_EMISORBYTIPOCLIENTE, replace

dis "Rergistros y variables final en esta sección"
dis "---------------------------------------------"
count
describe

log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log13_F04_CEL_codebook1.txt", text replace

* 2. ANALISIS ESTADÍSTICO PREVIO
*===============================================================================
* Por agregado anual
use F04_CEL2024FULL_ANUAL, clear
describe
codebook 
codebook, compact

* Por agregado tipo cliente
use F04_CEL2024_EMISORBYTIPOCLIENTE, clear
describe
codebook 
codebook, compact

log close 

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


cap log close 
log using "Log14_F04_Construccion_base_analitica_CEL.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Construcción del perfil F04 a nivel contribuyente, desde dos
               perspectivas complementarias en operaciones electrónicas:
                 (a) lado EMISOR — comportamiento de ventas,
                 (b) lado CLIENTE — comportamiento de compras cuando el cliente
                     porta RUC y es candidato a integrar el catastro primario.
               El cruce con el catastro primario (797.161 contribuyentes) se
               realiza posteriormente, en la integración del dataset analítico
               final, mediante merge 1:1 por ID.
  FUENTES    : F04_CEL2024FULL_ANUAL.dta  (emisor × cliente × marca_nc × año)
  SALIDA     : AF04_perfil_contribuyente.dta — una fila por ID y año
  COBERTURA  : 2024 exclusivamente
  LOGS       : Log14_F04_Construccion_base_analitica_CEL.txt
*******************************************************************************/

* 3. CONSTRUCCION DE VARIABLES ANALITICAS
*===============================================================================


*3.1. Construcción del perfil F04 a nivel contribuyente emisor
*----------------------------------------------------------------------------


*3.1.1. Lado EMISOR — bloque facturas (marca_notacredito==0)
*----------------------------------------------------------------------------
*Conteo de clientes distintos a partir de ID0_cliente: cada fila de la base
*FULL_ANUAL corresponde a un cliente distinto del emisor (la primera 
*colapsada se hizo por ruc_vendedor × ruc × marca_nc × año). Sumar la 
*indicadora 1 por fila reproduce el conteo de clientes distintos.
clear all
set more off, permanently
set type double, permanently
use F04_CEL2024FULL_ANUAL, clear
keep if marca_notacredito == 0

gen double v_cf       = (sub_total_12 + sub_total_0) * (marca_cliente_ruc == 0)
gen double v_ruc      = (sub_total_12 + sub_total_0) * (marca_cliente_ruc == 1)
gen double comp_cf    = numero_comprobantes          * (marca_cliente_ruc == 0)
gen byte un_cli_cf    = (marca_cliente_ruc == 0)
gen byte un_cli_ruc   = (marca_cliente_ruc == 1)

collapse (sum) ///
    tot_gravado_fe       = sub_total_12 ///
    tot_cero_fe          = sub_total_0  ///
    ventas_cf_fe         = v_cf  ///
    ventas_ruc_fe        = v_ruc ///
    n_comprobantes_cf_fe = comp_cf ///
    n_clientes_cf_fe     = un_cli_cf ///
    n_clientes_ruc_fe    = un_cli_ruc, ///
    by(ID0_emisor ID_emisor anio_emision)

gen double tot_facturado_fe  = tot_gravado_fe + tot_cero_fe
gen double prop_gravado_fe   = tot_gravado_fe / tot_facturado_fe if tot_facturado_fe > 0
gen double prop_ventas_cf_fe = ventas_cf_fe   / tot_facturado_fe if tot_facturado_fe > 0

compress
tempfile fact_emisor
save `fact_emisor'

*3.1.2. Lado EMISOR — bloque notas de crédito (marca_notacredito==1)
*----------------------------------------------------------------------------
*Las notas de crédito acumulan signo negativo en sub_total_12 y sub_total_0; 
*el valor absoluto de la suma recupera el monto bruto devuelto por el emisor.

use F04_CEL2024FULL_ANUAL, clear
keep if marca_notacredito == 1
gen double monto_nc = sub_total_12 + sub_total_0

collapse (sum) tot_nc_raw = monto_nc, by(ID0_emisor ID_emisor anio_emision)
gen double tot_nc_fe = abs(tot_nc_raw)
drop tot_nc_raw

compress
tempfile nc_emisor
save `nc_emisor'

*3.1.3. Lado EMISOR — HHI de clientes con RUC
*----------------------------------------------------------------------------
*Concentración de ventas gravadas entre clientes con RUC. El consumidor final
*queda fuera porque la base FULL_ANUAL retuvo a cada cliente CF como fila
*individual mediante ID0_cliente, pero el HHI mide concentración relativa al
*total gravado a clientes con RUC, perspectiva interpretable y consistente
*con la lógica del crédito fiscal cruzado.

use F04_CEL2024FULL_ANUAL, clear
keep if marca_notacredito == 0 & marca_cliente_ruc == 1

bysort ID0_emisor anio_emision: egen double tot_grav_ruc = total(sub_total_12)
gen double share2 = (sub_total_12 / tot_grav_ruc)^2 if tot_grav_ruc > 0

collapse (sum) hhi_clientes_fe = share2 ///
         (max) chk_grav = tot_grav_ruc, ///
         by(ID0_emisor ID_emisor anio_emision)

replace hhi_clientes_fe = . if chk_grav <= 0 | missing(chk_grav)
drop chk_grav

compress
tempfile hhi_emisor
save `hhi_emisor'

*3.1.4. Consolidación lado EMISOR
*----------------------------------------------------------------------------

use `fact_emisor', clear
merge 1:1 ID0_emisor ID_emisor anio_emision using `nc_emisor', nogen
recode tot_nc_fe (missing = 0)
merge 1:1 ID0_emisor ID_emisor anio_emision using `hhi_emisor', nogen

gen double ratio_nc_fe = tot_nc_fe / tot_facturado_fe if tot_facturado_fe > 0

rename ID0_emisor ID0
rename ID_emisor  ID

compress
tempfile perfil_emisor
save `perfil_emisor'


*3.2. Construcción del perfil F04 a nivel contribuyente cliente
*----------------------------------------------------------------------------


*3.2.1. Lado CLIENTE — bloque compras (facturas recibidas con marca_cliente_ruc==1)
*----------------------------------------------------------------------------
*Espejo del bloque ventas del lado emisor. Solo se conservan operaciones con 
*cliente con RUC, ya que esos contribuyentes son los candidatos a aparecer en 
*el catastro primario. El conteo de proveedores distintos opera por la misma 
*lógica del conteo de clientes en el lado emisor.

use F04_CEL2024FULL_ANUAL, clear
keep if marca_cliente_ruc == 1 & marca_notacredito == 0

gen byte un_prov = 1
collapse (sum) ///
    tot_compras_grav_fe = sub_total_12 ///
    tot_compras_cero_fe = sub_total_0  ///
    n_proveedores_fe    = un_prov, ///
    by(ID0_cliente ID_cliente anio_emision)

gen double tot_compras_fe       = tot_compras_grav_fe + tot_compras_cero_fe
gen double prop_compras_grav_fe = tot_compras_grav_fe / tot_compras_fe if tot_compras_fe > 0

compress
tempfile compras_cliente
save `compras_cliente'

*3.2.2. Lado CLIENTE — bloque notas de crédito recibidas
*----------------------------------------------------------------------------

use F04_CEL2024FULL_ANUAL, clear
keep if marca_cliente_ruc == 1 & marca_notacredito == 1
gen double monto_nc_rec = sub_total_12 + sub_total_0

collapse (sum) tot_nc_rec_raw = monto_nc_rec, ///
         by(ID0_cliente ID_cliente anio_emision)
gen double tot_nc_recibidas_fe = abs(tot_nc_rec_raw)
drop tot_nc_rec_raw

compress
tempfile nc_cliente
save `nc_cliente'

*3.2.3. Lado CLIENTE — HHI de proveedores
*----------------------------------------------------------------------------
*Concentración de compras gravadas entre proveedores. Clientes que solo 
*reciben tarifa 0% quedan en missing — no se imputan a cero porque ausencia 
*de gravado no equivale a dispersión máxima.

use F04_CEL2024FULL_ANUAL, clear
keep if marca_notacredito == 0 & marca_cliente_ruc == 1

bysort ID0_cliente anio_emision: egen double tot_grav_prov = total(sub_total_12)
gen double share2_p = (sub_total_12 / tot_grav_prov)^2 if tot_grav_prov > 0

collapse (sum) hhi_proveedores_fe = share2_p ///
         (max) chk_grav_p = tot_grav_prov, ///
         by(ID0_cliente ID_cliente anio_emision)

replace hhi_proveedores_fe = . if chk_grav_p <= 0 | missing(chk_grav_p)
drop chk_grav_p

compress
tempfile hhi_cliente
save `hhi_cliente'

*3.2.4. Consolidación lado CLIENTE
*----------------------------------------------------------------------------

use `compras_cliente', clear
merge 1:1 ID0_cliente ID_cliente anio_emision using `nc_cliente', nogen
recode tot_nc_recibidas_fe (missing = 0)
merge 1:1 ID0_cliente ID_cliente anio_emision using `hhi_cliente', nogen

gen double ratio_nc_recibidas_fe = tot_nc_recibidas_fe / tot_compras_fe if tot_compras_fe > 0

rename ID0_cliente ID0
rename ID_cliente  ID

compress
tempfile perfil_cliente
save `perfil_cliente'

*3.3. Construcción del perfil F04 a nivel contribuyente cliente
*----------------------------------------------------------------------------
*Unificación EMISOR + CLIENTE en una sola fila por contribuyente y año
*El merge 1:1 por (ID0, ID, anio_emision) consolida los dos roles. Un mismo 
*RUC puede aparecer solo como emisor, solo como cliente, o en ambos roles. 
*Las variables del lado donde el contribuyente no actúa quedan en missing y 
*serán tratadas en la fase de imputación del dataset analítico final.

use `perfil_emisor', clear
merge 1:1 ID0 ID anio_emision using `perfil_cliente', nogen

order ID0 ID anio_emision ///
      tot_gravado_fe tot_cero_fe tot_facturado_fe prop_gravado_fe ///
      tot_nc_fe ratio_nc_fe ///
      ventas_cf_fe ventas_ruc_fe prop_ventas_cf_fe ///
      n_clientes_ruc_fe n_clientes_cf_fe n_comprobantes_cf_fe ///
      hhi_clientes_fe ///
      tot_compras_grav_fe tot_compras_cero_fe tot_compras_fe prop_compras_grav_fe ///
      tot_nc_recibidas_fe ratio_nc_recibidas_fe ///
      n_proveedores_fe hhi_proveedores_fe

label var tot_gravado_fe         "Ventas gravadas (12/15%) — facturas — 2024"
label var tot_cero_fe            "Ventas tarifa 0% — facturas — 2024"
label var tot_facturado_fe       "Total facturado neto — 2024"
label var prop_gravado_fe        "Proporción gravada / facturado"
label var tot_nc_fe              "Notas de crédito emitidas — monto"
label var ratio_nc_fe            "Razón NC emitidas / facturado"
label var ventas_cf_fe           "Ventas a consumidor final — facturas"
label var ventas_ruc_fe          "Ventas a clientes con RUC — facturas"
label var prop_ventas_cf_fe      "Proporción ventas a CF / facturado"
label var n_clientes_ruc_fe      "Nro clientes con RUC distintos"
label var n_clientes_cf_fe       "Nro clientes CF distintos (vía ID0_cliente)"
label var n_comprobantes_cf_fe   "Nro comprobantes emitidos a CF"
label var hhi_clientes_fe        "HHI ventas gravadas entre clientes con RUC"
label var tot_compras_grav_fe    "Compras gravadas recibidas — facturas"
label var tot_compras_cero_fe    "Compras tarifa 0% recibidas — facturas"
label var tot_compras_fe         "Total compras netas recibidas — 2024"
label var prop_compras_grav_fe   "Proporción compras gravadas / compras"
label var tot_nc_recibidas_fe    "Notas de crédito recibidas — monto"
label var ratio_nc_recibidas_fe  "Razón NC recibidas / compras"
label var n_proveedores_fe       "Nro proveedores con RUC distintos"
label var hhi_proveedores_fe     "HHI compras gravadas entre proveedores"

note: AF04_perfil_contribuyente — un registro por contribuyente y año. Cobertura exclusiva 2024.
note: Sufijo _fe en variables indica origen en facturación electrónica.
note: Lado emisor — comportamiento de ventas. Lado cliente — comportamiento de compras.
note: Variables candidatas a clustering -> prop_gravado_fe, ratio_nc_fe, prop_ventas_cf_fe, hhi_clientes_fe, prop_compras_grav_fe, ratio_nc_recibidas_fe, hhi_proveedores_fe.
note: Variables de caracterización -> tot_facturado_fe, n_clientes_ruc_fe, n_clientes_cf_fe, tot_compras_fe, n_proveedores_fe.
note: El cruce con el catastro primario se realiza posteriormente en la integración del dataset analítico final.
compress
save AF04_perfil_contribuyente, replace

*3.4. Limpieza, marcas de rol, filtrado al catastro primario y validación
*----------------------------------------------------------------------------
*Bloque integrado de cierre para la fuente F04. :
*  (1) Recorte de proporciones y HHI al rango conceptual [0,1] — corrige el 
*      efecto residual de facturas con monto negativo (correctivas) que el 
*      filtro marca_notacredito==1 no captura. Magnitudes marginales pero 
*      contaminan las variables derivadas.
*  (2 Marcas de rol del contribuyente en operaciones electrónicas 2024 
*      (emisor, cliente con RUC, ambos, solo NC).
*  (3) Filtrado al catastro primario (AF00_F01F03_seleccion1, 797.161 
*      contribuyentes) — alineación con el patrón ya aplicado en F05. Las 
*      variables se calcularon ANTES del filtro sobre la red completa, 
*      preservando la validez de HHI, conteos y proporciones, que dependen 
*      de la red comercial real y no del subconjunto del catastro.
*  (4) Reporte de validación pre- y post-filtro.
*
*Las razones ratio_nc_fe y ratio_nc_recibidas_fe NO se winsorizan aquí — ese 
*tratamiento de colas se hará en la fase de preparación del dataset 
*analítico final, evaluando el comportamiento conjunto de todas las fuentes.

use AF04_perfil_contribuyente, clear

*Recorte de proporciones y HHI al rango [0,1]
foreach v of varlist prop_gravado_fe prop_ventas_cf_fe ///
                     prop_compras_grav_fe ///
                     hhi_clientes_fe hhi_proveedores_fe {
    replace `v' = 0 if `v' < 0 & !missing(`v')
    replace `v' = 1 if `v' > 1 & !missing(`v')
}

*Marcas de rol — un contribuyente puede actuar en uno o ambos roles
gen byte flg_emisor_fe      = !missing(tot_facturado_fe)
gen byte flg_cliente_ruc_fe = !missing(tot_compras_fe)
gen byte flg_solo_nc_em_fe  = missing(tot_facturado_fe) & tot_nc_fe > 0 & !missing(tot_nc_fe)
gen byte flg_solo_nc_cl_fe  = missing(tot_compras_fe)   & tot_nc_recibidas_fe > 0 & !missing(tot_nc_recibidas_fe)

label var flg_emisor_fe      "1 = contribuyente emitió facturas en 2024"
label var flg_cliente_ruc_fe "1 = contribuyente recibió facturas con RUC en 2024"
label var flg_solo_nc_em_fe  "1 = solo emisor de NC (sin facturas en 2024)"
label var flg_solo_nc_cl_fe  "1 = solo cliente de NC recibidas (sin compras 2024)"

*Rol consolidado para análisis descriptivos
gen byte rol_fe = .
replace rol_fe = 1 if flg_emisor_fe == 1 & flg_cliente_ruc_fe == 0
replace rol_fe = 2 if flg_emisor_fe == 0 & flg_cliente_ruc_fe == 1
replace rol_fe = 3 if flg_emisor_fe == 1 & flg_cliente_ruc_fe == 1
replace rol_fe = 4 if (flg_solo_nc_em_fe == 1 | flg_solo_nc_cl_fe == 1) & missing(rol_fe)

label define rol_fe_lab 1 "Solo emisor" ///
                        2 "Solo cliente con RUC" ///
                        3 "Emisor y cliente con RUC" ///
                        4 "Solo notas de crédito"
label values rol_fe rol_fe_lab
label var rol_fe "Rol del contribuyente en F04 — 2024"

*Reorden de variables: identificación y rol primero, luego el perfil
order ID0 ID anio_emision rol_fe ///
      flg_emisor_fe flg_cliente_ruc_fe flg_solo_nc_em_fe flg_solo_nc_cl_fe

*Reporte pre-filtro
di as text " "
di as text "==============================================================="
di as text "ESTADO PRE-FILTRO — red completa de operaciones electrónicas"
di as text "==============================================================="
count
di as text "Distribución por rol antes del filtro al catastro primario:"
tab rol_fe, missing

*Filtrado al catastro primario (alineación con F05)
*El merge m:1 por ID restringe el perfil a los 797.161 contribuyentes del 
*catastro. Los sujetos fuera del catastro (RIMPE NP, sector público, RUCs 
*suspendidos, personas sin obligación de IVA, etc.) fueron necesarios para 
*calcular correctamente las métricas de red, pero no son sujetos del 
*análisis y se descartan en este punto.

merge m:1 ID using AF00_F01F03_seleccion1, keep(3) keepusing(ID) nogen

*Reporte post-filtro
di as text " "
di as text "==============================================================="
di as text "ESTADO POST-FILTRO — restringido al catastro primario"
di as text "==============================================================="
count
isid ID0 ID anio_emision

di as text "Distribución por rol en F04 dentro del catastro primario:"
tab rol_fe, missing

di as text "Casos borde 'solo NC' dentro del catastro:"
tab flg_solo_nc_em_fe
tab flg_solo_nc_cl_fe

di as text "Variables candidatas a clustering (post-limpieza):"
summ prop_gravado_fe prop_ventas_cf_fe hhi_clientes_fe ///
     prop_compras_grav_fe hhi_proveedores_fe, detail

di as text "Razones NC — pendientes de winsorización en integración:"
summ ratio_nc_fe ratio_nc_recibidas_fe, detail

di as text "Variables descriptivas de magnitud (caracterización post-cluster):"
summ tot_facturado_fe ventas_cf_fe ventas_ruc_fe ///
     n_clientes_ruc_fe n_clientes_cf_fe n_comprobantes_cf_fe ///
     tot_compras_fe n_proveedores_fe, detail

note: Proporciones y HHI recortadas a [0,1] para corregir contaminación por facturas con monto negativo.
note: Razones ratio_nc_fe y ratio_nc_recibidas_fe NO winsorizadas — diferido a la integración del dataset analítico final.
note: Marcas de rol (flg_*_fe, rol_fe) identifican el papel del contribuyente en operaciones electrónicas 2024.
note: Archivo filtrado al catastro primario AF00_F01F03_seleccion1 — alineación con el patrón de F05.
note: Las variables se calcularon sobre la red completa de operaciones electrónicas ANTES del filtro, preservando la validez de HHI, conteos y proporciones.

compress
save AF04_perfil_contribuyente, replace

log close
 
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@