package com.pfe.llmchat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.mlkit.genai.inference.LanguageModelInference
import com.google.mlkit.genai.inference.InferenceOptions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

// ── Modèles de données ────────────────────────────────────────────────────────

data class ChatMessage(
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    /** Latence totale en millisecondes (0 pour les messages utilisateur) */
    val latencyMs: Long = 0,
    /** Tokens générés (0 pour les messages utilisateur) */
    val tokensGenerated: Int = 0,
)

sealed class InferenceState {
    object Idle : InferenceState()
    object ModelLoading : InferenceState()
    object ModelReady : InferenceState()
    data class Generating(val partialText: String) : InferenceState()
    data class Error(val message: String) : InferenceState()
}

// ── Métriques pour le PFE ─────────────────────────────────────────────────────

data class InferenceMetrics(
    val latencyMs: Long,
    val tokensGenerated: Int,
    val tokensPerSecond: Double,
    val promptLength: Int,
)

// ── ViewModel ─────────────────────────────────────────────────────────────────

class LlmViewModel : ViewModel() {

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages

    private val _state = MutableStateFlow<InferenceState>(InferenceState.Idle)
    val state: StateFlow<InferenceState> = _state

    private val _lastMetrics = MutableStateFlow<InferenceMetrics?>(null)
    val lastMetrics: StateFlow<InferenceMetrics?> = _lastMetrics

    private var modelClient: LanguageModelInference? = null

    /**
     * Initialise Gemini Nano via ML Kit GenAI / AICore.
     * À appeler au démarrage — déclenche le téléchargement du modèle si nécessaire.
     *
     * Appareils supportés (2025) :
     *   - Google Pixel 9, Pixel 9 Pro, Pixel 9 Pro XL, Pixel 10
     *   - Samsung Galaxy S25, S25+, S25 Ultra, S26
     */
    fun initializeModel() {
        viewModelScope.launch {
            _state.value = InferenceState.ModelLoading
            try {
                // Vérifier la disponibilité sur l'appareil
                val availability = LanguageModelInference.checkAvailability()
                if (!availability.isAvailable) {
                    _state.value = InferenceState.Error(
                        "Gemini Nano non disponible.\n" +
                        "Appareils requis : Pixel 9/10, Galaxy S25/S26.\n" +
                        "Statut : ${availability.statusCode}"
                    )
                    return@launch
                }

                // Créer le client (déclenche le téléchargement si pas encore présent)
                modelClient = LanguageModelInference.getClient()
                _state.value = InferenceState.ModelReady

            } catch (e: Exception) {
                _state.value = InferenceState.Error(
                    "Erreur initialisation AICore : ${e.message}"
                )
            }
        }
    }

    /**
     * Envoie un message utilisateur et génère une réponse via Gemini Nano.
     * Mesure la latence et le débit pour l'analyse de performances PFE.
     */
    fun sendMessage(userInput: String) {
        val client = modelClient ?: run {
            _state.value = InferenceState.Error("Modèle non initialisé. Redémarrer l'app.")
            return
        }

        // Ajouter le message utilisateur à l'historique
        _messages.value = _messages.value + ChatMessage(
            content = userInput,
            isUser = true,
        )

        val startTime = System.currentTimeMillis()
        var tokenCount = 0

        viewModelScope.launch {
            _state.value = InferenceState.Generating("")
            val responseBuilder = StringBuilder()

            try {
                val options = InferenceOptions.Builder()
                    .setMaxTokens(512)
                    .setTemperature(0.7f)
                    .setTopK(40)
                    .build()

                // Streaming token-par-token
                client.generateResponseAsync(
                    prompt = buildPrompt(userInput),
                    options = options,
                    onPartialResult = { partial ->
                        responseBuilder.append(partial)
                        tokenCount++
                        _state.value = InferenceState.Generating(responseBuilder.toString())
                    },
                    onComplete = { _ ->
                        val latencyMs = System.currentTimeMillis() - startTime
                        val tps = if (latencyMs > 0) tokenCount * 1000.0 / latencyMs else 0.0

                        // Enregistrer les métriques (pour l'analyse PFE)
                        _lastMetrics.value = InferenceMetrics(
                            latencyMs = latencyMs,
                            tokensGenerated = tokenCount,
                            tokensPerSecond = tps,
                            promptLength = userInput.length,
                        )

                        // Ajouter la réponse à l'historique
                        _messages.value = _messages.value + ChatMessage(
                            content = responseBuilder.toString(),
                            isUser = false,
                            latencyMs = latencyMs,
                            tokensGenerated = tokenCount,
                        )
                        _state.value = InferenceState.ModelReady
                    },
                    onError = { e ->
                        _state.value = InferenceState.Error(
                            "Erreur inférence : ${e.message}"
                        )
                    }
                )

            } catch (e: Exception) {
                _state.value = InferenceState.Error(e.message ?: "Erreur inconnue")
            }
        }
    }

    /**
     * Construit le prompt avec historique de conversation (fenêtre glissante).
     * Gemini Nano a une fenêtre de contexte limitée (~2 048 tokens via AICore).
     */
    private fun buildPrompt(userInput: String): String {
        val history = _messages.value.takeLast(6) // 3 derniers échanges
        return buildString {
            history.forEach { msg ->
                if (msg.isUser) append("User: ${msg.content}\n")
                else append("Assistant: ${msg.content}\n")
            }
            append("User: $userInput\nAssistant:")
        }
    }

    fun clearHistory() {
        _messages.value = emptyList()
    }

    override fun onCleared() {
        super.onCleared()
        modelClient?.close()
    }
}
