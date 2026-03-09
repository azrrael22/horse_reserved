package horse_reserved.service;

import horse_reserved.dto.request.CreateReservaRequest;
import horse_reserved.dto.request.ParticipanteRequest;
import horse_reserved.dto.response.ReservaResponse;
import horse_reserved.exception.AccessDeniedBusinessException;
import horse_reserved.exception.BusinessRuleException;
import horse_reserved.model.Caballo;
import horse_reserved.model.Reserva;
import horse_reserved.model.Rol;
import horse_reserved.model.Ruta;
import horse_reserved.model.Salida;
import horse_reserved.model.Usuario;
import horse_reserved.repository.CaballoRepository;
import horse_reserved.repository.GuiaRepository;
import horse_reserved.repository.ReservaRepository;
import horse_reserved.repository.RutaRepository;
import horse_reserved.repository.SalidaRepository;
import horse_reserved.repository.UsuarioRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ReservaServiceTest {

    @Mock
    private ReservaRepository reservaRepository;
    @Mock
    private SalidaRepository salidaRepository;
    @Mock
    private RutaRepository rutaRepository;
    @Mock
    private CaballoRepository caballoRepository;
    @Mock
    private GuiaRepository guiaRepository;
    @Mock
    private UsuarioRepository usuarioRepository;
    @Mock
    private ReservaMapper reservaMapper;

    @InjectMocks
    private ReservaService reservaService;

    @BeforeEach
    void inicializar() {
        SecurityContextHolder.clearContext();
    }

    @AfterEach
    void limpiarContexto() {
        SecurityContextHolder.clearContext();
    }

    /**
     * Verifica que se pueda crear una reserva para un cliente autenticado
     * con una salida existente y disponibilidad suficiente de cupo.
     */
    @Test
    void crearReserva_deberiaRegistrarReserva_siClienteAutenticadoYSalidaExiste() {
        Usuario cliente = Usuario.builder()
                .id(10L)
                .email("cliente@test.com")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(cliente.getEmail(), "n/a")
        );

        Ruta ruta = Ruta.builder()
                .id(3L)
                .nombre("Ruta Cocora")
                .precio(new BigDecimal("120000.00"))
                .duracionMinutos(120)
                .build();

        Salida salida = Salida.builder()
                .id(20L)
                .ruta(ruta)
                .fechaProgramada(LocalDate.now().plusDays(3))
                .tiempoInicio(LocalTime.of(9, 0))
                .tiempoFin(LocalTime.of(11, 0))
                .estado("programado")
                .caballos(List.of(
                        Caballo.builder().id(1L).nombre("A").activo(true).build(),
                        Caballo.builder().id(2L).nombre("B").activo(true).build(),
                        Caballo.builder().id(3L).nombre("C").activo(true).build()
                ))
                .build();

        CreateReservaRequest request = CreateReservaRequest.builder()
                .rutaId(3L)
                .fecha(salida.getFechaProgramada())
                .horaInicio(salida.getTiempoInicio())
                .cantPersonas(2)
                .participantes(List.of(participante("Ana", "1"), participante("Luis", "2")))
                .build();

        when(usuarioRepository.findByEmail(cliente.getEmail())).thenReturn(Optional.of(cliente));
        when(salidaRepository.findProgramadaByRutaAndFechaAndHora(3L, request.getFecha(), request.getHoraInicio()))
                .thenReturn(Optional.of(salida));
        when(reservaRepository.sumPersonasReservadasActivasBySalida(20L)).thenReturn(0L);
        when(guiaRepository.findDisponibles(any(), any(), any())).thenReturn(List.of());
        when(reservaRepository.save(any(Reserva.class))).thenAnswer(invocation -> {
            Reserva r = invocation.getArgument(0);
            r.setId(500L);
            return r;
        });
        when(reservaMapper.toResponse(any(Reserva.class))).thenReturn(ReservaResponse.builder().id(500L).build());

        ReservaResponse response = reservaService.crearReserva(request);

        ArgumentCaptor<Reserva> reservaCaptor = ArgumentCaptor.forClass(Reserva.class);
        verify(reservaRepository).save(reservaCaptor.capture());
        Reserva saved = reservaCaptor.getValue();

        assertThat(saved.getCliente()).isEqualTo(cliente);
        assertThat(saved.getOperador()).isNull();
        assertThat(saved.getEstado()).isEqualTo("reservado");
        assertThat(saved.getCantPersonas()).isEqualTo(2);
        assertThat(saved.getParticipantes()).hasSize(2);
        assertThat(saved.getPrecioUnitario()).isEqualTo(new BigDecimal("120000.00"));
        assertThat(saved.getPrecioTotal()).isEqualByComparingTo("240000.00");
        assertThat(response.getId()).isEqualTo(500L);
    }

    /**
     * Verifica que la creación de reserva falle si no hay cupo disponible
     * suficiente para la cantidad de personas solicitadas.
     */
    @Test
    void crearReserva_deberiaFallar_siNoHayCupoDisponible() {
        Usuario cliente = Usuario.builder()
                .id(10L)
                .email("cliente@test.com")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(cliente.getEmail(), "n/a")
        );

        Ruta ruta = Ruta.builder().id(3L).precio(new BigDecimal("100000.00")).duracionMinutos(120).build();
        Salida salida = Salida.builder()
                .id(21L)
                .ruta(ruta)
                .fechaProgramada(LocalDate.now().plusDays(2))
                .tiempoInicio(LocalTime.of(8, 0))
                .tiempoFin(LocalTime.of(10, 0))
                .estado("programado")
                .caballos(List.of(Caballo.builder().id(1L).activo(true).build()))
                .build();

        CreateReservaRequest request = CreateReservaRequest.builder()
                .rutaId(3L)
                .fecha(salida.getFechaProgramada())
                .horaInicio(salida.getTiempoInicio())
                .cantPersonas(2)
                .participantes(List.of(participante("Ana", "1"), participante("Luis", "2")))
                .build();

        when(usuarioRepository.findByEmail(cliente.getEmail())).thenReturn(Optional.of(cliente));
        when(salidaRepository.findProgramadaByRutaAndFechaAndHora(3L, request.getFecha(), request.getHoraInicio()))
                .thenReturn(Optional.of(salida));
        when(reservaRepository.sumPersonasReservadasActivasBySalida(21L)).thenReturn(0L);

        assertThatThrownBy(() -> reservaService.crearReserva(request))
                .isInstanceOf(BusinessRuleException.class)
                .hasMessageContaining("Cupo insuficiente");

        verify(reservaRepository, never()).save(any());
    }

    /**
     * Verifica que un cliente no pueda cancelar una reserva que pertenece
     * a otro cliente, lanzando excepción de acceso denegado.
     */
    @Test
    void cancelarReserva_deberiaFallar_siClienteIntentaCancelarReservaDeOtro() {
        Usuario actual = Usuario.builder()
                .id(100L)
                .email("actual@test.com")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();
        Usuario otroCliente = Usuario.builder()
                .id(101L)
                .email("otro@test.com")
                .role(Rol.CLIENTE)
                .isActive(true)
                .build();

        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(actual.getEmail(), "n/a")
        );

        Reserva reserva = Reserva.builder()
                .id(333L)
                .cliente(otroCliente)
                .estado("reservado")
                .build();

        when(usuarioRepository.findByEmail(actual.getEmail())).thenReturn(Optional.of(actual));
        when(reservaRepository.findDetailedById(333L)).thenReturn(Optional.of(reserva));

        assertThatThrownBy(() -> reservaService.cancelarReserva(333L))
                .isInstanceOf(AccessDeniedBusinessException.class)
                .hasMessageContaining("No tienes permisos");

        verify(reservaRepository, never()).save(any());
    }

    private ParticipanteRequest participante(String nombre, String documento) {
        return ParticipanteRequest.builder()
                .primerNombre(nombre)
                .primerApellido("Test")
                .tipoDocumento("CEDULA")
                .documento(documento)
                .edad((short) 30)
                .cmAltura((short) 170)
                .kgPeso(new BigDecimal("70.50"))
                .build();
    }
}