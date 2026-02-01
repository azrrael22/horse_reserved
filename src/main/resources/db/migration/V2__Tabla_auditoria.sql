-- =========================
-- 6. Tabla de auditoría para cambios de estado de reserva
-- =========================

CREATE TABLE reserva_historial (
                                   id_historial SERIAL PRIMARY KEY,
                                   id_reserva INTEGER NOT NULL REFERENCES reserva(id_reserva) ON DELETE CASCADE,
                                   estado_anterior VARCHAR(30),
                                   estado_nuevo VARCHAR(30) NOT NULL,
                                   usuario_modifica INTEGER REFERENCES usuario(id_usuario),
                                   motivo TEXT,
                                   created_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_historial_reserva ON reserva_historial(id_reserva);
