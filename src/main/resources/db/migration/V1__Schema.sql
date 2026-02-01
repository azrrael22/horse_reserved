-- =========================
-- 1. Tablas básicas
-- =========================

-- Tipos de documento
CREATE TABLE tipo_documento (
                                id_tipo_doc SERIAL PRIMARY KEY,
                                nombre_tipo VARCHAR(255) NOT NULL
);

-- Documentos de identidad (catálogo)
CREATE TABLE documento_identidad (
                                     id_documento_identidad SERIAL PRIMARY KEY,
                                     documento VARCHAR(255) NOT NULL,
                                     id_tipo_doc INTEGER NOT NULL REFERENCES tipo_documento(id_tipo_doc)
);

-- Usuarios (clientes, guías, admins) -- contrasena aquí es solo un campo; en producción guarda hash
CREATE TABLE usuario (
                         id_usuario SERIAL PRIMARY KEY,
                         primer_nombre VARCHAR(50) NOT NULL,
                         primer_apellido VARCHAR(50) NOT NULL,
                         genero VARCHAR(20),
                         correo VARCHAR(255) UNIQUE NOT NULL,
                         contrasena VARCHAR(255) NOT NULL,
                         telefono VARCHAR(50),
                         fecha_nacimiento DATE,
                         imagen_usuario_url VARCHAR(500),
                         activo BOOLEAN NOT NULL DEFAULT TRUE,
                         id_tipo_doc INTEGER NOT NULL REFERENCES tipo_documento(id_tipo_doc)
);

-- Roles (CLIENTE, GUIA, ADMIN)
CREATE TABLE rol (
                     id_rol SERIAL PRIMARY KEY,
                     nombre VARCHAR(50) UNIQUE NOT NULL
);

-- Asignación de roles a usuario (permite múltiples roles)
CREATE TABLE usuario_rol (
                             id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario),
                             id_rol INTEGER NOT NULL REFERENCES rol(id_rol),
                             PRIMARY KEY (id_usuario, id_rol)
);

-- Tabla para extender usuario si es guía (datos específicos)
CREATE TABLE guia (
                      id_guia INTEGER PRIMARY KEY REFERENCES usuario(id_usuario),
                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                      telefono_emergencia VARCHAR(50),
                      observaciones TEXT
);

-- Caballos
CREATE TABLE caballo (
                         id_caballo SERIAL PRIMARY KEY,
                         nombre VARCHAR(100) NOT NULL,
                         raza VARCHAR(50),
                         edad INTEGER,
                         color VARCHAR(50),
                         observaciones TEXT,
                         activo BOOLEAN NOT NULL DEFAULT TRUE,
                         imagen_caballo_url VARCHAR(500)
);

-- Rutas de cabalgata (plantilla)
CREATE TABLE ruta_cabalgata (
                                id_ruta SERIAL PRIMARY KEY,
                                nombre VARCHAR(255) NOT NULL,
                                descripcion TEXT,
                                duracion_minutos INTEGER NOT NULL, -- duración estimada
                                nivel_dificultad VARCHAR(50)
);

-- =========================
-- 2. Recorridos programados (slots)
--    Este es el recurso reservable real: fecha + hora_inicio + hora_fin
-- =========================

CREATE TABLE recorrido_programado (
                                      id_recorrido_programado SERIAL PRIMARY KEY,
                                      id_ruta INTEGER NOT NULL REFERENCES ruta_cabalgata(id_ruta),
                                      fecha DATE NOT NULL,
                                      hora_inicio TIME NOT NULL,
                                      hora_fin TIME NOT NULL,
                                      capacidad_total INTEGER NOT NULL CHECK (capacidad_total > 0), -- número de caballos / personas máximo
                                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                                      observaciones TEXT,
                                      CONSTRAINT recorrido_horas CHECK (hora_fin > hora_inicio)
);

CREATE INDEX idx_recorrido_fecha ON recorrido_programado(fecha, hora_inicio, hora_fin);

-- =========================
-- 3. Asignación de guías a recorrido
--    Un recorrido puede tener N guías. Se valida solapamiento con trigger.
-- =========================

CREATE TABLE recorrido_guia (
                                id_recorrido_programado INTEGER NOT NULL REFERENCES recorrido_programado(id_recorrido_programado) ON DELETE CASCADE,
                                id_guia INTEGER NOT NULL REFERENCES guia(id_guia) ON DELETE CASCADE,
                                PRIMARY KEY (id_recorrido_programado, id_guia)
);

-- =========================
-- 4. Reservas
--    Varias reservas apuntan al mismo recorrido_programado (compartidas).
-- =========================

CREATE TABLE reserva (
                         id_reserva SERIAL PRIMARY KEY,
                         id_recorrido_programado INTEGER NOT NULL REFERENCES recorrido_programado(id_recorrido_programado) ON DELETE CASCADE,
                         id_cliente INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
                         cantidad_personas INTEGER NOT NULL CHECK (cantidad_personas > 0),
                         fecha_reserva TIMESTAMP NOT NULL DEFAULT now(),
                         estado VARCHAR(30) NOT NULL DEFAULT 'ACTIVA', -- ACTIVA, CANCELADA, FINALIZADA, etc.
                         datos_contacto JSONB, -- opcional: info del grupo
                         CHECK (cantidad_personas > 0)
);

CREATE INDEX idx_reserva_recorrido ON reserva(id_recorrido_programado);