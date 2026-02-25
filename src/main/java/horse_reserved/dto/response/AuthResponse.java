package horse_reserved.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
/**
 * DTO para el proceso de autenticacion
 */
public class AuthResponse {

    private String token;
    private String type; // "Bearer"
    private Long expiresIn; // Tiempo de expiración en segundos

    // Información del usuario
    private Long userId;
    private String email;
    private String primerNombre;
    private String primerApellido;
    private String role;
}