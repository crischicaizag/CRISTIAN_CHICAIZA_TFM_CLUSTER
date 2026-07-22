
cap log close
log using "Log15_Integracion_dataset_analitico.txt", text replace

/*==============================================================================
  PROYECTO   : TFM — Propuesta metodológica para la identificación y
               caracterización de patrones de resistencia fiscal en el IVA
               (caso ecuatoriano, período 2020–2025)
  MÁSTER     : Análisis y Visualización de Datos Masivos — UNIR
  AUTOR      : Cristian Edelberto Chicaiza Gualoto
  DIRECTOR   : Jesús Cigales Canga

  OBJETIVO   : Construir el dataset analítico final con una fila por
               contribuyente integrando las siete fuentes administrativas
               procesadas en los pasos previos (F01 a F07), partiendo del
               catastro primario AF00_F01F03_seleccion1 (797.161 RUCs).

  ENTRADAS   : AF00_F01F03_seleccion1.dta   (catastro base)
               AF01_perfil_analitico.dta    (792.750 obs, ~50 vars, escala original)
               AF02_perfil_contribuyente.dta (761.711 obs, 38 vars)
               AF03_perfil_contribuyente.dta (797.161 obs, 54 vars)
               AF04_perfil_contribuyente.dta (797.161 obs, 27 vars)
               AF05_perfil_contribuyente.dta (797.161 obs, 21 vars)
               AF06_perfil_contribuyente.dta (797.161 obs, 19 vars)
               AF07_perfil_contribuyente.dta (797.161 obs, 41 vars)

  SALIDA     : B00_DATASET_ANALITICO_INTEGRADO.dta
               Una fila por contribuyente del catastro (797.161 RUCs).

  LOG        : Log15_Integracion_dataset_analitico.txt

  CRITERIO   : El integrador hereda los perfiles tal como fueron entregados
               por cada fuente. No se recalcula ninguna variable analítica
               aquí — la winsorización, estandarización y construcción de
               ratios cruzados pertenecen al paso de preparación final para
               el clustering (_Code11).

  NOTA DE REVISIÓN : Versión corregida tras auditoría de coherencia entre
               do-files y logs actualizados. Cambios respecto al borrador
               previo: (1) todos los nombres de archivo de entrada se
               ajustan a la convención vigente con prefijo "A"; (2) el
               núcleo de clustering de F01 ya no lleva sufijo _z — F01 no
               estandariza en origen (decisión firme del proyecto), por lo
               que la imputación de faltantes se hace en escala original;
               (3) I_ingresos_avg y reca_total_f05 reemplazan a los nombres
               obsoletos log_ingresos_avg y log_reca_total_f05.
==============================================================================*/

clear all
set more off, permanently
set type double, permanently

*1. Punto de partida — catastro primario
*------------------------------------------------------------------------------
*El catastro define el universo exacto de 797.161 contribuyentes. Todos los
*merges siguientes se anclan a él vía 1:1 por ID. La estrategia es outer
*merge contra el catastro: cada fuente que no cubre los 797.161 contribuyentes
*aporta filas para los suyos y deja missing para el resto, missings que se
*resuelven inmediatamente con flags y reglas de imputación específicas.

use AF00_F01F03_seleccion1, clear
keep ID
duplicates drop ID, force
isid ID
count
di as txt "Universo de partida (catastro AF00): " %15.0fc r(N) " contribuyentes"

*2. Merge F01 — declaraciones IVA (perfil analítico, escala original)
*------------------------------------------------------------------------------
*F01 cubre 792.750 contribuyentes. De los 4.411 ausentes, 4.359 son
*formalmente activos sin movimiento económico real (todas las declaraciones
*en cero en las variables materiales de ventas y compras) y 52 quedaron
*fuera por saneamiento previo del catastro en la auditoría manual de
*outliers documentada en _code02. F01 no aplica transformaciones de
*escala en origen (decisión firme del proyecto), por lo
*que las variables llegan en su unidad original (USD, tasas en [0,1],
*conteos). El integrador les imputa cero en las 42 variables núcleo del
*clustering, decisión coherente con su naturaleza: "sin movimiento
*económico real" equivale a cero ventas, cero compras, cero IVA pagado,
*etc. en la escala original. Se activa la bandera flg_sin_perfil_f01.

merge 1:1 ID using AF01_perfil_analitico, ///
    keep(1 3) generate(_mF01)

gen byte flg_sin_perfil_f01 = (_mF01 == 1)
label var flg_sin_perfil_f01 ///
    "F01: 1 si contribuyente sin movimiento económico real en 2020–2025"

*Imputación de cero en las 42 variables núcleo de clustering (escala original)
local f01_zvars ///
    tot_v_grav_nta tot_v_grav_brt tot_imp_v_grav ///
    tot_v_tc_cdc tot_v_tc_sdc ///
    tot_c_grav_cdc_nta tot_imp_c_cdc tot_c_tc_iaf ///
    tot_crt_aplicable tot_iva_causado tot_iva_pagado ///
    tot_iva_total_pagar tot_ret_recibidas tot_multas_int ///
    tot_cve_emitidos tot_cve_anulados tot_cve_recibidos ///
    med_saldo_crt_acum med_v_grav_nta med_factor_prop ///
    ratio_imp_vtas_vtas ratio_crt_imp_cmp ratio_nc_ventas ///
    ratio_anul_emit ratio_pago_causado ratio_saldo_iva_vtas ///
    cv_v_grav_nta cv_c_grav_cdc_nta cv_iva_pagado cv_ret_recibidas ///
    n_anos_con_vtas n_anos_con_exp_tc_cdc n_anos_con_compras ///
    n_anos_con_retenedor n_anos_con_iva_pagado n_meses_cubiertos ///
    pct_decl_cero pct_decl_sustitutiva pct_decl_con_mora ///
    pct_decl_anul_alta pct_decl_nc_alta pct_decl_saldo_pos

foreach v of local f01_zvars {
    replace `v' = 0 if missing(`v') & flg_sin_perfil_f01 == 1
}

drop _mF01
di as txt "Merge F01 completado. Faltantes imputados: " ///
    "ver flg_sin_perfil_f01."
tab flg_sin_perfil_f01, missing

*3. Merge F02 — Impuesto a la Renta
*------------------------------------------------------------------------------
*F02 cubre 761.711 contribuyentes. Los ausentes son contribuyentes sin
*declaración de renta en 2020–2025. Tratamiento asimétrico por naturaleza
*de variable: cero para conteos (n_decl_renta, n_anios_*) y flags; missing
*para ratios y promedios monetarios donde el cero significaría algo distinto
*("declaró pero con valor cero" vs "no declaró").

merge 1:1 ID using AF02_perfil_contribuyente, keep(1 3) generate(_mF02)

gen byte flg_sin_perfil_f02 = (_mF02 == 1)
label var flg_sin_perfil_f02 ///
    "F02: 1 si contribuyente sin declaración de renta 2020–2025"

*Imputación cero para conteos y flags
foreach v of varlist n_decl_renta n_anios_perdida_trib n_anios_perdida_cont ///
                     n_anios_saldo_pagar anios_cubiertos ///
                     flag_irc_saldo_pagar flag_obligado_sin_balance ///
                     flag_patrimonio_neg_alguno outlier_costos {
    replace `v' = 0 if missing(`v') & flg_sin_perfil_f02 == 1
}

*La variable obligado queda como missing donde no hay declaración — el flag
*flg_sin_perfil_f02 captura la condición; mantener obligado=. evita inflar
*artificialmente el grupo "no obligados".

*Ratios y promedios monetarios quedan missing — son indefinidos sin
*declaración base, no son ceros.

drop _mF02
di as txt "Merge F02 completado. Faltantes: " %15.0fc 797161 - 761711 ///
    " contribuyentes sin declaración de renta."
tab flg_sin_perfil_f02, missing

*4. Merge F03 — RUC y establecimientos
*------------------------------------------------------------------------------
*F03 tiene cardinalidad exacta 797.161 (coincidencia perfecta con catastro).
*El merge es 1:1 sin faltantes esperados. Cualquier desviación es error.

merge 1:1 ID using AF03_perfil_contribuyente, keep(1 3) generate(_mF03)

qui count if _mF03 == 1
if r(N) > 0 {
    di as error "ERROR INTEGRIDAD: " r(N) " contribuyentes del catastro sin perfil F03."
    di as error "                  Revisar consistencia entre catastros."
}

drop _mF03
di as txt "Merge F03 completado sin faltantes esperados."

*5. Merge F04 — facturación electrónica
*------------------------------------------------------------------------------
*F04 tiene cardinalidad 797.161 después del filtro al catastro aplicado en
*origen. Se eliminan dos variables auxiliares: ID0 (string RUC original,
*reintroduce información identificable y duplica ID) y anio_emision
*(constante = 2024 tras filtro al catastro).

*Lectura selectiva — descartar variables auxiliares en el merge
preserve
    use AF04_perfil_contribuyente, clear
    cap drop ID0
    cap drop anio_emision
    tempfile f04_clean
    save `f04_clean'
restore

merge 1:1 ID using `f04_clean', keep(1 3) generate(_mF04)

qui count if _mF04 == 1
if r(N) > 0 {
    di as error "ERROR INTEGRIDAD: " r(N) " contribuyentes del catastro sin perfil F04."
}

drop _mF04
di as txt "Merge F04 completado. Variables ID0 y anio_emision descartadas."

*6. Merge F05 — recaudación
*------------------------------------------------------------------------------
*F05 tiene cardinalidad 797.161 (outer merge contra catastro ya aplicado
*en origen). La bandera flag_sin_recaudacion_f05 está construida.

merge 1:1 ID using AF05_perfil_contribuyente, keep(1 3) generate(_mF05)

qui count if _mF05 == 1
if r(N) > 0 {
    di as error "ERROR INTEGRIDAD: " r(N) " contribuyentes del catastro sin perfil F05."
}

drop _mF05
di as txt "Merge F05 completado."

*7. Merge F06 — cumplimiento de obligaciones
*------------------------------------------------------------------------------
*F06 tiene cardinalidad exacta 797.161 (validación cruzada confirmada en
*origen). Merge 1:1 sin faltantes esperados.

merge 1:1 ID using AF06_perfil_contribuyente, keep(1 3) generate(_mF06)

qui count if _mF06 == 1
if r(N) > 0 {
    di as error "ERROR INTEGRIDAD: " r(N) " contribuyentes del catastro sin perfil F06."
}

drop _mF06
di as txt "Merge F06 completado."

*8. Merge F07 — retenciones
*------------------------------------------------------------------------------
*F07 tiene cardinalidad 797.161 (outer merge contra catastro aplicado en
*origen). Las banderas flg_es_retenedor y flg_es_retenido ya distinguen
*contribuyentes con y sin participación efectiva en F07. Conteos y montos
*ya están imputados a cero para los ausentes; las tasas y proporciones
*quedan en missing donde no hay denominador.

merge 1:1 ID using AF07_perfil_contribuyente, keep(1 3) generate(_mF07)

qui count if _mF07 == 1
if r(N) > 0 {
    di as error "ERROR INTEGRIDAD: " r(N) " contribuyentes del catastro sin perfil F07."
}

drop _mF07
di as txt "Merge F07 completado."

*9. Reordenamiento final — núcleo de clustering primero, caracterización después
*------------------------------------------------------------------------------
*Estructura: ID, banderas de presencia por fuente, núcleo clustering (las
*42 variables de F01 en escala original + núcleo numérico de F02 a F07),
*caracterización post-clustering, estratificación, fechas, strings
*categóricos.

order ID                                                                     ///
      flg_sin_perfil_f01 flg_sin_perfil_f02                                    ///
      flag_sin_recaudacion_f05 flg_es_retenedor flg_es_retenido                ///
      flg_emisor_fe flg_cliente_ruc_fe flg_solo_nc_em_fe flg_solo_nc_cl_fe rol_fe ///
      `f01_zvars'                                                              ///
      I_ingresos_avg margen_operativo_avg costos_ingresos_avg                  ///
      carga_efectiva_ir_avg gap_ret_ir_avg prop_anios_perdida                  ///
      flag_irc_saldo_pagar flag_obligado_sin_balance flag_patrimonio_neg_alguno ///
      outlier_costos obligado                                                  ///
      antig_actividad n_establ_total tasa_cierre_establ                        ///
      n_cierres_24m n_aperturas_24m n_provincias_distintas                     ///
      n_actividades_unicas_ruc n_secciones_ciiu                                ///
      prop_gravado_fe ratio_nc_fe prop_ventas_cf_fe hhi_clientes_fe            ///
      prop_compras_grav_fe ratio_nc_recibidas_fe hhi_proveedores_fe            ///
      reca_total_f05 prop_efectivo_f05 prop_pagos_tardios_f05                  ///
      rezago_medio_f05 cv_reca_mensual_f05 hhi_reca_f05                        ///
      tasa_omision tasa_tardio promedio_dias_demora p90_dias_demora            ///
      n_lin_iva_agr n_contrap_iva_agr n_meses_iva_agr                          ///
      base_iva_agr ret_iva_agr tasa_efe_iva_agr                                ///
      p_t10_agr p_t20_agr p_t30_agr p_t50_agr p_t70_agr p_t100_agr             ///
      hhi_iva_agr prop_ruc_iva_agr prop_cat_iva_agr                            ///
      n_lin_iva_ard n_contrap_iva_ard n_meses_iva_ard                          ///
      base_iva_ard ret_iva_ard tasa_efe_iva_ard                                ///
      p_t10_ard p_t20_ard p_t30_ard p_t50_ard p_t70_ard p_t100_ard             ///
      hhi_iva_ard prop_cat_iva_ard

*10. Reporte de completitud — cobertura conjunta del dataset
*------------------------------------------------------------------------------
di _newline(2) "================================================================"
di "REPORTE DE COMPLETITUD POR FUENTE Y CRUCE"
di "================================================================"

qui count
di "Total contribuyentes en dataset integrado: " %15.0fc r(N)

di _newline "Cobertura individual por fuente:"
qui count if flg_sin_perfil_f01 == 0
di "  F01 (con perfil IVA):              " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flg_sin_perfil_f02 == 0
di "  F02 (con perfil renta):            " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flag_sin_recaudacion_f05 == 0
di "  F05 (con recaudación efectiva):    " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flg_es_retenido == 1
di "  F07 (como agente retenido):        " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flg_es_retenedor == 1
di "  F07 (como agente de retención):    " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flg_emisor_fe == 1
di "  F04 (como emisor electrónico):     " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"
qui count if flg_cliente_ruc_fe == 1
di "  F04 (como cliente con RUC):        " %15.0fc r(N) "  " ///
   %5.2f r(N)/797161*100 "%"

di _newline "Cobertura conjunta (intersecciones clave):"
qui count if flg_sin_perfil_f01 == 0 & flg_sin_perfil_f02 == 0
di "  F01 ∩ F02:                         " %15.0fc r(N)
qui count if flg_sin_perfil_f01 == 0 & flg_sin_perfil_f02 == 0 & ///
             flag_sin_recaudacion_f05 == 0
di "  F01 ∩ F02 ∩ F05:                   " %15.0fc r(N)
qui count if flg_sin_perfil_f01 == 0 & flg_sin_perfil_f02 == 0 & ///
             flag_sin_recaudacion_f05 == 0 & flg_es_retenido == 1
di "  F01 ∩ F02 ∩ F05 ∩ F07_ard:         " %15.0fc r(N)
qui count if flg_sin_perfil_f01 == 0 & flg_sin_perfil_f02 == 0 & ///
             flag_sin_recaudacion_f05 == 0 & ///
             (flg_es_retenido == 1 | flg_es_retenedor == 1)
di "  F01 ∩ F02 ∩ F05 ∩ F07 (cualquier rol): " %15.0fc r(N)
qui count if flg_sin_perfil_f01 == 0 & flg_sin_perfil_f02 == 0 & ///
             flag_sin_recaudacion_f05 == 0 & ///
             (flg_es_retenido == 1 | flg_es_retenedor == 1) & ///
             (flg_emisor_fe == 1 | flg_cliente_ruc_fe == 1)
di "  Las siete fuentes con participación efectiva: " %15.0fc r(N)

*11. Auditoría de integridad — claves y unicidad
*------------------------------------------------------------------------------
di _newline(2) "================================================================"
di "AUDITORÍA DE INTEGRIDAD"
di "================================================================"

isid ID
di "  Unicidad de ID:                     OK"

qui count
local n_obs = r(N)
qui describe, varlist
local n_vars = r(k)
di "  N obs:                              " %15.0fc `n_obs'
di "  N variables:                        " %15.0fc `n_vars'

*Verificación de ausencia de _merge residuales (paranoia metodológica)
cap ds _merge* _m*, has(type numeric)
if _rc == 0 & "`r(varlist)'" != "" {
    di as error "  ADVERTENCIA: variables _merge residuales detectadas — se eliminan."
    drop `r(varlist)'
}
else {
    di "  OK: sin variables _merge residuales."
}

*12. Guardado final
*------------------------------------------------------------------------------
compress
save B00_DATASET_ANALITICO_INTEGRADO, replace

di _newline(2) "================================================================"
di "INTEGRACIÓN COMPLETADA"
di "================================================================"
di "Archivo: B00_DATASET_ANALITICO_INTEGRADO.dta"
di "Próximo paso: _Code09 — preparación para clustering (winsorización"
di "de ratios pendientes, construcción de variables cruzadas F05×F01,"
di "estandarización homogénea, eliminación de variables redundantes)."

log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

clear all
set more off
cap log close
log using "Log16_EDA_para_decisiones.txt", text replace
use B00_DATASET_ANALITICO_INTEGRADO, clear

*Descriptivos brevess
describe, short

*===========================================================================
* _Code10_EDA_para_decisiones.do
* Genera las estadísticas necesarias para cerrar las decisiones del
* formulario de _Code11. No modifica el dataset integrado.
*===========================================================================

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 2 — Quiénes son los 35.450 sin F02"
di "================================================================"
preserve
    keep if flg_sin_perfil_f02 == 1
    di "Total: " _N
    tab tipo_contrib, missing
    tab flag_rimpe, missing
    tab estado_ruc, missing
    tab flag_sociedad flag_persona_natural, missing
restore

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 3 — Quiénes son los 291.983 sin recaudación F05"
di "================================================================"
preserve
    keep if flag_sin_recaudacion_f05 == 1
    di "Total: " _N
    tab tipo_contrib, missing
    tab flag_rimpe, missing
    tab estado_ruc, missing
    di _newline "Cruce con tasa_omision F06:"
    summ tasa_omision, detail
    di _newline "Distribución por tramos de omisión:"
    gen byte _tramo = .
    replace _tramo = 0 if tasa_omision == 0
    replace _tramo = 1 if tasa_omision > 0   & tasa_omision <= 0.10
    replace _tramo = 2 if tasa_omision > 0.10 & tasa_omision <= 0.30
    replace _tramo = 3 if tasa_omision > 0.30 & tasa_omision <= 0.50
    replace _tramo = 4 if tasa_omision > 0.50 & !missing(tasa_omision)
    tab _tramo, missing
restore

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 5 — Cobertura de cruces interfuente candidatos"
di "================================================================"
* F05 × F01: denominador es tot_iva_total_pagar de F01
di _newline "F05×F01: cobertura para construir ratio_pago_global"
count if !missing(tot_iva_total_pagar) & tot_iva_total_pagar > 0
di "  Contribuyentes con denominador F01 válido: " r(N)

* F04 × F01: denominadores son tot_v_grav_brt y tot_c_grav_cdc_nta
di _newline "F04×F01: cobertura para ratios coherencia"
count if !missing(tot_v_grav_brt) & tot_v_grav_brt > 0 & !missing(tot_facturado_fe)
di "  Con ventas declaradas F01 y facturado F04: " r(N)
count if !missing(tot_c_grav_cdc_nta) & tot_c_grav_cdc_nta > 0 & !missing(tot_compras_fe)
di "  Con compras declaradas F01 y compras F04: " r(N)

* F07 × F01: denominador es tot_ret_recibidas de F01
di _newline "F07×F01: cobertura"
count if !missing(tot_ret_recibidas) & tot_ret_recibidas > 0 & flg_es_retenido == 1
di "  Con retenciones recibidas F01 y registradas F07: " r(N)

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 6 — Winsorización ratios F04"
di "================================================================"
foreach v of varlist ratio_nc_fe ratio_nc_recibidas_fe {
    di _newline "Percentiles de `v':"
    _pctile `v' if !missing(`v'), p(50 75 90 95 99 99.5 99.9)
    di "  P50:   " %12.4f r(r1)
    di "  P75:   " %12.4f r(r2)
    di "  P90:   " %12.4f r(r3)
    di "  P95:   " %12.4f r(r4)
    di "  P99:   " %12.4f r(r5)
    di "  P99.5: " %12.4f r(r6)
    di "  P99.9: " %12.4f r(r7)
    quietly summ `v', detail
    di "  Máx:   " %12.4f r(max)
}

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 7 — Asimetría de variables candidatas a estandarizar"
di "================================================================"
local var_no_f01 ///
    I_ingresos_avg margen_operativo_avg costos_ingresos_avg ///
    carga_efectiva_ir_avg gap_ret_ir_avg prop_anios_perdida ///
    antig_actividad n_establ_total tasa_cierre_establ ///
    n_cierres_24m n_aperturas_24m n_provincias_distintas ///
    n_actividades_unicas_ruc n_secciones_ciiu ///
    prop_gravado_fe prop_ventas_cf_fe hhi_clientes_fe ///
    prop_compras_grav_fe hhi_proveedores_fe ///
    reca_total_f05 prop_efectivo_f05 prop_pagos_tardios_f05 ///
    rezago_medio_f05 cv_reca_mensual_f05 hhi_reca_f05 ///
    tasa_omision tasa_tardio promedio_dias_demora p90_dias_demora ///
    tasa_efe_iva_agr tasa_efe_iva_ard hhi_iva_agr hhi_iva_ard

di "Variable               N     Skewness     Kurtosis"
di "------------------------------------------------"
foreach v of local var_no_f01 {
    cap quietly summ `v', detail
    if _rc == 0 {
        di %-22s "`v'" %12.0fc r(N) "  " %10.3f r(skewness) "  " %10.3f r(kurtosis)
    }
}

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 8 — Cardinalidad y frecuencias de categóricas"
di "================================================================"
foreach v of varlist tipo_contrib subtipo_contrib estado_ruc ///
                     ciiu_seccion ciiu_2dig_ruc region_matriz ///
                     tipo_declara {
    di _newline "Variable: `v'"
    cap tab `v', missing sort
}

di _newline(2) "================================================================"
di "EDA PARA DECISIÓN 9 — Correlaciones para confirmar redundancia"
di "================================================================"

di _newline "F05 — proporciones:"
pwcorr prop_efectivo_f05 prop_compensa_f05 prop_nc_f05, sig

di _newline "F06 — conteos vs tasas:"
pwcorr tasa_omision n_periodos_omisos n_periodos_no_omisos, sig
pwcorr tasa_omision_reciente n_omisos_recientes n_no_omisos_recientes, sig

di _newline "F04 — totales vs proporciones:"
pwcorr tot_facturado_fe tot_gravado_fe tot_cero_fe prop_gravado_fe, sig
pwcorr tot_compras_fe tot_compras_grav_fe tot_compras_cero_fe prop_compras_grav_fe, sig

log close