-- 1. Colonne calculée (table 'public dim_temps')
-- La table doit être marquée comme table de dates.

Date = DATE('public dim_temps'[annee], 'public dim_temps'[mois], 'public dim_temps'[jour])


-- 2. Cartes KPI

-- Carte 1 : Échanges réalisés
Nb échanges = COUNTROWS('public fact_echanges')

-- Carte 2 : Échanges aboutis
Nb échanges terminés =
CALCULATE([Nb échanges], 'public fact_echanges'[statut] = "termine")

Taux de réussite = DIVIDE([Nb échanges terminés], [Nb échanges])

-- Carte 3 : Membres actifs
Utilisateurs actifs =
COUNTROWS(
    DISTINCT(
        UNION(
            VALUES('public fact_echanges'[id_emetteur]),
            VALUES('public fact_echanges'[id_receveur])
        )
    )
)

Total utilisateurs = COUNTROWS(ALL('public dim_utilisateurs'))

Taux d'activation = DIVIDE([Utilisateurs actifs], [Total utilisateurs])

-- Carte 4 : Offre pour 1 demande
-- L'offre et la demande sont un stock : elles ignorent le segment Période.
Compétences proposées =
CALCULATE(
    COUNTROWS('public fact_profil_competences'),
    'public fact_profil_competences'[type_relation] = "proposee",
    REMOVEFILTERS('public dim_temps')
) + 0

Compétences recherchées =
CALCULATE(
    COUNTROWS('public fact_profil_competences'),
    'public fact_profil_competences'[type_relation] = "recherchee",
    REMOVEFILTERS('public dim_temps')
) + 0

Ratio O/D global = DIVIDE([Compétences proposées], [Compétences recherchées])

-- Carte 5 : Catalogue jamais échangé
-- Indicateur global : les segments sont désactivés sur cette carte.
Compétences sans échange =
COUNTROWS(
    FILTER(
        ALL('public dim_competences'[id_competence_dw]),
        CALCULATE([Nb échanges], REMOVEFILTERS('public dim_temps')) = 0
    )
)

Total compétences catalogue = COUNTROWS(ALL('public dim_competences'))

Part compétences dormantes =
DIVIDE([Compétences sans échange], [Total compétences catalogue])


-- 3. Échanges par mois et par année
-- Comparaison 2026 vs 2025 à dates égales, indépendante du segment Période.

Échanges 2026 YTD =
VAR fin = TODAY()
RETURN
CALCULATE([Nb échanges], REMOVEFILTERS('public dim_temps'),
    'public dim_temps'[Date] >= DATE(2026,1,1),
    'public dim_temps'[Date] <= fin)

Échanges 2025 YTD =
VAR fin = EDATE(TODAY(), -12)
RETURN
CALCULATE([Nb échanges], REMOVEFILTERS('public dim_temps'),
    'public dim_temps'[Date] >= DATE(2025,1,1),
    'public dim_temps'[Date] <= fin)

Variation 2026 vs 2025 =
DIVIDE([Échanges 2026 YTD] - [Échanges 2025 YTD], [Échanges 2025 YTD])

Titre évolution =
VAR v = [Variation 2026 vs 2025]
RETURN
"Les échanges " & IF(v >= 0, "progressent de ", "reculent de ")
    & FORMAT(ABS(v), "0%") & " en 2026 vs 2025 " & IF(v >= 0, "▲", "▼")

-- Info-bulle de ce visuel (chaque mesure s'évalue dans le mois et l'année survolés)
Tooltip échanges = [Nb échanges]

Tooltip échanges N-1 =
VAR a = SELECTEDVALUE('public dim_temps'[annee])
VAR m = SELECTEDVALUE('public dim_temps'[mois])
RETURN
IF(ISBLANK(a) || ISBLANK(m), BLANK(),
    CALCULATE([Nb échanges], REMOVEFILTERS('public dim_temps'),
        'public dim_temps'[annee] = a - 1,
        'public dim_temps'[mois] = m))

Tooltip variation % =
DIVIDE([Tooltip échanges] - [Tooltip échanges N-1], [Tooltip échanges N-1])

Tooltip évolution texte =
VAR v = [Tooltip variation %]
VAR a = SELECTEDVALUE('public dim_temps'[annee])
RETURN
IF(ISBLANK(v), "Pas de mois équivalent en " & (a - 1),
    IF(v > 0, "▲ +", IF(v < 0, "▼ ", "► ")) & FORMAT(v, "0%")
        & " vs même mois " & (a - 1) & " (" & [Tooltip échanges N-1] & ")")

Tooltip part de l'année =
DIVIDE([Nb échanges],
    CALCULATE([Nb échanges], ALLEXCEPT('public dim_temps', 'public dim_temps'[annee])))

Tooltip titre =
VAR m = SELECTEDVALUE('public dim_temps'[nom_mois])
VAR a = SELECTEDVALUE('public dim_temps'[annee])
RETURN
IF(ISBLANK(m) || ISBLANK(a), "Échanges",
    UPPER(LEFT(m, 1)) & MID(m, 2, 20) & " " & a)


-- 4. Crédits transférés par mois

Crédits transférés = SUM('public fact_echanges'[credits_transferes])

Crédits mois pic =
MAXX(ALLSELECTED('public dim_temps'[nom_mois]), [Crédits transférés])

Mois pic =
VAR t = ADDCOLUMNS(VALUES('public dim_temps'[nom_mois]), "@c", [Crédits transférés])
VAR maxi = MAXX(t, [@c])
RETURN CONCATENATEX(FILTER(t, [@c] = maxi), 'public dim_temps'[nom_mois], ", ")

Titre crédits =
"Les crédits culminent en " & [Mois pic] & " (" & [Crédits mois pic] & " crédits)"


-- 5. Échanges par quartier
-- Le total ignore le filtre Top N du visuel pour que les pourcentages restent exacts.
-- Le titre s'adapte au nombre de quartiers sélectionnés (aucun, un seul, plusieurs).

Top 2 résumé =
VAR t =
    FILTER(
        ADDCOLUMNS(
            ALLSELECTED('public dim_quartiers'[nom_quartier]),
            "@n", [Nb échanges]
        ),
        [@n] > 0
    )
VAR nb = COUNTROWS(t)
VAR total = CALCULATE([Nb échanges], REMOVEFILTERS('public dim_quartiers'))
VAR top2 = TOPN(2, t, [@n], DESC)
VAR noms = CONCATENATEX(top2, 'public dim_quartiers'[nom_quartier], " et ", [@n], DESC)
RETURN
SWITCH(
    TRUE(),
    nb = 0, "Aucun échange pour cette sélection",
    nb = 1,
        MAXX(t, 'public dim_quartiers'[nom_quartier]) & " représente "
            & FORMAT(DIVIDE(MAXX(t, [@n]), total), "0%")
            & " des échanges (" & MAXX(t, [@n]) & " sur " & total & ")",
    noms & " : " & FORMAT(DIVIDE(SUMX(top2, [@n]), total), "0%") & " des échanges"
)

Pied quartiers =
"Total tous quartiers : "
    & CALCULATE([Nb échanges], REMOVEFILTERS('public dim_quartiers'))
    & " échanges"


-- 6. Échanges par compétence (Top 8)
-- Le total retire seulement le filtre sur nom_competence (segment Compétence et Top N)
-- mais conserve Région et Catégorie.
-- Le titre s'adapte au nombre de compétences affichées.

Compétences actives =
COUNTROWS(FILTER(ALL('public dim_competences'[nom_competence]), [Nb échanges] > 0))

Top 8 part % =
VAR t =
    FILTER(
        ADDCOLUMNS(ALLSELECTED('public dim_competences'[nom_competence]), "@n", [Nb échanges]),
        [@n] > 0
    )
VAR total = CALCULATE([Nb échanges], REMOVEFILTERS('public dim_competences'[nom_competence]))
RETURN DIVIDE(SUMX(TOPN(8, t, [@n], DESC), [@n]), total)

Compétence n°1 =
VAR t = ADDCOLUMNS(ALLSELECTED('public dim_competences'[nom_competence]), "@n", [Nb échanges])
VAR maxi = MAXX(t, [@n])
RETURN CONCATENATEX(FILTER(t, [@n] = maxi), 'public dim_competences'[nom_competence], " et ")

Titre compétences =
VAR t =
    FILTER(
        ADDCOLUMNS(
            ALLSELECTED('public dim_competences'[nom_competence]),
            "@n", [Nb échanges]
        ),
        [@n] > 0
    )
VAR nb = COUNTROWS(t)
VAR pct = FORMAT([Top 8 part %], "0%")
RETURN
SWITCH(
    TRUE(),
    nb = 0, "Aucun échange pour cette sélection",
    nb = 1, MAXX(t, 'public dim_competences'[nom_competence])
                & " représente " & pct & " des échanges de la sélection",
    nb < 8, "Les " & nb & " compétences affichées pèsent " & pct
                & " des échanges de la sélection",
    [Compétence n°1] & " domine, et le top 8 pèse " & pct & " des échanges"
)


-- 7. Écart offre - demande par catégorie
-- L'offre et la demande sont un stock : elles ignorent le segment Période.

Écart nb = [Compétences proposées] - [Compétences recherchées]

Écart offre-demande =
VAR e = [Écart nb]
VAR p = DIVIDE(e, [Compétences recherchées])
RETURN e & IF(ISBLANK(p), "", "  (" & FORMAT(p, "0%") & ")")

Catégorie en tension =
VAR t =
    FILTER(
        ADDCOLUMNS(ALLSELECTED('public dim_categories'[nom_categorie]), "@e", [Écart nb]),
        NOT ISBLANK([@e])
    )
VAR mini = MINX(t, [@e])
RETURN
IF(mini >= 0, BLANK(),
    CONCATENATEX(FILTER(t, [@e] = mini), 'public dim_categories'[nom_categorie], " et "))

Titre offre demande =
IF(ISBLANK([Catégorie en tension]),
    "Aucune catégorie en déficit d'offre",
    [Catégorie en tension] & " manque le plus d'offre")