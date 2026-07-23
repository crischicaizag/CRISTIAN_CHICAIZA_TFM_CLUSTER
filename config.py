# config.py
# ============================================================
# TFM — Resistencia fiscal en el IVA (caso ecuatoriano)
# Cristian Edelberto Chicaiza Gualoto — UNIR 2026
# Configuración central del pipeline Python
# ============================================================

from pathlib import Path

# ------------------------------------------------------------
# RUTAS
# ------------------------------------------------------------
ROOT         = Path(r"D:\inf_sri_hist3\z_CLUSTER")
DATA_DIR     = ROOT / "data"
NB_DIR       = ROOT / "notebooks"
OUT_DIR      = ROOT / "outputs"

DTA_FILE     = DATA_DIR / "B00_DATASET_ANALITICO_INTEGRADO.dta"
PARQUET_FILE = DATA_DIR / "B00_DATASET_ANALITICO_INTEGRADO.parquet"

for d in [DATA_DIR, NB_DIR, OUT_DIR]:
    d.mkdir(parents=True, exist_ok=True)

# ------------------------------------------------------------
# UNIVERSO
# ------------------------------------------------------------
N_UNIVERSE = 797_161

# ------------------------------------------------------------
# VARIABLES NÚCLEO DE CLUSTERING
# ------------------------------------------------------------
F01_VARS = [
    "tot_v_grav_nta", "tot_v_grav_brt", "tot_imp_v_grav",
    "tot_v_tc_cdc", "tot_v_tc_sdc",
    "tot_c_grav_cdc_nta", "tot_imp_c_cdc", "tot_c_tc_iaf",
    "tot_crt_aplicable", "tot_iva_causado", "tot_iva_pagado",
    "tot_iva_total_pagar", "tot_ret_recibidas", "tot_multas_int",
    "tot_cve_emitidos", "tot_cve_anulados", "tot_cve_recibidos",
    "med_saldo_crt_acum", "med_v_grav_nta", "med_factor_prop",
    "ratio_imp_vtas_vtas", "ratio_crt_imp_cmp", "ratio_nc_ventas",
    "ratio_anul_emit", "ratio_pago_causado", "ratio_saldo_iva_vtas",
    "cv_v_grav_nta", "cv_c_grav_cdc_nta", "cv_iva_pagado", "cv_ret_recibidas",
    "n_anos_con_vtas", "n_anos_con_exp_tc_cdc", "n_anos_con_compras",
    "n_anos_con_retenedor", "n_anos_con_iva_pagado", "n_meses_cubiertos",
    "pct_decl_cero", "pct_decl_sustitutiva", "pct_decl_con_mora",
    "pct_decl_anul_alta", "pct_decl_nc_alta", "pct_decl_saldo_pos",
]

F02_VARS = [
    "I_ingresos_avg", "margen_operativo_avg", "costos_ingresos_avg",
    "carga_efectiva_ir_avg", "gap_ret_ir_avg", "prop_anios_perdida",
]

F03_VARS = [
    "antig_actividad", "n_establ_total", "tasa_cierre_establ",
    "n_cierres_24m", "n_aperturas_24m", "n_provincias_distintas",
    "n_actividades_unicas_ruc", "n_secciones_ciiu",
]

F04_VARS = [
    "prop_gravado_fe", "ratio_nc_fe", "prop_ventas_cf_fe", "hhi_clientes_fe",
    "prop_compras_grav_fe", "ratio_nc_recibidas_fe", "hhi_proveedores_fe",
]

# prop_nc_f05 excluida — redundante con prop_efectivo_f05 (r=-0.89, Log16)
F05_VARS = [
    "reca_total_f05", "prop_efectivo_f05", "prop_compensa_f05",
    "prop_pagos_tardios_f05", "rezago_medio_f05",
    "cv_reca_mensual_f05", "hhi_reca_f05",
]

# n_periodos_omisos excluida (r=0.95 con tasa_omision, Log16)
# n_omisos_recientes excluida (r=0.91 con tasa_omision_reciente, Log16)
F06_VARS = [
    "tasa_omision", "tasa_tardio", "promedio_dias_demora", "p90_dias_demora",
    "tasa_omision_reciente", "tasa_tardio_reciente",
]

F07_VARS = [
    "tasa_efe_iva_agr", "hhi_iva_agr",
    "tasa_efe_iva_ard", "hhi_iva_ard",
]

CLUSTER_VARS = F01_VARS + F02_VARS + F03_VARS + F04_VARS + F05_VARS + F06_VARS + F07_VARS

# ------------------------------------------------------------
# VARIABLES DE CARACTERIZACIÓN POST-CLUSTERING
# ------------------------------------------------------------
CHARAC_VARS = [
    "roa_avg", "endeudamiento_avg", "apalancamiento_avg",
    "liquidez_avg", "rotacion_avg", "T_Baseimponible_avg",
    "flag_irc_saldo_pagar", "flag_obligado_sin_balance",
    "flag_patrimonio_neg_alguno", "outlier_costos", "obligado",
    "n_establ_abiertos", "n_establ_cerrados",
    "flag_multisociedad", "flag_multilocal", "flag_interregional",
    "tot_facturado_fe", "ventas_cf_fe", "ventas_ruc_fe",
    "n_clientes_ruc_fe", "n_clientes_cf_fe",
    "tot_compras_fe", "n_proveedores_fe",
    "reca_efectivo_f05", "reca_compensa_f05", "reca_nc_f05",
    "reca_importaciones_f05", "n_periodos_pagados_f05",
    "rezago_max_f05", "n_pagos_tardios_f05", "monto_pagos_tardios_f05",
    "n_periodos_obligacion", "n_periodos_omisos", "n_periodos_no_omisos",
    "n_periodos_tardios", "n_periodos_demora_grave",
    "n_omisos_recientes", "n_no_omisos_recientes",
    "base_iva_agr", "ret_iva_agr", "n_lin_iva_agr", "n_contrap_iva_agr",
    "base_iva_ard", "ret_iva_ard", "n_lin_iva_ard", "n_contrap_iva_ard",
    "base_renta_agr", "ret_renta_agr",
    "base_renta_ard", "ret_renta_ard",
]

# ------------------------------------------------------------
# FLAGS DE COBERTURA Y ESTRATIFICACIÓN
# ------------------------------------------------------------
FLAGS_VARS = [
    "flg_sin_perfil_f01",
    "flg_sin_perfil_f02",
    "flag_sin_recaudacion_f05",
    "flg_es_retenedor",
    "flg_es_retenido",
    "flg_emisor_fe",
    "flg_cliente_ruc_fe",
    "flag_persona_natural", "flag_sociedad",
    "flag_rimpe", "flag_especial", "flag_gran_contrib",
    "flag_obligado_contab", "flag_artesano",
    "flag_construccion", "flag_comercio",
    "flag_hoteleria_turismo", "flag_sector_riesgo",
    "flag_suspension_def",
]

# ------------------------------------------------------------
# VARIABLES CATEGÓRICAS
# ------------------------------------------------------------
STRING_VARS = [
    "estado_ruc", "tipo_contrib", "subtipo_contrib",
    "ciiu_seccion", "ciiu_2dig_ruc",
    "region_matriz", "prov_matriz",
    "rol_fe",
]

# ------------------------------------------------------------
# TRANSFORMACIONES PREVIAS A ESTANDARIZACIÓN
# Basado en skewness > 4 confirmado en Log16
# ------------------------------------------------------------
LOG_TRANSFORM_VARS = [
    "I_ingresos_avg", "carga_efectiva_ir_avg",
    "n_establ_total", "n_cierres_24m", "n_aperturas_24m",
    "n_provincias_distintas", "n_actividades_unicas_ruc",
    "reca_total_f05", "rezago_medio_f05",
    "tasa_omision", "costos_ingresos_avg",
    "tot_v_grav_nta", "tot_v_grav_brt", "tot_imp_v_grav",
    "tot_v_tc_cdc", "tot_v_tc_sdc",
    "tot_c_grav_cdc_nta", "tot_imp_c_cdc", "tot_c_tc_iaf",
    "tot_crt_aplicable", "tot_iva_causado", "tot_iva_pagado",
    "tot_iva_total_pagar", "tot_ret_recibidas", "tot_multas_int",
    "tot_cve_emitidos", "tot_cve_anulados", "tot_cve_recibidos",
    "med_saldo_crt_acum", "med_v_grav_nta",
]

# Umbrales de winsorización confirmados en Log16 (P99.5)
WINSOR_PARAMS = {
    "ratio_nc_fe":           0.3167,
    "ratio_nc_recibidas_fe": 0.4525,
}


# Añadir al final de config.py
# ------------------------------------------------------------
# DECISIONES DE TRANSFORMACIÓN CONFIRMADAS EN EDA (02_EDA.ipynb)
# ------------------------------------------------------------

# Grupo B — winsorizar al P99 ANTES de aplicar log(x+1)
# Valores confirmados en celda 23 del notebook EDA
WINSOR_ANTES_LOG = {
    "ratio_anul_emit"     : 0.9286,
    "ratio_pago_causado"  : 96.7939,
    "ratio_saldo_iva_vtas": 31.4766,
}

# Grupo C — variables que van directo a z-score sin log
# (proporciones, tasas, coeficientes de variación, conteos discretos acotados)
NO_LOG_VARS = [
    "med_factor_prop", "ratio_crt_imp_cmp", "cv_v_grav_nta",
    "cv_c_grav_cdc_nta", "cv_iva_pagado", "cv_ret_recibidas",
    "n_anos_con_vtas", "n_anos_con_exp_tc_cdc", "n_anos_con_compras",
    "n_anos_con_retenedor", "n_anos_con_iva_pagado", "n_meses_cubiertos",
    "pct_decl_cero", "pct_decl_sustitutiva", "pct_decl_con_mora",
    "pct_decl_anul_alta", "pct_decl_nc_alta", "pct_decl_saldo_pos",
    "ratio_nc_ventas", "ratio_imp_vtas_vtas",
    "tasa_omision", "tasa_tardio", "tasa_omision_reciente", "tasa_tardio_reciente",
    "promedio_dias_demora", "p90_dias_demora",
    "margen_operativo_avg", "gap_ret_ir_avg", "prop_anios_perdida",
    "prop_gravado_fe", "prop_ventas_cf_fe", "prop_compras_grav_fe",
    "hhi_clientes_fe", "hhi_proveedores_fe",
    "ratio_nc_fe", "ratio_nc_recibidas_fe",
    "prop_efectivo_f05", "prop_compensa_f05", "prop_pagos_tardios_f05",
    "hhi_reca_f05", "cv_reca_mensual_f05",
    "tasa_efe_iva_agr", "hhi_iva_agr", "tasa_efe_iva_ard", "hhi_iva_ard",
]

# ------------------------------------------------------------
# NÚCLEO DEFINITIVO DE CLUSTERING — confirmado en EDA (02_EDA.ipynb)
# 80 originales → 12 eliminadas por redundancia → 68 definitivas
# ------------------------------------------------------------

import json as _json
_ruta_json = DATA_DIR / "cluster_vars_final.json"
if _ruta_json.exists():
    with open(_ruta_json, "r", encoding="utf-8") as _f:
        _vars_json = _json.load(_f)
    CLUSTER_VARS_FINAL     = _vars_json["CLUSTER_VARS_FINAL"]
    LOG_VARS_EN_CLUSTER    = _vars_json["LOG_VARS_EN_CLUSTER"]
    NO_LOG_VARS_EN_CLUSTER = _vars_json["NO_LOG_VARS_EN_CLUSTER"]
    ELIMINADAS_REDUNDANCIA = _vars_json["ELIMINADAS_REDUNDANCIA"]
else:
    raise FileNotFoundError(
        f"No se encontró {_ruta_json.name} en {DATA_DIR}. "
        "Este archivo lo genera 02_EDA.ipynb. "
        "Ejecutar los notebooks en orden: 01 → 02 → 03 → 04 → 05."
    )