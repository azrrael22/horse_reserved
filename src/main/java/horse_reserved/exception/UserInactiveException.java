package horse_reserved.exception;

/**
 * Excepción lanzada cuando se intenta autenticar un usuario inactivo
 */
public class UserInactiveException extends RuntimeException {

    public UserInactiveException(String message) {
        super(message);
    }

    public UserInactiveException(String message, Throwable cause) {
        super(message, cause);
    }
}