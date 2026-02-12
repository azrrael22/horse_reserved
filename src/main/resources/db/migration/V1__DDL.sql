CREATE TYPE rol_usuario AS ENUM (
    'cliente',
    'operador',
    'administrador'
    );

CREATE TYPE reserva_estado AS ENUM (
    'reservado',
    'en_curso',
    'cancelado',
    'completado'
    );

CREATE TYPE salida_estado AS ENUM (
    'programado',
    'en_curso',
    'completado',
    'cancelado'
    );

CREATE TYPE nivel_dificultad AS ENUM (
    'facil',
    'moderado',
    'dificil'
    );

CREATE TYPE tipo_documento AS ENUM (
    'cedula',
    'pasaporte',
    'tarjeta_identidad'
    );

-- =============================================================
--  TABLA: usuarios
-- =============================================================

CREATE TABLE usuarios (
                          id                  BIGSERIAL       PRIMARY KEY,
                          primer_nombre       VARCHAR(100)    NOT NULL,
                          primer_apellido     VARCHAR(100)    NOT NULL,
                          tipo_documento      tipo_documento  NOT NULL,
                          documento           VARCHAR(50)     NOT NULL,
                          email               VARCHAR(200)    NOT NULL UNIQUE,
                          password_hash       VARCHAR(255)    NOT NULL,
                          telefono            VARCHAR(20),
                          role                rol_usuario     NOT NULL DEFAULT 'cliente',
                          is_active           BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE  usuarios               IS 'Usuarios del sistema: clientes, operadores y administradores.';
COMMENT ON COLUMN usuarios.password_hash IS 'Contraseña almacenada con hash.';

-- =============================================================
--  TABLA: rutas
-- =============================================================

CREATE TABLE rutas (
                       id                  BIGSERIAL           PRIMARY KEY,
                       nombre              VARCHAR(150)        NOT NULL,
                       descripcion         TEXT,
                       dificultad          nivel_dificultad    NOT NULL,
                       duracion_minutos    INT                 NOT NULL CHECK (duracion_minutos > 0),
                       max_caballos        INT                 NOT NULL CHECK (max_caballos > 0),
                       min_guias           INT                 NOT NULL DEFAULT 1 CHECK (min_guias > 0),
                       image_url           VARCHAR(500),
                       is_active           BOOLEAN             NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE  rutas                  IS 'Rutas turísticas. Solo los administradores pueden crearlas.';
COMMENT ON COLUMN rutas.max_caballos       IS 'Capacidad máxima de personas (= caballos) por salida.';
COMMENT ON COLUMN rutas.min_guias       IS 'Guías mínimos requeridos para realizar la salida.';
COMMENT ON COLUMN rutas.duracion_minutos IS 'Duración estimada en minutos; determina la hora de fin de cada salida.';

-- =============================================================
--  TABLA: caballos
-- =============================================================

CREATE TABLE caballos
(
    id          BIGSERIAL       PRIMARY KEY,
    nombre      VARCHAR(100)    NOT NULL,
    raza        VARCHAR(100),
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE caballos IS 'Recurso: caballos disponibles para las rutas.';

-- =============================================================
--  TABLA: guias
-- =============================================================

CREATE TABLE guias (
                       id          BIGSERIAL       PRIMARY KEY,
                       nombre      VARCHAR(100)    NOT NULL,
                       telefono    VARCHAR(20),
                       email       VARCHAR(150),
                       is_active   BOOLEAN         NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE guias IS 'Recurso: guías turísticos.';

-- =============================================================
--  TABLA: salidas
--  Una "salida" = una ruta en una fecha y hora concreta.
--  Múltiples reservas pueden unirse a la misma salida.
--  Los recursos se asignan aquí, no en cada reserva.
-- =============================================================

CREATE TABLE salidas (
                         id                  BIGSERIAL       PRIMARY KEY,
                         ruta_id             BIGINT          NOT NULL REFERENCES rutas (id),
                         fecha_programada    DATE            NOT NULL,
                         tiempo_inicio       TIME            NOT NULL,
                         tiempo_fin          TIME            NOT NULL,
                         estado              salida_estado   NOT NULL DEFAULT 'programado',
                         CONSTRAINT chk_salida_tipo CHECK (tiempo_fin > tiempo_inicio)
);

COMMENT ON TABLE  salidas          IS 'Salida concreta (ruta + fecha + hora). Agrupa reservas que viajan juntas.';
COMMENT ON COLUMN salidas.tiempo_fin IS 'tiempo_inicio + duration_minutes de la ruta. Calculado al crear la salida.';

-- =============================================================
--  TABLA: salida_caballos
--  Caballos asignados a una salida (total <= routes.max_horses)
-- =============================================================

CREATE TABLE salida_caballos (
                                 id          BIGSERIAL   PRIMARY KEY,
                                 salida_id   BIGINT      NOT NULL REFERENCES salidas (id) ON DELETE CASCADE,
                                 horse_id    BIGINT      NOT NULL REFERENCES caballos (id),
                                 CONSTRAINT uq_salida_caballo UNIQUE (salida_id, horse_id)
);

COMMENT ON TABLE salida_caballos IS 'Caballos asignados a una salida. Cantidad <= routes.max_horses.';

-- =============================================================
--  TABLA: salida_guias
--  Guías asignados a una salida (total >= routes.min_guides)
-- =============================================================

CREATE TABLE salida_guias (
                              id          BIGSERIAL   PRIMARY KEY,
                              salida_id   BIGINT      NOT NULL REFERENCES salidas (id) ON DELETE CASCADE,
                              guia_id     BIGINT      NOT NULL REFERENCES guias (id),
                              CONSTRAINT uq_salida_guia UNIQUE (salida_id, guia_id)
);

COMMENT ON TABLE salida_guias IS 'Guías asignados a una salida. Cantidad >= routes.min_guides.';

-- =============================================================
--  TABLA: reservaciones
-- =============================================================

CREATE TABLE reservaciones (
                               id            BIGSERIAL          PRIMARY KEY,
                               salida_id     BIGINT             NOT NULL REFERENCES salidas (id),
                               client_id     BIGINT             NOT NULL REFERENCES usuarios (id),
                               operator_id   BIGINT             REFERENCES usuarios (id),
                               num_people    INT                NOT NULL DEFAULT 1 CHECK (num_people > 0),
                               estado        reserva_estado     NOT NULL DEFAULT 'reservado'
);

COMMENT ON TABLE  reservaciones             IS 'Reserva de un grupo para una salida específica.';
COMMENT ON COLUMN reservaciones.operator_id IS 'NULL si el cliente reservó directamente; si no, el operador que gestionó la reserva.';
COMMENT ON COLUMN reservaciones.num_people  IS 'Cantidad de personas en el grupo. Debe coincidir con los registros en participantes.';

-- =============================================================
--  TABLA: participantes
--  Datos personales de cada integrante de una reserva.
--  Debe haber exactamente num_people registros por reserva.
-- =============================================================

CREATE TABLE participantes (
                               id                  BIGSERIAL       PRIMARY KEY,
                               reservacion_id      BIGINT          NOT NULL REFERENCES reservaciones (id) ON DELETE CASCADE,
                               primer_nombre       VARCHAR(100)    NOT NULL,
                               primer_apellido     VARCHAR(100)    NOT NULL,
                               tipo_documento      tipo_documento  NOT NULL,
                               documento           VARCHAR(50)     NOT NULL,
                               edad                SMALLINT        NOT NULL CHECK (edad > 0 AND edad < 120),
                               altura_cm           SMALLINT        NOT NULL CHECK (altura_cm > 0),
                               peso_kg             NUMERIC(5,2)    NOT NULL CHECK (peso_kg > 0),

                               CONSTRAINT uq_participant_doc UNIQUE (reservacion_id, tipo_documento, documento)
);

COMMENT ON TABLE  participantes                 IS 'Datos personales de cada integrante de una reserva.';
COMMENT ON COLUMN participantes.altura_cm       IS 'Estatura en centímetros (ej. 170).';
COMMENT ON COLUMN participantes.peso_kg       IS 'Peso en kilogramos con hasta 2 decimales (ej. 75.50).';
COMMENT ON COLUMN participantes.documento IS 'Número de cédula, pasaporte o tarjeta de identidad.';


