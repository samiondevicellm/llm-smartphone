package com.pfe.llmchat

import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.view.inputmethod.EditorInfo
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.google.android.material.snackbar.Snackbar
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
        setSupportActionBar(binding.toolbar)

        setupRecyclerView()
        setupInput()
        observeViewModel()

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
                sendMessage()
                true
            } else {
                false
            }
        }
    }

    private fun sendMessage() {
        val text = binding.etInput.text?.toString()?.trim() ?: return
        if (text.isEmpty()) return
        binding.etInput.text?.clear()
        viewModel.sendMessage(text)
    }

    private fun observeViewModel() {
        lifecycleScope.launch {
            viewModel.state.collect { state ->
                when (state) {
                    is InferenceState.Idle -> {
                        binding.tvStatus.text = "En attente d'initialisation..."
                        binding.btnSend.isEnabled = false
                    }
                    is InferenceState.ModelLoading -> {
                        binding.tvStatus.text = "⏳ Chargement de Gemini Nano (AICore)..."
                        binding.btnSend.isEnabled = false
                    }
                    is InferenceState.ModelReady -> {
                        binding.tvStatus.text = "✅ Gemini Nano prêt"
                        binding.btnSend.isEnabled = true
                    }
                    is InferenceState.Generating -> {
                        binding.tvStatus.text = "💬 Génération en cours..."
                        binding.btnSend.isEnabled = false
                    }
                    is InferenceState.Error -> {
                        binding.tvStatus.text = "❌ Erreur"
                        binding.btnSend.isEnabled = false
                        Snackbar.make(binding.root, state.message, Snackbar.LENGTH_LONG).show()
                    }
                }
            }
        }

        lifecycleScope.launch {
            viewModel.messages.collect { messages ->
                chatAdapter.submitList(messages)
                if (messages.isNotEmpty()) {
                    binding.rvChat.smoothScrollToPosition(messages.size - 1)
                }
            }
        }

        // Afficher les métriques d'inférence (pour le PFE)
        lifecycleScope.launch {
            viewModel.lastMetrics.collect { metrics ->
                metrics?.let {
                    val text = "⚡ ${it.tokensPerSecond.format(1)} tok/s | " +
                               "${it.latencyMs} ms | " +
                               "${it.tokensGenerated} tokens"
                    binding.tvMetrics.text = text
                }
            }
        }
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        menuInflater.inflate(R.menu.main_menu, menu)
        return true
    }

    override fun onOptionsItemSelected(item: MenuItem): Boolean {
        return when (item.itemId) {
            R.id.action_clear -> {
                viewModel.clearHistory()
                chatAdapter.submitList(emptyList())
                true
            }
            else -> super.onOptionsItemSelected(item)
        }
    }
}

private fun Double.format(digits: Int) = "%.${digits}f".format(this)
