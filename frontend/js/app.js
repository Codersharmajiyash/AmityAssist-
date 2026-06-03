const API_BASE = "http://localhost:8000";

const state = {
    isVerified: false,
    sessionId: null,
    studentId: null,
    studentName: null,
    course: null,
    profile: null,
    conversationState: null,
};

const $ = (id) => document.getElementById(id);

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
const themeToggle = $("theme-toggle");

function escapeHtml(str) {
    const map = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
    return String(str ?? "").replace(/[&<>"']/g, (c) => map[c]);
}

function renderMarkdown(escaped) {
    return escaped
        .replace(/`([^`]+)`/g, "<code>$1</code>")
        .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
        .replace(/\n/g, "<br>");
}

function formatCurrency(value) {
    return new Intl.NumberFormat("en-IN", {
        style: "currency",
        currency: "INR",
        maximumFractionDigits: 0,
    }).format(Number(value || 0));
}

function switchTab(screenId, navElement) {
    if (!state.isVerified && screenId !== "verify-screen") {
        alert("Please verify your identity first to access this tab.");
        return;
    }

    document.querySelectorAll(".screen").forEach((screen) => {
        screen.hidden = true;
        screen.classList.remove("screen--active");
    });

    const target = $(screenId);
    if (target) {
        target.hidden = false;
        target.classList.add("screen--active");
    }

    document.querySelectorAll(".sidebar__nav-item").forEach((item) => {
        item.classList.remove("sidebar__nav-item--active");
    });
    if (navElement?.classList) {
        navElement.classList.add("sidebar__nav-item--active");
    }
}

function renderStudentBadge(name, course) {
    studentBadge.innerHTML = `
    <div class="student-badge" role="status" aria-label="Logged in as ${escapeHtml(name)}">
      <span class="student-badge__name">${escapeHtml(name)}</span>
      <span class="student-badge__course">${escapeHtml(course)}</span>
    </div>`;
}

function renderDashboard(profile) {
    const firstName = (profile.name || "Student").split(" ")[0];
    const attendance = Math.max(0, Math.min(100, Number(profile.attendance || 0)));
    const cgpa = Number(profile.cgpa || 0);

    $("welcome-name").textContent = `Hi ${firstName}, your campus cockpit is ready.`;
    $("welcome-summary").textContent = `${profile.course || "Programme"} student with ${attendance.toFixed(1)}% attendance and CGPA ${cgpa.toFixed(2)}.`;
    $("profile-branch").textContent = profile.branch ? `${profile.branch}` : "Branch -";
    $("profile-semester").textContent = profile.semester ? `Semester ${profile.semester}` : "Semester -";

    $("attendance-ring").style.setProperty("--progress", attendance);
    $("attendance-value").textContent = `${Math.round(attendance)}%`;
    $("cgpa-value").textContent = cgpa ? cgpa.toFixed(2) : "--";
    $("academic-note").textContent = attendance >= 75
        ? "Attendance is above the minimum threshold."
        : "Attendance needs attention before exam clearance.";
    $("performance-value").textContent = profile.academic_performance || "Academic standing unavailable.";
    $("fee-due-value").textContent = formatCurrency(profile.fee_due);
    $("fee-status-value").textContent = profile.fee_status || "Fee status unavailable.";
    $("hostel-status-value").textContent = profile.hostel_status || "Hostel status unavailable.";
    $("scholarship-status-value").textContent = profile.scholarship_status || "Scholarship status unavailable.";
}

function renderNotices(notices) {
    const list = $("notices-list");
    $("notice-count").textContent = notices.length;

    if (!notices.length) {
        list.innerHTML = `<p class="muted">No targeted notices for your current branch and semester.</p>`;
        return;
    }

    list.innerHTML = notices.slice(0, 4).map((notice) => `
      <article class="notice-item">
        <div>
          <span class="notice-item__category">${escapeHtml(notice.category)}</span>
          <h4>${escapeHtml(notice.title)}</h4>
        </div>
        <p>${escapeHtml(notice.content)}</p>
      </article>
    `).join("");
}

async function fetchStudentNotices(studentId) {
    const res = await fetch(`${API_BASE}/api/student/notices?student_id=${encodeURIComponent(studentId)}`);
    if (!res.ok) return [];
    return res.json();
}

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

verifyForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    const rawId = studentIdInput.value.trim();
    const rawEmail = emailInput.value.trim();

    if (!rawId && !rawEmail) {
        showVerifyError("Please enter your Student ID or institutional email.");
        return;
    }

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

        state.isVerified = true;
        state.sessionId = data.session_id;
        state.studentId = data.student_id || rawId || null;
        state.studentName = data.student_name;
        state.course = data.course;
        state.profile = {
            id: data.student_id,
            name: data.student_name,
            course: data.course,
            branch: data.branch,
            semester: data.semester,
            attendance: data.attendance,
            cgpa: data.cgpa,
            fee_status: data.fee_status,
            fee_due: data.fee_due,
            hostel_status: data.hostel_status,
            scholarship_status: data.scholarship_status,
            academic_performance: data.academic_performance,
            interests: data.interests,
        };

        renderStudentBadge(data.student_name, data.course);
        renderDashboard(state.profile);
        fetchStudentNotices(state.studentId).then(renderNotices).catch(() => renderNotices([]));

        if (data.has_existing_request) {
            $("status-content").innerHTML = `
              <strong>Status:</strong> <span class="status-label">${escapeHtml(data.request_status)}</span><br><br>
              You already have a withdrawal request under review. You can still use the dashboard and document center.`;
        }

        seedAdvisorGreeting(data.message);
        switchTab("dashboard-screen", $("nav-dashboard"));
        sendBtn.disabled = false;
    } catch (err) {
        showVerifyError("Unable to connect to the server. Please ensure it is running and try again.");
        console.error("[Verify Error]", err);
    } finally {
        setVerifyLoading(false);
    }
});

function seedAdvisorGreeting(message) {
    if (messagesEl.children.length) return;
    appendMessage({ role: "system", text: "Verified - your AmityAssist session is secure." });
    appendMessage({
        role: "bot",
        text: `${message}\n\nYou can ask me about **CGPA**, **attendance**, **scholarships**, **notices**, **grievances**, or **withdrawal refund estimates**.`,
    });
    state.conversationState = "ASK_REASON";
}

function setVerifyLoading(loading) {
    verifyBtn.disabled = loading;
    verifyBtn.querySelector(".btn__text").hidden = loading;
    verifyBtn.querySelector(".btn__spinner").hidden = !loading;
}

function showVerifyError(msg) {
    verifyError.hidden = false;
    verifyError.textContent = msg;
}

function clearVerifyError() {
    verifyError.hidden = true;
    verifyError.textContent = "";
}

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

    const initials = isBot ? "AI" : escapeHtml((state.studentName || "?").charAt(0).toUpperCase());
    let metaHtml = "";

    if (isBot && (intent || sentiment)) {
        const intentBadge = intent ? `<span class="badge badge--intent">${escapeHtml(intent)}</span>` : "";
        const sentMap = { positive: "badge--positive", negative: "badge--negative", neutral: "badge--neutral" };
        const sentimentBadge = sentiment
            ? `<span class="badge ${sentMap[sentiment] || "badge--neutral"}">${escapeHtml(sentiment)}</span>`
            : "";
        metaHtml = `<div class="message__meta">${intentBadge}${sentimentBadge}</div>`;
    }

    wrapper.className = `message message--${isBot ? "bot" : "user"}`;
    wrapper.innerHTML = `
    <div class="message__avatar" aria-hidden="true">${initials}</div>
    <div>
      <div class="message__bubble">${renderMarkdown(escapeHtml(text))}</div>
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

function showTyping() {
    typingIndicator.hidden = false;
    scrollToBottom();
}

function hideTyping() {
    typingIndicator.hidden = true;
}

const QUICK_REPLIES = {
    SUGGEST: ["Yes, tell me more", "No, I want to proceed"],
    CONFIRM: ["CONFIRM", "CANCEL"],
    ASK_REASON: [],
};

function renderQuickReplies(convState) {
    const options = QUICK_REPLIES[convState] || [];
    if (!options.length) {
        quickReplies.hidden = true;
        return;
    }
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

function updateCharCount() {
    const len = messageInput.value.length;
    charCount.textContent = `${len} / 2000`;
    charCount.style.color = len > 1800 ? "#b45309" : "";
    sendBtn.disabled = len === 0 || !state.sessionId;
}

messageInput.addEventListener("input", () => {
    updateCharCount();
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

chatForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const val = messageInput.value.trim();
    if (val && state.sessionId) sendMessage(val);
});

async function sendMessage(text) {
    if (!text || !state.sessionId) return;

    messageInput.value = "";
    messageInput.style.height = "auto";
    updateCharCount();
    sendBtn.disabled = true;
    quickReplies.hidden = true;
    appendMessage({ role: "user", text });
    showTyping();

    try {
        await new Promise((resolve) => setTimeout(resolve, 500 + Math.random() * 500));
        const data = await sendChatMessage(text);
        hideTyping();

        appendMessage({
            role: "bot",
            text: data.reply,
            intent: data.intent || null,
            sentiment: data.sentiment || null,
        });

        state.conversationState = data.state;

        if (data.state === "DONE") {
            state.sessionId = null;
            sendBtn.disabled = true;
            messageInput.disabled = true;
            messageInput.placeholder = "Conversation ended.";
            quickReplies.hidden = true;

            if (data.withdrawal_submitted) {
                $("status-content").innerHTML = `
                  <strong>Status:</strong> <span class="status-label">pending</span><br><br>
                  Your withdrawal request has been submitted and is currently being processed by the Registrar's Office.`;
            }
        } else {
            renderQuickReplies(data.state);
            sendBtn.disabled = false;
        }
    } catch (err) {
        hideTyping();
        appendMessage({ role: "bot", text: "I hit a connection issue. Please check the backend server and try again." });
        sendBtn.disabled = false;
        console.error("[Chat Error]", err);
    }
}

function setTheme(mode) {
    document.documentElement.dataset.theme = mode;
    themeToggle.setAttribute("aria-pressed", String(mode === "dark"));
    themeToggle.querySelector(".theme-toggle__text").textContent = mode === "dark" ? "Light" : "Dark";
}

themeToggle.addEventListener("click", () => {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark";
    setTheme(next);
});

(function init() {
    setTheme("light");
    updateCharCount();
    studentIdInput.focus();
})();
