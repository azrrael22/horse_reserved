package horse_reserved;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;

@SpringBootApplication
@EnableAsync
public class ReservaDeCabalgatasApplication {

	public static void main(String[] args) {
		SpringApplication.run(ReservaDeCabalgatasApplication.class, args);
	}

}
