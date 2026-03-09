package horse_reserved.service;

import horse_reserved.dto.request.ChangePasswordRequest;
import horse_reserved.dto.request.LoginRequest;
import horse_reserved.dto.request.RegisterRequest;
import horse_reserved.dto.response.AuthResponse;
import horse_reserved.exception.EmailAlreadyExistsException;
import horse_reserved.exception.InvalidCredentialsException;
import horse_reserved.exception.UserInactiveException;
import horse_reserved.model.Rol;
import horse_reserved.model.TipoDocumento;
import horse_reserved.model.Usuario;
import horse_reserved.repository.UsuarioRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UsuarioRepository usuarioRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @Mock
    private AuthenticationManager authenticationManager;

    @InjectMocks
    private AuthService authService;

    @BeforeEach
    void inicializarContexto() {
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void limpiarContexto() {
        SecurityContextHolder.clearContext();
    }

    /**
     * Verifica que el registro de un cliente persista correctamente el usuario
     * y que devuelva un JWT con los datos esperados.
     */
    @Test
    void registrar_deberiaPersistirCliente_yDevolverJwt() {
        RegisterRequest request = RegisterRequest.builder()
                .primerNombre("Ana")
                .primerApellido("Perez")
                .tipoDocumento("cedula")
                .documento("123")
                .email("ana@test.com")
                .password("secreto123")
                .telefono("3001234567")
                .habeasDataConsent(true)
                .build();

        when(usuarioRepository.existsByEmail(request.getEmail())).thenReturn(false);
        when(passwordEncoder.encode(request.getPassword())).thenReturn("encoded");
        when(usuarioRepository.save(any(Usuario.class))).thenAnswer(invocation -> {
            Usuario u = invocation.getArgument(0);
            u.setId(77L);
            return u;
        });
        when(jwtService.generateToken(any(Usuario.class), any(Map.class))).thenReturn("jwt-token");

        AuthResponse response = authService.register(request);

        // Verificar que el usuario se guardó con los datos correctos
        ArgumentCaptor<Usuario> userCaptor = ArgumentCaptor.forClass(Usuario.class);
        verify(usuarioRepository).save(userCaptor.capture());
        Usuario saved = userCaptor.getValue();

        assertThat(saved.getRole()).isEqualTo(Rol.CLIENTE);
        assertThat(saved.getTipoDocumento()).isEqualTo(TipoDocumento.CEDULA);
        assertThat(saved.getPasswordHash()).isEqualTo("encoded");
        assertThat(saved.getHabeasDataConsented()).isTrue();
        assertThat(saved.getHabeasDataConsentedAt()).isNotNull();

        // Verificar que el JWT devuelto contiene la información correcta
        assertThat(response.getToken()).isEqualTo("jwt-token");
        assertThat(response.getUserId()).isEqualTo(77L);
        assertThat(response.getRole()).isEqualTo("CLIENTE");
    }

    /**
     * Verifica que el registro falle si el correo ya existe.
     */
    @Test
    void registrar_deberiaFallar_siCorreoExiste() {
        RegisterRequest request = RegisterRequest.builder().email("ana@test.com").build();
        when(usuarioRepository.existsByEmail("ana@test.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(request))
                .isInstanceOf(EmailAlreadyExistsException.class);

        verify(usuarioRepository, never()).save(any());
    }

    /**
     * Verifica que un usuario activo pueda autenticarse y recibir un JWT.
     */
    @Test
    void login_deberiaAutenticarUsuarioActivo_yDevolverJwt() {
        LoginRequest request = LoginRequest.builder()
                .email("ana@test.com")
                .password("secreto123")
                .build();

        Usuario usuario = Usuario.builder()
                .id(8L)
                .email("ana@test.com")
                .primerNombre("Ana")
                .primerApellido("Perez")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();

        when(usuarioRepository.findByEmail(request.getEmail())).thenReturn(Optional.of(usuario));
        when(jwtService.generateToken(eq(usuario), any(Map.class))).thenReturn("jwt-login");

        AuthResponse response = authService.login(request);

        verify(authenticationManager).authenticate(any());
        assertThat(response.getToken()).isEqualTo("jwt-login");
        assertThat(response.getEmail()).isEqualTo("ana@test.com");
    }

    /**
     * Verifica que el login falle si las credenciales son incorrectas.
     */
    @Test
    void login_deberiaFallar_siCredencialesIncorrectas() {
        LoginRequest request = LoginRequest.builder().email("ana@test.com").password("bad").build();
        when(authenticationManager.authenticate(any())).thenThrow(new BadCredentialsException("bad"));

        assertThatThrownBy(() -> authService.login(request))
                .isInstanceOf(InvalidCredentialsException.class)
                .hasMessageContaining("incorrectos");
    }

    /**
     * Verifica que un usuario inactivo no pueda autenticarse.
     */
    @Test
    void login_deberiaFallar_siUsuarioInactivo() {
        LoginRequest request = LoginRequest.builder().email("ana@test.com").password("ok").build();
        Usuario usuario = Usuario.builder()
                .email("ana@test.com")
                .role(Rol.CLIENTE)
                .isActive(false)
                .build();

        when(usuarioRepository.findByEmail("ana@test.com")).thenReturn(Optional.of(usuario));

        assertThatThrownBy(() -> authService.login(request))
                .isInstanceOf(UserInactiveException.class);
    }

    /**
     * Verifica que el cambio de contraseña actualice correctamente el hash
     * y la fecha de modificación cuando todas las validaciones pasan.
     */
    @Test
    void cambiarContrasena_deberiaActualizarHash_yFechaCambio() {
        var auth = new org.springframework.security.authentication.UsernamePasswordAuthenticationToken("ana@test.com", "x");
        SecurityContextHolder.getContext().setAuthentication(auth);

        Usuario usuario = Usuario.builder()
                .id(50L)
                .email("ana@test.com")
                .passwordHash("old-hash")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();

        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .passwordActual("actual123")
                .passwordNueva("nueva123")
                .confirmarPassword("nueva123")
                .build();

        when(usuarioRepository.findByEmail("ana@test.com")).thenReturn(Optional.of(usuario));
        when(passwordEncoder.matches("actual123", "old-hash")).thenReturn(true);
        when(passwordEncoder.matches("nueva123", "old-hash")).thenReturn(false);
        when(passwordEncoder.encode("nueva123")).thenReturn("new-hash");

        authService.changePassword(request);

        assertThat(usuario.getPasswordHash()).isEqualTo("new-hash");
        assertThat(usuario.getPasswordChangedAt()).isNotNull();
        verify(usuarioRepository).save(usuario);
    }
}