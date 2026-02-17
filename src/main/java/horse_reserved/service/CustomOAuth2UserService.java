package horse_reserved.service;

import horse_reserved.dto.OAuth2UserInfo;
import horse_reserved.exception.OAuth2AuthenticationProcessingException;
import horse_reserved.model.TipoDocumento;
import horse_reserved.model.Usuario;
import horse_reserved.repository.UsuarioRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class CustomOAuth2UserService extends DefaultOAuth2UserService {

    private final UsuarioRepository usuarioRepository;

    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        OAuth2User oAuth2User = super.loadUser(userRequest);

        try {
            return processOAuth2User(userRequest, oAuth2User);
        } catch (AuthenticationException ex) {
            throw ex;
        } catch (Exception ex) {
            throw new OAuth2AuthenticationProcessingException(ex.getMessage(), ex);
        }
    }

    private OAuth2User processOAuth2User(OAuth2UserRequest userRequest, OAuth2User oAuth2User) {
        String registrationId = userRequest.getClientRegistration().getRegistrationId();

        OAuth2UserInfo oAuth2UserInfo;
        if ("google".equals(registrationId)) {
            oAuth2UserInfo = OAuth2UserInfo.fromGoogle(oAuth2User.getAttributes());
        } else {
            throw new OAuth2AuthenticationProcessingException(
                    "Login con " + registrationId + " no está soportado");
        }

        if (oAuth2UserInfo.getEmail() == null || oAuth2UserInfo.getEmail().isEmpty()) {
            throw new OAuth2AuthenticationProcessingException("Email no encontrado del proveedor OAuth2");
        }

        Optional<Usuario> usuarioOptional = usuarioRepository.findByEmail(oAuth2UserInfo.getEmail());
        Usuario usuario;

        if (usuarioOptional.isPresent()) {
            usuario = usuarioOptional.get();
            // Actualizar información si es necesario
            usuario = updateExistingUser(usuario, oAuth2UserInfo);
        } else {
            usuario = registerNewUser(oAuth2UserInfo);
        }

        return oAuth2User;
    }

    private Usuario registerNewUser(OAuth2UserInfo oAuth2UserInfo) {
        // Separar el nombre completo en primer nombre y apellido
        String[] nameParts = oAuth2UserInfo.getName().split(" ", 2);
        String primerNombre = nameParts[0];
        String primerApellido = nameParts.length > 1 ? nameParts[1] : "";

        Usuario usuario = Usuario.builder()
                .primerNombre(primerNombre)
                .primerApellido(primerApellido)
                .email(oAuth2UserInfo.getEmail())
                .passwordHash("") // No hay contraseña para usuarios OAuth2
                .tipoDocumento(TipoDocumento.CEDULA) // Por defecto
                .documento("OAUTH2-" + oAuth2UserInfo.getId()) // Temporal
                .role("cliente")
                .isActive(true)
                .build();

        return usuarioRepository.save(usuario);
    }

    private Usuario updateExistingUser(Usuario usuario, OAuth2UserInfo oAuth2UserInfo) {
        // Actualizar información si es necesario
        String[] nameParts = oAuth2UserInfo.getName().split(" ", 2);
        usuario.setPrimerNombre(nameParts[0]);
        if (nameParts.length > 1) {
            usuario.setPrimerApellido(nameParts[1]);
        }

        return usuarioRepository.save(usuario);
    }
}