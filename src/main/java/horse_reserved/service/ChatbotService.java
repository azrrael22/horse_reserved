package horse_reserved.service;

import horse_reserved.dto.response.ChatbotAnswerResponse;
import horse_reserved.model.chatbot.FaqIntent;
import horse_reserved.model.chatbot.FaqKnowledgeBase;
import horse_reserved.service.chatbot.FaqKnowledgeBaseProvider;
import horse_reserved.service.chatbot.IntentMatcher;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
/**
 * Orquesta la lógica principal del chatbot.
 * Coordina la obtención de intents, matching
 * y construcción de la respuesta final.
 */
public class ChatbotService {

    private final IntentMatcher intentMatcher;
    private final FaqKnowledgeBaseProvider kbProvider;

    public ChatbotService(IntentMatcher intentMatcher, FaqKnowledgeBaseProvider kbProvider) {
        this.intentMatcher = intentMatcher;
        this.kbProvider = kbProvider;
    }

    /**
     * Procesa la pregunta del usuario y retorna la mejor respuesta posible.
     * Aplica validación de threshold y fallback si es necesario.
     */
    public ChatbotAnswerResponse answer(String question) {
        FaqKnowledgeBase kb = kbProvider.getKnowledgeBase();

        IntentMatcher.MatchResult result = intentMatcher.findBestMatch(question, kb.getIntents());
        FaqIntent intent = result.intent();

        if (intent == null) {
            return fallback(kb, 0.0);
        }

        double threshold = intent.getThreshold() == null ? 0.70 : intent.getThreshold();
        if (result.score() < threshold) {
            return fallback(kb, result.score());
        }

        return ChatbotAnswerResponse.builder()
                .intentId(intent.getId())
                .confidence(round(result.score()))
                .answer(intent.getResponse().getText())
                .action(intent.getResponse().getAction())
                .notes(intent.getResponse().getNotes())
                .suggestions(List.of())
                .build();
    }

    /**
     * Construye la respuesta de fallback cuando no hay coincidencia válida.
     */
    private ChatbotAnswerResponse fallback(FaqKnowledgeBase kb, double confidence) {
        return ChatbotAnswerResponse.builder()
                .intentId("fallback")
                .confidence(round(confidence))
                .answer(kb.getFallback().getMessage())
                .suggestions(kb.getFallback().getSuggestions())
                .action(null)
                .build();
    }

    /**
     * Redondea el score a 3 decimales para presentación.
     */
    private double round(double value) {
        return Math.round(value * 1000.0) / 1000.0;
    }
}