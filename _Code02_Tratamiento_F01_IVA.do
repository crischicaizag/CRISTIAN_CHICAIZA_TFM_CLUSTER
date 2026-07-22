
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
log using "Log03_F01_F104_Codebook0.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Procesamiento inicial de la fuente F01 — Formulario 104
               (declaraciones mensuales/semestrales del IVA). 
  FUENTES    : F01 — F01_F104*.txt   (declaraciones de IVA, 2020–2025)

  SALIDA     : Inicial: F01_01F104seleccion1.dta, F01_03F104_imputado.dta
			   F01_catastro_outliers_exclusion_M
               Logs: Log03_F01_F104_Codebook0.txt
*******************************************************************************/

* 0. CONFIGURACION DEL ENTORNO
*===============================================================================

clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* 1. PROCESAMIENTO INICIAL DE LA FUENTE F01 — F104 DECLARACIONES DE IVA 2020–2025
*===============================================================================
*    Bases anuales en formato plano, delimitadas por tabulador
/*
* 1.1. Lectura y conversión de tipos
*------------------------------------------------------------------------------
* Se recorre el conjunto de archivos planos anuales f01_f104*.txt y se
* importa cada uno como cadenas (stringcols(_all)). Posteriormente, sobre
* el listado de casilleros numéricos del formulario 104 (varlist `v')
* se aplica destring con la opción dpcomma — necesaria porque el
* separador decimal en los archivos fuente es la coma. La variable ID0 
* es estandarizar el nombre del identificador del contribuyente a lo largo 
* del pipeline. Cada archivo
* anual queda guardado como t0f01_f104*.dta para su uso posterior.

clear
local txt : dir . files "f01_f104*.txt"
foreach x of local txt {
    dis "`x'"
    import delimited "`x'", varnames(1) stringcols(_all) clear

    local v vlb_eaf_tdc_450	vln_eaf_tdc_460	imp_vln_eaf_tdc_470	///
	tot_vln_eaf_tdc_480	vt_bru_afj_tdc_510	vt_nta_afj_tdc_520	///
	imp_vt_nta_afj_tdc_530	vlb_sdc_eaf_tce_570	vln_sdc_eaf_tce_580	///
	vt_bru_afj_sdc_eaf_tce_610	vt_nta_afj_sdc_tce_620	vlb_cdc_eaf_tce_670	///
	vln_cdc_eaf_tce_680	vt_bru_afj_cdc_tce_700	vt_nta_afj_cdc_tce_710	///
	tot_vt_exp_bru_iaf_860	tot_vt_exp_nta_iaf_tcd_870	tot_imp_vt_iaf_tdc_880 ///	
	vt_bru_no_objeto_iva_1038	vt_nta_no_objeto_iva_1040	///
	ncr_vt_nta_pcm_msi_tce_1050	ncr_vt_nta_pcm_msi_tdc_1070	///
	inc_vt_nta_pcm_msi_tdc_1080	ing_bru_rdg_itm_1098	ing_nto_rdg_itm_1100 ///
	imp_ing_nto_prg_tdc_1110	tot_vnt_mac_iaf_tdc_1200	///
	tot_vnr_mac_iaf_tdc_1210	tot_imp_vt_eip_iaf_1220	imp_vnl_man_iaf_1230 ///
	imp_vnl_mac_iaf_1240	imp_vnl_msi_iaf_1250	tot_imp_vnl_mac_iaf_1260 ///
	clb_bys_cdc_eaf_tdc_1270	cln_bys_cdc_eaf_tdc_1280	///
	icl_nta_bys_cdc_eaf_tdc_1290	clb_afj_cdc_tdc_1390 ///
	cln_afj_cdc_tdc_1400	icl_nta_afj_cdc_tdc_1410 ///
	ocl_bru_bys_sdc_eaf_tdc_1470	ioc_nta_sdc_eaf_tdc_1480 ///
	cln_bos_sdc_eaf_tdc_1550	clb_iaf_tce_1720	cln_bys_iaf_tce_1730 ///
	clb_rise_1735	cln_rise_1740	tot_bru_com_iaf_tcd_1780 ///
	tot_cle_nta_iaf_tcd_1790	imp_clo_ipr_nta_1800	clb_no_objeto_iva_1818 ///
	cln_no_objeto_iva_1820	adquisiciones_bru_exi_1823	adquisiciones_exi_1825 ///
	ncr_cln_pcm_msi_tce_1830	ncr_cln_pcm_msi_tdc_1900 ///
	imp_ncr_cln_pcm_msi_tdc_1910	pgb_prg_itm_tcd_1978	pgn_prg_itm_tcd_1980 ///
	imp_pgn_prg_itm_tcd_1990	fap_crt_tdf_2110	crt_acu_fap_2130 ///
	impuesto_causado_2140	credito_tributario_mac_2150	saldo_crt_cle_man_2160 ///
	saldo_crt_rfu_man_2170	rfu_mes_actual_2200	aju_idr_pc_ipt_crt_mac_2210	 ///
	ajuste_idv_ipt_crt_mac_2215	saldo_crt_clo_ipr_msi_2220	saldo_crt_rfu_msi_2230 ///
	subtotal_apa_aip_2250	iva_prs_sja_tdc_2260	tot_imp_apa_percepcion_2270 ///
	pago_previo_2570	det_imputacion_impuesto_2580	det_imputacion_intereses_2590 ///
	det_impuesti_multa_2600	pago_directo_tna_2605	total_impuesto_a_pagar_2610 ///
	interes_por_mora_2620	multas_2630	total_pagado_2640	vpa_che_dba_efe_ufp_2650 ///
	valor_a_pagar_mdn_cps_2660	valor_a_pagar_mdn_ncr_2670	numero_nota_credito_1_2680 ///
	valor_nota_credito_1_2690	numero_nota_credito_2_2700	valor_nota_credito_2_2710 ///
	numero_nota_credito_3_2720	valor_nota_credito_3_2730	valor_nota_credito_4_2750 ///
	num_resolucion_cps_1_2760	valor_resolucion_cps_1_2770	numero_resolucion_cps_2_2780 ///
	valor_resolucion_cps_2_2790	ruc_contador_2810	aju_idr_pc_ipt_crt_mac_rf_2212 ///
	tbc_2845	med_tbc_2850	tot_imp_vt_eip_iaf_tdc_890	tot_cve_emitidos_252 ///
	tot_cve_anulados_254	tot_cve_recibidos_aen_256	tot_nvr_258	tot_lce_trr_260	 ///
	exp_brutas_bienes_790	exportaciones_netas_bienes_800	exp_brutas_servicios_810 ///
	exp_netas_servicios_820	ipr_bru_bie_eaf_tdc_1552	ipr_nta_bie_eaf_tdc_1554 ///
	imp_ipr_nta_bie_eaf_tdc_1556	ipr_bru_bie_tdc_1600	ipr_nta_bie_tdc_1610 ///
	imp_ipr_nta_bie_tdc_1620	ipr_bru_afj_tdc_1640	ipr_nta_afj_tdc_1650 ///
	imp_ipr_nta_afj_tdc_1660	ipr_bru_bie_iaf_tce_1700	ipr_nta_bie_iaf_tce_1710 ///
	retencion_iva_10_2515	retencion_iva_30_2520	retencion_iva_20_2525 ///
	retencion_iva_70_2530	retencion_iva_100_2540	tot_iva_retenido_2550 ///
	dev_pro_iva_com_ret_efe_2555	tot_iva_a_pagar_2560	tot_iap_ret_2565 ///
	iva_gen_dif_adq_nc_2860	comp_iva_vet_med_elec_2870	comp_iva_vet_zon_soli_2880 ///
	comp_iva_medio_elec_2890	comp_iva_zona_soli_2900	ajust_iva_dev_adq_med_ele_2910 ///
	ajust_iva_dev_adq_zon_sol_2920	com_iva_vent_med_elec_2930	///
	com_iva_vent_zon_soli_2940	iva_gen_dif_adq_nc_2950	iva_gen_dif_adq_nc_an_2865 ///
	iva_gen_dif_adq_nc_af_2955	retencion_iva_50_2960	imp_mat_prim_bien_exp_2970 ///
	isd_imp_mat_prim_bien_exp_2980	porcent_div_relac_exp_2990 ///
	pag_dif_iva_2019_eme_san_2601	cuota_1_pag_dif_iva_2602 ///
	cuota_2_pag_dif_iva_2603	cuota_3_pag_dif_iva_2604	cuota_4_pag_dif_iva_2606 ///
	cuota_5_pag_dif_iva_2607	cuota_6_pag_dif_iva_2608	dev_iva_com_ret_efe_sp_3555 ///
	tarifa_variable_91	vlb_eaf_tvar_451	vln_eaf_tvar_461	imp_vln_eaf_tvar_471 ///
	clb_bys_cdc_eaf_tvar_1271	cln_bys_cdc_eaf_tdc_1281	icl_nta_bys_cdc_eaf_tdc_1291 ///
	iva_dev_gru_prio_2951	pag_serv_digi_3020	mes_pago_vtas_cred_1251	tamano_copci_1252 ///
	vlb_eaf_t5_452	vln_eaf_t5_462	imp_vln_eaf_t5_472	vtas_cln_b_t5_1253	///
	clb_b_cdc_eaf_t5_1261	cln_b_cdc_eaf_t5_1262	icl_nta_bi_cdc_eaf_t5_1263	/// 
	aplica_remision_1	pro_dep_no_res_1273	prg_ctr_prc_fus_abs_1274	/// 
	crt_prc_fus_abs_1275	fap_no_crt_1276	crt_acu_gdd_ir_1277	///
	crt_acu_gdd_ir_1278	crt_ajt_pres_1279

    * Conversión 
    cap destring `v', replace dpcomma
    cap ren numero_identificacion ID0
    save "t0`x'.dta", replace
}
*/

* 2. UNIFICACION DE LAS BASES ANUALES F104
*===============================================================================
* Se apilan las bases anuales (2020–2025) en una sola y se filtra dejando
* únicamente los contribuyentes presentes en AF00_F01F03_seleccion1 mediante un
* merge m:1 con keep(3) (solo registros con pareo).
*
* A continuación se realizan tres tareas de saneamiento:
**Se eliminan en una sola instrucción las variables de control
* administrativo no relevantes para el análisis (fecha de
* recaudación, claves y numeraciones de formulario).
**Se recodifica el campo sustitutiva_original a una letra (O/S).
**Se descompone el período fiscal en mes_desde / mes_hasta y se
* convierte fecha_recepcion a formato de fecha de Stata (%td)
* bajo el nombre fecharecepcion, eliminando los campos originales.
*
* El resultado de esta fase es F01_01F104seleccion1.dta, la base de
* trabajo de declaraciones de IVA filtrada y normalizada que alimenta
* los pasos siguientes del pipeline analítico.

clear
local dta4 : dir . files "t0f01_f104*.dta"
append using `dta4'
dis "Número de registros inciales antes de cruces: "
dis "======================================================================="
count
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen

dis "Número de registros luego de cruce con catastro primario: "
dis "======================================================================="
count

gen mes_desde = substr(periodo_fiscal_desde,5,2)
gen mes_hasta = substr(periodo_fiscal_hasta,5,2)
merge m:1 ID0 mes_desde mes_hasta anio_fiscal using F00_CUMPLIMIENTO_ID, keep(3) nogen

dis "Número de registros luego de cruce con catastro y con obligación real F06: "
dis "======================================================================="
count

* Eliminación de variables administrativas no relevantes — consolidado.
drop fecha_recaudacion contribuyente_pk codigo_formulario ///
     numero_formulario numero_secuencial numero_adhesivo ///
     numero_formulario_sustituye

* Recodificación de sustitutiva_original a un carácter.
replace sustitutiva_original = cond(sustitutiva_original == "ORIGINAL", "O", ///
                                cond(sustitutiva_original == "SUSTITUTIVA", "S", sustitutiva_original))

* Descomposición del período fiscal y conversión de fecha_recepcion.
order mes_desde mes_hasta, after(periodo_fiscal_hasta)
drop periodo_fiscal_desde periodo_fiscal_hasta
replace fecha_recepcion = substr(fecha_recepcion,1,10)
gen fecharecepcion = date(fecha_recepcion, "YMD")
format fecharecepcion %td
order fecharecepcion, after(fecha_recepcion)
drop fecha_recepcion
save F01_01F104seleccion1, replace

*3. PROCESAMIENTO PREVIO A ESTADISTICAS Y ANTES DE AUDITORIA MANUAL DE OUTLIERS
*===============================================================================
clear all
set more off , permanently
set type double , permanently

*3.0. Carga
*-------------------------------------------------------------------------------
use "F01_01F104seleccion1.dta", clear

*3.1. Verificación fecha de recepción
*-------------------------------------------------------------------------------
* fecharecepcion entró como double con formato %td en el log previo;
* dofc convierte de datetime a fecha calendaria; si ya es fecha,
* la fórmula es inocua y reconforma el formato.
capture confirm variable fecharecepcion
if !_rc {
    quietly summarize fecharecepcion, meanonly
    * Si la mediana de los valores excede el rango plausible de fechas
    * (> 22 000 ≈ año 2020 en %td), asumimos que está en %tc.
    if r(mean) > 1e9 {
        gen double fecha_decl = dofc(fecharecepcion)
    }
    else {
        gen double fecha_decl = fecharecepcion
    }
    format fecha_decl %td
    label var fecha_decl "Fecha de recepción de la declaración (solo fecha)"
}

*3.2. Verificación tipo de declaración 
*-------------------------------------------------------------------------------
* Si es semestral o el mensual

gen byte tipo_decl = .
replace tipo_decl = 1 if mes_desde == mes_hasta
replace tipo_decl = 2 if (mes_desde == "01" & mes_hasta == "06") | ///
                          (mes_desde == "07" & mes_hasta == "12")
label define tipoLBL 1 "Mensual" 2 "Semestral"
label values tipo_decl tipoLBL
label var tipo_decl "Tipo declaración (1=Mensual, 2=Semestral)"

*3.3. Normalización de missings en variables post 2024
*-------------------------------------------------------------------------------
* Las variables de tarifa variable (451/461/471, 1271/1281/1291) y
* tarifa 5 % (452/462/472, 1261/1262/1263) son missing por estructura
* en las declaraciones previas a su entrada en vigencia. Para que las
* sumas no se propaguen como missing, se imputan a cero.
local post2024 vlb_eaf_tvar_451 vln_eaf_tvar_461 imp_vln_eaf_tvar_471 ///
               clb_bys_cdc_eaf_tvar_1271 cln_bys_cdc_eaf_tdc_1281 ///
               icl_nta_bys_cdc_eaf_tdc_1291 ///
               vlb_eaf_t5_452 vln_eaf_t5_462 imp_vln_eaf_t5_472 ///
               clb_b_cdc_eaf_t5_1261 cln_b_cdc_eaf_t5_1262 ///
               icl_nta_bi_cdc_eaf_t5_1263

foreach v of local post2024 {
    capture confirm variable `v'
    if !_rc replace `v' = 0 if missing(`v')
}

* 3.4. Agregaciones del bloque del formulario sobre ventas
*-------------------------------------------------------------------------------
* EL detalle de ventas está muy desagregado, requiere agregación a nivel de
* columnas

gen double agr_v_grav_brt = vlb_eaf_tdc_450 + vt_bru_afj_tdc_510 + ///
                            vlb_eaf_tvar_451 + vlb_eaf_t5_452
gen double agr_v_grav_nta = vln_eaf_tdc_460 + vt_nta_afj_tdc_520 + ///
                            vln_eaf_tvar_461 + vln_eaf_t5_462
gen double agr_imp_v_grav = imp_vln_eaf_tdc_470 + imp_vt_nta_afj_tdc_530 + ///
                            imp_vln_eaf_tvar_471 + imp_vln_eaf_t5_472
gen double agr_v_tc_cdc   = vln_cdc_eaf_tce_680 + vt_nta_afj_cdc_tce_710 + ///
                            exportaciones_netas_bienes_800 + exp_netas_servicios_820
gen double agr_v_tc_sdc   = vln_sdc_eaf_tce_580 + vt_nta_afj_sdc_tce_620
gen double agr_v_no_obj   = vt_nta_no_objeto_iva_1040
gen double agr_imp_iva_vtas_per = tot_imp_vnl_mac_iaf_1260

label var agr_v_grav_brt        "Ventas gravadas brutas (todas tarifas, incluye AF)"
label var agr_v_grav_nta        "Ventas gravadas netas (todas tarifas, incluye AF)"
label var agr_imp_v_grav        "IVA generado en ventas gravadas"
label var agr_v_tc_cdc          "Ventas tarifa 0% con derecho a crédito + exportaciones"
label var agr_v_tc_sdc          "Ventas tarifa 0% sin derecho a crédito"
label var agr_v_no_obj          "Ventas no objeto / exentas de IVA"
label var agr_imp_iva_vtas_per  "IVA ventas a liquidar mes actual (concepto 1260)"

*3.5. Agregaciones del bloque de adquisiciones (compras) 
*-------------------------------------------------------------------------------
* Similar al bloque de ventas, se agrupan columnas

gen double agr_c_grav_cdc_nta = cln_bys_cdc_eaf_tdc_1280 + cln_afj_cdc_tdc_1400 + ///
                                cln_bys_cdc_eaf_tdc_1281 + cln_b_cdc_eaf_t5_1262 + ///
                                ipr_nta_bie_eaf_tdc_1554 + ipr_nta_bie_tdc_1610 + ///
                                ipr_nta_afj_tdc_1650
gen double agr_imp_c_cdc = icl_nta_bys_cdc_eaf_tdc_1290 + icl_nta_afj_cdc_tdc_1410 + ///
                           icl_nta_bys_cdc_eaf_tdc_1291 + icl_nta_bi_cdc_eaf_t5_1263 + ///
                           imp_ipr_nta_bie_eaf_tdc_1556 + imp_ipr_nta_bie_tdc_1620 + ///
                           imp_ipr_nta_afj_tdc_1660
gen double agr_c_grav_sdc_nta = cln_bos_sdc_eaf_tdc_1550
gen double agr_c_tc_iaf       = cln_bys_iaf_tce_1730
gen double agr_c_rimpe        = cln_rise_1740
gen double agr_factor_prop    = fap_crt_tdf_2110
gen double agr_crt_aplicable  = crt_acu_fap_2130

label var agr_c_grav_cdc_nta "Compras gravadas netas con derecho a crédito (todas tarifas)"
label var agr_imp_c_cdc      "IVA en compras con derecho a crédito (potencial)"
label var agr_c_grav_sdc_nta "Compras gravadas sin derecho a crédito"
label var agr_c_tc_iaf       "Compras tarifa 0% (incluye activos fijos)"
label var agr_c_rimpe        "Compras a contribuyentes RIMPE / RISE"
label var agr_factor_prop    "Factor de proporcionalidad (concepto 2110)"
label var agr_crt_aplicable  "Crédito tributario aplicable (concepto 2130)"

* 3.6. Agregaciones bloque liquidación percepción
*-------------------------------------------------------------------------------
gen double agr_iva_causado     = impuesto_causado_2140
gen double agr_crt_mes         = credito_tributario_mac_2150
gen double agr_saldo_crt_acum  = saldo_crt_clo_ipr_msi_2220 + saldo_crt_rfu_msi_2230
gen double agr_ret_recibidas   = rfu_mes_actual_2200
gen double agr_iva_pagar_perc  = tot_imp_apa_percepcion_2270

label var agr_iva_causado     "Impuesto causado (concepto 2140)"
label var agr_crt_mes         "Crédito tributario mes actual (concepto 2150)"
label var agr_saldo_crt_acum  "Saldo CT trasladable al siguiente periodo (2220+2230)"
label var agr_ret_recibidas   "Retenciones IVA recibidas mes actual (2200)"
label var agr_iva_pagar_perc  "Total a pagar como agente de percepción (2270)"

*3.7. Agregaciones bloque retención y pago
*-------------------------------------------------------------------------------
gen double agr_ret_efectuadas  = tot_iva_retenido_2550
gen double agr_iva_total_pagar = tot_iva_a_pagar_2560
gen double agr_iva_pagado      = total_pagado_2640
gen double agr_multas_int      = multas_2630 + interes_por_mora_2620

label var agr_ret_efectuadas   "Retenciones IVA practicadas como agente (2550)"
label var agr_iva_total_pagar  "IVA total a pagar consolidado (2560)"
label var agr_iva_pagado       "Total pagado (2640)"
label var agr_multas_int       "Multas + intereses por mora (2630+2620)"

* 3.8. Agregaciones bloque operacional
*-------------------------------------------------------------------------------
gen double agr_cve_emitidos  = tot_cve_emitidos_252
gen double agr_cve_anulados  = tot_cve_anulados_254
gen double agr_cve_recibidos = tot_cve_recibidos_aen_256

label var agr_cve_emitidos   "Comprobantes de venta emitidos (252)"
label var agr_cve_anulados   "Comprobantes de venta anulados (254)"
label var agr_cve_recibidos  "Comprobantes recibidos por adquisiciones (256)"

* 3.8b. FLAGS PARA CRUCE POSTERIOR CON F07 (RETENCIONES) 
* Estos indicadores no entran al modelo de clustering — sirven para
* trazabilidad en la validación cruzada contra el catastro F07.
gen byte flg_ret_recibidas = (agr_ret_recibidas > 0 & !missing(agr_ret_recibidas))
gen byte flg_ret_efectuadas = (agr_ret_efectuadas > 0 & !missing(agr_ret_efectuadas))

label var flg_ret_recibidas  "Declaración con retención recibida > 0 (cruce F07 informado)"
label var flg_ret_efectuadas "Declaración con retención efectuada > 0 (cruce F07 informante)"

* 3.9. Lista maestra de agregados 
*-------------------------------------------------------------------------------
local agregados ///
    agr_v_grav_brt agr_v_grav_nta agr_imp_v_grav ///
    agr_v_tc_cdc agr_v_tc_sdc agr_v_no_obj agr_imp_iva_vtas_per ///
    agr_c_grav_cdc_nta agr_imp_c_cdc agr_c_grav_sdc_nta ///
    agr_c_tc_iaf agr_c_rimpe agr_factor_prop agr_crt_aplicable ///
    agr_iva_causado agr_crt_mes agr_saldo_crt_acum ///
    agr_ret_recibidas agr_iva_pagar_perc ///
    agr_ret_efectuadas agr_iva_total_pagar agr_iva_pagado agr_multas_int ///
    agr_cve_emitidos agr_cve_anulados agr_cve_recibidos

* 3.10. Controles y categorías
*-------------------------------------------------------------------------------
di "============================================================"
di "VARIABLES CATEGÓRICAS Y DE CONTROL"
di "============================================================"

foreach v of varlist tipo_decl anio_fiscal mes_fiscal ///
                     sustitutiva_original declaracion_cero ///
                     aplica_remision {
    di _newline "--- `v' ---"
    tab `v', missing
}

* 3.11. Codebook esencial sobre agregados 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "VARIABLES AGREGADAS - ESTADÍSTICAS ESENCIALES"
di "Columnas: N_validos | %_missing | %_cero | %_negativo"
di "          min | p25 | p50 | p75 | p99 | max | media"
di "============================================================"

foreach v of local agregados {
    cap quietly {
        count if missing(`v')
        local n_miss   = r(N)
        local pct_miss = round(`n_miss'/_N*100, 0.01)

        count if `v' == 0 & !missing(`v')
        local n_cero   = r(N)
        count if !missing(`v')
        local n_val    = r(N)
        local pct_cero = cond(`n_val' > 0, round(`n_cero'/`n_val'*100, 0.01), .)

        count if `v' < 0 & !missing(`v')
        local n_neg    = r(N)
        local pct_neg  = cond(`n_val' > 0, round(`n_neg'/`n_val'*100, 0.01), .)

        summarize `v', detail
        local vmin  = r(min)
        local vp25  = r(p25)
        local vp50  = r(p50)
        local vp75  = r(p75)
        local vp99  = r(p99)
        local vmax  = r(max)
        local vmean = round(r(mean), 0.01)
    }
    di _newline "=== `v' ==="
    di "  N válidos: `n_val'  |  Missing: `n_miss' (`pct_miss'%)" ///
       "  |  Ceros: `n_cero' (`pct_cero'%)" ///
       "  |  Negativos: `n_neg' (`pct_neg'%)"
    di "  min=`vmin'  p25=`vp25'  p50=`vp50'" ///
       "  p75=`vp75'  p99=`vp99'  max=`vmax'  media=`vmean'"
}

* 3.12. ALERTAS — >80% CEROS
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS - AGREGADOS CON >80% CEROS"
di "(Candidatos a descarte o transformación binaria)"
di "============================================================"

foreach v of local agregados {
    cap quietly {
        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)
        count if !missing(`v')
        local n_val  = r(N)
        local pct    = cond(`n_val' > 0, `n_cero'/`n_val'*100, 0)
    }
    if `pct' > 80 {
        di "  ALTA CONCENTRACIÓN DE CEROS: `v' (" %5.2f `pct' "%)"
    }
}

* 3.13. ALERTAS — VALORES NEGATIVOS 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS - AGREGADOS CON VALORES NEGATIVOS"
di "============================================================"

foreach v of local agregados {
    cap quietly count if `v' < 0 & !missing(`v')
    if r(N) > 0 {
        di "  NEGATIVOS: `v'  N=" r(N)
    }
}

* 3.14. ALERTAS ESPECÍFICAS - FOCOS DE RIESGO 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS ESPECÍFICAS - FOCOS DE RIESGO FISCAL"
di "============================================================"

* (a) Factor de proporcionalidad fuera de rango plausible [0,1]
quietly count if agr_factor_prop > 1 & !missing(agr_factor_prop)
di "  Factor proporcionalidad > 1 (anómalo): N=" r(N)
quietly count if agr_factor_prop < 0 & !missing(agr_factor_prop)
di "  Factor proporcionalidad < 0 (imposible): N=" r(N)

* (b) Saldo CT acumulado sistemático (señal de subdeclaración estructural)
quietly count if agr_saldo_crt_acum > 0 & !missing(agr_saldo_crt_acum)
di "  Declaraciones con saldo CT positivo trasladable: N=" r(N)

* (c) Ratio anulaciones / emitidos elevado
gen double tmp_ratio_anul = cond(agr_cve_emitidos > 0, ///
                                 agr_cve_anulados/agr_cve_emitidos, .)
quietly count if tmp_ratio_anul > 0.20 & !missing(tmp_ratio_anul)
di "  Declaraciones con ratio anulación > 20%: N=" r(N)
drop tmp_ratio_anul

* (d) Diferencia bruto-neto > 10 % (uso intensivo de notas de crédito)
gen double tmp_dif_bn = cond(agr_v_grav_brt > 0, ///
                             (agr_v_grav_brt - agr_v_grav_nta)/agr_v_grav_brt, .)
quietly count if tmp_dif_bn > 0.10 & !missing(tmp_dif_bn)
di "  Declaraciones con NC > 10% sobre ventas brutas: N=" r(N)
drop tmp_dif_bn

* (e) Universos candidatos al cruce con F07
quietly count if flg_ret_recibidas == 1
di "  Declaraciones con retención recibida (cruce F07 como informado): N=" r(N)
quietly count if flg_ret_efectuadas == 1
di "  Declaraciones con retención efectuada (cruce F07 como informante): N=" r(N)

* 3.15. GUARDADO 
*-------------------------------------------------------------------------------
* Conserva variables crudas + agregadas + controles
save "F01_02F104_con_agregados.dta", replace

*4. AUDITORIA MANUAL DE OUTLIERS
*===============================================================================
/*******************************************************************************
 Propósito:
 Identificar y exportar los registros candidatos a auditoría manual
 en las variables crudas con valores fuera de rango plausible.
 El resultado es un conjunto de CSV con los IDs, periodo fiscal,
 fecha, marca de sustitutiva y declaración cero, y el valor extremo
 observado en la variable problemática.
 Insumo: F01_02F104_con_agregados.dta
*******************************************************************************/
/*
clear all
set more off, permanently
set type double, permanently

*Variables anómalas detectadas en sección anterior
use F01_01F104seleccion1, clear
 /*variables problemáticas
         vlb_eaf_tdc_450 ///
		 cln_bys_cdc_eaf_tdc_1280 ///
         cln_bys_iaf_tce_1730 ///
		 rfu_mes_actual_2200 ///
         tot_cve_emitidos_252 ///
		 tot_cve_anulados_254 ///
         tot_cve_recibidos_aen_256 ///
		 fap_crt_tdf_2110 */

gsort - vlb_eaf_tdc_450  // 52 casos marcados en var193
gsort -	cln_bys_cdc_eaf_tdc_1280   // 5939116
gsort - cln_bys_iaf_tce_1730 // 1143306 
gsort - rfu_mes_actual_2200  // 6 casos marcados en var193
gsort -  tot_cve_emitidos_252 // no tratados 
gsort - tot_cve_anulados_254  // no tratados
gsort -  tot_cve_recibidos_aen_256  // no tratados
gsort - fap_crt_tdf_2110   // casos mayores a 28, error de rtegistro 

keep if var193!=. | inlist(ID, 5939116 , 1143306, 1429880, 2048361, 157924, 1047421, 3154098,4945650)
keep ID
duplicates drop
*58 casos que se excluiran de manera tranversal, se guarda como archivo trabajo
save F01_catastro_outliers_exclusion_M, replace 
*/

*5. PROCESAMIENTO PREVIO A ESTADISTICAS LIBRE DE AUDITORIA MANUAL DE OUTLIERS
*===========================================================================
clear all
set more off

* 5.0. CARGA
*-------------------------------------------------------------------------------
use "F01_01F104seleccion1.dta", clear

* 5.1. ELIMINACION DE ATIPICOS Y CORRECION DE FACTOR DE PROPORCIONALIDAD
*-------------------------------------------------------------------------------
dis "Número de registros antes de atípicos :"
dis "===================================================================="
count
merge m:1 ID using F01_catastro_outliers_exclusion_M, keep(1) nogen
dis "Número de registros despues de atípicos :"
dis "===================================================================="
count
replace fap_crt_tdf_2110 = 1 if fap_crt_tdf_2110>1 //28 casos 

* 5.2. TIPO DE DECLARACIÓN 
*-------------------------------------------------------------------------------
gen byte tipo_decl = .
replace tipo_decl = 1 if mes_desde == mes_hasta
replace tipo_decl = 2 if (mes_desde == "01" & mes_hasta == "06") | ///
                          (mes_desde == "07" & mes_hasta == "12")
label define tipoLBL 1 "Mensual" 2 "Semestral"
label values tipo_decl tipoLBL
label var tipo_decl "Tipo declaración (1=Mensual, 2=Semestral)"


* 5.3. NORMALIZACIÓN DE MISSINGS EN VARIABLES POST-2024 
*-------------------------------------------------------------------------------
* Las variables de tarifa variable (451/461/471, 1271/1281/1291) y
* tarifa 5 % (452/462/472, 1261/1262/1263) son missing por estructura
* en las declaraciones previas a su entrada en vigencia. Para que las
* sumas no se propaguen como missing, se imputan a cero.
local post2024 vlb_eaf_tvar_451 vln_eaf_tvar_461 imp_vln_eaf_tvar_471 ///
               clb_bys_cdc_eaf_tvar_1271 cln_bys_cdc_eaf_tdc_1281 ///
               icl_nta_bys_cdc_eaf_tdc_1291 ///
               vlb_eaf_t5_452 vln_eaf_t5_462 imp_vln_eaf_t5_472 ///
               clb_b_cdc_eaf_t5_1261 cln_b_cdc_eaf_t5_1262 ///
               icl_nta_bi_cdc_eaf_t5_1263

foreach v of local post2024 {
    capture confirm variable `v'
    if !_rc replace `v' = 0 if missing(`v')
}

* 5.4. AGREGACIONES — BLOQUE VENTAS 
*-------------------------------------------------------------------------------
gen double agr_v_grav_brt = vlb_eaf_tdc_450 + vt_bru_afj_tdc_510 + ///
                            vlb_eaf_tvar_451 + vlb_eaf_t5_452
gen double agr_v_grav_nta = vln_eaf_tdc_460 + vt_nta_afj_tdc_520 + ///
                            vln_eaf_tvar_461 + vln_eaf_t5_462
gen double agr_imp_v_grav = imp_vln_eaf_tdc_470 + imp_vt_nta_afj_tdc_530 + ///
                            imp_vln_eaf_tvar_471 + imp_vln_eaf_t5_472
gen double agr_v_tc_cdc   = vln_cdc_eaf_tce_680 + vt_nta_afj_cdc_tce_710 + ///
                            exportaciones_netas_bienes_800 + exp_netas_servicios_820
gen double agr_v_tc_sdc   = vln_sdc_eaf_tce_580 + vt_nta_afj_sdc_tce_620
gen double agr_v_no_obj   = vt_nta_no_objeto_iva_1040
gen double agr_imp_iva_vtas_per = tot_imp_vnl_mac_iaf_1260

label var agr_v_grav_brt        "Ventas gravadas brutas (todas tarifas, incluye AF)"
label var agr_v_grav_nta        "Ventas gravadas netas (todas tarifas, incluye AF)"
label var agr_imp_v_grav        "IVA generado en ventas gravadas"
label var agr_v_tc_cdc          "Ventas tarifa 0% con derecho a crédito + exportaciones"
label var agr_v_tc_sdc          "Ventas tarifa 0% sin derecho a crédito"
label var agr_v_no_obj          "Ventas no objeto / exentas de IVA"
label var agr_imp_iva_vtas_per  "IVA ventas a liquidar mes actual (concepto 1260)"

* 5.5. AGREGACIONES — BLOQUE ADQUISICIONES 
*-------------------------------------------------------------------------------
gen double agr_c_grav_cdc_nta = cln_bys_cdc_eaf_tdc_1280 + cln_afj_cdc_tdc_1400 + ///
                                cln_bys_cdc_eaf_tdc_1281 + cln_b_cdc_eaf_t5_1262 + ///
                                ipr_nta_bie_eaf_tdc_1554 + ipr_nta_bie_tdc_1610 + ///
                                ipr_nta_afj_tdc_1650
gen double agr_imp_c_cdc = icl_nta_bys_cdc_eaf_tdc_1290 + icl_nta_afj_cdc_tdc_1410 + ///
                           icl_nta_bys_cdc_eaf_tdc_1291 + icl_nta_bi_cdc_eaf_t5_1263 + ///
                           imp_ipr_nta_bie_eaf_tdc_1556 + imp_ipr_nta_bie_tdc_1620 + ///
                           imp_ipr_nta_afj_tdc_1660
gen double agr_c_grav_sdc_nta = cln_bos_sdc_eaf_tdc_1550
gen double agr_c_tc_iaf       = cln_bys_iaf_tce_1730
gen double agr_c_rimpe        = cln_rise_1740
gen double agr_factor_prop    = fap_crt_tdf_2110
gen double agr_crt_aplicable  = crt_acu_fap_2130

label var agr_c_grav_cdc_nta "Compras gravadas netas con derecho a crédito (todas tarifas)"
label var agr_imp_c_cdc      "IVA en compras con derecho a crédito (potencial)"
label var agr_c_grav_sdc_nta "Compras gravadas sin derecho a crédito"
label var agr_c_tc_iaf       "Compras tarifa 0% (incluye activos fijos)"
label var agr_c_rimpe        "Compras a contribuyentes RIMPE / RISE"
label var agr_factor_prop    "Factor de proporcionalidad (concepto 2110)"
label var agr_crt_aplicable  "Crédito tributario aplicable (concepto 2130)"


* 5.6 AGREGACIONES — BLOQUE LIQUIDACIÓN PERCEPCIÓN 
*-------------------------------------------------------------------------------
gen double agr_iva_causado     = impuesto_causado_2140
gen double agr_crt_mes         = credito_tributario_mac_2150
gen double agr_saldo_crt_acum  = saldo_crt_clo_ipr_msi_2220 + saldo_crt_rfu_msi_2230
gen double agr_ret_recibidas   = rfu_mes_actual_2200
gen double agr_iva_pagar_perc  = tot_imp_apa_percepcion_2270

label var agr_iva_causado     "Impuesto causado (concepto 2140)"
label var agr_crt_mes         "Crédito tributario mes actual (concepto 2150)"
label var agr_saldo_crt_acum  "Saldo CT trasladable al siguiente periodo (2220+2230)"
label var agr_ret_recibidas   "Retenciones IVA recibidas mes actual (2200)"
label var agr_iva_pagar_perc  "Total a pagar como agente de percepción (2270)"


* 5.7. AGREGACIONES — BLOQUE RETENCIÓN Y PAGO 
*-------------------------------------------------------------------------------
gen double agr_ret_efectuadas  = tot_iva_retenido_2550
gen double agr_iva_total_pagar = tot_iva_a_pagar_2560
gen double agr_iva_pagado      = total_pagado_2640
gen double agr_multas_int      = multas_2630 + interes_por_mora_2620

label var agr_ret_efectuadas   "Retenciones IVA practicadas como agente (2550)"
label var agr_iva_total_pagar  "IVA total a pagar consolidado (2560)"
label var agr_iva_pagado       "Total pagado (2640)"
label var agr_multas_int       "Multas + intereses por mora (2630+2620)"


* 5.8. AGREGACIONES — BLOQUE OPERACIONAL 
*-------------------------------------------------------------------------------
gen double agr_cve_emitidos  = tot_cve_emitidos_252
gen double agr_cve_anulados  = tot_cve_anulados_254
gen double agr_cve_recibidos = tot_cve_recibidos_aen_256

label var agr_cve_emitidos   "Comprobantes de venta emitidos (252)"
label var agr_cve_anulados   "Comprobantes de venta anulados (254)"
label var agr_cve_recibidos  "Comprobantes recibidos por adquisiciones (256)"


* 5.8b. FLAGS PARA CRUCE POSTERIOR CON F07 (RETENCIONES) 
* Estos indicadores no entran al modelo de clustering — sirven para
* trazabilidad en la validación cruzada contra el catastro F07.
gen byte flg_ret_recibidas = (agr_ret_recibidas > 0 & !missing(agr_ret_recibidas))
gen byte flg_ret_efectuadas = (agr_ret_efectuadas > 0 & !missing(agr_ret_efectuadas))

label var flg_ret_recibidas  "Declaración con retención recibida > 0 (cruce F07 informado)"
label var flg_ret_efectuadas "Declaración con retención efectuada > 0 (cruce F07 informante)"

* 5.9. LISTA MAESTRA DE AGREGADOS 
*-------------------------------------------------------------------------------
local agregados ///
    agr_v_grav_brt agr_v_grav_nta agr_imp_v_grav ///
    agr_v_tc_cdc agr_v_tc_sdc agr_v_no_obj agr_imp_iva_vtas_per ///
    agr_c_grav_cdc_nta agr_imp_c_cdc agr_c_grav_sdc_nta ///
    agr_c_tc_iaf agr_c_rimpe agr_factor_prop agr_crt_aplicable ///
    agr_iva_causado agr_crt_mes agr_saldo_crt_acum ///
    agr_ret_recibidas agr_iva_pagar_perc ///
    agr_ret_efectuadas agr_iva_total_pagar agr_iva_pagado agr_multas_int ///
    agr_cve_emitidos agr_cve_anulados agr_cve_recibidos


* 5.10. CONTROLES Y CATEGÓRICAS 
*-------------------------------------------------------------------------------
di "============================================================"
di "VARIABLES CATEGÓRICAS Y DE CONTROL"
di "============================================================"

foreach v of varlist tipo_decl anio_fiscal mes_fiscal ///
                     sustitutiva_original declaracion_cero ///
                     aplica_remision {
    di _newline "--- `v' ---"
    tab `v', missing
}


* 5.11. CODEBOOK ESENCIAL SOBRE AGREGADOS 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "VARIABLES AGREGADAS - ESTADÍSTICAS ESENCIALES"
di "Columnas: N_validos | %_missing | %_cero | %_negativo"
di "          min | p25 | p50 | p75 | p99 | max | media"
di "============================================================"

foreach v of local agregados {
    cap quietly {
        count if missing(`v')
        local n_miss   = r(N)
        local pct_miss = round(`n_miss'/_N*100, 0.01)

        count if `v' == 0 & !missing(`v')
        local n_cero   = r(N)
        count if !missing(`v')
        local n_val    = r(N)
        local pct_cero = cond(`n_val' > 0, round(`n_cero'/`n_val'*100, 0.01), .)

        count if `v' < 0 & !missing(`v')
        local n_neg    = r(N)
        local pct_neg  = cond(`n_val' > 0, round(`n_neg'/`n_val'*100, 0.01), .)

        summarize `v', detail
        local vmin  = r(min)
        local vp25  = r(p25)
        local vp50  = r(p50)
        local vp75  = r(p75)
        local vp99  = r(p99)
        local vmax  = r(max)
        local vmean = round(r(mean), 0.01)
    }
    di _newline "=== `v' ==="
    di "  N válidos: `n_val'  |  Missing: `n_miss' (`pct_miss'%)" ///
       "  |  Ceros: `n_cero' (`pct_cero'%)" ///
       "  |  Negativos: `n_neg' (`pct_neg'%)"
    di "  min=`vmin'  p25=`vp25'  p50=`vp50'" ///
       "  p75=`vp75'  p99=`vp99'  max=`vmax'  media=`vmean'"
}


* 5.12. ALERTAS — >80% CEROS 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS - AGREGADOS CON >80% CEROS"
di "(Candidatos a descarte o transformación binaria)"
di "============================================================"

foreach v of local agregados {
    cap quietly {
        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)
        count if !missing(`v')
        local n_val  = r(N)
        local pct    = cond(`n_val' > 0, `n_cero'/`n_val'*100, 0)
    }
    if `pct' > 80 {
        di "  ALTA CONCENTRACIÓN DE CEROS: `v' (" %5.2f `pct' "%)"
    }
}

* 5.13. ALERTAS — VALORES NEGATIVOS 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS - AGREGADOS CON VALORES NEGATIVOS"
di "============================================================"

foreach v of local agregados {
    cap quietly count if `v' < 0 & !missing(`v')
    if r(N) > 0 {
        di "  NEGATIVOS: `v'  N=" r(N)
    }
}

* 5.14. ALERTAS ESPECÍFICAS - FOCOS DE RIESGO 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "ALERTAS ESPECÍFICAS - FOCOS DE RIESGO FISCAL"
di "============================================================"

* (a) Factor de proporcionalidad fuera de rango plausible [0,1]
quietly count if agr_factor_prop > 1 & !missing(agr_factor_prop)
di "  Factor proporcionalidad > 1 (anómalo): N=" r(N)
quietly count if agr_factor_prop < 0 & !missing(agr_factor_prop)
di "  Factor proporcionalidad < 0 (imposible): N=" r(N)

* (b) Saldo CT acumulado sistemático (señal de subdeclaración estructural)
quietly count if agr_saldo_crt_acum > 0 & !missing(agr_saldo_crt_acum)
di "  Declaraciones con saldo CT positivo trasladable: N=" r(N)

* (c) Ratio anulaciones / emitidos elevado
gen double tmp_ratio_anul = cond(agr_cve_emitidos > 0, ///
                                 agr_cve_anulados/agr_cve_emitidos, .)
quietly count if tmp_ratio_anul > 0.20 & !missing(tmp_ratio_anul)
di "  Declaraciones con ratio anulación > 20%: N=" r(N)
drop tmp_ratio_anul

* (d) Diferencia bruto-neto > 10 % (uso intensivo de notas de crédito)
gen double tmp_dif_bn = cond(agr_v_grav_brt > 0, ///
                             (agr_v_grav_brt - agr_v_grav_nta)/agr_v_grav_brt, .)
quietly count if tmp_dif_bn > 0.10 & !missing(tmp_dif_bn)
di "  Declaraciones con NC > 10% sobre ventas brutas: N=" r(N)
drop tmp_dif_bn

* (e) Universos candidatos al cruce con F07
quietly count if flg_ret_recibidas == 1
di "  Declaraciones con retención recibida (cruce F07 como informado): N=" r(N)
quietly count if flg_ret_efectuadas == 1
di "  Declaraciones con retención efectuada (cruce F07 como informante): N=" r(N)

* 5.15. GUARDADO 
*-------------------------------------------------------------------------------
* Conserva variables crudas + agregadas + controles
save "F01_02F104_con_agregados.dta", replace


*6. IMPUTACION VARIABLES ANOMALAS SOBRE COMPROBANTES EMITIDOS
*===========================================================================

/*******************************************************************************
   Propósito:
     Imputar con la mediana del propio contribuyente los valores
     anómalos detectados en los tres conceptos de comprobantes:
       - tot_cve_emitidos_252
       - tot_cve_anulados_254
       - tot_cve_recibidos_aen_256
     La mediana se calcula por RUC y tipo de declaración, usando
     únicamente las declaraciones no anómalas como base de cálculo.
   Insumo:  F01_02F104_con_agregados.dta  luego de auditoría manual
   Salida:  F01_03F104_imputado.dta
*******************************************************************************/

clear all
set more off
use "F01_02F104_con_agregados.dta", clear

* 6.0. UMBRALES PARAMETRIZADOS 
*-------------------------------------------------------------------------------
* Diferenciados por tipo de declaración. Ajustables si tras la corrida
* aparecen contribuyentes legítimos (telcos, retail masivo) incluidos.
local U252_MEN = 5000000        // Emitidos mensual
local U252_SEM = 30000000       // Emitidos semestral
local U254_MEN = 1000000        // Anulados mensual
local U254_SEM = 6000000        // Anulados semestral
local U256_MEN = 5000000        // Recibidos mensual
local U256_SEM = 30000000       // Recibidos semestral

* 6.1. IDENTIFICACIÓN DE CANDIDATOS 
*-------------------------------------------------------------------------------
gen byte flg_imp_252 = 0
replace flg_imp_252 = 1 if (tipo_decl == 1 & tot_cve_emitidos_252 > `U252_MEN') | ///
                           (tipo_decl == 2 & tot_cve_emitidos_252 > `U252_SEM')

gen byte flg_imp_254 = 0
replace flg_imp_254 = 1 if (tipo_decl == 1 & tot_cve_anulados_254 > `U254_MEN') | ///
                            (tipo_decl == 2 & tot_cve_anulados_254 > `U254_SEM')

gen byte flg_imp_256 = 0
replace flg_imp_256 = 1 if (tipo_decl == 1 & tot_cve_recibidos_aen_256 > `U256_MEN') | ///
                            (tipo_decl == 2 & tot_cve_recibidos_aen_256 > `U256_SEM')

label var flg_imp_252 "Declaración imputada en CVE emitidos (252)"
label var flg_imp_254 "Declaración imputada en CVE anulados (254)"
label var flg_imp_256 "Declaración imputada en CVE recibidos (256)"

di _newline(2) "============================================================"
di "CANDIDATOS A IMPUTACIÓN — CONTEO INICIAL"
di "============================================================"
foreach v in 252 254 256 {
    quietly count if flg_imp_`v' == 1
    di "  Declaraciones candidatas en `v': " r(N)
    quietly levelsof ID if flg_imp_`v' == 1, local(tmp_ids)
    local n_ruc_`v' : word count `tmp_ids'
    di "  RUCs involucrados en `v': `n_ruc_`v''"
}


* 6.2. CONSERVAR VALOR ORIGINAL ANTES DE IMPUTAR 
*-------------------------------------------------------------------------------
gen double cve_emitidos_pre_imp  = tot_cve_emitidos_252      if flg_imp_252 == 1
gen double cve_anulados_pre_imp  = tot_cve_anulados_254      if flg_imp_254 == 1
gen double cve_recibidos_pre_imp = tot_cve_recibidos_aen_256 if flg_imp_256 == 1

label var cve_emitidos_pre_imp  "Valor original CVE emitidos antes de imputar"
label var cve_anulados_pre_imp  "Valor original CVE anulados antes de imputar"
label var cve_recibidos_pre_imp "Valor original CVE recibidos antes de imputar"


* 6.3. CÁLCULO DE MEDIANAS POR RUC Y TIPO DE DECLARACIÓN 
*-------------------------------------------------------------------------------
* Solo se promedian declaraciones NO anómalas del mismo tipo
gen double tmp_252 = tot_cve_emitidos_252      if flg_imp_252 == 0
gen double tmp_254 = tot_cve_anulados_254      if flg_imp_254 == 0
gen double tmp_256 = tot_cve_recibidos_aen_256 if flg_imp_256 == 0

bysort ID tipo_decl: egen median_cve_emi = median(tmp_252)
bysort ID tipo_decl: egen median_cve_anu = median(tmp_254)
bysort ID tipo_decl: egen median_cve_rec = median(tmp_256)

bysort ID tipo_decl: egen n_no_anom_252 = total(flg_imp_252 == 0 & !missing(tot_cve_emitidos_252))
bysort ID tipo_decl: egen n_no_anom_254 = total(flg_imp_254 == 0 & !missing(tot_cve_anulados_254))
bysort ID tipo_decl: egen n_no_anom_256 = total(flg_imp_256 == 0 & !missing(tot_cve_recibidos_aen_256))

drop tmp_252 tmp_254 tmp_256

* 6.4. CASOS SIN BASE DE CÁLCULO 
*-------------------------------------------------------------------------------
* RUCs cuyas declaraciones del tipo correspondiente son todas anómalas
* o no existen — requieren decisión manual posterior.
gen byte sin_base_252 = (flg_imp_252 == 1 & missing(median_cve_emi))
gen byte sin_base_254 = (flg_imp_254 == 1 & missing(median_cve_anu))
gen byte sin_base_256 = (flg_imp_256 == 1 & missing(median_cve_rec))

di _newline(2) "============================================================"
di "CASOS SIN BASE DE CÁLCULO PARA MEDIANA"
di "============================================================"
foreach v in 252 254 256 {
    quietly count if sin_base_`v' == 1
    di "  Sin base en `v': " r(N) " declaraciones"
}

preserve
    keep if sin_base_252 == 1 | sin_base_254 == 1 | sin_base_256 == 1
    keep ID anio_fiscal mes_fiscal tipo_decl ///
         tot_cve_emitidos_252 tot_cve_anulados_254 tot_cve_recibidos_aen_256 ///
         sin_base_252 sin_base_254 sin_base_256 ///
         n_no_anom_252 n_no_anom_254 n_no_anom_256
    export delimited "casos_imputacion_sin_base.csv", replace
restore

* 6.5. SUSTITUCIÓN 
*-------------------------------------------------------------------------------
replace tot_cve_emitidos_252      = median_cve_emi if flg_imp_252 == 1 & !missing(median_cve_emi)
replace tot_cve_anulados_254      = median_cve_anu if flg_imp_254 == 1 & !missing(median_cve_anu)
replace tot_cve_recibidos_aen_256 = median_cve_rec if flg_imp_256 == 1 & !missing(median_cve_rec)

* 6.6. RECONSTRUCCIÓN DE AGREGACIONES DEPENDIENTES 
*-------------------------------------------------------------------------------
* Las agregaciones que consumen estas variables deben recalcularse
* para reflejar los valores imputados.
replace agr_cve_emitidos  = tot_cve_emitidos_252
replace agr_cve_anulados  = tot_cve_anulados_254
replace agr_cve_recibidos = tot_cve_recibidos_aen_256

* 6.7. RECODEBOOK DE LAS TRES VARIABLES TRAS IMPUTACIÓN 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "VERIFICACIÓN POST-IMPUTACIÓN"
di "============================================================"
foreach v in agr_cve_emitidos agr_cve_anulados agr_cve_recibidos {
    di _newline "=== `v' (post-imputación) ==="
    quietly summarize `v', detail
    di "  min=" r(min) "  p50=" r(p50) "  p75=" r(p75) "  p99=" r(p99) "  max=" r(max) "  media=" r(mean)
}

* 6.8. RESUMEN DE TRAZABILIDAD 
*-------------------------------------------------------------------------------
di _newline(2) "============================================================"
di "TRAZABILIDAD DE IMPUTACIÓN"
di "============================================================"
quietly count if flg_imp_252 == 1 & !missing(cve_emitidos_pre_imp)
di "  Total imputaciones CVE emitidos:  " r(N)
quietly count if flg_imp_254 == 1 & !missing(cve_anulados_pre_imp)
di "  Total imputaciones CVE anulados:  " r(N)
quietly count if flg_imp_256 == 1 & !missing(cve_recibidos_pre_imp)
di "  Total imputaciones CVE recibidos: " r(N)
quietly count if flg_imp_252 == 1 | flg_imp_254 == 1 | flg_imp_256 == 1
di "  Declaraciones con al menos una imputación: " r(N)


* 6.9. LIMPIEZA DE VARIABLES AUXILIARES 
*-------------------------------------------------------------------------------
* Se conservan flags y valores originales — necesarios para el TFM.
* Se eliminan medianas auxiliares y conteos de soporte.
drop median_cve_emi median_cve_anu median_cve_rec ///
     n_no_anom_252 n_no_anom_254 n_no_anom_256 ///
     sin_base_252 sin_base_254 sin_base_256
* 6.10. GUARDADO 
*-------------------------------------------------------------------------------
save "F01_03F104_imputado.dta", replace
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log04_F01_F104_01_Construccion_variables_analiticas.txt", text replace

*7 BLOQUE CONTRUCCION DE VARIABLES ANALÍSTICAS FUENTE F01 - F104
*=============================================================================

/*******************************************************************************
  Objetivo:   Construir el dataset analítico a nivel RUC (1 fila por contribuyente)
     a partir de la base de declaraciones depurada e imputada.
     Versión optimizada para bases grandes (~88 GB en disco):
       - Carga selectiva (solo las 28 variables necesarias)
       - 'compress' tras cada paso intermedio
       - 'collapse' en cascada en lugar de 'bysort: egen' iterado
       - Medianas calculadas en pase separado sobre subconjunto filtrado
   Insumo: F01_03F104_imputado.dta
   Salida: F01_05F104_perfil_ruc.dta      (1 fila por RUC, ~42 variables)
           F01_04F104_panel_anual.dta     (paso intermedio, RUC × año)
           Log04_F01_F104_01_Construccion_variables_analiticas.txt
******************************************************************************/

* 7.0. CONFIGURACIÓN DEL ENTORNO
*-------------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

timer clear
timer on 1

* 7.1 PARTE A. CARGA SELECTIVA
* --------------------------------------------------------------------------

* De las ~200 variables del .dta solo se cargan las 28 que alimentan
* el perfil. Esto reduce la memoria de partida en aproximadamente 85%.

use ID anio_fiscal mes_fiscal tipo_decl ///
    declaracion_cero sustitutiva_original ///
    agr_v_grav_brt agr_v_grav_nta agr_imp_v_grav ///
    agr_v_tc_cdc agr_v_tc_sdc agr_imp_iva_vtas_per ///
    agr_c_grav_cdc_nta agr_imp_c_cdc agr_c_grav_sdc_nta ///
    agr_c_tc_iaf agr_c_rimpe ///
    agr_factor_prop agr_crt_aplicable ///
    agr_iva_causado agr_crt_mes ///
    agr_saldo_crt_acum agr_ret_recibidas agr_iva_pagar_perc ///
    agr_ret_efectuadas ///
    agr_iva_total_pagar agr_iva_pagado agr_multas_int ///
    agr_cve_emitidos agr_cve_anulados agr_cve_recibidos ///
    using "F01_03F104_imputado.dta", clear

* 7.2 Conversión de variables string que se usan aritméticamente 
*-------------------------------------------------------------------------------
* anio_fiscal y mes_fiscal vienen como string en el .dta original.
* Se construye anio_fiscal_num para uso en periodo_yyyymm y en el
* collapse del panel anual.
capture confirm string variable anio_fiscal
if !_rc {
    gen int anio_fiscal_num = real(anio_fiscal)
}
else {
    gen int anio_fiscal_num = anio_fiscal
}
label var anio_fiscal_num "Año fiscal (numérico)"

compress
di _newline "=== Memoria tras carga selectiva ==="
memory

* 7.3. VARIABLES AUXILIARES POR DECLARACIÓN
* --------------------------------------------------------------------------

* 7.3.1 Periodo numérico 
gen long periodo_yyyymm = anio_fiscal_num * 100 + real(mes_fiscal)
label var periodo_yyyymm "Periodo fiscal en formato YYYYMM"

* 7.3.2 Movimiento económico real 
gen byte tiene_movimiento = (agr_v_grav_nta > 0 | agr_v_tc_cdc > 0 | ///
                              agr_v_tc_sdc > 0 | agr_c_grav_cdc_nta > 0 | ///
                              agr_c_tc_iaf > 0 | agr_c_grav_sdc_nta > 0)

* 7.3.3 Ventana de actividad declarativa real 
bysort ID: egen periodo_primer_mov = min(cond(tiene_movimiento==1, periodo_yyyymm, .))
bysort ID: egen periodo_ultimo_mov = max(cond(tiene_movimiento==1, periodo_yyyymm, .))

gen byte dentro_ventana = 0
replace dentro_ventana = 1 if !missing(periodo_primer_mov) & ///
                              periodo_yyyymm >= periodo_primer_mov & ///
                              periodo_yyyymm <= periodo_ultimo_mov

drop periodo_primer_mov periodo_ultimo_mov

* 7.3.4 Flags binarios de comportamiento 
gen byte flg_es_cero    = (declaracion_cero == "S")
gen byte flg_es_sust    = (sustitutiva_original == "S")
gen byte flg_con_mora   = (agr_multas_int > 0)
gen byte flg_saldo_pos  = (agr_saldo_crt_acum > 0)
gen byte flg_anul_alta  = (agr_cve_emitidos > 0 & ///
                            agr_cve_anulados/agr_cve_emitidos > 0.20)
gen byte flg_nc_alta    = (agr_v_grav_brt > 0 & ///
                            (agr_v_grav_brt - agr_v_grav_nta)/agr_v_grav_brt > 0.10)

* 7.3.5 Indicadores de tipo de declaración por fila 
gen byte aux_mensual    = (tipo_decl == 1)
gen byte aux_semestral  = (tipo_decl == 2)

compress
di _newline "=== Memoria tras variables auxiliares ==="
memory

* 7.4. COLLAPSE 1 — MEDIANAS DENTRO DE VENTANA (TEMPFILE)
* --------------------------------------------------------------------------
* Calculadas en pase separado sobre el subconjunto dentro_ventana == 1
* para evitar crear variables duplicadas en la base completa.

preserve
    keep if dentro_ventana == 1
    collapse (median) med_factor_prop    = agr_factor_prop ///
                       med_saldo_crt_acum = agr_saldo_crt_acum ///
                       med_v_grav_nta     = agr_v_grav_nta, ///
                                            by(ID) fast
    compress
    tempfile medianas_ruc
    save `medianas_ruc'
restore

* 7.5. COLLAPSE 2 — PANEL ANUAL (RUC × AÑO FISCAL)
* --------------------------------------------------------------------------
* Solo se acumulan los montos de declaraciones dentro de la ventana.
* Este archivo se conserva en disco — sirve para el CV interanual y
* queda disponible para análisis longitudinales posteriores.

preserve
    keep if dentro_ventana == 1
    collapse (sum) sa_v_grav_nta       = agr_v_grav_nta ///
                    sa_v_grav_brt       = agr_v_grav_brt ///
                    sa_imp_v_grav       = agr_imp_v_grav ///
                    sa_imp_iva_vtas_per = agr_imp_iva_vtas_per ///
                    sa_v_tc_cdc         = agr_v_tc_cdc ///
                    sa_v_tc_sdc         = agr_v_tc_sdc ///
                    sa_c_grav_cdc_nta   = agr_c_grav_cdc_nta ///
                    sa_imp_c_cdc        = agr_imp_c_cdc ///
                    sa_c_grav_sdc_nta   = agr_c_grav_sdc_nta ///
                    sa_c_tc_iaf         = agr_c_tc_iaf ///
                    sa_c_rimpe          = agr_c_rimpe ///
                    sa_crt_aplicable    = agr_crt_aplicable ///
                    sa_iva_causado      = agr_iva_causado ///
                    sa_iva_pagado       = agr_iva_pagado ///
                    sa_iva_total_pagar  = agr_iva_total_pagar ///
                    sa_ret_recibidas    = agr_ret_recibidas ///
                    sa_ret_efectuadas   = agr_ret_efectuadas ///
                    sa_multas_int       = agr_multas_int ///
                    sa_cve_emitidos     = agr_cve_emitidos ///
                    sa_cve_anulados     = agr_cve_anulados ///
                    sa_cve_recibidos    = agr_cve_recibidos, ///
                                          by(ID anio_fiscal_num) fast
    rename anio_fiscal_num anio_fiscal
    compress
    save "F01_04F104_panel_anual.dta", replace
restore

* 7.6. COLLAPSE 3 — PERFIL RUC (BASE DECLARACIÓN)
* --------------------------------------------------------------------------
* Sumas totales, conteos y extremos temporales en un único pase.

collapse (sum) tot_v_grav_nta       = agr_v_grav_nta ///
                tot_v_grav_brt       = agr_v_grav_brt ///
                tot_imp_v_grav       = agr_imp_v_grav ///
                tot_imp_iva_vtas_per = agr_imp_iva_vtas_per ///
                tot_v_tc_cdc         = agr_v_tc_cdc ///
                tot_v_tc_sdc         = agr_v_tc_sdc ///
                tot_c_grav_cdc_nta   = agr_c_grav_cdc_nta ///
                tot_imp_c_cdc        = agr_imp_c_cdc ///
                tot_c_grav_sdc_nta   = agr_c_grav_sdc_nta ///
                tot_c_tc_iaf         = agr_c_tc_iaf ///
                tot_c_rimpe          = agr_c_rimpe ///
                tot_crt_aplicable    = agr_crt_aplicable ///
                tot_iva_causado      = agr_iva_causado ///
                tot_iva_pagado       = agr_iva_pagado ///
                tot_iva_total_pagar  = agr_iva_total_pagar ///
                tot_ret_recibidas    = agr_ret_recibidas ///
                tot_ret_efectuadas   = agr_ret_efectuadas ///
                tot_multas_int       = agr_multas_int ///
                tot_cve_emitidos     = agr_cve_emitidos ///
                tot_cve_anulados     = agr_cve_anulados ///
                tot_cve_recibidos    = agr_cve_recibidos ///
                n_decl_dentro_vent   = dentro_ventana ///
                n_decl_cero          = flg_es_cero ///
                n_decl_sustitutiva   = flg_es_sust ///
                n_decl_con_mora      = flg_con_mora ///
                n_decl_anul_alta     = flg_anul_alta ///
                n_decl_nc_alta       = flg_nc_alta ///
                n_decl_saldo_pos     = flg_saldo_pos ///
                n_decl_mensuales     = aux_mensual ///
                n_decl_semestrales   = aux_semestral ///
         (count) n_declaraciones = periodo_yyyymm ///
         (min)   periodo_primer_decl = periodo_yyyymm ///
         (max)   periodo_ultimo_decl = periodo_yyyymm, ///
                                       by(ID) fast
compress
di _newline "=== Memoria tras colapso perfil RUC ==="
memory

*7.7. INTEGRACIÓN DE MEDIANAS (TEMPFILE)
* --------------------------------------------------------------------------
merge 1:1 ID using `medianas_ruc', nogen

* 7.8. CV INTERANUAL Y PERSISTENCIA DESDE PANEL ANUAL
* --------------------------------------------------------------------------
* Se carga el panel anual en memoria, se calculan estadísticas por RUC
* y se trae al perfil mediante merge.
preserve
    use "F01_04F104_panel_anual.dta", clear
    
    * Indicadores binarios año a año
    gen byte ha_vtas       = (sa_v_grav_nta > 0)
    gen byte ha_exp_tc_cdc = (sa_v_tc_cdc > 0)
    gen byte ha_compras    = (sa_c_grav_cdc_nta > 0)
    gen byte ha_retenedor  = (sa_ret_efectuadas > 0)
    gen byte ha_iva_pagado = (sa_iva_pagado > 0)
    
    collapse (sum) n_anos_con_vtas       = ha_vtas ///
                    n_anos_con_exp_tc_cdc = ha_exp_tc_cdc ///
                    n_anos_con_compras    = ha_compras ///
                    n_anos_con_retenedor  = ha_retenedor ///
                    n_anos_con_iva_pagado = ha_iva_pagado ///
             (mean) media_anual_vtas = sa_v_grav_nta ///
                    media_anual_cmp  = sa_c_grav_cdc_nta ///
                    media_anual_iva  = sa_iva_pagado ///
                    media_anual_ret  = sa_ret_recibidas ///
             (sd)   sd_anual_vtas    = sa_v_grav_nta ///
                    sd_anual_cmp     = sa_c_grav_cdc_nta ///
                    sd_anual_iva     = sa_iva_pagado ///
                    sd_anual_ret     = sa_ret_recibidas, ///
                                       by(ID) fast
    
    gen double cv_v_grav_nta     = cond(media_anual_vtas > 0, sd_anual_vtas/media_anual_vtas, .)
    gen double cv_c_grav_cdc_nta = cond(media_anual_cmp  > 0, sd_anual_cmp/media_anual_cmp,   .)
    gen double cv_iva_pagado     = cond(media_anual_iva  > 0, sd_anual_iva/media_anual_iva,   .)
    gen double cv_ret_recibidas  = cond(media_anual_ret  > 0, sd_anual_ret/media_anual_ret,   .)
    
    drop media_anual_* sd_anual_*
    compress
    tempfile cv_persistencia
    save `cv_persistencia'
restore

merge 1:1 ID using `cv_persistencia', nogen

* 7.9. RATIOS DERIVADOS Y MÉTRICAS COMPUESTAS
* ------------------------------------------------------------------------
* 7.9.1 Ratios estructurales 
gen double ratio_imp_vtas_vtas = cond(tot_v_grav_nta > 0, ///
                                       tot_imp_v_grav/tot_v_grav_nta, .)
gen double ratio_crt_imp_cmp   = cond(tot_imp_c_cdc > 0, ///
                                       tot_crt_aplicable/tot_imp_c_cdc, .)
gen double ratio_nc_ventas     = cond(tot_v_grav_brt > 0, ///
                                       (tot_v_grav_brt - tot_v_grav_nta)/tot_v_grav_brt, .)
gen double ratio_anul_emit     = cond(tot_cve_emitidos > 0, ///
                                       tot_cve_anulados/tot_cve_emitidos, .)
gen double ratio_pago_causado  = cond(tot_iva_causado > 0, ///
                                       tot_iva_pagado/tot_iva_causado, .)
gen double ratio_saldo_iva_vtas = cond(tot_imp_v_grav > 0, ///
                                        med_saldo_crt_acum/tot_imp_v_grav, .)
* 7.9.2 Porcentajes de comportamiento 
gen double pct_decl_cero        = n_decl_cero/n_declaraciones
gen double pct_decl_sustitutiva = n_decl_sustitutiva/n_declaraciones
gen double pct_decl_con_mora    = n_decl_con_mora/n_declaraciones
gen double pct_decl_anul_alta   = n_decl_anul_alta/n_declaraciones
gen double pct_decl_nc_alta     = n_decl_nc_alta/n_declaraciones
gen double pct_decl_saldo_pos   = n_decl_saldo_pos/n_declaraciones

* 7.9.3 Flags estructurales 
gen byte flg_exportador       = (tot_v_tc_cdc > 0)
gen byte flg_agente_retenedor = (tot_ret_efectuadas > 0)
gen byte flg_compras_rimpe    = (tot_c_rimpe > 0)

* 7.9.4 Meses cubiertos efectivos
* Una declaración mensual cubre 1 mes; una semestral cubre 6.
gen int n_meses_cubiertos = n_decl_mensuales + 6 * n_decl_semestrales

* 7.9.5 Tipo declaración predominante
gen byte tipo_decl_predominante = .
replace tipo_decl_predominante = 1 if n_decl_mensuales >  n_decl_semestrales
replace tipo_decl_predominante = 2 if n_decl_semestrales > n_decl_mensuales
replace tipo_decl_predominante = 3 if n_decl_mensuales == n_decl_semestrales & n_decl_mensuales > 0
label define tipoPredLBL 1 "Mensual" 2 "Semestral" 3 "Mixto"
label values tipo_decl_predominante tipoPredLBL

* 7.10. ETIQUETADO
* --------------------------------------------------------------------------
label var tot_v_grav_nta       "Ventas gravadas netas — suma 2020-2025"
label var tot_v_grav_brt       "Ventas gravadas brutas — suma 2020-2025"
label var tot_imp_v_grav       "IVA generado en ventas — suma 2020-2025"
label var tot_imp_iva_vtas_per "IVA ventas a liquidar (1260) — suma"
label var tot_v_tc_cdc         "Ventas tarifa 0% con CT + exportaciones — suma"
label var tot_v_tc_sdc         "Ventas tarifa 0% sin CT — suma"
label var tot_c_grav_cdc_nta   "Compras gravadas con CT — suma 2020-2025"
label var tot_imp_c_cdc        "IVA en compras con CT — suma 2020-2025"
label var tot_c_grav_sdc_nta   "Compras gravadas sin CT — suma"
label var tot_c_tc_iaf         "Compras tarifa 0% — suma"
label var tot_c_rimpe          "Compras a RIMPE — suma"
label var tot_crt_aplicable    "Crédito tributario aplicable — suma"
label var tot_iva_causado      "IVA causado — suma 2020-2025"
label var tot_iva_pagado       "IVA pagado — suma 2020-2025"
label var tot_iva_total_pagar  "IVA total a pagar consolidado — suma"
label var tot_ret_recibidas    "Retenciones IVA recibidas — suma"
label var tot_ret_efectuadas   "Retenciones IVA efectuadas — suma"
label var tot_multas_int       "Multas + intereses — suma 2020-2025"
label var tot_cve_emitidos     "Comprobantes emitidos — suma"
label var tot_cve_anulados     "Comprobantes anulados — suma"
label var tot_cve_recibidos    "Comprobantes recibidos — suma"

label var med_factor_prop      "Factor de proporcionalidad — mediana"
label var med_saldo_crt_acum   "Saldo CT acumulado — mediana"
label var med_v_grav_nta       "Ventas gravadas netas — mediana mensual"

label var cv_v_grav_nta        "CV interanual ventas gravadas netas"
label var cv_c_grav_cdc_nta    "CV interanual compras con CT"
label var cv_iva_pagado        "CV interanual IVA pagado"
label var cv_ret_recibidas     "CV interanual retenciones recibidas"

label var n_anos_con_vtas       "Años con ventas > 0 (de los 6 del periodo)"
label var n_anos_con_exp_tc_cdc "Años con exportaciones o ventas 0% con CT > 0"
label var n_anos_con_compras    "Años con compras con CT > 0"
label var n_anos_con_retenedor  "Años actuando como agente de retención"
label var n_anos_con_iva_pagado "Años con IVA pagado > 0"

label var ratio_imp_vtas_vtas   "Tarifa efectiva media (IVA / ventas)"
label var ratio_crt_imp_cmp     "Crédito tributario / IVA compras"
label var ratio_nc_ventas       "Intensidad notas de crédito sobre ventas"
label var ratio_anul_emit       "Tasa anulación de comprobantes"
label var ratio_pago_causado    "Cumplimiento efectivo (pagado/causado)"
label var ratio_saldo_iva_vtas  "Intensidad acumulación saldo CT"

label var n_declaraciones       "Total declaraciones presentadas 2020-2025"
label var n_decl_dentro_vent    "Declaraciones dentro de ventana de actividad"
label var n_meses_cubiertos     "Meses fiscales efectivos cubiertos"
label var periodo_primer_decl   "Primer periodo fiscal declarado (YYYYMM)"
label var periodo_ultimo_decl   "Último periodo fiscal declarado (YYYYMM)"

label var pct_decl_cero         "% declaraciones en cero"
label var pct_decl_sustitutiva  "% declaraciones sustitutivas"
label var pct_decl_con_mora     "% declaraciones con multa/interés"
label var pct_decl_anul_alta    "% declaraciones con anulación > 20%"
label var pct_decl_nc_alta      "% declaraciones con NC > 10%"
label var pct_decl_saldo_pos    "% declaraciones con saldo CT positivo"

label var flg_exportador        "Exportador (al menos 1 año con ventas 0% CT)"
label var flg_agente_retenedor  "Agente retenedor (al menos 1 año)"
label var flg_compras_rimpe     "Compró a RIMPE (al menos 1 año)"
label var tipo_decl_predominante "Tipo declaración predominante"

* 7.11. CODEBOOK DEL DATASET ANALÍTICO
* --------------------------------------------------------------------------
di _newline(2) "============================================================"
di "DATASET ANALÍTICO — PERFIL RUC"
di "============================================================"
quietly count
di "  N contribuyentes: " r(N)
di "============================================================"

local perfil_vars ///
    tot_v_grav_nta tot_imp_v_grav tot_imp_iva_vtas_per ///
    tot_v_tc_cdc tot_v_tc_sdc tot_c_grav_cdc_nta tot_imp_c_cdc ///
    tot_c_grav_sdc_nta tot_c_tc_iaf tot_c_rimpe ///
    tot_crt_aplicable tot_iva_causado tot_iva_pagado tot_iva_total_pagar ///
    tot_ret_recibidas tot_ret_efectuadas tot_multas_int ///
    tot_cve_emitidos tot_cve_anulados tot_cve_recibidos ///
    med_factor_prop med_saldo_crt_acum med_v_grav_nta ///
    cv_v_grav_nta cv_c_grav_cdc_nta cv_iva_pagado cv_ret_recibidas ///
    n_anos_con_vtas n_anos_con_exp_tc_cdc n_anos_con_compras ///
    n_anos_con_retenedor n_anos_con_iva_pagado ///
    ratio_imp_vtas_vtas ratio_crt_imp_cmp ratio_nc_ventas ///
    ratio_anul_emit ratio_pago_causado ratio_saldo_iva_vtas ///
    n_declaraciones n_meses_cubiertos ///
    pct_decl_cero pct_decl_sustitutiva pct_decl_con_mora ///
    pct_decl_anul_alta pct_decl_nc_alta pct_decl_saldo_pos

foreach v of local perfil_vars {
    cap quietly {
        count if missing(`v')
        local n_miss = r(N)
        local pct_miss = round(`n_miss'/_N*100, 0.01)
        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)
        count if !missing(`v')
        local n_val = r(N)
        local pct_cero = cond(`n_val' > 0, round(`n_cero'/`n_val'*100, 0.01), .)
        summarize `v', detail
        local vmin = r(min)
        local vp25 = r(p25)
        local vp50 = r(p50)
        local vp75 = r(p75)
        local vp99 = r(p99)
        local vmax = r(max)
        local vmean = round(r(mean), 0.0001)
    }
    di _newline "=== `v' ==="
    di "  N válidos: `n_val'  |  Missing: `n_miss' (`pct_miss'%)  |  Ceros: `n_cero' (`pct_cero'%)"
    di "  min=`vmin'  p25=`vp25'  p50=`vp50'  p75=`vp75'  p99=`vp99'  max=`vmax'  media=`vmean'"
}

* 7.12. GUARDADO Y CIERRE
* --------------------------------------------------------------------------
compress
save "F01_05F104_perfil_ruc.dta", replace
timer off 1
di _newline(2) "=== TIEMPO TOTAL DE EJECUCIÓN ==="
timer list 1
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close
log using "Log04_F01_F104_02_Consolidacion_analitica.txt", text replace

*8. CONSOLIDACIÓN DEL DATASET ANALÍTICO F01 (SIN TRANSFORMACIONES DE ESCALA)
*===============================================================================

/*******************************************************************************
 Objetivo:
   Dejar el perfil RUC de F01 en su forma final para integración con las
   demás fuentes (F02-F07), conservando todas las variables en su unidad
   original (USD, tasas en [0,1], conteos). Operaciones aplicadas:
     (a) Filtrado de RUCs sin movimiento real (categoría aparte, no transformación
	     de escala — son contribuyentes sin variabilidad
         económica que no aportan al clustering)
     (b) Corrección de bug en n_meses_cubiertos (acotar a 72 — error de
         cómputo, no decisión de escala)
     (c) Saneamiento de dos ratios con límite conceptual imposible
         (ratio_nc_ventas y ratio_crt_imp_cmp no pueden exceder 1 ni ser negativos
		 por definición — esto es corrección de inconsistencia
         matemática, no winsorización estadística)
   Operaciones explícitamente NO aplicadas en esta etapa (se posponen al
   EDA del dataset integrado en Python):
     - Winsorización estadística de ratios sin techo conceptual
       (ratio_pago_causado, ratio_anul_emit, ratio_saldo_iva_vtas)
     - Imputación de missings (CV interanual, ratios con denominador 0)
     - Transformación log(1+x)
     - Estandarización Z-score / Min-Max
   Las variables quedan en sus unidades originales: montos en USD, tasas y ratios
   entre 0 y 1 (donde aplica conceptualmente), conteos enteros.
   Los missings se conservan intactos y documentados — su tratamiento se
   decide en el EDA conjunto.
   Insumo: F01_05F104_perfil_ruc.dta
   Salidas: AF01_perfil_analitico.dta   (base final, lista para integración
            — variables en unidad original)
            F01_06F104_inactivos_formales.dta (categoría descriptiva)
            Log05_F01_F104_consolidacion_analitica.txt
******************************************************************************/

*8.0. CONFIGURACIÓN DEL ENTORNO
*-------------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"
timer clear
timer on 1

*8.1. CARGA DEL PERFIL RUC
*-------------------------------------------------------------------------------
use "F01_05F104_perfil_ruc.dta", clear
di _newline "============================================================"
di "BLOQUE 7 — CONSOLIDACIÓN DEL DATASET ANALÍTICO (SIN ESCALA)"
di "============================================================"
quietly count
di "Contribuyentes en el perfil RUC inicial: " r(N)

*8.2. FILTRADO DE INACTIVOS FORMALES
*-------------------------------------------------------------------------------
* Los contribuyentes sin movimiento económico real (todas sus declaraciones
* en cero en variables materiales de ventas/compras) tienen med_factor_prop
* missing. Se identifican y se guardan aparte como categoría descriptiva del
* TFM, y se excluyen del dataset de clustering por carecer de variabilidad
* analítica. Esta es una decisión de universo, no una transformación de
* escala — son contribuyentes que no tienen comportamiento que caracterizar.

gen byte flg_sin_movimiento = missing(med_factor_prop)
label var flg_sin_movimiento "RUC formalmente activo sin movimiento económico real"

quietly count if flg_sin_movimiento == 1
local n_inact = r(N)
di _newline "Inactivos formales (sin movimiento real): `n_inact'"

preserve
    keep if flg_sin_movimiento == 1
    compress
    save "F01_06F104_inactivos_formales.dta", replace
    di "  Guardados en F01_06F104_inactivos_formales.dta"
restore

drop if flg_sin_movimiento == 1
drop flg_sin_movimiento

quietly count
di "Contribuyentes en el dataset analítico: " r(N)

*8.3. CORRECCIÓN DE BUG EN n_meses_cubiertos
*-------------------------------------------------------------------------------
* La fórmula n_decl_mensuales + 6*n_decl_semestrales puede superar 72 cuando
* un mismo periodo se cubre por declaraciones de tipos distintos (cambio de
* régimen, sustitutivas que modifican el tipo). Esto es un error de cómputo
* — el valor correcto no puede exceder el máximo teórico del periodo
* 2020-2025 — no una decisión de tratamiento de outliers.

quietly count if n_meses_cubiertos > 72
di _newline "Registros con n_meses_cubiertos > 72 (corregidos por error de cómputo): " r(N)
replace n_meses_cubiertos = 72 if n_meses_cubiertos > 72

*8.4. SANEAMIENTO DE RATIOS CON LÍMITE CONCEPTUAL IMPOSIBLE
*-------------------------------------------------------------------------------
* ratio_nc_ventas (notas de crédito / ventas brutas) y ratio_crt_imp_cmp
* (crédito tributario aplicable / IVA en compras) tienen un techo y un piso
* definidos por la naturaleza de lo que miden: ambos son fracciones de un
* total y no pueden ser negativos ni superar 1. Valores fuera de ese rango
* son inconsistencias de captura o de fórmula, no señal real a preservar
* para el EDA — son del mismo tipo que los outliers ya tratados en el
* bloque 3-4 sobre variables crudas. Se corrigen sobre la variable
* original, sin crear versión "_w" adicional, porque no es una decisión
* de tratamiento estadístico sino de validez matemática.

quietly count if ratio_nc_ventas < 0 & !missing(ratio_nc_ventas)
di _newline "ratio_nc_ventas < 0 (matemáticamente imposible, corregido a 0): " r(N)
replace ratio_nc_ventas = 0 if ratio_nc_ventas < 0 & !missing(ratio_nc_ventas)

quietly count if ratio_nc_ventas > 1 & !missing(ratio_nc_ventas)
di "ratio_nc_ventas > 1 (matemáticamente imposible, corregido a 1): " r(N)
replace ratio_nc_ventas = 1 if ratio_nc_ventas > 1 & !missing(ratio_nc_ventas)

quietly count if ratio_crt_imp_cmp < 0 & !missing(ratio_crt_imp_cmp)
di "ratio_crt_imp_cmp < 0 (matemáticamente imposible, corregido a 0): " r(N)
replace ratio_crt_imp_cmp = 0 if ratio_crt_imp_cmp < 0 & !missing(ratio_crt_imp_cmp)

quietly count if ratio_crt_imp_cmp > 1 & !missing(ratio_crt_imp_cmp)
di "ratio_crt_imp_cmp > 1 (matemáticamente imposible, corregido a 1): " r(N)
replace ratio_crt_imp_cmp = 1 if ratio_crt_imp_cmp > 1 & !missing(ratio_crt_imp_cmp)

*8.5. VALIDACIÓN FINAL — DATASET EN UNIDADES ORIGINALES
*-------------------------------------------------------------------------------
* No se aplica winsorización estadística, imputación de missings, log() ni
* z-score. Los missings remanentes en CV interanual y en ratios con
* denominador cero quedan documentados para que la decisión de tratamiento
* se tome en el EDA del dataset integrado.

di _newline(2) "============================================================"
di "DATASET ANALÍTICO F01 — VERIFICACIÓN FINAL (UNIDADES ORIGINALES)"
di "============================================================"
quietly count
di "  N contribuyentes: " r(N)

local vars_finales ///
    tot_v_grav_nta tot_v_grav_brt tot_imp_v_grav tot_imp_iva_vtas_per ///
    tot_v_tc_cdc tot_v_tc_sdc ///
    tot_c_grav_cdc_nta tot_imp_c_cdc tot_c_grav_sdc_nta tot_c_tc_iaf ///
    tot_c_rimpe tot_crt_aplicable ///
    tot_iva_causado tot_iva_pagado tot_iva_total_pagar ///
    tot_ret_recibidas tot_ret_efectuadas tot_multas_int ///
    tot_cve_emitidos tot_cve_anulados tot_cve_recibidos ///
    med_factor_prop med_saldo_crt_acum med_v_grav_nta ///
    cv_v_grav_nta cv_c_grav_cdc_nta cv_iva_pagado cv_ret_recibidas ///
    n_anos_con_vtas n_anos_con_exp_tc_cdc n_anos_con_compras ///
    n_anos_con_retenedor n_anos_con_iva_pagado ///
    ratio_imp_vtas_vtas ratio_crt_imp_cmp ratio_nc_ventas ///
    ratio_anul_emit ratio_pago_causado ratio_saldo_iva_vtas ///
    n_declaraciones n_meses_cubiertos ///
    pct_decl_cero pct_decl_sustitutiva pct_decl_con_mora ///
    pct_decl_anul_alta pct_decl_nc_alta pct_decl_saldo_pos ///
    flg_exportador flg_agente_retenedor flg_compras_rimpe

di _newline "Variable                            N_validos   %Missing   %Cero      Min          P50          Max"
di "----------------------------------------------------------------------------------------------------------"
foreach v of local vars_finales {
    cap quietly {
        count if missing(`v')
        local n_miss = r(N)
        local pct_miss = round(`n_miss'/_N*100, 0.01)
        count if `v' == 0 & !missing(`v')
        local n_cero = r(N)
        count if !missing(`v')
        local n_val = r(N)
        local pct_cero = cond(`n_val' > 0, round(`n_cero'/`n_val'*100, 0.01), .)
        summarize `v', detail
        local vmin = r(min)
        local vp50 = r(p50)
        local vmax = r(max)
    }
    di "  " %-32s "`v'" "  " %9.0f `n_val' "  " %7.2f `pct_miss' "  " ///
       %7.2f `pct_cero' "  " %11.2f `vmin' "  " %11.2f `vp50' "  " %11.2f `vmax'
}

di _newline(2) "NOTA METODOLÓGICA:"
di "Las variables anteriores se entregan en su unidad original (USD, tasas"
di "en [0,1], conteos)."


*8.6. GUARDADO
*-------------------------------------------------------------------------------
compress
save "AF01_perfil_analitico.dta", replace
di _newline "Dataset analítico de F01 guardado en AF01_perfil_analitico.dta"
di "Variables en unidad original — sin transformaciones de escala."
di "Pendiente para EDA conjunto: tratamiento de outliers residuales,"
di "imputación de missings, transformación logarítmica y estandarización."
timer off 1
di _newline(2) "=== TIEMPO TOTAL EJECUCIÓN BLOQUE 7 ==="
timer list 1
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

