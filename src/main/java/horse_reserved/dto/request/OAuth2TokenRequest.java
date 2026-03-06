package horse_reserved.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class OAuth2TokenRequest {

    @NotBlank
    private String code;
}
