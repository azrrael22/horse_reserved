-- =========================
-- 1. Tablas básicas
-- =========================

-- Tipos de documento (CC, Pasaporte, etc.)
CREATE TABLE tipo_documento (
                                id_tipo_doc SERIAL PRIMARY KEY,
                                nombre_tipo VARCHAR(50) NOT NULL UNIQUE,
                                codigo VARCHAR(10) NOT NULL UNIQUE, -- CC, PA, etc.
                                descripcion VARCHAR(255),
                                created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Usuarios (clientes, guías, admins)
CREATE TABLE usuario (
                         id_usuario SERIAL PRIMARY KEY,
                         primer_nombre VARCHAR(50) NOT NULL,
                         segundo_nombre VARCHAR(50),
                         primer_apellido VARCHAR(50) NOT NULL,
                         segundo_apellido VARCHAR(50),
                         genero VARCHAR(20),
                         correo VARCHAR(255) UNIQUE NOT NULL,
                         contrasena VARCHAR(255) NOT NULL, -- BCrypt hash en producción
                         telefono VARCHAR(50),
                         fecha_nacimiento DATE,
                         imagen_usuario_url VARCHAR(500),
                         activo BOOLEAN NOT NULL DEFAULT TRUE,
                         id_tipo_doc INTEGER NOT NULL REFERENCES tipo_documento(id_tipo_doc),
                         numero_documento VARCHAR(50) NOT NULL, -- Número de documento real
                         created_at TIMESTAMP NOT NULL DEFAULT now(),
                         updated_at TIMESTAMP NOT NULL DEFAULT now(),
                         CONSTRAINT usuario_documento_unico UNIQUE (id_tipo_doc, numero_documento)
);

CREATE INDEX idx_usuario_correo ON usuario(correo);
CREATE INDEX idx_usuario_activo ON usuario(activo);

-- Roles (CLIENTE, GUIA, ADMIN)
CREATE TABLE rol (
                     id_rol SERIAL PRIMARY KEY,
                     nombre VARCHAR(50) UNIQUE NOT NULL,
                     descripcion VARCHAR(255),
                     created_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Asignación de roles a usuario (permite múltiples roles)
CREATE TABLE usuario_rol (
                             id_usuario INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
                             id_rol INTEGER NOT NULL REFERENCES rol(id_rol) ON DELETE CASCADE,
                             created_at TIMESTAMP NOT NULL DEFAULT now(),
                             PRIMARY KEY (id_usuario, id_rol)
);

-- Tabla para extender usuario si es guía (datos específicos)
CREATE TABLE guia (
                      id_guia INTEGER PRIMARY KEY REFERENCES usuario(id_usuario) ON DELETE CASCADE,
                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                      telefono_emergencia VARCHAR(50),
                      observaciones TEXT,
                      created_at TIMESTAMP NOT NULL DEFAULT now(),
                      updated_at TIMESTAMP NOT NULL DEFAULT now()
);

-- Caballos
CREATE TABLE caballo (
                         id_caballo SERIAL PRIMARY KEY,
                         nombre VARCHAR(100) NOT NULL,
                         raza VARCHAR(50),
                         edad INTEGER CHECK (edad >= 0),
                         color VARCHAR(50),
                         peso_max_jinete INTEGER, -- Peso máximo recomendado del jinete en kg
                         temperamento VARCHAR(50), -- Tranquilo, Nervioso, Energético, etc.
                         observaciones TEXT,
                         activo BOOLEAN NOT NULL DEFAULT TRUE,
                         imagen_caballo_url VARCHAR(500),
                         created_at TIMESTAMP NOT NULL DEFAULT now(),
                         updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_caballo_activo ON caballo(activo);

-- Rutas de cabalgata (plantilla)
CREATE TABLE ruta_cabalgata (
                                id_ruta SERIAL PRIMARY KEY,
                                nombre VARCHAR(255) NOT NULL,
                                descripcion TEXT,
                                duracion_minutos INTEGER NOT NULL CHECK (duracion_minutos > 0),
                                nivel_dificultad VARCHAR(50), -- Fácil, Intermedio, Difícil
                                distancia_km DECIMAL(5,2),
                                precio_base DECIMAL(10,2), -- Precio por persona
                                activo BOOLEAN NOT NULL DEFAULT TRUE,
                                created_at TIMESTAMP NOT NULL DEFAULT now(),
                                updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_ruta_activa ON ruta_cabalgata(activo);

-- =========================
-- 2. Recorridos programados (slots)
--    Este es el recurso reservable real: fecha + hora_inicio + hora_fin
-- =========================

CREATE TABLE recorrido_programado (
                                      id_recorrido_programado SERIAL PRIMARY KEY,
                                      id_ruta INTEGER NOT NULL REFERENCES ruta_cabalgata(id_ruta) ON DELETE CASCADE,
                                      fecha DATE NOT NULL,
                                      hora_inicio TIME NOT NULL,
                                      hora_fin TIME NOT NULL,
                                      capacidad_total INTEGER NOT NULL CHECK (capacidad_total > 0),
                                      precio_por_persona DECIMAL(10,2), -- Puede ser diferente al precio_base de la ruta
                                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                                      observaciones TEXT,
                                      created_at TIMESTAMP NOT NULL DEFAULT now(),
                                      updated_at TIMESTAMP NOT NULL DEFAULT now(),
                                      CONSTRAINT recorrido_horas CHECK (hora_fin > hora_inicio)
);

CREATE INDEX idx_recorrido_fecha ON recorrido_programado(fecha, hora_inicio, hora_fin);
CREATE INDEX idx_recorrido_activo ON recorrido_programado(activo);
CREATE INDEX idx_recorrido_fecha_activo ON recorrido_programado(fecha, activo);

-- =========================
-- 3. Asignación de guías a recorrido
--    Un recorrido puede tener N guías.
-- =========================

CREATE TABLE recorrido_guia (
                                id_recorrido_programado INTEGER NOT NULL REFERENCES recorrido_programado(id_recorrido_programado) ON DELETE CASCADE,
                                id_guia INTEGER NOT NULL REFERENCES guia(id_guia) ON DELETE CASCADE,
                                es_guia_principal BOOLEAN NOT NULL DEFAULT FALSE,
                                created_at TIMESTAMP NOT NULL DEFAULT now(),
                                PRIMARY KEY (id_recorrido_programado, id_guia)
);

CREATE INDEX idx_recorrido_guia_guia ON recorrido_guia(id_guia);

-- =========================
-- 4. Asignación de caballos a recorrido
--    Para rastrear qué caballos están en qué recorrido
-- =========================

CREATE TABLE recorrido_caballo (
                                   id_recorrido_programado INTEGER NOT NULL REFERENCES recorrido_programado(id_recorrido_programado) ON DELETE CASCADE,
                                   id_caballo INTEGER NOT NULL REFERENCES caballo(id_caballo) ON DELETE CASCADE,
                                   created_at TIMESTAMP NOT NULL DEFAULT now(),
                                   PRIMARY KEY (id_recorrido_programado, id_caballo)
);

CREATE INDEX idx_recorrido_caballo_caballo ON recorrido_caballo(id_caballo);

-- =========================
-- 5. Reservas
--    Varias reservas apuntan al mismo recorrido_programado (compartidas).
-- =========================

CREATE TABLE reserva (
                         id_reserva SERIAL PRIMARY KEY,
                         id_recorrido_programado INTEGER NOT NULL REFERENCES recorrido_programado(id_recorrido_programado) ON DELETE CASCADE,
                         id_cliente INTEGER NOT NULL REFERENCES usuario(id_usuario) ON DELETE CASCADE,
                         cantidad_personas INTEGER NOT NULL CHECK (cantidad_personas > 0),
                         fecha_reserva TIMESTAMP NOT NULL DEFAULT now(),
                         estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE', -- PENDIENTE, CONFIRMADA, CANCELADA, COMPLETADA
                         precio_total DECIMAL(10,2),
                         datos_contacto JSONB, -- Info del grupo: nombres, edades, pesos, etc.
                         observaciones TEXT,
                         codigo_confirmacion VARCHAR(50) UNIQUE, -- Código único para la reserva
                         created_at TIMESTAMP NOT NULL DEFAULT now(),
                         updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_reserva_recorrido ON reserva(id_recorrido_programado);
CREATE INDEX idx_reserva_cliente ON reserva(id_cliente);
CREATE INDEX idx_reserva_estado ON reserva(estado);
CREATE INDEX idx_reserva_codigo ON reserva(codigo_confirmacion);