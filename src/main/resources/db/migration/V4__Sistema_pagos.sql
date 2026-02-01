-- =========================
-- Sistema de Pagos
-- =========================

-- Métodos de pago aceptados
CREATE TABLE metodo_pago (
                             id_metodo_pago SERIAL PRIMARY KEY,
                             nombre VARCHAR(50) NOT NULL UNIQUE,
                             codigo VARCHAR(20) NOT NULL UNIQUE, -- EFECTIVO, TARJETA, PSE, NEQUI, etc.
                             descripcion VARCHAR(255),
                             requiere_confirmacion BOOLEAN NOT NULL DEFAULT FALSE,
                             activo BOOLEAN NOT NULL DEFAULT TRUE,
                             icono_url VARCHAR(500),
                             orden_visualizacion INTEGER DEFAULT 0, -- Para ordenar en el frontend
                             created_at TIMESTAMP NOT NULL DEFAULT now(),
                             updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_metodo_pago_activo ON metodo_pago(activo);
CREATE INDEX idx_metodo_pago_orden ON metodo_pago(orden_visualizacion);

-- Políticas de cancelación
CREATE TABLE politica_cancelacion (
                                      id_politica SERIAL PRIMARY KEY,
                                      nombre VARCHAR(100) NOT NULL,
                                      horas_antes_minimo INTEGER NOT NULL CHECK (horas_antes_minimo >= 0),
                                      horas_antes_maximo INTEGER CHECK (horas_antes_maximo IS NULL OR horas_antes_maximo > horas_antes_minimo),
                                      porcentaje_reembolso DECIMAL(5,2) NOT NULL CHECK (porcentaje_reembolso BETWEEN 0 AND 100),
                                      descripcion TEXT,
                                      activo BOOLEAN NOT NULL DEFAULT TRUE,
                                      es_politica_defecto BOOLEAN NOT NULL DEFAULT FALSE,
                                      created_at TIMESTAMP NOT NULL DEFAULT now(),
                                      updated_at TIMESTAMP NOT NULL DEFAULT now(),
                                      CONSTRAINT validar_rangos CHECK (horas_antes_maximo IS NULL OR horas_antes_maximo > horas_antes_minimo)
);

CREATE INDEX idx_politica_activa ON politica_cancelacion(activo);

-- Transacciones de pago
CREATE TABLE pago (
                      id_pago SERIAL PRIMARY KEY,
                      id_reserva INTEGER NOT NULL REFERENCES reserva(id_reserva) ON DELETE CASCADE,
                      id_metodo_pago INTEGER NOT NULL REFERENCES metodo_pago(id_metodo_pago),
                      monto DECIMAL(10,2) NOT NULL CHECK (monto > 0),
                      concepto VARCHAR(255) NOT NULL DEFAULT 'Pago de reserva',
                      estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE', -- PENDIENTE, APROBADO, RECHAZADO, REEMBOLSADO
                      referencia_externa VARCHAR(255), -- ID de transacción de pasarela de pago
                      referencia_interna VARCHAR(100) UNIQUE, -- Código único interno
                      comprobante_url VARCHAR(500),
                      datos_transaccion JSONB, -- Info adicional de la pasarela
                      fecha_pago TIMESTAMP, -- Fecha real de aprobación del pago
                      fecha_reembolso TIMESTAMP,
                      monto_reembolsado DECIMAL(10,2),
                      motivo_rechazo TEXT,
                      usuario_aprueba INTEGER REFERENCES usuario(id_usuario), -- Admin que aprueba
                      notas TEXT,
                      created_at TIMESTAMP NOT NULL DEFAULT now(),
                      updated_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_pago_reserva ON pago(id_reserva);
CREATE INDEX idx_pago_estado ON pago(estado);
CREATE INDEX idx_pago_fecha ON pago(fecha_pago);
CREATE INDEX idx_pago_referencia_externa ON pago(referencia_externa);
CREATE INDEX idx_pago_referencia_interna ON pago(referencia_interna);

-- Historial de cambios de estado de pago
CREATE TABLE pago_historial (
                                id_historial SERIAL PRIMARY KEY,
                                id_pago INTEGER NOT NULL REFERENCES pago(id_pago) ON DELETE CASCADE,
                                estado_anterior VARCHAR(30),
                                estado_nuevo VARCHAR(30) NOT NULL,
                                usuario_modifica INTEGER REFERENCES usuario(id_usuario),
                                motivo TEXT,
                                created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_pago_historial_pago ON pago_historial(id_pago);

-- =========================
-- Triggers para sistema de pagos
-- =========================

-- Trigger para actualizar updated_at en metodo_pago
CREATE TRIGGER update_metodo_pago_updated_at BEFORE UPDATE ON metodo_pago
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para actualizar updated_at en politica_cancelacion
CREATE TRIGGER update_politica_updated_at BEFORE UPDATE ON politica_cancelacion
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para actualizar updated_at en pago
CREATE TRIGGER update_pago_updated_at BEFORE UPDATE ON pago
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para registrar cambios de estado en pago
CREATE OR REPLACE FUNCTION registrar_cambio_estado_pago()
    RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado != NEW.estado THEN
        INSERT INTO pago_historial (id_pago, estado_anterior, estado_nuevo, usuario_modifica)
        VALUES (NEW.id_pago, OLD.estado, NEW.estado, NEW.usuario_aprueba);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER registrar_historial_pago
    AFTER UPDATE ON pago
    FOR EACH ROW
EXECUTE FUNCTION registrar_cambio_estado_pago();

-- Trigger para generar referencia interna automáticamente
CREATE OR REPLACE FUNCTION generar_referencia_pago()
    RETURNS TRIGGER AS $$
BEGIN
    IF NEW.referencia_interna IS NULL THEN
        NEW.referencia_interna := 'PAG-' || TO_CHAR(now(), 'YYYYMMDD') || '-' || LPAD(NEW.id_pago::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER generar_referencia_pago_trigger
    BEFORE INSERT ON pago
    FOR EACH ROW
EXECUTE FUNCTION generar_referencia_pago();

-- Trigger para validar que solo haya una política por defecto activa
CREATE OR REPLACE FUNCTION validar_politica_defecto()
    RETURNS TRIGGER AS $$
DECLARE
    politicas_defecto INTEGER;
BEGIN
    IF NEW.es_politica_defecto = TRUE AND NEW.activo = TRUE THEN
        SELECT COUNT(*) INTO politicas_defecto
        FROM politica_cancelacion
        WHERE es_politica_defecto = TRUE
          AND activo = TRUE
          AND id_politica != NEW.id_politica;

        IF politicas_defecto > 0 THEN
            RAISE EXCEPTION 'Ya existe una política de cancelación por defecto activa';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_politica_defecto_trigger
    BEFORE INSERT OR UPDATE ON politica_cancelacion
    FOR EACH ROW
EXECUTE FUNCTION validar_politica_defecto();
