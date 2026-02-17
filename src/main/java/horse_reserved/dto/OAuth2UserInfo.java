package horse_reserved.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.Map;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class OAuth2UserInfo {
    private Map<String, Object> attributes;
    private String id;
    private String name;
    private String email;
    private String imageUrl;

    public static OAuth2UserInfo fromGoogle(Map<String, Object> attributes) {
        return OAuth2UserInfo.builder()
                .attributes(attributes)
                .id((String) attributes.get("sub"))
                .name((String) attributes.get("name"))
                .email((String) attributes.get("email"))
                .imageUrl((String) attributes.get("picture"))
                .build();
    }
}
