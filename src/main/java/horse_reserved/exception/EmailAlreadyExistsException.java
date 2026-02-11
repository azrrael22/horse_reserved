package horse_reserved.exception;

/**
 * Excepción lanzada cuando se intenta registrar un usuario con un email que ya existe
 */
public class EmailAlreadyExistsException extends RuntimeException {

    public EmailAlreadyExistsException(String message) {
        super(message);
    }

    public EmailAlreadyExistsException(String message, Throwable cause) {
        super(message, cause);
    }
}