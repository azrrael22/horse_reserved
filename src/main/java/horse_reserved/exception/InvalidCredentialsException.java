package horse_reserved.exception;

/**
 * Excepción lanzada cuando las credenciales de autenticación son inválidas
 */
public class InvalidCredentialsException extends RuntimeException {

    public InvalidCredentialsException(String message) {
        super(message);
    }

    public InvalidCredentialsException(String message, Throwable cause) {
        super(message, cause);
    }
}