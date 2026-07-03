package com.pfe.llmchat

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

const val DEFAULT_MODEL_PATH = "/sdcard/Download/gemma-3-1b-it-cpu-int4.task"

data class ChatMessage(
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val latencyMs: Long = 0,
    val tokensGenerated: Int = 0,
)

data class InferenceMetrics(
    val latencyMs: Long,
    val tokensGenerated: Int,
    val tokensPerSecond: Double,
    val promptLength: Int,
)

sealed class InferenceState {
    object Idle : InferenceState()
    object ModelLoading : InferenceState()
    object ModelReady : InferenceState()
    data class Generating(val partialText: String) : InferenceState()
    data class Error(val message: String) : InferenceState()
}

class LlmViewModel(application: Application) : AndroidViewModel(application) {

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages

    private val _state = MutableStateFlow<InferenceState>(InferenceState.Idle)
    val state: StateFlow<InferenceState> = _state

    private val _lastMetrics = MutableStateFlow<InferenceMetrics?>(null)
    val lastMetrics: StateFlow<InferenceMetrics?> = _lastMetrics

    private var llmInference: LlmInference? = null

    fun initializeModel(modelPath: String = DEFAULT_MODEL_PATH) {
        viewModelScope.launch {
            _state.value = InferenceState.ModelLoading
            try {
                withContext(Dispatchers.IO) {
                    val options = LlmInference.LlmInferenceOptions.builder()
                        .setModelPath(modelPath)
                        .setMaxTokens(512)
                        .setTopK(40)
                        .setTemperature(0.7f)
                        .build()
                    llmInference = LlmInference.createFromOptions(getApplication(), options)
                }
                _state.value = InferenceState.ModelReady
            } catch (e: Exception) {
                _state.value = InferenceState.Error(
                    "Modèle introuvable : $modelPath\n${e.message}"
                )
            }
        }
    }

    fun sendMessage(userInput: String) {
        val inference = llmInference ?: run {
            _state.value = InferenceState.Error("Modèle non chargé.")
            return
        }
        _messages.value = _messages.value + ChatMessage(content = userInput, isUser = true)

        val startTime = System.currentTimeMillis()
        val responseBuilder = StringBuilder()
        var tokenCount = 0

        viewModelScope.launch {
            _state.value = InferenceState.Generating("")
            try {
                withContext(Dispatchers.IO) {
                    inference.generateResponseAsync(buildPrompt(userInput)) { partial, done ->
                        partial?.let {
                            responseBuilder.append(it)
                            tokenCount++
                            _state.value = InferenceState.Generating(responseBuilder.toString())
                        }
                        if (done) {
                            val latencyMs = System.currentTimeMillis() - startTime
                            val tps = if (latencyMs > 0) tokenCount * 1000.0 / latencyMs else 0.0
                            _lastMetrics.value = InferenceMetrics(latencyMs, tokenCount, tps, userInput.length)
                            _messages.value = _messages.value + ChatMessage(
                                content = responseBuilder.toString(),
                                isUser = false,
                                latencyMs = latencyMs,
                                tokensGenerated = tokenCount,
                            )
                            _state.value = InferenceState.ModelReady
                        }
                    }
                }
            } catch (e: Exception) {
                _state.value = InferenceState.Error(e.message ?: "Erreur inconnue")
            }
        }
    }

    private fun buildPrompt(userInput: String): String {
        val history = _messages.value.takeLast(6)
        return buildString {
            history.forEach { msg ->
                if (msg.isUser) append("User: ${msg.content}\n")
                else append("Model: ${msg.content}\n")
            }
            append("User: $userInput\nModel:")
        }
    }

    fun clearHistory() { _messages.value = emptyList() }

    override fun onCleared() {
        super.onCleared()
        llmInference?.close()
    }
}
