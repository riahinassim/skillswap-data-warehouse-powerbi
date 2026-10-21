-- SkillSwap Tunisia : base source applicative (PostgreSQL 17)
-- Structure uniquement, sans aucune donnée

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

CREATE TABLE public.categories (
    id_categorie  SERIAL PRIMARY KEY,
    nom_categorie VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE public.competences (
    id_competence  SERIAL PRIMARY KEY,
    nom_competence VARCHAR(100) NOT NULL,
    id_categorie   INTEGER REFERENCES public.categories(id_categorie) ON DELETE CASCADE
);

CREATE TABLE public.quartiers (
    id_quartier  SERIAL PRIMARY KEY,
    nom_quartier VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE public.utilisateurs (
    id_utilisateur   SERIAL PRIMARY KEY,
    nom_complet      VARCHAR(100) NOT NULL,
    email            VARCHAR(150) NOT NULL UNIQUE,
    mot_de_passe     VARCHAR(255) NOT NULL,
    role             VARCHAR(20) DEFAULT 'utilisateur',
    id_quartier      INTEGER REFERENCES public.quartiers(id_quartier) ON DELETE SET NULL,
    solde_credits    INTEGER DEFAULT 5,
    est_bloque       BOOLEAN DEFAULT false,
    date_inscription TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT utilisateurs_role_check
        CHECK (role IN ('utilisateur', 'administrateur'))
);

CREATE TABLE public.echanges (
    id_echange        SERIAL PRIMARY KEY,
    id_emetteur       INTEGER REFERENCES public.utilisateurs(id_utilisateur),
    id_receveur       INTEGER REFERENCES public.utilisateurs(id_utilisateur),
    id_competence     INTEGER REFERENCES public.competences(id_competence),
    date_demande      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_session      TIMESTAMP,
    duree_heures      INTEGER DEFAULT 1,
    statut            VARCHAR(20) DEFAULT 'en_attente',
    commentaire_admin TEXT,
    heures_utilisees  INTEGER DEFAULT 0,
    CONSTRAINT echanges_statut_check
        CHECK (statut IN ('en_attente', 'accepte', 'refuse', 'termine', 'annule', 'en_cours'))
);

CREATE TABLE public.profil_competences (
    id_profil      SERIAL PRIMARY KEY,
    id_utilisateur INTEGER REFERENCES public.utilisateurs(id_utilisateur) ON DELETE CASCADE,
    id_competence  INTEGER REFERENCES public.competences(id_competence) ON DELETE CASCADE,
    type_relation  VARCHAR(20) NOT NULL,
    description    TEXT,
    niveau         VARCHAR(50),
    CONSTRAINT profil_competences_type_relation_check
        CHECK (type_relation IN ('proposee', 'recherchee')),
    UNIQUE (id_utilisateur, id_competence, type_relation)
);

CREATE TABLE public.notifications (
    id_notification SERIAL PRIMARY KEY,
    id_utilisateur  INTEGER NOT NULL REFERENCES public.utilisateurs(id_utilisateur) ON DELETE CASCADE,
    type            VARCHAR(50) NOT NULL,
    id_echange      INTEGER,
    message         TEXT NOT NULL,
    lu              BOOLEAN DEFAULT false,
    date_creation   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE public.signalements (
    id_signalement   SERIAL PRIMARY KEY,
    id_auteur        INTEGER REFERENCES public.utilisateurs(id_utilisateur),
    id_cible         INTEGER REFERENCES public.utilisateurs(id_utilisateur),
    motif            TEXT NOT NULL,
    date_signalement TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    traite           BOOLEAN DEFAULT false
);

-- Index
CREATE INDEX idx_competence_nom     ON public.competences (nom_competence);
CREATE INDEX idx_quartier_nom       ON public.quartiers (nom_quartier);
CREATE INDEX idx_user_email         ON public.utilisateurs (email);
CREATE INDEX idx_notifications_user ON public.notifications (id_utilisateur, date_creation DESC);