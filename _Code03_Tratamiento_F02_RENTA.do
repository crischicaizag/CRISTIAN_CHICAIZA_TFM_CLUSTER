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
log using "Log05_F02_Renta_codebook.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Procesamiento de la fuente de impuesto a la renta 2020-2025
  FUENTES    : F02_F102_20202025.txt  (renta personas naturales)
               F02_F101_20202025.txt  (renta sociedades)
               AF00_F01F03_seleccion1  (catastro de selección 797.161)
               F00_RUC_auxiliar         (perfil RUC + flag obligado contabilidad)
  SALIDA     : F02_RENTA.dta                 (base unificada limpia)
               AF02_perfil_contribuyente.dta  (perfil colapsado a nivel ID)
  LOGS       : Log05_F02_Renta_codebook.txt
               Log06_F02_construccion_analiticas.txt
*******************************************************************************/

*0 CONFIGURACIÓN DEL ENTORNO
*===============================================================================
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

*1 PREPROCESAMIENTO FUENTE F02: Renta Personas Naturales F102
*===============================================================================

import delimited "F02_F102_20202025.txt", varnames(1) stringcols(_all) clear
dis "Número de registros inicial F102:"
dis "========================================================================"
count

* 1.1 Filtro con catastro primario
*------------------------------------------------------------------------------
ren numero_identificacion ID0
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) keepusing(ID) nogen

* 1.2 Transformación de variables numéricas
*------------------------------------------------------------------------------
destring caja_bancos_160 tot_act_corriente_410 total_activo_830 ///
tot_pasivo_corriente_1030 tot_pasivo_largo_plazo_1250 ingresos_aem_rie_1280 ///
 deducciones_aem_rie_1290 total_pasivo_1310 tot_patrimonio_neto_1330 ///
 vne_grv_tce_1360 exportaciones_netas_1370 total_ingresos_1440 ///
 total_costos_gastos_2760 utilidad_neta_ejercicio_2800 perdida_ejercicio_2810 ///
 gto_no_deducible_locales_2850 gto_no_deducible_exterior_2860 ///
 gto_generar_ing_exentos_2870 utilidad_gravable_2970 perdida_2980 ///
 base_imponible_3480 imp_renta_causado_3490 anio_fiscal_1 vne_grv_tdc_1350 ///
 sub_ing_rgr_tyc_srd_3200 sub_gto_ded_tyc_srd_3210 rfn_qlr_eje_fiscal_3510 ///
 tot_activo_no_corriente_812 subtotal_imp_apa_3562 subtotal_sal_favor_3564 ///
 ing_obt_comision_sim_1371 ing_agro_sil_efo_1373 , replace dpcomma

recode caja_bancos_160 tot_act_corriente_410 total_activo_830 ///
tot_pasivo_corriente_1030 tot_pasivo_largo_plazo_1250 ingresos_aem_rie_1280 ///
 deducciones_aem_rie_1290 total_pasivo_1310 tot_patrimonio_neto_1330 ///
 vne_grv_tce_1360 exportaciones_netas_1370 total_ingresos_1440 ///
 total_costos_gastos_2760 utilidad_neta_ejercicio_2800 perdida_ejercicio_2810 ///
 gto_no_deducible_locales_2850 gto_no_deducible_exterior_2860 ///
 gto_generar_ing_exentos_2870 utilidad_gravable_2970 perdida_2980 ///
 base_imponible_3480 imp_renta_causado_3490 anio_fiscal_1 vne_grv_tdc_1350 ///
 sub_ing_rgr_tyc_srd_3200 sub_gto_ded_tyc_srd_3210 rfn_qlr_eje_fiscal_3510 ///
 tot_activo_no_corriente_812 subtotal_imp_apa_3562 subtotal_sal_favor_3564 ///
 ing_obt_comision_sim_1371 ing_agro_sil_efo_1373 (.=0)

* 1.3  Construcción de variables primarias
gen A_efectivo          = caja_bancos_160
gen A_activocorriente   = tot_act_corriente_410
gen A_activonocorriente = tot_activo_no_corriente_812
gen A_activototal       = total_activo_830
gen P_pasivocorriente   = tot_pasivo_corriente_1030
gen P_pasiconocorriente = tot_pasivo_largo_plazo_1250
gen P_pasivototal       = total_pasivo_1310
gen P_patrimonio        = tot_patrimonio_neto_1330

egen I_ingresos = rowtotal(total_ingresos_1440 sub_ing_rgr_tyc_srd_3200)
egen I_ingresosordi = rowtotal(vne_grv_tdc_1350 vne_grv_tce_1360 ///
                          exportaciones_netas_1370 ing_obt_comision_sim_1371 ///
                               ing_agro_sil_efo_1373 ingresos_aem_rie_1280)
egen G_costosgastos = rowtotal(total_costos_gastos_2760 sub_gto_ded_tyc_srd_3210)

gen R_utilidadejercicio = utilidad_neta_ejercicio_2800 + ///
                  max(sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210, 0)
gen R_peridaejercicio = perdida_ejercicio_2810 + ///
                abs(min(sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210, 0))

egen CT_gastonodeducibles = rowtotal(gto_no_deducible_locales_2850 ///
                   gto_no_deducible_exterior_2860 gto_generar_ing_exentos_2870)

gen RT_utilidadgravable = utilidad_gravable_2970 + ///
                    max(sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210, 0)
gen RT_perdidatributaria = perdida_2980 + ///
                abs(min(sub_ing_rgr_tyc_srd_3200 - sub_gto_ded_tyc_srd_3210, 0))

gen T_Baseimponible = base_imponible_3480
gen T_IRC           = imp_renta_causado_3490
gen T_Retenciones   = rfn_qlr_eje_fiscal_3510
gen T_Saldopagar    = subtotal_imp_apa_3562
gen T_Saldofavor    = subtotal_sal_favor_3564

* 1.4  Depuración: declaraciones de sociedades que declaran mal como PN
*------------------------------------------------------------------------------

merge m:1 ID using F00_RUC_auxiliar, keep(3) keepusing(codigo_opera_area) nogen
qui count
local antes_filtro = r(N)
keep if substr(codigo_opera_area,1,1) == "1"
qui count
local despues_filtro = r(N)
di "F102: Declaracione de sociedades que declaran mal como personas naturales: " ///
   %12.0fc `antes_filtro' - `despues_filtro'

gen tipo_declara = "PN"
keep ID0 ID tipo_declara anio_fiscal A_* P_* I_* G_* R_* CT_* RT_* T_*

dis "Número de registros final F102:"
dis "========================================================================"
count

tempfile F02_F102
save "`F02_F102'", replace

*2 PREPROCESAMIENTO FUENTE F02: Renta Sociedades F101
*==============================================================================

import delimited "F02_F101_20202025.txt", varnames(1) stringcols(_all) clear
dis "Número de registros inicial F101:"
dis "========================================================================"
count

* 2.1 Filtro con catastro primario
*-------------------------------------------------------------------------------
ren numero_identificacion ID0
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) keepusing(ID) nogen

* 2.2 Transformación de variables numéricas
*-------------------------------------------------------------------------------
destring caja_bancos_170 total_activo_corriente_470 ///
total_activos_largo_plazo_1070 total_activo_1080 tot_pasivos_corrientes_1340 ///
total_pasivos_largo_plazo_1590 total_pasivos_1620 capital_suscrito_asignado_1630 ///
 csu_no_pagado_ate_1640 aso_afu_1650 total_patrimonio_neto_1780 ///
 total_ingresos_1930 totas_costos_gastos_3380 utilidad_ejercicio_3420 ///
 perdida_ejercicio_3430 gto_no_deducibles_loc_3470 gto_no_deducibles_exr_3480 ///
 gto_generar_ing_exentos_3490 utilidad_gravable_3560 perdida_3570 ///
 impuesto_renta_causado_3600 ret_fuente_eje_fiscal_3620 ///
 subtotal_imp_apa_3662 subtotal_sal_favor_3664 ingreso_act_ext_1816, replace dpcomma

recode caja_bancos_170 total_activo_corriente_470 ///
total_activos_largo_plazo_1070 total_activo_1080 tot_pasivos_corrientes_1340 ///
total_pasivos_largo_plazo_1590 total_pasivos_1620 capital_suscrito_asignado_1630 ///
 csu_no_pagado_ate_1640 aso_afu_1650 total_patrimonio_neto_1780 ///
 total_ingresos_1930 totas_costos_gastos_3380 utilidad_ejercicio_3420 ///
 perdida_ejercicio_3430 gto_no_deducibles_loc_3470 gto_no_deducibles_exr_3480 ///
 gto_generar_ing_exentos_3490 utilidad_gravable_3560 perdida_3570 ///
 impuesto_renta_causado_3600 ret_fuente_eje_fiscal_3620 ///
 subtotal_imp_apa_3662 subtotal_sal_favor_3664 ingreso_act_ext_1816 (.=0)

 * 2.3 Construccion de variables agregadas
*-------------------------------------------------------------------------------
gen A_efectivo          = caja_bancos_170
gen A_activocorriente   = total_activo_corriente_470
gen A_activonocorriente = total_activos_largo_plazo_1070
gen A_activototal       = total_activo_1080
gen P_pasivocorriente   = tot_pasivos_corrientes_1340
gen P_pasiconocorriente = total_pasivos_largo_plazo_1590
gen P_pasivototal       = total_pasivos_1620
gen P_patrimonio        = total_patrimonio_neto_1780

egen I_ingresos     = rowtotal(total_ingresos_1930)
egen I_ingresosordi = rowtotal(ingreso_act_ext_1816)
egen G_costosgastos = rowtotal(totas_costos_gastos_3380)

gen R_utilidadejercicio = utilidad_ejercicio_3420
gen R_peridaejercicio   = perdida_ejercicio_3430

egen CT_gastonodeducibles = rowtotal(gto_no_deducibles_loc_3470 ///
                       gto_no_deducibles_exr_3480 gto_generar_ing_exentos_3490)

gen RT_utilidadgravable  = utilidad_gravable_3560
gen RT_perdidatributaria = perdida_3570

gen T_Baseimponible = RT_utilidadgravable
gen T_IRC           = impuesto_renta_causado_3600
gen T_Retenciones   = ret_fuente_eje_fiscal_3620
gen T_Saldopagar    = subtotal_imp_apa_3662
gen T_Saldofavor    = subtotal_sal_favor_3664

* 2.4 Depuración: declaraciones de PN que declaran mal como sociedades
*-------------------------------------------------------------------------------
merge m:1 ID using F00_RUC_auxiliar, keep(3) keepusing(codigo_opera_area) nogen
qui count
local antes_filtro = r(N)
keep if substr(codigo_opera_area,1,1) == "2"
qui count
local despues_filtro = r(N)
di "F101: Declaraciones de personas que declaran mal como sociedades: " ///
   %12.0fc `antes_filtro' - `despues_filtro'

gen tipo_declara = "SD"
keep ID0 ID tipo_declara anio_fiscal A_* P_* I_* G_* R_* CT_* RT_* T_*

dis "Número de registros final F101:"
dis "========================================================================"
count

tempfile F02_F101
save "`F02_F101'", replace

*3 UNIFICACIÓN Y DESCARTE FORMAL DE VARIABLES POCO REPRESENTATIVAS
*==============================================================================

use "`F02_F102'", clear
append using "`F02_F101'"
* 3.1. Estdísticos exploratios rápidos
*-------------------------------------------------------------------------------

codebook, compact

* 3.2. DECISIÓN METODOLÓGICA — DESCARTE EXPLÍCITO (CRISP-DM, Data Preparation):
*------------------------------------------------------------------------------
* Las siguientes variables se eliminan del perfil F02 con base en su nula
* aportación al modelo de clustering y su redundancia con variables retenidas:
*
*   A_efectivo (82,4% ceros)          - redundante con A_activototal
*   A_activonocorriente (95,0% ceros) - concentración extrema, sin uso en ratios
*   P_pasiconocorriente (92,8% ceros) - concentración extrema, sin uso en ratios
*   I_ingresosordi (42,7% ceros)      - definición heterogénea F101 vs F102
*   CT_gastonodeducibles (93,8% ceros)- concentración extrema, sin uso en ratios
*   T_Saldofavor (54,8% ceros)        - información ya recogida por gap_ret_ir
*
* T_Saldopagar se conserva hasta la sección 5.2 para construir flag binario
* antes de su descarte.
* R_peridaejercicio y RT_perdidatributaria continuas se conservan hasta la
* sección 5.3 para construir sus respectivos flags binarios.

drop A_efectivo A_activonocorriente P_pasiconocorriente ///
     I_ingresosordi CT_gastonodeducibles T_Saldofavor

save F02_RENTA, replace

*4 CODEBOOK EXPLORATORIO F02 — sobre conjunto ya depurado
*-------------------------------------------------------------------------------
use "F02_RENTA.dta", clear

di "============================================================"
di "ESTRUCTURA GENERAL"
di "============================================================"
describe
di "Total observaciones: " %12.0fc _N
bysort ID: gen n_decl = _N
bysort ID: keep if _n == 1
di "Contribuyentes únicos: " %12.0fc _N

use "F02_RENTA.dta", clear

di "============================================================"
di "VARIABLES CATEGÓRICAS Y DE CONTROL"
di "============================================================"

foreach v of varlist anio_fiscal tipo_declara {
    di _newline "--- `v' ---"
    tab `v', missing
}

di _newline "--- Declaraciones por año ---"
tab anio_fiscal

di "============================================================"
di "VARIABLES NUMÉRICAS - ESTADÍSTICAS ESENCIALES"
di "Columnas: N_validos | %_missing | %_cero | %_negativo"
di "          min | p25 | p50 | p75 | p99 | max | media"
di "============================================================"

unab vars_num : A_activocorriente - T_Saldopagar
local excluir ID

foreach v of varlist `vars_num' {
    if `: list v in excluir' continue

    cap quietly {
        count if missing(`v')
        local n_miss   = r(N)
        local pct_miss = round(`n_miss' / _N * 100, 0.01)

        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)

        count if !missing(`v')
        local n_val = r(N)
        local pct_cero = cond(`n_val'>0, round(`n_cero'/`n_val'*100, 0.01), .)

        count if `v' < 0 & !missing(`v')
        local n_neg = r(N)
        local pct_neg = cond(`n_val'>0, round(`n_neg'/`n_val'*100, 0.01), .)

        summarize `v', detail
        local vmin = r(min)
        local vp25 = r(p25)
        local vp50 = r(p50)
        local vp75 = r(p75)
        local vp99 = r(p99)
        local vmax = r(max)
        local vmean = round(r(mean), 0.01)
    }

    di _newline "=== `v' ==="
    di "  N válidos: `n_val'  |  Missing: `n_miss' (`pct_miss'%)" ///
       "  |  Ceros: `n_cero' (`pct_cero'%)" ///
       "  |  Negativos: `n_neg' (`pct_neg'%)"
    di "  min=`vmin'  p25=`vp25'  p50=`vp50'" ///
       "  p75=`vp75'  p99=`vp99'  max=`vmax'  media=`vmean'"
}

di "============================================================"
di "ALERTAS - VARIABLES CON > 80% CEROS"
di "============================================================"
foreach v of varlist `vars_num' {
    if `: list v in excluir' continue
    cap quietly {
        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)
        count if !missing(`v')
        local n_val = r(N)
        local pct = cond(`n_val'>0, `n_cero'/`n_val'*100, 0)
    }
    if `pct' > 80 {
        di "  ALTA CONCENTRACIÓN DE CEROS: `v' (`pct'%)"
    }
}

di "============================================================"
di "ALERTAS - VARIABLES CON VALORES NEGATIVOS"
di "============================================================"
foreach v of varlist `vars_num' {
    if `: list v in excluir' continue
    cap quietly count if `v' < 0 & !missing(`v')
    if r(N) > 0 {
        di "  NEGATIVOS: `v'  N=`r(N)'"
    }
}
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close
log using "Log06_F02_construccion_analiticas.txt", text replace

* 5. CONSTRUCCIÓN DE VARIABLES ANALÍTICAS
*==============================================================================

clear all
set more off, permanently
set type double, permanently

*5.0 CARGAR BASE UNIFICADA F102+F101
*---------------------------------------------------------------
use "F02_RENTA.dta", clear

cap confirm string variable anio_fiscal
if !_rc destring anio_fiscal, replace

*5.1 INCORPORAR FLAG OBLIGADO A LLEVAR CONTABILIDAD DESDE F03
*---------------------------------------------------------------
* DECISIÓN METODOLÓGICA (CRISP-DM, Data Preparation):
*   La concentración 81-95% de ceros en las variables de balance
*   no es problema de calidad: corresponde a contribuyentes no
*   obligados a llevar contabilidad, que no declaran balance.
*   La distinción es estructural y se gestiona con el flag
*   `obligado` proveniente del RUC (F03).
merge m:1 ID using AF03_perfil_contribuyente, ///
    keepusing(flag_obligado_contab) keep(1 3) nogen

gen byte obligado = (flag_obligado_contab == 1)
drop flag_obligado_contab

* Verificación: % obligados vs % no-ceros en balance
qui count if A_activototal > 0 & !missing(A_activototal)
local pct_balance_pos = r(N) / _N * 100
qui count if obligado == 1
local pct_obligado = r(N) / _N * 100
di "Verificación cruzada:"
di "  % observaciones con A_activototal > 0:   `pct_balance_pos'%"
di "  % observaciones con obligado==1 (RUC):   `pct_obligado'%"
di "  Diferencia esperada por desfase temporal entre F02 y corte RUC."

*5.2 CORRECCIÓN DE OUTLIERS Y CONSTRUCCIÓN DE FLAG SALDO A PAGAR
*---------------------------------------------------------------
* 5.2.1 Negativos espurios (errores de digitación, baja frecuencia)
replace G_costosgastos = 0 if G_costosgastos < 0

* 5.2.2 Outlier extremo de costos / pérdida (~USD ≥ 1.000 millones)
*       Se identifica como error de captura. Umbral fijado en 1e9.
gen byte _outlier_costos = (G_costosgastos > 1e9)

* Auditoría informativa de outliers (no altera el umbral)
preserve
    keep if _outlier_costos == 1
    keep ID tipo_declara anio_fiscal I_ingresos G_costosgastos ///
         R_peridaejercicio RT_perdidatributaria
    gsort -G_costosgastos
    di _newline "=========================================="
    di "AUDITORÍA OUTLIERS G_costosgastos > 1e9"
    di "=========================================="
    qui count
    di "Total registros marcados: " %12.0fc r(N)
    local n_show = min(20, _N)
    list in 1/`n_show', sepby(tipo_declara) abbreviate(20)
    export delimited "audit_outliers_costos.csv", replace
restore

replace G_costosgastos       = . if _outlier_costos == 1
replace R_peridaejercicio    = . if _outlier_costos == 1
replace RT_perdidatributaria = . if _outlier_costos == 1

* 5.2.3 Winsorización al 99,5% por año en variables de ingresos/gastos
foreach v in I_ingresos G_costosgastos R_utilidadejercicio ///
             RT_utilidadgravable T_IRC T_Retenciones {
    bysort anio_fiscal: egen _p995 = pctile(`v'), p(99.5)
    replace `v' = _p995 if `v' > _p995 & !missing(`v')
    drop _p995
}

* 5.2.4 Patrimonio negativo: se conserva (insolvencia técnica legítima)
gen byte flag_patrimonio_negativo = (P_patrimonio < 0)

* 5.2.5 Flag de saldo a pagar antes de descartar la variable continua
gen byte flag_saldo_pagar_anio = (T_Saldopagar > 0) & !missing(T_Saldopagar)
drop T_Saldopagar

*5.3 CONSTRUCCIÓN DE RATIOS A NIVEL CONTRIBUYENTE-AÑO
*------------------------------------------------------------------------------
* Regla general: denominador <= 0 → missing. Evita división por
* cero y excluye años no operativos del promedio.

* 5.3.1 Bloque operativo y tributario — entran al clustering
gen margen_operativo   = R_utilidadejercicio / I_ingresos if I_ingresos > 0
gen costos_ingresos    = G_costosgastos      / I_ingresos if I_ingresos > 0
gen carga_efectiva_ir  = T_IRC / RT_utilidadgravable      if RT_utilidadgravable > 0
gen flag_perdida_trib  = (RT_perdidatributaria > 0) & !missing(RT_perdidatributaria)
gen flag_perdida_cont  = (R_peridaejercicio    > 0) & !missing(R_peridaejercicio)

* Ratio retenciones/IR robusto a IR=0
gen gap_ret_ir = (T_Retenciones - T_IRC) / max(T_IRC, T_Retenciones) ///
    if max(T_IRC, T_Retenciones) > 0

* Descarte de variables continuas de pérdida (ya capturadas como flags)
drop R_peridaejercicio RT_perdidatributaria

* 5.3.2 Bloque balance — solo caracterización post-clustering, condicional a 
* obligado
gen roa                = R_utilidadejercicio / A_activototal      if A_activototal > 0 & obligado == 1
gen endeudamiento      = P_pasivototal       / A_activototal      if A_activototal > 0 & obligado == 1
gen apalancamiento     = P_pasivototal       / P_patrimonio       if P_patrimonio  > 0 & obligado == 1
gen liquidez_corriente = A_activocorriente   / P_pasivocorriente  if P_pasivocorriente > 0 & obligado == 1
gen rotacion_activos   = I_ingresos          / A_activototal      if A_activototal > 0 & obligado == 1

* 5.3.3 Winsorización adicional de ratios (cola superior e inferior, p1-p99)
foreach r in margen_operativo costos_ingresos carga_efectiva_ir ///
             roa endeudamiento apalancamiento liquidez_corriente ///
             rotacion_activos {
    bysort anio_fiscal: egen _p99 = pctile(`r'), p(99)
    bysort anio_fiscal: egen _p01 = pctile(`r'), p(1)
    replace `r' = _p99 if `r' > _p99 & !missing(`r')
    replace `r' = _p01 if `r' < _p01 & !missing(`r')
    drop _p99 _p01
}

*5.4 COLAPSO A UNA FILA POR CONTRIBUYENTE
*---------------------------------------------------------------
* Diseño temporal: el dataset analítico final tiene un perfil
* por contribuyente. F02 (Renta) es anual y se resume con tres
* ventanas:
* Promedio del período 2020-2025 — comportamiento típico
* Último año disponible — estado actual
* Primer año — referencia para tendencia

* 5.4.1 Identificar primer y último año disponible por contribuyente
bysort ID: egen _anio_min = min(anio_fiscal)
bysort ID: egen _anio_max = max(anio_fiscal)
gen byte _es_ultimo  = (anio_fiscal == _anio_max)
gen byte _es_primero = (anio_fiscal == _anio_min)

* 5.4.2 Marcas para valores en primer y último año
foreach v in margen_operativo costos_ingresos carga_efectiva_ir ///
             I_ingresos T_IRC T_Retenciones RT_utilidadgravable {
    gen `v'_ultimo  = `v' if _es_ultimo  == 1
    gen `v'_primero = `v' if _es_primero == 1
}

* 5.4.3 Colapso (promedios sobre años con dato válido)
collapse ///
    (mean)   margen_operativo_avg    = margen_operativo ///
             costos_ingresos_avg     = costos_ingresos ///
             carga_efectiva_ir_avg   = carga_efectiva_ir ///
             gap_ret_ir_avg          = gap_ret_ir ///
             I_ingresos_avg          = I_ingresos ///
             T_IRC_avg               = T_IRC ///
             T_Retenciones_avg       = T_Retenciones ///
             RT_utilidadgravable_avg = RT_utilidadgravable ///
             T_Baseimponible_avg     = T_Baseimponible ///
             roa_avg                 = roa ///
             endeudamiento_avg       = endeudamiento ///
             apalancamiento_avg      = apalancamiento ///
             liquidez_avg            = liquidez_corriente ///
             rotacion_avg            = rotacion_activos ///
    (mean)   margen_ultimo           = margen_operativo_ultimo ///
             carga_ir_ultimo         = carga_efectiva_ir_ultimo ///
             ingresos_ultimo         = I_ingresos_ultimo ///
             irc_ultimo              = T_IRC_ultimo ///
             ugravable_ultimo        = RT_utilidadgravable_ultimo ///
    (mean)   margen_primero          = margen_operativo_primero ///
             ingresos_primero        = I_ingresos_primero ///
    (sum)    n_anios_perdida_trib    = flag_perdida_trib ///
             n_anios_perdida_cont    = flag_perdida_cont ///
             n_anios_saldo_pagar     = flag_saldo_pagar_anio ///
    (max)    flag_patrimonio_neg_alguno = flag_patrimonio_negativo ///
             outlier_costos          = _outlier_costos ///
    (count)  n_decl_renta            = anio_fiscal ///
    (first)  obligado tipo_declara ///
    (min)    anio_primero            = anio_fiscal ///
    (max)    anio_ultimo             = anio_fiscal ///
    , by(ID)

* 5.4.4 Indicadores derivados sobre el agregado
gen tendencia_ingresos = ingresos_ultimo - ingresos_primero ///
    if !missing(ingresos_ultimo) & !missing(ingresos_primero)
gen tendencia_margen   = margen_ultimo - margen_primero ///
    if !missing(margen_ultimo)  & !missing(margen_primero)
gen prop_anios_perdida = n_anios_perdida_trib / n_decl_renta
gen anios_cubiertos    = anio_ultimo - anio_primero + 1

* 5.4.5 Variables nuevas del perfil

* Tamaño económico absoluto en unidad original — entra al clustering.
* NOTA METODOLÓGICA: la transformación de escala (logarítmica, z-score,
* min-max u otra) se decide en la fase de EDA sobre el dataset analítico
* integrado completo, en Python, junto con el resto de decisiones de
* escala del proyecto. En esta etapa la variable se conserva en su
* unidad original (USD).

* Flag de saldo a pagar consolidado (sustituye a T_Saldopagar continua)
gen byte flag_irc_saldo_pagar = (n_anios_saldo_pagar > 0)

* Sub-flag de obligados sin balance positivo en ningún año
* (omisión parcial o sociedades inactivas dentro del grupo obligado)
gen byte flag_obligado_sin_balance = (obligado == 1 & missing(roa_avg))

* 5.4.6 Etiquetas
label var obligado                   "1 si obligado a llevar contabilidad (RUC)"
label var tipo_declara               "PN=persona natural, SD=sociedad"
label var n_decl_renta               "N° de declaraciones de renta en F02"
label var anios_cubiertos            "Años cubiertos por F02 (rango)"
label var margen_operativo_avg       "Promedio del margen operativo periodo"
label var carga_efectiva_ir_avg      "Promedio de la carga efectiva de IR"
label var prop_anios_perdida         "Proporción de años con pérdida tributaria"
label var flag_patrimonio_neg_alguno "1 si patrimonio negativo en algún año (obligados)"
label var outlier_costos             "1 si presentó outlier extremo de costos (revisión)"
label var flag_irc_saldo_pagar       "1 si tuvo saldo a pagar de IR en al menos un año"
label var flag_obligado_sin_balance  "1 si obligado a contabilidad sin balance positivo en periodo"
label var T_Baseimponible_avg        "Promedio de base imponible (caracterización)"
label var n_anios_saldo_pagar        "N° de años con saldo a pagar de IR"

*5.5 AUDITORÍA FINAL Y EXPORTACIÓN
*---------------------------------------------------------------
di "=========================================="
di "PERFIL F02 — RESUMEN FINAL"
di "=========================================="
di "Contribuyentes en perfil F02: " %12.0fc _N

qui count if obligado == 1
di "  Obligados a llevar contabilidad:    " %12.0fc r(N)
qui count if obligado == 0
di "  No obligados:                       " %12.0fc r(N)
qui count if tipo_declara == "SD"
di "  Sociedades (F101):                  " %12.0fc r(N)
qui count if tipo_declara == "PN"
di "  Personas naturales (F102):          " %12.0fc r(N)

di _newline "=========================================="
di "AUDITORÍA: consistencia tipo_declara x obligado"
di "=========================================="
tab tipo_declara obligado, missing

di _newline "Sub-grupos derivados:"
qui count if flag_obligado_sin_balance == 1
di "  Obligados sin balance positivo en periodo: " %12.0fc r(N)
qui count if flag_irc_saldo_pagar == 1
di "  Contribuyentes con saldo a pagar IR algún año: " %12.0fc r(N)
qui count if flag_patrimonio_neg_alguno == 1
di "  Contribuyentes con patrimonio negativo algún año: " %12.0fc r(N)
qui count if outlier_costos == 1
di "  Contribuyentes con outlier extremo de costos: " %12.0fc r(N)

di _newline "Cobertura de variables que entran al clustering:"
foreach v in I_ingresos_avg  margen_operativo_avg costos_ingresos_avg ///
             carga_efectiva_ir_avg gap_ret_ir_avg {
    qui count if !missing(`v')
    local pct = round(r(N) / _N * 100, 0.1)
    di "  `v': " %12.0fc r(N) "  (`pct'% del perfil F02)"
}

di _newline "Cobertura de variables de balance (caracterización):"
foreach v in roa_avg endeudamiento_avg apalancamiento_avg ///
             liquidez_avg rotacion_avg T_Baseimponible_avg {
    qui count if !missing(`v')
    local pct = round(r(N) / _N * 100, 0.1)
    di "  `v': " %12.0fc r(N) "  (`pct'% del perfil F02)"
}

*5.6 Guardar perfil 
save AF02_perfil_contribuyente, replace

*5.7 VERIFICACIONES DE CIERRE
*---------------------------------------------------------------

* 5.7.1 Estructura del perfil exportado
di _newline "=========================================="
di "ESTRUCTURA DEL PERFIL F02 EXPORTADO"
di "=========================================="
describe, fullnames

* 5.7.2 Cobertura efectiva (valor positivo, (no solo no-missing))
di _newline "=========================================="
di "COBERTURA EFECTIVA — VALORES POSITIVOS"
di "=========================================="
di "Diferencia entre cobertura no-missing y cobertura > 0:"
foreach v in I_ingresos_avg  margen_operativo_avg costos_ingresos_avg ///
             carga_efectiva_ir_avg gap_ret_ir_avg ///
             T_Baseimponible_avg T_IRC_avg T_Retenciones_avg ///
             RT_utilidadgravable_avg {
    qui count if !missing(`v')
    local n_nomiss = r(N)
    qui count if `v' > 0 & !missing(`v')
    local n_pos = r(N)
    local pct_nomiss = round(`n_nomiss' / _N * 100, 0.1)
    local pct_pos    = round(`n_pos'    / _N * 100, 0.1)
    di "  `v': no-missing=`pct_nomiss'%  |  positivo=`pct_pos'%"
}

* 5.7.3 Distribución del flag_obligado_sin_balance por tipo declarante
di _newline "=========================================="
di "OBLIGADOS SIN BALANCE POSITIVO POR TIPO DECLARANTE"
di "=========================================="
tab tipo_declara flag_obligado_sin_balance if obligado == 1, ///
    row missing

* 5.7.4 Outliers de costos: declaraciones vs contribuyentes
di _newline "Outliers de costos extremo:"
qui count if outlier_costos == 1
di "  Contribuyentes únicos afectados: " %12.0fc r(N)
di "  (corresponden a 38 declaraciones año-contribuyente"
di "   marcadas durante el preprocesamiento de F02_RENTA)"

* 5.7.5 Resumen ejecutivo de cierre
di _newline "=========================================="
di "RESUMEN EJECUTIVO DE CIERRE F02"
di "=========================================="
di "  Universo catastro:            797.161 contribuyentes"
qui count
di "  Contribuyentes en perfil F02: " %12.0fc r(N)
local fuera = 797161 - r(N)
di "  Contribuyentes sin F02:       " %12.0fc `fuera' ///
   "  (a flaggear como tiene_F02=0 en merge final)"
di "  Período cubierto:             2020 - 2025"
di "  Variables del perfil:         ver describe arriba"


log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@








