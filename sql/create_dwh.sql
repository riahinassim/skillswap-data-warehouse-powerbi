-- SkillSwap Tunisia : Data Warehouse (PostgreSQL 17)
-- Schéma en étoile : 5 dimensions + 2 tables de faits
-- Structure uniquement : les données sont chargées par les jobs Talend
-- Clés _dw = clés de substitution ; clés _src = clés de la base source


-- Rôle de lecture utilisé par Power BI (créé s'il n'existe pas)
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'bi_user') THEN
        CREATE ROLE bi_user;
    END IF;
END
$$;

-- ---------------------------
-- DIMENSIONS
-- ---------------------------

CREATE TABLE public.dim_categories (
    id_categorie_dw  SERIAL PRIMARY KEY,
    id_categorie_src INTEGER,
    nom_categorie    VARCHAR(100)
);

CREATE TABLE public.dim_competences (
    id_competence_dw  SERIAL PRIMARY KEY,
    id_competence_src INTEGER,
    nom_competence    VARCHAR(100),
    nom_categorie     VARCHAR(100),
    id_categorie_dw   INTEGER
);

CREATE TABLE public.dim_quartiers (
    id_quartier_dw  SERIAL PRIMARY KEY,
    id_quartier_src INTEGER,
    nom_quartier    VARCHAR(100)
);

CREATE TABLE public.dim_temps (
    id_temps      SERIAL PRIMARY KEY,
    date_complete DATE,
    jour          INTEGER,
    nom_jour      VARCHAR(20),
    mois          INTEGER,
    nom_mois      VARCHAR(20),
    trimestre     INTEGER,
    semaine       INTEGER,
    annee         INTEGER,
    est_weekend   BOOLEAN
);

CREATE TABLE public.dim_utilisateurs (
    id_utilisateur_dw  SERIAL PRIMARY KEY,
    id_utilisateur_src INTEGER,
    nom_complet        VARCHAR(100),
    email              VARCHAR(150),
    nom_quartier       VARCHAR(100),
    solde_credits      INTEGER,
    est_bloque         BOOLEAN,
    role               VARCHAR(20),
    date_inscription   DATE
);

-- ---------------------------
-- FAITS
-- ---------------------------

CREATE TABLE public.fact_echanges (
    id_fait_echange    SERIAL PRIMARY KEY,
    id_temps           INTEGER,
    id_emetteur        INTEGER,
    id_receveur        INTEGER,
    id_competence      INTEGER,
    id_quartier        INTEGER,
    duree_heures       INTEGER,
    statut             VARCHAR(20),
    credits_transferes INTEGER,
    date_demande       TIMESTAMP,
    id_echange_src     INTEGER NOT NULL
);

CREATE TABLE public.fact_profil_competences (
    id_fait_profil SERIAL PRIMARY KEY,
    id_utilisateur INTEGER,
    id_competence  INTEGER,
    id_temps       INTEGER,
    type_relation  VARCHAR(20),
    niveau         VARCHAR(50),
    id_profil_src  INTEGER
);

-- ---------------------------
-- DROITS DE LECTURE POUR POWER BI
-- ---------------------------

GRANT USAGE ON SCHEMA public TO bi_user;
GRANT SELECT ON
    public.dim_categories,
    public.dim_competences,
    public.dim_quartiers,
    public.dim_temps,
    public.dim_utilisateurs,
    public.fact_echanges,
    public.fact_profil_competences
TO bi_user;