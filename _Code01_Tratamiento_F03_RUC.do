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
log using "Log01_F03_RUC_Codebooks.txt", text replace

/*******************************************************************************
  DESCRIPCIÓN: Procesamiento inicial de la fuente F03 — RUC, establecimientos
               y actividades de los establecimientos.
  FUENTES    : F03 — F03_RUC_FULL_20260605.txt           (catastro RUC)
               F03 — F03_RUC_ESTABLECIMIENTOS.txt        (establecimientos)
               F03 — F03_RUC_ESTABLECIMIENTOS_ACTIVIDADES.txt (actividades)
  SALIDA     : AF03_perfil_contribuyente.dta — una fila por contribuyente con las
               variables analíticas seleccionadas para el clustering.
               Logs: "Log01_F03_RUC_Codebooks.txt"
                     "Log02_F03_RUC_01_Variables_analiticas.txt"
*******************************************************************************/

* BLOQUE 1: Lectura y estadísticos iniciales para toma de decisiones
*==============================================================================

* 0. CONFIGURACIÓN DEL ENTORNO
*-----------------------------------------------------------------------------
clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* 1. Lectura del RUC
*-------------------------------------------------------------------------------

* Base 1 — datos generales del RUC
*------------------------------------------------------------------------------
import delimited "F03_RUC_FULL_20260605.txt", varnames(1) stringcols(_all) clear
ren numero_ruc ID0
merge 1:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen
ren (fecha_inicio_actividades fecha_inscripcion fecha_suspension_def) (f1 f2 f3)
gen fecha_inicio_actividades = date(f1, "YMD")
gen fecha_inscripcion = date(f2, "YMD")
gen fecha_suspension_def = date(f3, "YMD")
format fecha_inicio_actividades fecha_inscripcion fecha_suspension_def %td
drop f1 f2 f3 ID0
order ID fecha_inicio_actividades fecha_inscripcion fecha_suspension_def, first
describe
codebook
save t0f03_ruc, replace

* Base 2 — establecimientos del RUC
*-------------------------------------------------------------------------
import delimited "F03_RUC_ESTABLECIMIENTOS.txt", varnames(1) stringcols(_all) clear
ren numero_ruc ID0
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen
ren (fecha_inicio_actividades fecha_cierre) (f1 f2)
gen fecha_inicio_actividades = date(f1, "YMD")
gen fecha_cierre = date(f2, "YMD")
format fecha_inicio_actividades fecha_cierre %td
order ID fecha_inicio_actividades fecha_cierre, first
drop f1 f2 ID0
ren numero_establecimiento ID_establecimiento
tab tipo_establecimiento
replace tipo_establecimiento = "OTR" if inlist(tipo_establecimiento,"ELE","EMB","LCT","TRA")
describe
codebook
save t0f03_est, replace 

* Base 3 — actividades económicas de los establecimientos
*-------------------------------------------------------------------------
import delimited "F03_RUC_ESTABLECIMIENTOS_ACTIVIDADES.txt", varnames(1) stringcols(_all) clear
ren numero_ruc ID0
ren establecimiento ID_establecimiento
merge m:1 ID0 using AF00_F01F03_seleccion1, keep(3) nogen
replace actividad_economica = substr(actividad_economica, 1, 7)
duplicates drop
order ID ID_establecimiento, first
describe
codebook
save t0f03_est_activ, replace

* Estadísticos auxiliares para toma de decisiones
gen num_actividades = 1

* Por RUC
preserve
    keep ID actividad_economica num*
    duplicates drop   // actividades únicas en cualquier establecimiento
    collapse (sum) num_*, by(ID)
    describe
    codebook
    summarize num_*
    return list
restore

* Por establecimiento
preserve
    duplicates drop
    collapse (sum) num_*, by(ID ID_establecimiento)
    describe
    codebook
    summarize num_*
    return list
restore
log close

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close 
log using "Log02_F03_RUC_01_Variables_analiticas.txt", text replace

* BLOQUE 2: Construcción de variables analíticas
*==============================================================================

clear all
set more off, permanently
set type double, permanently
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"

* Globals
global fcorte = td(31dec2025)
global fmin   = td(01jan1970)   // umbral inferior de saneamiento
global f24m   = td(01jan2024)   // ventana últimos 24 meses

* Base 1. RUC — saneamiento, banderas y tipología DIC_AREA
*-------------------------------------------------------------------------------
use t0f03_ruc, clear

* 1.1 Saneamiento de fechas extremas
*-------------------------------------------------------------------------------
* Se eliminan fechas anteriores al SRI moderno y posteriores al corte.
replace fecha_inicio_actividades = . if ///
    fecha_inicio_actividades < $fmin | fecha_inicio_actividades > $fcorte
replace fecha_inscripcion        = . if ///
    fecha_inscripcion < $fmin | fecha_inscripcion > $fcorte
replace fecha_suspension_def     = . if ///
    fecha_suspension_def < $fmin | fecha_suspension_def > $fcorte

* 1.2 Banderas binarias dicotómicas
*-------------------------------------------------------------------------------
* Convención: campo vacío equivale a NO.
* Nota: flag_gran_contrib y flag_grupo_econ se han eliminado del dataset
* analítico por prevalencia <0,1% en el universo filtrado (613 y 111
* registros respectivamente). Si se requieren para reporte ejecutivo de
* élite, recuperarlos en cruce ad-hoc posterior.
gen byte flag_rimpe           = (codigo_opera_clase_contrib == "RMP")
gen byte flag_especial        = (codigo_opera_clase_contrib == "ESP")
gen byte flag_obligado_contab = (obligado == "S")
gen byte flag_artesano        = inlist(codigo_opera_tipo_artesano, "1","2","3")
gen byte flag_gran_contrib    = (gran_contribuyente == "SI")

label var flag_rimpe            "1 si RIMPE (Emprendedores; Negocios Populares ya excluidos)"
label var flag_especial         "1 si Contribuyente Especial"
label var flag_obligado_contab  "1 si obligado a llevar contabilidad"
label var flag_artesano         "1 si calificación artesanal (MIPRO/JNDA/Otro)"
label var flag_gran_contrib     "1 si Gran Contribuyente (caracterización post-clustering)"

* 1.3 Estado del RUC (variable de estratificación)
*-------------------------------------------------------------------------------
gen estado_ruc = codigo_opera_estado_contrib
label var estado_ruc "Estado contribuyente: ACT/PAS/SDE"

* 1.4 Tipología derivada de codigo_opera_area (DIC_AREA)
*-------------------------------------------------------------------------------
* Estructura del diccionario oficial del SRI:
*   1 dígito  -> tipo    (1=PN, 2=Sociedad)
*   2 dígitos -> subtipo (11/12 PN, 21 privado, 24 popular y solidario)
*   3 dígitos -> grupo   (211 Supercía, 212 Superbancos, 213 Otras, 215 ONG)
* IMPORTANTE: el catastro guarda el código truncado a "1" para personas
* naturales comunes. Por tanto NO es posible distinguir PN ecuatoriano de
* extranjero desde F03 (los antiguos flag_pn_ecuatoriano y flag_pn_extranjero
* quedaban en cero universal y se han eliminado). Esto se declara como
* limitación de la fuente en el capítulo 8 (sección 8.1) del TFM.


gen tipo_contrib    = substr(codigo_opera_area, 1, 1)
gen subtipo_contrib = substr(codigo_opera_area, 1, 2)
gen grupo_contrib   = substr(codigo_opera_area, 1, 3)

label var tipo_contrib    "Tipo SRI: 1=Persona Natural, 2=Sociedad"
label var subtipo_contrib "Subtipo (11/12/21/24 en universo filtrado)"
label var grupo_contrib   "Grupo a 3 dígitos del DIC_AREA"

gen byte flag_persona_natural    = (tipo_contrib == "1")
gen byte flag_sociedad           = (tipo_contrib == "2")
gen byte flag_sector_privado     = (subtipo_contrib == "21")
gen byte flag_popular_solidario  = (subtipo_contrib == "24")
gen byte flag_bajo_supercia      = (grupo_contrib == "211")
gen byte flag_sin_fines_lucro    = (grupo_contrib == "215")

label var flag_persona_natural   "1 si persona natural"
label var flag_sociedad          "1 si sociedad (jurídica)"
label var flag_sector_privado    "1 si sociedad del sector privado"
label var flag_popular_solidario "1 si sociedad de economía popular y solidaria"
label var flag_bajo_supercia     "1 si bajo control de la Superintendencia de Compañías"
label var flag_sin_fines_lucro   "1 si sociedad u ONG privada sin fines de lucro"

* Verificación: en el universo filtrado no deberían aparecer subtipos 22 o 23.
qui count if inlist(subtipo_contrib, "22","23")
local incons = r(N)
if `incons' > 0 {
    di as error "ALERTA: `incons' contribuyentes con subtipo 22 o 23 — revisar filtro previo."
}

* 1.5 Antigüedades (en años, base 31dec2025)
*-------------------------------------------------------------------------------
gen float antig_actividad    = ($fcorte - fecha_inicio_actividades)/365.25
gen float antig_inscripcion  = ($fcorte - fecha_inscripcion)/365.25
gen float gap_inicio_inscr   = fecha_inscripcion - fecha_inicio_actividades

* Tratamiento de gap_inicio_inscr con valores anómalos:
* El log evidenció min=-9.659 días (~26 años de "inscripción anterior al
* inicio de actividades"). Se considera anómalo cualquier desfase negativo
* superior a 1 año — se trunca a missing para no contaminar el modelo.
replace gap_inicio_inscr = . if gap_inicio_inscr < -365

label var antig_actividad   "Años desde inicio de actividades al 31dic2025"
label var antig_inscripcion "Años desde inscripción al 31dic2025"
label var gap_inicio_inscr  "Días entre inicio de actividades e inscripción (-365 a +inf)"

* 1.6 Suspensión definitiva
*-------------------------------------------------------------------------------
gen byte flag_suspendido_def     = !missing(fecha_suspension_def)
gen float anios_desde_suspension = ($fcorte - fecha_suspension_def)/365.25 ///
    if flag_suspendido_def == 1
label var flag_suspendido_def    "1 si tiene suspensión definitiva válida"
label var anios_desde_suspension "Años desde la suspensión definitiva"

* 1.7 CIIU del RUC: sección (letra) y división (2 dígitos numéricos)
*-------------------------------------------------------------------------------
gen ciiu_seccion_ruc = substr(codigo_opera_actividad_eco, 1, 1)
gen ciiu_2dig_ruc    = substr(codigo_opera_actividad_eco, 2, 2)
replace ciiu_seccion_ruc = "" if missing(codigo_opera_actividad_eco)
replace ciiu_2dig_ruc    = "" if missing(codigo_opera_actividad_eco)

* 1.8 Conservar codigo_opera_parroquia para auditoría (no se mantiene en final).
* La provincia y región se construyen desde ESTABLECIMIENTOS (matriz),
* por consistencia con la información geográfica operativa.

* 1.9 Descartar variables con cobertura insuficiente o por minimización LOPDP.
*-------------------------------------------------------------------------------
drop identifica_contador tipo_identifica_contador ///
     identifica_rep_legal tipo_identifica_rep_legal

keep ID fecha_inicio_actividades fecha_inscripcion fecha_suspension_def ///
     flag_rimpe flag_especial flag_obligado_contab flag_artesano flag_gran_contrib ///
     estado_ruc ///
     tipo_contrib subtipo_contrib grupo_contrib ///
     flag_persona_natural flag_sociedad ///
     flag_sector_privado flag_popular_solidario ///
     flag_bajo_supercia flag_sin_fines_lucro ///
     antig_actividad antig_inscripcion gap_inicio_inscr ///
     flag_suspendido_def anios_desde_suspension ///
     ciiu_seccion_ruc ciiu_2dig_ruc

tempfile ruc_clean
save `ruc_clean'


* Base 2. ESTABLECIMIENTOS — colapso a una fila por ID
*-------------------------------------------------------------------------------
use t0f03_est, clear

* 2.1 Saneamiento de fechas
*-------------------------------------------------------------------------------
replace fecha_inicio_actividades = . if ///
    fecha_inicio_actividades < $fmin | fecha_inicio_actividades > $fcorte
replace fecha_cierre = . if ///
    fecha_cierre < $fmin | fecha_cierre > $fcorte

* 2.2 Banderas a nivel de establecimiento
*-------------------------------------------------------------------------------
gen byte est_abierto = (estado_establecimiento == "ABI")
gen byte est_cerrado = (estado_establecimiento == "CER")
gen byte tipo_LOC    = (tipo_establecimiento == "LOC")
gen byte tipo_MAT    = (tipo_establecimiento == "MAT")
gen byte tipo_OTROS  = inlist(tipo_establecimiento, "OFI","BOD","ADM","SUC","OTR")

* 2.3 Cierres y aperturas en los últimos 24 meses
*-------------------------------------------------------------------------------
gen byte cierre_24m   = (fecha_cierre >= $f24m & fecha_cierre <= $fcorte) ///
                        & !missing(fecha_cierre)
gen byte apertura_24m = (fecha_inicio_actividades >= $f24m & ///
                         fecha_inicio_actividades <= $fcorte) ///
                        & !missing(fecha_inicio_actividades)

* 2.4 Códigos territoriales agregables (DIC_UBICACION)
*-------------------------------------------------------------------------------
* Estructura confirmada por el diccionario oficial:
*   1 dígito  -> región    (1=COSTA, 2=SIERRA, 3=AMAZONÍA, 4=INSULAR)
*   1-3 díg.  -> provincia (107=EL ORO, 206=CHIMBORAZO, etc.)
*   1-5 díg.  -> cantón    (10707=HUAQUILLAS, 20601=RIOBAMBA)
*   1-7 díg.  -> parroquia (los 7 dígitos completos)
gen reg  = substr(ubicacion_geografica, 1, 1)
gen prov = substr(ubicacion_geografica, 1, 3)
gen cant = substr(ubicacion_geografica, 1, 5)
gen parr = ubicacion_geografica

* 2.5 Información específica del establecimiento matriz
*-------------------------------------------------------------------------------
preserve
    keep if tipo_MAT == 1
    keep ID fecha_inicio_actividades prov reg
    rename fecha_inicio_actividades fecha_inicio_matriz
    rename prov prov_matriz
    rename reg  region_matriz
    gen float antig_matriz = ($fcorte - fecha_inicio_matriz)/365.25
    label var antig_matriz   "Años desde inicio del establ. matriz al 31dic2025"
    label var prov_matriz    "Provincia DPA del establecimiento matriz"
    label var region_matriz  "Región (1=Costa, 2=Sierra, 3=Amazonía, 4=Insular)"
    tempfile matriz
    save `matriz'
restore

* 2.6 Conteos por contribuyente
*-------------------------------------------------------------------------------
preserve
    gen n = 1
    collapse (count) n_establ_total = n ///
             (sum)   n_establ_abiertos = est_abierto ///
                     n_establ_cerrados = est_cerrado ///
                     n_locales         = tipo_LOC ///
                     n_oficinas_bodegas= tipo_OTROS ///
                     n_cierres_24m     = cierre_24m ///
                     n_aperturas_24m   = apertura_24m, ///
             by(ID)

    gen float tasa_cierre_establ = n_establ_cerrados / n_establ_total
    gen int   saldo_neto_24m     = n_aperturas_24m - n_cierres_24m
    gen byte  flag_multiestab    = (n_establ_total > 1)

    label var n_establ_total      "N° total de establecimientos del contribuyente"
    label var n_establ_abiertos   "N° de establecimientos abiertos (ABI)"
    label var n_establ_cerrados   "N° de establecimientos cerrados (CER)"
    label var n_locales           "N° de establecimientos tipo LOC"
    label var n_oficinas_bodegas  "N° de establ. tipo OFI/BOD/ADM/SUC/OTR"
    label var n_cierres_24m       "Cierres entre 2024-01-01 y 2025-12-31"
    label var n_aperturas_24m     "Aperturas entre 2024-01-01 y 2025-12-31"
    label var tasa_cierre_establ  "Proporción de establ. cerrados sobre total"
    label var saldo_neto_24m      "Aperturas menos cierres últimos 24 meses"
    label var flag_multiestab     "1 si tiene más de un establecimiento"

    tempfile est_counts
    save `est_counts'
restore

* 2.7 Dispersión geográfica (regiones, provincias, cantones, parroquias)
*-------------------------------------------------------------------------------
preserve
    keep ID reg
    bysort ID reg: keep if _n == 1
    bysort ID: gen n_regiones_distintas = _N
    bysort ID: keep if _n == 1
    keep ID n_regiones_distintas
    label var n_regiones_distintas "N° de regiones naturales con establecimientos"
    tempfile g_reg
    save `g_reg'
restore

preserve
    keep ID prov
    bysort ID prov: keep if _n == 1
    bysort ID: gen n_provincias_distintas = _N
    bysort ID: keep if _n == 1
    keep ID n_provincias_distintas
    label var n_provincias_distintas "N° de provincias distintas con establecimientos"
    tempfile g_prov
    save `g_prov'
restore

preserve
    keep ID cant
    bysort ID cant: keep if _n == 1
    bysort ID: gen n_cantones_distintos = _N
    bysort ID: keep if _n == 1
    keep ID n_cantones_distintos
    label var n_cantones_distintos "N° de cantones distintos con establecimientos"
    tempfile g_cant
    save `g_cant'
restore

preserve
    keep ID parr
    bysort ID parr: keep if _n == 1
    bysort ID: gen n_parroquias_distintas = _N
    bysort ID: keep if _n == 1
    keep ID n_parroquias_distintas
    label var n_parroquias_distintas "N° de parroquias distintas con establecimientos"
    tempfile g_parr
    save `g_parr'
restore

* 2.8 Consolidar perfil de establecimientos
*-------------------------------------------------------------------------------
use `est_counts', clear
merge 1:1 ID using `matriz', nogen keep(1 3)
merge 1:1 ID using `g_reg',  nogen keep(1 3)
merge 1:1 ID using `g_prov', nogen keep(1 3)
merge 1:1 ID using `g_cant', nogen keep(1 3)
merge 1:1 ID using `g_parr', nogen keep(1 3)

gen byte flag_interregional   = (n_regiones_distintas  > 1)
gen byte flag_multiprovincial = (n_provincias_distintas > 1)
label var flag_interregional   "1 si opera en más de una región natural"
label var flag_multiprovincial "1 si opera en más de una provincia"

tempfile est_perfil
save `est_perfil'


* Base 3. ACTIVIDADES DE ESTABLECIMIENTOS — colapso a una fila por ID
*-------------------------------------------------------------------------------
use t0f03_est_activ, clear

gen ciiu_sec = substr(actividad_economica, 1, 1)
gen ciiu_2d  = substr(actividad_economica, 2, 2)

* 3.1 N° de actividades únicas por contribuyente
*-------------------------------------------------------------------------------
preserve
    keep ID actividad_economica
    duplicates drop
    bysort ID: gen n_actividades_unicas_ruc = _N
    bysort ID: keep if _n == 1
    keep ID n_actividades_unicas_ruc
    tempfile act_ruc
    save `act_ruc'
restore

* 3.2 Máximo de actividades únicas por establecimiento
*-------------------------------------------------------------------------------
preserve
    keep ID ID_establecimiento actividad_economica
    duplicates drop
    bysort ID ID_establecimiento: gen n_act_est = _N
    bysort ID ID_establecimiento: keep if _n == 1
    collapse (max) n_actividades_max_establ = n_act_est, by(ID)
    tempfile act_max
    save `act_max'
restore

* 3.3 N° de secciones CIIU distintas por contribuyente
*-------------------------------------------------------------------------------
preserve
    keep ID ciiu_sec
    duplicates drop
    bysort ID: gen n_secciones_ciiu = _N
    bysort ID: keep if _n == 1
    keep ID n_secciones_ciiu
    tempfile act_sec
    save `act_sec'
restore

* 3.4 Sección CIIU modal por contribuyente (para imputar RUC)
*-------------------------------------------------------------------------------
preserve
    keep ID ciiu_sec
    drop if missing(ciiu_sec)
    gen byte _uno = 1
    collapse (sum) freq = _uno, by(ID ciiu_sec)
    bysort ID (freq ciiu_sec): keep if _n == _N
    rename ciiu_sec ciiu_seccion_modal
    keep ID ciiu_seccion_modal
    tempfile act_modal
    save `act_modal'
restore

* 3.5 Consolidar perfil de actividades
*-------------------------------------------------------------------------------
use `act_ruc', clear
merge 1:1 ID using `act_max',   nogen keep(1 3)
merge 1:1 ID using `act_sec',   nogen keep(1 3)
merge 1:1 ID using `act_modal', nogen keep(1 3)

gen byte flag_multiactividad = (n_actividades_unicas_ruc > 1)
label var n_actividades_unicas_ruc "N° actividades únicas declaradas por el contribuyente"
label var n_actividades_max_establ "Máximo de actividades en un único establecimiento"
label var n_secciones_ciiu         "N° de secciones CIIU distintas"
label var flag_multiactividad      "1 si declara más de una actividad"

tempfile act_perfil
save `act_perfil'


* Unificación de bases: merge final — una fila por ID
*==============================================================================
use `ruc_clean', clear
merge 1:1 ID using `est_perfil', nogen keep(1 3)
merge 1:1 ID using `act_perfil', nogen keep(1 3)

* 4.1 Imputación de CIIU sección cuando RUC venía vacío
*-------------------------------------------------------------------------------
replace ciiu_seccion_ruc = ciiu_seccion_modal if ///
    missing(ciiu_seccion_ruc) & !missing(ciiu_seccion_modal)

gen str1 ciiu_seccion = ciiu_seccion_ruc
replace ciiu_seccion = "Z" if missing(ciiu_seccion)
label var ciiu_seccion "Sección CIIU final (Z = no clasificable)"

* 4.2 Banderas sectoriales de alto riesgo (Thackray, Barra y Yost, 2021)
*-------------------------------------------------------------------------------
gen byte flag_construccion = inlist(ciiu_2dig_ruc, "41","42","43")
gen byte flag_comercio     = inlist(ciiu_2dig_ruc, "45","46","47")
gen byte flag_hotel_rest   = inlist(ciiu_2dig_ruc, "55","56")
gen byte flag_sector_alto_riesgo = flag_construccion | flag_comercio | flag_hotel_rest

label var flag_construccion       "CIIU 41-43 (construcción)"
label var flag_comercio           "CIIU 45-47 (comercio)"
label var flag_hotel_rest         "CIIU 55-56 (alojamiento y restaurantes)"
label var flag_sector_alto_riesgo "Sector de alto riesgo (Thackray et al., 2021)"

* 4.3 Tratamiento de missing en variables de conteo
*-------------------------------------------------------------------------------
foreach v of varlist n_establ_total n_establ_abiertos n_establ_cerrados ///
                    n_locales n_oficinas_bodegas n_cierres_24m n_aperturas_24m ///
                    n_regiones_distintas n_provincias_distintas ///
                    n_cantones_distintos n_parroquias_distintas ///
                    n_actividades_unicas_ruc n_actividades_max_establ ///
                    n_secciones_ciiu {
    replace `v' = 0 if missing(`v')
}

* 4.4 Auditoría de contribuyentes sin actividad CIIU asociada
*-------------------------------------------------------------------------------
* En el run anterior, 8 contribuyentes quedaron con n_actividades_unicas_ruc=0
* tras la imputación, pese a tener establecimiento matriz. Se marca con un
* flag para tratamiento posterior (no se excluyen para preservar el universo).
gen byte flag_sin_actividad_ciiu = (n_actividades_unicas_ruc == 0)
label var flag_sin_actividad_ciiu "1 si no tiene actividad CIIU en EST_ACTIV (inconsistencia)"

di _n "Auditoría: contribuyentes sin actividad CIIU declarada"
qui count if flag_sin_actividad_ciiu == 1
di "  -> " r(N) " contribuyente(s) detectado(s)."
if r(N) > 0 & r(N) <= 50 {
    list ID estado_ruc subtipo_contrib flag_suspendido_def ///
         if flag_sin_actividad_ciiu == 1, noobs sep(0)
}

* 4.5 Recalcular flags dependientes una vez imputado
*-------------------------------------------------------------------------------
replace flag_multiestab      = (n_establ_total > 1)            if !missing(n_establ_total)
replace flag_multiactividad  = (n_actividades_unicas_ruc > 1)  if !missing(n_actividades_unicas_ruc)
replace flag_multiprovincial = (n_provincias_distintas > 1)    if !missing(n_provincias_distintas)
replace flag_interregional   = (n_regiones_distintas > 1)      if !missing(n_regiones_distintas)
replace tasa_cierre_establ   = n_establ_cerrados / n_establ_total if n_establ_total > 0

* 4.6 Limpieza final: eliminar variables intermedias del dataset analítico
*-------------------------------------------------------------------------------
drop ciiu_seccion_ruc ciiu_seccion_modal

* 4.7 Ordenar variables del dataset analítico final
*-------------------------------------------------------------------------------
* SRI agrupa las variables por su rol esperado en el modelo.
* El bloque "núcleo clustering" contiene las candidatas a entrar al K-means
* tras transformación (log o z-score). El resto son variables de
* caracterización post-clustering, estratificación o auditoría.
order ID ///
      /* Estratificación y tipología */ ///
      estado_ruc tipo_contrib subtipo_contrib grupo_contrib ///
      flag_persona_natural flag_sociedad ///
      flag_sector_privado flag_popular_solidario ///
      flag_bajo_supercia flag_sin_fines_lucro ///
      /* Régimen y obligaciones */ ///
      flag_rimpe flag_especial flag_obligado_contab flag_artesano flag_gran_contrib ///
      /* Núcleo clustering — trayectoria */ ///
      antig_actividad ///
      /* Caracterización — trayectoria */ ///
      antig_inscripcion antig_matriz gap_inicio_inscr ///
      flag_suspendido_def anios_desde_suspension ///
      /* Núcleo clustering — estructura */ ///
      n_establ_total tasa_cierre_establ ///
      /* Caracterización — estructura */ ///
      n_establ_abiertos n_establ_cerrados n_locales n_oficinas_bodegas ///
      flag_multiestab ///
      /* Núcleo clustering — dinámica reciente */ ///
      n_cierres_24m n_aperturas_24m ///
      /* Caracterización — dinámica reciente */ ///
      saldo_neto_24m ///
      /* Núcleo clustering — geografía */ ///
      n_provincias_distintas ///
      /* Caracterización — geografía */ ///
      region_matriz prov_matriz n_regiones_distintas ///
      n_cantones_distintos n_parroquias_distintas ///
      flag_interregional flag_multiprovincial ///
      /* Núcleo clustering — actividades */ ///
      n_actividades_unicas_ruc n_secciones_ciiu ///
      /* Caracterización — actividades */ ///
      n_actividades_max_establ flag_multiactividad ///
      flag_sin_actividad_ciiu ///
      /* Caracterización — sectorial */ ///
      ciiu_seccion ciiu_2dig_ruc ///
      flag_construccion flag_comercio flag_hotel_rest flag_sector_alto_riesgo

* 4.8 Verificación final
*-------------------------------------------------------------------------------
isid ID
count
describe

* Tabulaciones de control sobre tipología DIC_AREA
di _n "Distribución por tipo de contribuyente:"
tab tipo_contrib, missing
di _n "Distribución por subtipo de contribuyente:"
tab subtipo_contrib, missing
di _n "Distribución por grupo (3 dígitos):"
tab grupo_contrib, missing sort

* Tabulaciones de control sobre tipología DIC_UBICACION
di _n "Distribución por región natural (matriz):"
tab region_matriz, missing
di _n "Distribución por provincia (matriz) — top 10:"
tab prov_matriz, missing sort
di _n "Contribuyentes con operación interregional:"
tab flag_interregional, missing

* Resumen estadístico de variables candidatas al núcleo del clustering
di _n "Distribución de variables candidatas al núcleo del clustering:"
tabstat antig_actividad n_establ_total tasa_cierre_establ ///
        n_cierres_24m n_aperturas_24m ///
        n_provincias_distintas ///
        n_actividades_unicas_ruc n_secciones_ciiu, ///
        statistics(n mean sd min p25 p50 p75 p90 p99 max) col(stat)

codebook, compact
save "AF03_perfil_contribuyente.dta", replace
log close

* Limpieza de archivos intermedios
cap erase "t0f03_ruc.dta"
cap erase "t0f03_est.dta"  
cap erase "t0f03_est_activ.dta"

*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
*$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

cap log close
log using "Log02_F03_RUC_02_Validaciones_complementarias.txt", text replace

*===============================================================================
* Validaciones complementarias sobre AF03_perfil_contribuyente.dta
* Propósito: documentar tres hallazgos para el capítulo de metodología
*            y de limitaciones del TFM.
*===============================================================================

clear all
set more off
local ruta "C:\DTO_ESTUDIOS_E3_1\A_ESTUDIOS\CECG\CECG_CLUSTER"
cd "`ruta'"
use AF03_perfil_contribuyente.dta, clear

*-------------------------------------------------------------------------------
* V1. Cruce estado_ruc x flag_suspendido_def
* Permite distinguir entre contribuyentes con suspensión vigente (SDE) y
* contribuyentes con suspensión histórica reactivada (ACT + suspendido = 1).
* Este desglose es importante para describir un cluster específico de
* "salida y reentrada al sistema" en el capítulo de resultados.
*-------------------------------------------------------------------------------
di _n(2) "V1. estado_ruc x flag_suspendido_def"
di     "----------------------------------------"
tab estado_ruc flag_suspendido_def, missing row

*-------------------------------------------------------------------------------
* V2. Consistencia temporal antig_matriz vs antig_actividad
* La fecha de inicio del establecimiento matriz no debería ser posterior a
* la fecha de inicio de actividades del contribuyente. Si se detectan casos,
* documentar en metodología como error de captura del catastro.
*-------------------------------------------------------------------------------
di _n(2) "V2. Consistencia temporal antig_matriz vs antig_actividad"
di     "----------------------------------------------------------"
gen check_antig = .
replace check_antig = 0 if antig_matriz >= antig_actividad & ///
                           !missing(antig_matriz, antig_actividad)
replace check_antig = 1 if antig_matriz < antig_actividad & ///
                           !missing(antig_matriz, antig_actividad)
label define lcheck 0 "Consistente" 1 "Matriz iniciada después de actividad", replace
label values check_antig lcheck
tab check_antig, missing
di _n "Distribución de la diferencia (años, solo casos inconsistentes):"
gen dif_antig = antig_matriz - antig_actividad if check_antig == 1
summarize dif_antig, detail
drop check_antig dif_antig

*-------------------------------------------------------------------------------
* V3. Top 20 contribuyentes por número de establecimientos
* Los outliers extremos (max = 1.714 establ.) corresponden con alta
* probabilidad a cooperativas, sociedades financieras o grandes redes
* comerciales. Documentar para decidir tratamiento de outliers
* (winsorización al p99) en el preprocesamiento del clustering.
*-------------------------------------------------------------------------------
di _n(2) "V3. Top 20 contribuyentes por número de establecimientos"
di     "--------------------------------------------------------"
preserve
    gsort -n_establ_total
    keep ID estado_ruc subtipo_contrib grupo_contrib ///
         flag_gran_contrib flag_bajo_supercia flag_popular_solidario ///
         ciiu_seccion n_establ_total n_establ_abiertos n_establ_cerrados
    list in 1/20, noobs sep(0) abbrev(12)
restore

*-------------------------------------------------------------------------------
* V4. Distribución de regiones por tipo de contribuyente
* Documenta si la concentración geográfica varía entre PN y sociedades.
* Útil para discutir representatividad territorial en el capítulo de
* resultados.
*-------------------------------------------------------------------------------
di _n(2) "V4. Región matriz x tipo de contribuyente"
di     "------------------------------------------"
tab region_matriz tipo_contrib, missing col

*-------------------------------------------------------------------------------
* V5. Sectores de alto riesgo por tipo de contribuyente
* Permite ver si el perfil sectorial de Thackray et al. (2021) se
* distribuye distinto entre PN y sociedades.
*-------------------------------------------------------------------------------
di _n(2) "V5. Sector de alto riesgo x tipo de contribuyente"
di     "-------------------------------------------------"
tab flag_sector_alto_riesgo tipo_contrib, missing col

log close


*******************************************************************************



