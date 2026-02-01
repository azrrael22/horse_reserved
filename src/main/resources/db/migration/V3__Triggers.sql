-- =========================
-- 7. Triggers
-- =========================

-- Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a todas las tablas con updated_at
CREATE TRIGGER update_usuario_updated_at BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_guia_updated_at BEFORE UPDATE ON guia
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_caballo_updated_at BEFORE UPDATE ON caballo
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_ruta_updated_at BEFORE UPDATE ON ruta_cabalgata
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recorrido_updated_at BEFORE UPDATE ON recorrido_programado
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_reserva_updated_at BEFORE UPDATE ON reserva
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger para validar capacidad del recorrido
CREATE OR REPLACE FUNCTION validar_capacidad_recorrido()
    RETURNS TRIGGER AS $$
DECLARE
    capacidad_total INTEGER;
    personas_reservadas INTEGER;
BEGIN
    -- Obtener capacidad total del recorrido
    SELECT rp.capacidad_total INTO capacidad_total
    FROM recorrido_programado rp
    WHERE rp.id_recorrido_programado = NEW.id_recorrido_programado;

    -- Calcular personas ya reservadas (excluyendo canceladas)
    SELECT COALESCE(SUM(r.cantidad_personas), 0) INTO personas_reservadas
    FROM reserva r
    WHERE r.id_recorrido_programado = NEW.id_recorrido_programado
      AND r.estado NOT IN ('CANCELADA')
      AND (TG_OP = 'INSERT' OR r.id_reserva != NEW.id_reserva);

    -- Validar que no se exceda la capacidad
    IF (personas_reservadas + NEW.cantidad_personas) > capacidad_total THEN
        RAISE EXCEPTION 'No hay capacidad suficiente. Capacidad: %, Reservadas: %, Solicitadas: %',
            capacidad_total, personas_reservadas, NEW.cantidad_personas;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_capacidad_reserva
    BEFORE INSERT OR UPDATE ON reserva
    FOR EACH ROW
    WHEN (NEW.estado NOT IN ('CANCELADA'))
EXECUTE FUNCTION validar_capacidad_recorrido();

-- Trigger para validar que un guía no tenga solapamiento de horarios
CREATE OR REPLACE FUNCTION validar_solapamiento_guia()
    RETURNS TRIGGER AS $$
DECLARE
    recorridos_solapados INTEGER;
    fecha_recorrido DATE;
    hora_inicio_recorrido TIME;
    hora_fin_recorrido TIME;
BEGIN
    -- Obtener datos del recorrido
    SELECT rp.fecha, rp.hora_inicio, rp.hora_fin
    INTO fecha_recorrido, hora_inicio_recorrido, hora_fin_recorrido
    FROM recorrido_programado rp
    WHERE rp.id_recorrido_programado = NEW.id_recorrido_programado;

    -- Verificar si el guía ya tiene un recorrido en ese horario
    SELECT COUNT(*) INTO recorridos_solapados
    FROM recorrido_guia rg
             JOIN recorrido_programado rp ON rg.id_recorrido_programado = rp.id_recorrido_programado
    WHERE rg.id_guia = NEW.id_guia
      AND rp.fecha = fecha_recorrido
      AND rp.activo = TRUE
      AND rg.id_recorrido_programado != NEW.id_recorrido_programado
      AND (
        -- Solapamiento de horarios
        (rp.hora_inicio < hora_fin_recorrido AND rp.hora_fin > hora_inicio_recorrido)
        );

    IF recorridos_solapados > 0 THEN
        RAISE EXCEPTION 'El guía ya tiene un recorrido asignado en ese horario';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validar_solapamiento_guia_trigger
    BEFORE INSERT OR UPDATE ON recorrido_guia
    FOR EACH ROW
EXECUTE FUNCTION validar_solapamiento_guia();

-- Trigger para registrar cambios de estado en historial
CREATE OR REPLACE FUNCTION registrar_cambio_estado_reserva()
    RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.estado != NEW.estado THEN
        INSERT INTO reserva_historial (id_reserva, estado_anterior, estado_nuevo, usuario_modifica)
        VALUES (NEW.id_reserva, OLD.estado, NEW.estado, NULL); -- usuario_modifica se puede setear desde la app
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER registrar_historial_reserva
    AFTER UPDATE ON reserva
    FOR EACH ROW
EXECUTE FUNCTION registrar_cambio_estado_reserva();