package horse_reserved.service;

import horse_reserved.exception.InvalidTokenException;
import horse_reserved.model.PasswordResetToken;
import horse_reserved.model.Rol;
import horse_reserved.model.Usuario;
import horse_reserved.repository.PasswordResetTokenRepository;
import horse_reserved.repository.UsuarioRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class PasswordResetServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private PasswordResetTokenRepository tokenRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private EmailService emailService;

    @InjectMocks
    private PasswordResetService passwordResetService;

    private Usuario localUser;

    @BeforeEach
    void inicializarUsuario() {
        localUser = Usuario.builder()
                .id(10L)
                .email("cliente@test.com")
                .primerNombre("Ana")
                .passwordHash("hash-anterior")
                .role(Rol.CLIENTE)
                .build();
    }

    /**
     * Verifica que el proceso de "olvidé mi contraseña" termine silenciosamente
     * si el correo no existe en la base de datos.
     */
    @Test
    void procesarOlvideContrasena_deberiaTerminarSilencioso_siCorreoNoExiste() {
        when(usuarioRepository.findByEmail("missing@test.com")).thenReturn(Optional.empty());

        passwordResetService.processForgotPassword("missing@test.com");

        verify(tokenRepository, never()).invalidatePreviousTokens(any());
        verify(tokenRepository, never()).save(any());
        verify(emailService, never()).sendPasswordResetEmail(any(), any(), any());
    }

    /**
     * Verifica que el proceso de "olvidé mi contraseña" termine silenciosamente
     * para usuarios OAuth que no tienen contraseña.
     */
    @Test
    void procesarOlvideContrasena_deberiaTerminarSilencioso_siUsuarioOAuthSinPassword() {
        Usuario oauthUser = Usuario.builder()
                .id(12L)
                .email("oauth@test.com")
                .primerNombre("OAuth")
                .passwordHash("")
                .role(Rol.CLIENTE)
                .build();

        when(usuarioRepository.findByEmail("oauth@test.com")).thenReturn(Optional.of(oauthUser));

        passwordResetService.processForgotPassword("oauth@test.com");

        verify(tokenRepository, never()).invalidatePreviousTokens(any());
        verify(tokenRepository, never()).save(any());
        verify(emailService, never()).sendPasswordResetEmail(any(), any(), any());
    }

    /**
     * Verifica que el proceso de "olvidé mi contraseña" invalide tokens previos,
     * persista el nuevo token y envíe el correo correctamente.
     */
    @Test
    void procesarOlvideContrasena_deberiaInvalidarPersistirYEnviarEmail_siUsuarioValido() {
        when(usuarioRepository.findByEmail(localUser.getEmail())).thenReturn(Optional.of(localUser));

        ArgumentCaptor<PasswordResetToken> tokenCaptor = ArgumentCaptor.forClass(PasswordResetToken.class);
        passwordResetService.processForgotPassword(localUser.getEmail());

        verify(tokenRepository).invalidatePreviousTokens(localUser);
        verify(tokenRepository).save(tokenCaptor.capture());
        PasswordResetToken savedToken = tokenCaptor.getValue();

        assertThat(savedToken.getUsuario()).isEqualTo(localUser);
        assertThat(savedToken.getToken()).isNotBlank();
        assertThat(savedToken.getUsed()).isFalse();
        assertThat(savedToken.getExpiresAt())
                .isAfter(LocalDateTime.now().plusMinutes(4))
                .isBefore(LocalDateTime.now().plusMinutes(6));

        verify(emailService).sendPasswordResetEmail(
                localUser.getEmail(),
                localUser.getPrimerNombre(),
                savedToken.getToken()
        );
    }

    /**
     * Verifica que resetear la contraseña falle si el token no existe.
     */
    @Test
    void resetearContrasena_deberiaFallar_siTokenNoExiste() {
        when(tokenRepository.findByToken("invalid-token")).thenReturn(Optional.empty());

        assertThatThrownBy(() -> passwordResetService.resetPassword("invalid-token", "nueva123"))
                .isInstanceOf(InvalidTokenException.class);

        verify(usuarioRepository, never()).save(any());
    }

    /**
     * Verifica que resetear la contraseña falle si el token no es válido
     * (por expiración o ya usado).
     */
    @Test
    void resetearContrasena_deberiaFallar_siTokenNoValido() {
        PasswordResetToken expiredToken = PasswordResetToken.builder()
                .token("expired")
                .usuario(localUser)
                .expiresAt(LocalDateTime.now().minusMinutes(1))
                .used(false)
                .build();
        when(tokenRepository.findByToken("expired")).thenReturn(Optional.of(expiredToken));

        assertThatThrownBy(() -> passwordResetService.resetPassword("expired", "nueva123"))
                .isInstanceOf(InvalidTokenException.class);

        verify(usuarioRepository, never()).save(any());
    }

    /**
     * Verifica que resetear la contraseña con un token válido actualice la contraseña,
     * marque el token como usado y persista los cambios.
     */
    @Test
    void resetearContrasena_deberiaActualizarPassword_marcarTokenComoUsado_yPersistir() {
        PasswordResetToken validToken = PasswordResetToken.builder()
                .token("valid")
                .usuario(localUser)
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .used(false)
                .build();

        when(tokenRepository.findByToken("valid")).thenReturn(Optional.of(validToken));
        when(passwordEncoder.encode("nueva123")).thenReturn("encoded-password");

        Instant beforeReset = Instant.now();
        passwordResetService.resetPassword("valid", "nueva123");

        assertThat(localUser.getPasswordHash()).isEqualTo("encoded-password");
        assertThat(localUser.getPasswordChangedAt()).isAfter(beforeReset.minusSeconds(1));
        assertThat(validToken.getUsed()).isTrue();

        verify(usuarioRepository).save(localUser);
        verify(tokenRepository).save(validToken);
    }
}