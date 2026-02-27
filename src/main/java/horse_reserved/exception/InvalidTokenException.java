package horse_reserved.exception;

/**
 * Excepción lanzada cuando un token de restablecimiento de contraseña
 * es inválido, ha expirado o ya fue utilizado.
 */
public class InvalidTokenException extends RuntimeException {

    public InvalidTokenException(String message) {
        super(message);
    }

    public InvalidTokenException(String message, Throwable cause) {
        super(message, cause);
    }
}
