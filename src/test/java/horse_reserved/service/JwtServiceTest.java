package horse_reserved.service;

import horse_reserved.model.Rol;
import horse_reserved.model.Usuario;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Instant;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class JwtServiceTest {

    private JwtService jwtService;

    @BeforeEach
    void inicializarServicio() {
        jwtService = new JwtService();
        ReflectionTestUtils.setField(jwtService, "secretKey", "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970");
        ReflectionTestUtils.setField(jwtService, "jwtExpiration", 60_000L);
    }

    /**
     * Verifica que al generar un token se incluyan correctamente
     * el nombre de usuario y los claims adicionales.
     */
    @Test
    void generarToken_deberiaIncluirUsuario_yClaimsAdicionales() {
        UserDetails user = User.withUsername("alice@test.com").password("x").authorities("USER").build();

        String token = jwtService.generateToken(user, Map.of("rol", "CLIENTE"));

        assertThat(jwtService.extractUsername(token)).isEqualTo("alice@test.com");
        String rol = jwtService.extractClaim(token, claims -> claims.get("rol", String.class));
        assertThat(rol).isEqualTo("CLIENTE");
    }

    /**
     * Verifica que un token no sea válido si el username no coincide.
     */
    @Test
    void validarToken_deberiaDevolverFalso_siUsernameDiferente() {
        UserDetails tokenUser = User.withUsername("alice@test.com").password("x").authorities("USER").build();
        UserDetails differentUser = User.withUsername("bob@test.com").password("x").authorities("USER").build();

        String token = jwtService.generateToken(tokenUser);

        assertThat(jwtService.isTokenValid(token, differentUser)).isFalse();
    }

    /**
     * Verifica que un token expirado sea considerado inválido.
     */
    @Test
    void validarToken_deberiaDevolverFalso_siTokenExpirado() {
        ReflectionTestUtils.setField(jwtService, "jwtExpiration", -1L);
        UserDetails user = User.withUsername("alice@test.com").password("x").authorities("USER").build();

        String token = jwtService.generateToken(user);

        assertThat(jwtService.isTokenValid(token, user)).isFalse();
    }

    /**
     * Verifica que un token emitido antes del cambio de contraseña
     * del usuario sea considerado inválido.
     */
    @Test
    void validarToken_deberiaDevolverFalso_siEmitidoAntesCambioContrasena() {
        Usuario usuario = Usuario.builder()
                .email("alice@test.com")
                .passwordHash("hash")
                .role(Rol.CLIENTE)
                .passwordChangedAt(Instant.now().plusSeconds(30))
                .build();

        String token = jwtService.generateToken(usuario);

        assertThat(jwtService.isTokenValid(token, usuario)).isFalse();
    }

    /**
     * Verifica que un token válido y emitido después del cambio de contraseña
     * del usuario sea considerado válido.
     */
    @Test
    void validarToken_deberiaDevolverVerdadero_siTokenValido_yContrasenaActual() {
        Usuario usuario = Usuario.builder()
                .email("alice@test.com")
                .passwordHash("hash")
                .role(Rol.CLIENTE)
                .passwordChangedAt(Instant.EPOCH)
                .build();

        String token = jwtService.generateToken(usuario);

        assertThat(jwtService.isTokenValid(token, usuario)).isTrue();
    }
}