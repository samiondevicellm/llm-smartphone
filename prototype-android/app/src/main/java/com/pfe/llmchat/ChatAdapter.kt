package com.pfe.llmchat

import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView

class ChatAdapter : ListAdapter<ChatMessage, ChatAdapter.ViewHolder>(DiffCallback) {

    companion object DiffCallback : DiffUtil.ItemCallback<ChatMessage>() {
        override fun areItemsTheSame(a: ChatMessage, b: ChatMessage) =
            a.timestamp == b.timestamp
        override fun areContentsTheSame(a: ChatMessage, b: ChatMessage) = a == b

        private const val VIEW_TYPE_USER = 0
        private const val VIEW_TYPE_BOT  = 1
    }

    override fun getItemViewType(position: Int) =
        if (getItem(position).isUser) VIEW_TYPE_USER else VIEW_TYPE_BOT

    inner class ViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        val tvContent: TextView = itemView.findViewById(R.id.tv_message_content)
        val tvMeta: TextView    = itemView.findViewById(R.id.tv_message_meta)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val layout = if (viewType == VIEW_TYPE_USER)
            R.layout.item_message_user
        else
            R.layout.item_message_bot
        val view = LayoutInflater.from(parent.context).inflate(layout, parent, false)
        return ViewHolder(view)
    }

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val msg = getItem(position)
        holder.tvContent.text = msg.content
        if (!msg.isUser && msg.latencyMs > 0) {
            val tps = if (msg.latencyMs > 0) msg.tokensGenerated * 1000.0 / msg.latencyMs else 0.0
            holder.tvMeta.text = "${msg.latencyMs} ms · ${"%.1f".format(tps)} tok/s"
            holder.tvMeta.visibility = View.VISIBLE
        } else {
            holder.tvMeta.visibility = View.GONE
        }
    }
}
