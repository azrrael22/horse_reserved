-- =========================
-- Requisitos y Restricciones de Rutas
-- =========================

-- Tipos de requisitos (catálogo)
CREATE TABLE tipo_requisito (
                                id_tipo_requisito SERIAL PRIMARY KEY,
                                codigo VARCHAR(50) NOT NULL UNIQUE, -- PESO_MAX, EDAD_MIN, EXPERIENCIA, ALTURA_MIN, etc.
                                nombre VARCHAR(100) NOT NULL,
                                descripcion TEXT,
                                unidad_medida VARCHAR(20), -- kg, años, cm, etc.
                                tipo_valor VARCHAR(20) NOT NULL, -- NUMERICO, BOOLEANO, TEXTO
                                activo BOOLEAN NOT NULL DEFAULT TRUE,
                                created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_tipo_requisito_codigo ON tipo_requisito(codigo);
CREATE INDEX idx_tipo_requisito_activo ON tipo_requisito(activo);

-- Requisitos específicos por ruta
CREATE TABLE requisito_ruta (
                                id_requisito SERIAL PRIMARY KEY,
                                id_ruta INTEGER NOT NULL REFERENCES ruta_cabalgata(id_ruta) ON DELETE CASCADE,
                                id_tipo_requisito INTEGER NOT NULL REFERENCES tipo_requisito(id_tipo_requisito),
                                valor_minimo DECIMAL(10,2),
                                valor_maximo DECIMAL(10,2),
                                valor_texto VARCHAR(255), -- Para requisitos de tipo texto
                                valor_booleano BOOLEAN, -- Para requisitos de tipo booleano
                                es_obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
                                mensaje_validacion TEXT, -- Mensaje personalizado si no cumple el requisito
                                orden_visualizacion INTEGER DEFAULT 0,
                                activo BOOLEAN NOT NULL DEFAULT TRUE,
                                created_at TIMESTAMP NOT NULL DEFAULT now(),
                                updated_at TIMESTAMP NOT NULL DEFAULT now(),
                                CONSTRAINT validar_rango_valores CHECK (
                                    valor_minimo IS NULL OR
                                    valor_maximo IS NULL OR
                                    valor_maximo >= valor_minimo
                                    )
);

CREATE INDEX idx_requisito_ruta ON requisito_ruta(id_ruta);
CREATE INDEX idx_requisito_tipo ON requisito_ruta(id_tipo_requisito);
CREATE INDEX idx_requisito_activo ON requisito_ruta(activo);

-- Versiones de términos y condiciones
CREATE TABLE terminos_condiciones (
                                      id_terminos SERIAL PRIMARY KEY,
                                      version VARCHAR(20) NOT NULL UNIQUE,
                                      titulo VARCHAR(255) NOT NULL,
                                      contenido TEXT NOT NULL,
                                      resumen TEXT, -- Resumen breve para mostrar al usuario
                                      fecha_vigencia DATE NOT NULL,
                                      fecha_fin_vigencia DATE,
                                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                                      es_version_actual BOOLEAN NOT NULL DEFAULT FALSE,
                                      tipo VARCHAR(50) DEFAULT 'GENERAL', -- GENERAL, MENORES, EXTRANJEROS, etc.
                                      idioma VARCHAR(10) DEFAULT 'es',
                                      created_at TIMESTAMP NOT NULL DEFAULT now(),
                                      updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_terminos_activo ON terminos_condiciones(activo);
CREATE INDEX idx_terminos_version_actual ON terminos_condiciones(es_version_actual);
CREATE INDEX idx_terminos_vigencia ON terminos_condiciones(fecha_vigencia, fecha_fin_vigencia);

-- Aceptación de términos por reserva
CREATE TABLE reserva_terminos (
                                  id_reserva_terminos SERIAL PRIMARY KEY,
                                  id_reserva INTEGER NOT NULL REFERENCES reserva(id_reserva) ON DELETE CASCADE,
                                  id_terminos INTEGER NOT NULL REFERENCES terminos_condiciones(id_terminos),
                                  aceptado BOOLEAN NOT NULL DEFAULT FALSE,
                                  ip_aceptacion VARCHAR(50),
                                  user_agent TEXT, -- Navegador/dispositivo usado
                                  fecha_aceptacion TIMESTAMP,
                                  created_at TIMESTAMP NOT NULL DEFAULT now(),
                                  UNIQUE (id_reserva, id_terminos)
);

CREATE INDEX idx_reserva_terminos_reserva ON reserva_terminos(id_reserva);
CREATE INDEX idx_reserva_terminos_terminos ON reserva_terminos(id_terminos);
CREATE INDEX idx_reserva_terminos_aceptado ON reserva_terminos(aceptado);

-- Declaración de salud del participante (para cumplir requisitos)
CREATE TABLE declaracion_salud (
                                   id_declaracion SERIAL PRIMARY KEY,
                                   id_reserva INTEGER NOT NULL REFERENCES reserva(id_reserva) ON DELETE CASCADE,
                                   nombre_participante VARCHAR(255) NOT NULL,
                                   edad INTEGER CHECK (edad > 0),
                                   peso DECIMAL(5,2) CHECK (peso > 0),
                                   altura DECIMAL(5,2) CHECK (altura > 0),
                                   experiencia_previa VARCHAR(50), -- NINGUNA, BASICA, INTERMEDIA, AVANZADA
                                   condiciones_medicas TEXT,
                                   alergias TEXT,
                                   medicamentos_actuales TEXT,
                                   contacto_emergencia VARCHAR(255),
                                   telefono_emergencia VARCHAR(50),
                                   declara_apto BOOLEAN NOT NULL DEFAULT FALSE,
                                   observaciones TEXT,
                                   created_at TIMESTAMP NOT NULL DEFAULT now(),
                                   updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_declaracion_reserva ON declaracion_salud(id_reserva);

-- =========================
-- Triggers para requisitos y restricciones
-- =========================

-- Trigger para actualizar updated_at
CREATE TRIGGER update_requisito_ruta_updated_at BEFORE UPDATE ON requisito_ruta
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_terminos_updated_at BEFORE UPDATE ON terminos_condiciones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_declaracion_updated_at BEFORE UPDATE ON declaracion_salud
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para validar que solo haya una versión actual de términos activa por tipo
CREATE OR REPLACE FUNCTION validar_terminos_version_actual()
    RETURNS TRIGGER AS $$
DECLARE
    versiones_actuales INTEGER;
BEGIN
    IF NEW.es_version_actual = TRUE AND NEW.activo = TRUE THEN
        SELECT COUNT(*) INTO versiones_actuales
        FROM terminos_condiciones
        WHERE es_version_actual = TRUE
          AND activo = TRUE
          AND tipo = NEW.tipo
          AND idioma = NEW.idioma
          AND id_terminos != NEW.id_terminos;

        IF versiones_actuales > 0 THEN
            RAISE EXCEPTION 'Ya existe una versión actual activa de términos para tipo % e idioma %', NEW.tipo, NEW.idioma;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_terminos_version_actual_trigger
    BEFORE INSERT OR UPDATE ON terminos_condiciones
    FOR EACH ROW
EXECUTE FUNCTION validar_terminos_version_actual();

-- Función para validar requisitos de una reserva
CREATE OR REPLACE FUNCTION validar_requisitos_reserva(
    p_id_reserva INTEGER
) RETURNS TABLE(
                   cumple_requisitos BOOLEAN,
                   requisitos_incumplidos TEXT[]
               ) AS $$
DECLARE
    v_id_ruta INTEGER;
    v_requisitos_incumplidos TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Obtener la ruta del recorrido
    SELECT rc.id_ruta INTO v_id_ruta
    FROM reserva r
             JOIN recorrido_programado rp ON r.id_recorrido_programado = rp.id_recorrido_programado
             JOIN ruta_cabalgata rc ON rp.id_ruta = rc.id_ruta
    WHERE r.id_reserva = p_id_reserva;

    -- Por ahora solo retornamos que cumple, la validación real se haría en la aplicación
    -- comparando con las declaraciones de salud
    RETURN QUERY SELECT TRUE, v_requisitos_incumplidos;
END;
$$ LANGUAGE plpgsql;