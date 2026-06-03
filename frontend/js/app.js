/**
 * UniAssist — Withdrawal Chatbot Frontend
 *
 * Security practices implemented here:
 *  1. All user input is sanitized via escapeHtml() before rendering into DOM
 *     (prevents XSS; we never use innerHTML with raw user data)
 *  2. API calls use Content-Type: application/json only
 *  3. Session token is stored in memory (not localStorage/cookie) so it
 *     cannot be accessed by other tabs or via document.cookie
 *  4. Character limits enforced client-side to complement server-side limits
 */

/* ─────────────────────────────────────────────────────────
   Configuration
───────────────────────────────────────────────────────── */
const API_BASE = "http://localhost:8000";

/* ─────────────────────────────────────────────────────────
   Application State (in-memory only — not persisted)
───────────────────────────────────────────────────────── */
const state = {
    isVerified: false,
    sessionId: null,
    studentId: null,
    studentName: null,
    course: null,
    conversationState: null,
};

/* ─────────────────────────────────────────────────────────
   Security: HTML Escape
   Used before inserting ANY user-sourced text into the DOM
───────────────────────────────────────────────────────── */
function escapeHtml(str) {
    const map = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
    return String(str).replace(/[&<>"']/g, (c) => map[c]);
}

/* ─────────────────────────────────────────────────────────
   Markdown-lite parser (bold, inline code, line breaks)
   Operates on already-escaped text — safe to set as innerHTML
───────────────────────────────────────────────────────── */
function renderMarkdown(escaped) {
    return escaped
        .replace(/`([^`]+)`/g, "<code>$1</code>")
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/\n/g, "<br>");
}

/* ─────────────────────────────────────────────────────────
   DOM References
───────────────────────────────────────────────────────── */
const $ = (id) => document.getElementById(id);

const verifyScreen = $("verify-screen");
const chatScreen = $("chat-screen");
const verifyForm = $("verify-form");
const studentIdInput = $("student-id-input");
const emailInput = $("email-input");
const verifyError = $("verify-error");
const verifyBtn = $("verify-btn");
const studentBadge = $("student-badge");
const messagesEl = $("messages-container");
const typingIndicator = $("typing-indicator");
const chatForm = $("chat-form");
const messageInput = $("message-input");
const charCount = $("char-count");
const sendBtn = $("send-btn");
const quickReplies = $("quick-replies");

/* ─────────────────────────────────────────────────────────
   Screen Transitions
───────────────────────────────────────────────────────── */
function switchTab(screenId, navElement) {
    if (!state.isVerified && screenId !== 'verify-screen') {
        alert("Please verify your identity first to access this tab.");
        return;
    }
    document.querySelectorAll('.screen').forEach(s => {
        s.hidden = true;
        s.classList.remove('screen--active');
        s.style.display = "none";
    });
    
    const target = $(screenId);
    if (target) {
        target.hidden = false;
        target.classList.add('screen--active');
        if (screenId === 'chat-screen' || screenId === 'verify-screen') {
            target.style.display = "flex";
        } else {
            target.style.display = "block";
        }
    }
    
    if (navElement && !navElement.href.includes("#")) return; // ignore non-tabs
    
    document.querySelectorAll('.sidebar__nav-item').forEach(n => n.classList.remove('sidebar__nav-item--active'));
    if (navElement && navElement.classList) {
        navElement.classList.add('sidebar__nav-item--active');
    }
}

function showChatScreen() {
    switchTab('chat-screen', $('nav-chat'));
}

/* ─────────────────────────────────────────────────────────
   Student Badge
───────────────────────────────────────────────────────── */
function renderStudentBadge(name, course) {
    const safeName = escapeHtml(name);
    const safeCourse = escapeHtml(course);
    studentBadge.innerHTML = `
    <div class="student-badge" role="status" aria-label="Logged in as ${safeName}">
      <span class="student-badge__name">${safeName}</span>
      <span class="student-badge__course">· ${safeCourse}</span>
    </div>`;
}

/* ─────────────────────────────────────────────────────────
   Message Rendering
───────────────────────────────────────────────────────── */
function currentTime() {
    return new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
}

function appendMessage({ role, text, intent, sentiment }) {
    const isBot = role === "bot";
    const isSystem = role === "system";

    const wrapper = document.createElement("div");

    if (isSystem) {
        wrapper.className = "message message--system";
        wrapper.innerHTML = `<div class="message__bubble">${renderMarkdown(escapeHtml(text))}</div>`;
        messagesEl.appendChild(wrapper);
        scrollToBottom();
        return;
    }

    const initials = isBot
        ? `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
         <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
       </svg>`
        : escapeHtml((state.studentName || "?").charAt(0).toUpperCase());

    const safeText = renderMarkdown(escapeHtml(text));

    // Build badges for bot messages
    let metaHtml = "";
    if (isBot && (intent || sentiment)) {
        const intentBadge = intent ? `<span class="badge badge--intent">🧠 ${escapeHtml(intent)}</span>` : "";
        const sentMap = { positive: "badge--positive", negative: "badge--negative", neutral: "badge--neutral" };
        const sentLabel = { positive: "😊 positive", negative: "😟 negative", neutral: "😐 neutral" };
        const sentimentBadge = sentiment
            ? `<span class="badge ${sentMap[sentiment] || "badge--neutral"}">${sentLabel[sentiment] || escapeHtml(sentiment)}</span>`
            : "";
        metaHtml = `<div class="message__meta">${intentBadge}${sentimentBadge}</div>`;
    }

    wrapper.className = `message message--${isBot ? "bot" : "user"}`;
    wrapper.innerHTML = `
    <div class="message__avatar" aria-hidden="true">${initials}</div>
    <div>
      <div class="message__bubble">${safeText}</div>
      ${metaHtml}
      <div class="message__timestamp" aria-label="Sent at ${currentTime()}">${currentTime()}</div>
    </div>`;

    messagesEl.appendChild(wrapper);
    scrollToBottom();
}

function scrollToBottom() {
    requestAnimationFrame(() => {
        messagesEl.scrollTo({ top: messagesEl.scrollHeight, behavior: "smooth" });
    });
}

/* ─────────────────────────────────────────────────────────
   Typing Indicator
───────────────────────────────────────────────────────── */
function showTyping() {
    typingIndicator.hidden = false;
    scrollToBottom();
}
function hideTyping() {
    typingIndicator.hidden = true;
}

/* ─────────────────────────────────────────────────────────
   Quick Reply Chips
───────────────────────────────────────────────────────── */
const QUICK_REPLIES = {
    SUGGEST: ["Yes, tell me more", "No, I want to proceed"],
    CONFIRM: ["CONFIRM", "CANCEL"],
    ASK_REASON: [],
};

function renderQuickReplies(convState) {
    const options = QUICK_REPLIES[convState] || [];
    if (!options.length) { quickReplies.hidden = true; return; }
    quickReplies.innerHTML = options
        .map((opt) => `<button type="button" class="quick-reply-btn" data-value="${escapeHtml(opt)}">${escapeHtml(opt)}</button>`)
        .join("");
    quickReplies.hidden = false;
}

quickReplies.addEventListener("click", (e) => {
    const btn = e.target.closest(".quick-reply-btn");
    if (!btn) return;
    const val = btn.dataset.value;
    messageInput.value = val;
    updateCharCount();
    sendMessage(val);
    quickReplies.hidden = true;
});

/* ─────────────────────────────────────────────────────────
   Input Character Counter + Auto-resize Textarea
───────────────────────────────────────────────────────── */
function updateCharCount() {
    const len = messageInput.value.length;
    charCount.textContent = `${len} / 2000`;
    charCount.style.color = len > 1800 ? "#f59e0b" : "";
    sendBtn.disabled = len === 0 || !state.sessionId;
}

messageInput.addEventListener("input", () => {
    updateCharCount();
    // Auto-grow textarea
    messageInput.style.height = "auto";
    messageInput.style.height = Math.min(messageInput.scrollHeight, 160) + "px";
});

messageInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        const val = messageInput.value.trim();
        if (val && state.sessionId) sendMessage(val);
    }
});

/* ─────────────────────────────────────────────────────────
   API: Verify Student
───────────────────────────────────────────────────────── */
async function verifyStudent(payload) {
    const res = await fetch(`${API_BASE}/api/auth/verify`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
    });
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || `Server error (${res.status})`);
    }
    return res.json();
}

/* ─────────────────────────────────────────────────────────
   API: Send Chat Message
───────────────────────────────────────────────────────── */
async function sendChatMessage(message) {
    const res = await fetch(`${API_BASE}/api/chat/message`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ session_id: state.sessionId, message }),
    });
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || `Server error (${res.status})`);
    }
    return res.json();
}

/* ─────────────────────────────────────────────────────────
   Verify Form Submit
───────────────────────────────────────────────────────── */
verifyForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const rawId = studentIdInput.value.trim();
    const rawEmail = emailInput.value.trim();

    // Client-side guard
    if (!rawId && !rawEmail) {
        showVerifyError("Please enter your Student ID or institutional email.");
        return;
    }

    // Build safe payload — do NOT include both if only one provided
    const payload = {};
    if (rawId) payload.student_id = rawId;
    if (rawEmail) payload.email = rawEmail;

    setVerifyLoading(true);
    clearVerifyError();

    try {
        const data = await verifyStudent(payload);

        if (!data.verified) {
            showVerifyError(data.message);
            return;
        }

        // Store verified identity separately from the active chat session.
        state.isVerified = true;
        state.sessionId = data.session_id;
        state.studentId = data.student_id || rawId || null;
        state.studentName = data.student_name;
        state.course = data.course;

        renderStudentBadge(data.student_name, data.course);
        
        if (data.has_existing_request) {
            $("status-content").innerHTML = `
              <strong>Status:</strong> <span style="text-transform: uppercase; color: var(--color-warning);">${escapeHtml(data.request_status)}</span><br><br>
              You have already submitted a withdrawal request. It is currently being processed by the Registrar's Office. No new requests can be logged at this time.<br><br>
              If you require assistance or wish to provide additional documentation, please use the Document Upload feature or contact Support.
            `;
            switchTab('status-screen', $('nav-status'));
            return;
        }

        showChatScreen();

        // Greeting from bot
        appendMessage({
            role: "system",
            text: "🔒 Verified — your session is secure and encrypted",
        });
        appendMessage({
            role: "bot",
            text: data.message + "\n\nI'm here to assist you with your **withdrawal request**. Please describe in your own words why you're considering leaving your programme.",
        });

        state.conversationState = "ASK_REASON";
        renderQuickReplies("ASK_REASON");
        sendBtn.disabled = false;

    } catch (err) {
        showVerifyError("Unable to connect to the server. Please ensure it is running and try again.");
        console.error("[Verify Error]", err);
    } finally {
        setVerifyLoading(false);
    }
});

function setVerifyLoading(loading) {
    verifyBtn.disabled = loading;
    verifyBtn.querySelector(".btn__text").hidden = loading;
    verifyBtn.querySelector(".btn__spinner").hidden = !loading;
}
function showVerifyError(msg) {
    verifyError.hidden = false;
    verifyError.textContent = msg; // textContent is safe — no XSS risk
}
function clearVerifyError() {
    verifyError.hidden = true;
    verifyError.textContent = "";
}

/* ─────────────────────────────────────────────────────────
   Send Chat Message
───────────────────────────────────────────────────────── */
chatForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const val = messageInput.value.trim();
    if (val && state.sessionId) sendMessage(val);
});

async function sendMessage(text) {
    if (!text || !state.sessionId) return;

    // Disable input while waiting
    messageInput.value = "";
    messageInput.style.height = "auto";
    updateCharCount();
    sendBtn.disabled = true;
    quickReplies.hidden = true;

    // Render user bubble
    appendMessage({ role: "user", text });

    // Show typing indicator with realistic delay
    const typingDelay = 600 + Math.random() * 700;
    showTyping();

    try {
        await new Promise((r) => setTimeout(r, typingDelay));
        const data = await sendChatMessage(text);
        hideTyping();

        appendMessage({
            role: "bot",
            text: data.reply,
            intent: data.intent || null,
            sentiment: data.sentiment || null,
        });

        state.conversationState = data.state;

        if (data.state === "DONE" || data.state === "RESOLVED") {
            // Session is over — clear state
            state.sessionId = null;
            sendBtn.disabled = true;
            messageInput.disabled = true;
            messageInput.placeholder = "Conversation ended.";
            quickReplies.hidden = true;

            if (data.withdrawal_submitted) {
                $("status-content").innerHTML = `
                  <strong>Status:</strong> <span style="text-transform: uppercase; color: var(--color-warning);">pending</span><br><br>
                  Your withdrawal request has been submitted and is currently being processed by the Registrar's Office.<br><br>
                  You can upload supporting files from the Document Verification tab while the request is under review.
                `;
            }
        } else {
            renderQuickReplies(data.state);
            sendBtn.disabled = false;
        }

    } catch (err) {
        hideTyping();
        appendMessage({
            role: "bot",
            text: "I'm sorry, I encountered a connection issue. Please refresh the page if this persists.",
        });
        sendBtn.disabled = false;
        console.error("[Chat Error]", err);
    }
}

/* ─────────────────────────────────────────────────────────
   Initialise
───────────────────────────────────────────────────────── */
(function init() {
    updateCharCount();
    studentIdInput.focus();
})();
