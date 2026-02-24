package horse_reserved.controller;

import horse_reserved.dto.request.LoginRequest;
import horse_reserved.dto.request.RegisterRequest;
import horse_reserved.dto.response.AuthResponse;
import horse_reserved.dto.response.UserProfileResponse;
import horse_reserved.dto.request.ChangePasswordRequest;
import horse_reserved.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@CrossOrigin(origins = "${cors.allowed-origins}")
public class AuthController {

    private final AuthService authService;

    /**
     * Endpoint para registrar un nuevo cliente
     * POST /api/auth/register
     */
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@Valid @RequestBody RegisterRequest request) {
        AuthResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Endpoint para autenticar un usuario
     * POST /api/auth/login
     */
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        AuthResponse response = authService.login(request);
        return ResponseEntity.ok(response);
    }

    /**
     * Retorna el perfil del usuario autenticado
     * GET /api/auth/me
     * Requiere: Bearer token válido en el header Authorization
     */
    @GetMapping("/me")
    public ResponseEntity<UserProfileResponse> getCurrentUser() {
        UserProfileResponse profile = authService.getCurrentUser();
        return ResponseEntity.ok(profile);
    }

    /**
     * Cambia la contraseña del usuario autenticado
     * PUT /api/auth/change-password
     * Requiere: Bearer token válido
     */
    @PutMapping("/change-password")
    public ResponseEntity<String> changePassword(@Valid @RequestBody ChangePasswordRequest request) {
        authService.changePassword(request);
        return ResponseEntity.ok("Contraseña actualizada correctamente");
    }
}
