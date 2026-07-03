# Tutoriel — ML Kit GenAI (Gemini Nano) sur Android

> **Prérequis matériel strict** : cette solution ne fonctionne que sur des appareils certifiés AICore.  
> **Appareils compatibles (2025)** : Pixel 9, Pixel 9 Pro, Pixel 9 Pro XL, Pixel 10, Samsung Galaxy S25/S25+/S25 Ultra/S26.

---

## A. Vérification de compatibilité

### A.1 Appareils certifiés AICore

```kotlin
// Vérifier si l'appareil supporte ML Kit GenAI
// À placer dans votre Activity ou ViewModel

import com.google.mlkit.genai.inference.LanguageModelInference

suspend fun checkDeviceSupport(): Boolean {
    return try {
        val availability = LanguageModelInference.getClient()
            .checkFeatureAvailability()
        availability == FeatureStatus.AVAILABLE
    } catch (e: Exception) {
        false
    }
}
```

### A.2 Versions Android/API requises

| Condition | Valeur |
|---|---|
| Android minimum | 10 (API 29) |
| Android recommandé | 14 (API 34) |
| ML Kit GenAI SDK | 1.0.0-beta+ |
| Google Play Services | 24.20+ |

---

## B. Configuration du projet Android Studio

### B.1 Créer un nouveau projet

1. Ouvrir Android Studio (version Hedgehog 2023.1.1 ou plus récente)
2. **File → New → New Project → Empty Views Activity**
3. Paramètres :
   - Name : `LlmChatApp`
   - Package : `com.pfe.llmchat`
   - Language : **Kotlin**
   - Minimum SDK : **API 29 (Android 10)**

### B.2 Configurer `build.gradle` (Module: app)

```kotlin
// build.gradle.kts (module app)
android {
    compileSdk = 35

    defaultConfig {
        minSdk = 29
        targetSdk = 35
    }

    buildFeatures {
        viewBinding = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // ML Kit GenAI — Summarization, Proofreading, Free-form inference
    implementation("com.google.mlkit:genai-common:1.0.0-beta1")
    implementation("com.google.mlkit:genai-inference:1.0.0-beta1")

    // Coroutines pour l'inférence asynchrone
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.7.0")

    // UI
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("com.google.android.material:material:1.11.0")
}
```

### B.3 Configurer `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Requis pour télécharger le modèle Gemini Nano -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Déclarer la dépendance au service AICore -->
    <uses-library
        android:name="android.ext.adservices"
        android:required="false" />

    <application
        android:name=".LlmChatApplication"
        android:allowBackup="true"
        android:label="@string/app_name"
        android:theme="@style/Theme.LlmChat">

        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <!-- Déclaration pour ML Kit GenAI -->
        <meta-data
            android:name="com.google.mlkit.genai.ENABLED"
            android:value="true" />

    </application>
</manifest>
```

---

## C. Code Kotlin — Inférence avec ML Kit GenAI

### C.1 ViewModel (logique d'inférence)

```kotlin
// LlmViewModel.kt
package com.pfe.llmchat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.mlkit.genai.inference.LanguageModelInference
import com.google.mlkit.genai.inference.InferenceOptions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

data class ChatMessage(
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val latencyMs: Long = 0
)

sealed class InferenceState {
    object Idle : InferenceState()
    object ModelLoading : InferenceState()
    object ModelReady : InferenceState()
    data class Generating(val partialText: String) : InferenceState()
    data class Error(val message: String) : InferenceState()
}

class LlmViewModel : ViewModel() {

    private val _messages = MutableStateFlow<List<ChatMessage>>(emptyList())
    val messages: StateFlow<List<ChatMessage>> = _messages

    private val _state = MutableStateFlow<InferenceState>(InferenceState.Idle)
    val state: StateFlow<InferenceState> = _state

    private var modelClient: LanguageModelInference? = null

    // Initialiser le modèle Gemini Nano via AICore
    fun initializeModel() {
        viewModelScope.launch {
            _state.value = InferenceState.ModelLoading
            try {
                // Vérifier la disponibilité
                val availability = LanguageModelInference.checkAvailability()
                if (!availability.isAvailable) {
                    _state.value = InferenceState.Error(
                        "Gemini Nano non disponible sur cet appareil. " +
                        "Appareils supportés : Pixel 9/10, Galaxy S25/S26."
                    )
                    return@launch
                }

                // Créer le client — déclenche le téléchargement du modèle si nécessaire
                modelClient = LanguageModelInference.getClient()
                _state.value = InferenceState.ModelReady

            } catch (e: Exception) {
                _state.value = InferenceState.Error("Erreur initialisation : ${e.message}")
            }
        }
    }

    // Envoyer un message et recevoir la réponse en streaming
    fun sendMessage(userInput: String) {
        val client = modelClient ?: return
        val startTime = System.currentTimeMillis()

        // Ajouter le message utilisateur
        _messages.value = _messages.value + ChatMessage(userInput, isUser = true)

        viewModelScope.launch {
            _state.value = InferenceState.Generating("")
            val sb = StringBuilder()

            try {
                val options = InferenceOptions.Builder()
                    .setMaxTokens(512)
                    .setTemperature(0.7f)
                    .setTopK(40)
                    .build()

                // Streaming de la réponse token par token
                client.generateResponseAsync(
                    prompt = buildPrompt(userInput),
                    options = options,
                    onPartialResult = { partial ->
                        sb.append(partial)
                        _state.value = InferenceState.Generating(sb.toString())
                    },
                    onComplete = { _ ->
                        val latency = System.currentTimeMillis() - startTime
                        _messages.value = _messages.value + ChatMessage(
                            content = sb.toString(),
                            isUser = false,
                            latencyMs = latency
                        )
                        _state.value = InferenceState.ModelReady
                    },
                    onError = { e ->
                        _state.value = InferenceState.Error("Erreur inférence : ${e.message}")
                    }
                )
            } catch (e: Exception) {
                _state.value = InferenceState.Error(e.message ?: "Erreur inconnue")
            }
        }
    }

    // Construire le prompt avec historique de conversation
    private fun buildPrompt(userInput: String): String {
        val history = _messages.value.takeLast(6) // Fenêtre de contexte : 6 derniers messages
        val sb = StringBuilder()
        history.forEach { msg ->
            if (msg.isUser) sb.append("User: ${msg.content}\n")
            else sb.append("Assistant: ${msg.content}\n")
        }
        sb.append("User: $userInput\nAssistant:")
        return sb.toString()
    }

    override fun onCleared() {
        super.onCleared()
        modelClient?.close()
    }
}
```

### C.2 MainActivity

```kotlin
// MainActivity.kt
package com.pfe.llmchat

import android.os.Bundle
import android.view.inputmethod.EditorInfo
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.pfe.llmchat.databinding.ActivityMainBinding
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val viewModel: LlmViewModel by viewModels()
    private lateinit var chatAdapter: ChatAdapter

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupRecyclerView()
        setupInput()
        observeState()

        // Initialiser Gemini Nano au démarrage
        viewModel.initializeModel()
    }

    private fun setupRecyclerView() {
        chatAdapter = ChatAdapter()
        binding.rvChat.apply {
            layoutManager = LinearLayoutManager(this@MainActivity).apply {
                stackFromEnd = true
            }
            adapter = chatAdapter
        }
    }

    private fun setupInput() {
        binding.btnSend.setOnClickListener { sendMessage() }
        binding.etInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_SEND) {
                sendMessage(); true
            } else false
        }
    }

    private fun sendMessage() {
        val text = binding.etInput.text?.toString()?.trim() ?: return
        if (text.isEmpty()) return
        binding.etInput.text?.clear()
        viewModel.sendMessage(text)
    }

    private fun observeState() {
        lifecycleScope.launch {
            viewModel.state.collect { state ->
                when (state) {
                    is InferenceState.ModelLoading ->
                        binding.tvStatus.text = "⏳ Chargement de Gemini Nano..."
                    is InferenceState.ModelReady ->
                        binding.tvStatus.text = "✅ Gemini Nano prêt"
                    is InferenceState.Generating ->
                        binding.tvStatus.text = "💬 Génération en cours..."
                    is InferenceState.Error ->
                        binding.tvStatus.text = "❌ ${state.message}"
                    else -> {}
                }
            }
        }

        lifecycleScope.launch {
            viewModel.messages.collect { messages ->
                chatAdapter.submitList(messages)
                binding.rvChat.smoothScrollToPosition(messages.size)
            }
        }
    }
}
```

### C.3 Layout XML (activity_main.xml)

```xml
<?xml version="1.0" encoding="utf-8"?>
<androidx.constraintlayout.widget.ConstraintLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:app="http://schemas.android.com/apk/res-auto"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@color/background">

    <!-- Barre de statut du modèle -->
    <TextView
        android:id="@+id/tv_status"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:padding="8dp"
        android:text="Initialisation..."
        android:textSize="12sp"
        android:textColor="@color/status_text"
        android:background="@color/status_bg"
        app:layout_constraintTop_toTopOf="parent"/>

    <!-- Liste des messages -->
    <androidx.recyclerview.widget.RecyclerView
        android:id="@+id/rv_chat"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:padding="8dp"
        android:clipToPadding="false"
        app:layout_constraintTop_toBottomOf="@id/tv_status"
        app:layout_constraintBottom_toTopOf="@id/input_layout"/>

    <!-- Zone de saisie -->
    <LinearLayout
        android:id="@+id/input_layout"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:padding="8dp"
        android:background="@color/input_bg"
        app:layout_constraintBottom_toBottomOf="parent">

        <com.google.android.material.textfield.TextInputEditText
            android:id="@+id/et_input"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:hint="Posez votre question..."
            android:imeOptions="actionSend"
            android:inputType="textMultiLine"
            android:maxLines="3"/>

        <com.google.android.material.button.MaterialButton
            android:id="@+id/btn_send"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="8dp"
            android:text="Envoyer"/>
    </LinearLayout>

</androidx.constraintlayout.widget.ConstraintLayout>
```

---

## D. Cas d'usage avancés — Summarization et Proofreading

```kotlin
// Utilisation des APIs spécialisées ML Kit GenAI

import com.google.mlkit.genai.summarization.Summarization
import com.google.mlkit.genai.proofreading.Proofreading

// --- Résumé d'un texte ---
suspend fun summarizeText(text: String): String {
    val client = Summarization.getClient()
    return client.summarize(text).await()
}

// --- Correction grammaticale ---
suspend fun proofreadText(text: String): String {
    val client = Proofreading.getClient()
    return client.proofread(text).await()
}

// Exemple d'utilisation dans un Fragment :
viewLifecycleOwner.lifecycleScope.launch {
    val summary = summarizeText(longArticleText)
    textView.text = summary
}
```

---

## E. Pourquoi cette solution est limitée (analyse critique)

| Contrainte | Impact |
|---|---|
| Appareils certifiés seulement | Exclut ~95 % du parc Android mondial |
| Quota d'inférence par application | Impossibilité d'une utilisation intensive |
| Exécution premier plan uniquement | Pas de traitement en arrière-plan |
| Modèle non modifiable | Impossible de fine-tuner ou d'adapter |
| Dépendance Google totale | Risque de déprecation/modification unilatérale |

> **Conclusion** : ML Kit GenAI est idéal pour les applications grand public ciblant les flagships récents. Pour un usage de recherche ou un déploiement sur un parc hétérogène, llama.cpp reste incontournable.

---

## Références

- [ML Kit GenAI APIs](https://developers.google.com/ml-kit/genai)
- [AICore sur Android](https://developer.android.com/ml/aicore)
- [MediaPipe LLM Inference](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference/android)
- Google Developers (2025). *ML Kit GenAI APIs Overview*.
