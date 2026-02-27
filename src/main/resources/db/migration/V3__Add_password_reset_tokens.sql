-- Migración para añadir la tabla de tokens de restablecimiento de contraseña

CREATE TABLE password_reset_tokens (
    id          BIGSERIAL    PRIMARY KEY,
    token       VARCHAR(255) NOT NULL UNIQUE,
    usuario_id  BIGINT       NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
    expires_at  TIMESTAMP    NOT NULL,
    used        BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  password_reset_tokens              IS 'Tokens de un solo uso para restablecer contraseñas.';
COMMENT ON COLUMN password_reset_tokens.token        IS 'UUID aleatorio generado por el backend.';
COMMENT ON COLUMN password_reset_tokens.expires_at   IS 'Momento de expiración: created_at + 30 minutos.';
COMMENT ON COLUMN password_reset_tokens.used         IS 'TRUE una vez que el token fue utilizado con éxito.';

CREATE INDEX idx_prt_token      ON password_reset_tokens (token);
CREATE INDEX idx_prt_usuario_id ON password_reset_tokens (usuario_id);
