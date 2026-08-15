const API_BASE = "http://localhost:8000";

const state = {
    isVerified: false,
    sessionId: null,
    studentId: null,
    studentName: null,
    course: null,
    profile: null,
    conversationState: null,
    latestBotReply: "",
    recognition: null,
    isListening: false,
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
const logoutBtn = $("logout-btn");
const backpaperForm = $("backpaper-form");
const backpaperExam = $("backpaper-exam");
const backpaperStatus = $("backpaper-status");
const scholarshipList = $("scholarship-list");
const grievanceForm = $("grievance-form");
const grievanceDescription = $("grievance-description");
const documentForm = $("document-form");
const fileUpload = $("file-upload");
const documentSubmit = $("document-submit");
const documentStatus = $("document-status");
const voiceListenBtn = $("voice-listen-btn");
const voiceSpeakBtn = $("voice-speak-btn");
const voiceStatus = $("voice-status");

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

async function apiJson(path, options = {}) {
    const res = await fetch(`${API_BASE}${path}`, options);
    if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.detail || `Server error (${res.status})`);
    }
    return res.json();
}

async function fetchExams(studentId) {
    return apiJson(`/api/student/exams?student_id=${encodeURIComponent(studentId)}`);
}

async function fetchScholarships(studentId) {
    return apiJson(`/api/student/scholarships?student_id=${encodeURIComponent(studentId)}`);
}

async function fetchGrievances(studentId) {
    return apiJson(`/api/student/grievances?student_id=${encodeURIComponent(studentId)}`);
}

async function fetchWithdrawalStatus(studentId) {
    return apiJson(`/api/withdrawal/status/${encodeURIComponent(studentId)}`);
}

function statusClass(status) {
    const normalized = String(status || "pending").toLowerCase();
    if (["pass", "approved", "verified", "clean", "paid", "resolved"].includes(normalized)) return "record-pill--good";
    if (["fail", "f", "fraud_detected", "rejected", "error"].includes(normalized)) return "record-pill--danger";
    return "record-pill--pending";
}

function renderExams(exams) {
    $("academics-count").textContent = exams.length;
    const eligible = exams.filter((exam) => !exam.grade || ["F", "D"].includes(String(exam.grade).toUpperCase()));

    if (!exams.length) {
        $("exam-results").innerHTML = `<p class="muted">No exam records found for this student.</p>`;
    } else {
        $("exam-results").innerHTML = exams.map((exam) => `
          <article class="record-item">
            <div>
              <span class="record-item__meta">${escapeHtml(exam.exam_date || "Date pending")}</span>
              <h3>${escapeHtml(exam.subject_name || "Subject")}</h3>
              <p>${escapeHtml(exam.subject_code || "Code pending")} - ${escapeHtml(exam.exam_type || "Exam")}</p>
            </div>
            <div class="record-item__side">
              <span class="record-pill ${statusClass(exam.grade)}">Grade ${escapeHtml(exam.grade || "Pending")}</span>
              <span class="record-pill ${statusClass(exam.backpaper_status)}">${escapeHtml(exam.backpaper_status || "No backpaper")}</span>
            </div>
          </article>
        `).join("");
    }

    if (!eligible.length) {
        backpaperExam.innerHTML = `<option value="">No eligible backpapers</option>`;
        backpaperExam.disabled = true;
    } else {
        backpaperExam.disabled = false;
        backpaperExam.innerHTML = `<option value="">Choose a subject</option>` + eligible.map((exam) => (
            `<option value="${exam.id}">${escapeHtml(exam.subject_name)} (${escapeHtml(exam.grade || "Pending")})</option>`
        )).join("");
    }
}

function renderScholarships(schemes) {
    $("scholarship-count").textContent = schemes.length;
    const eligibleCount = schemes.filter((scheme) => scheme.eligible).length;
    $("scholarship-readiness").textContent = `${eligibleCount} Eligible`;
    $("scholarship-readiness-copy").textContent = eligibleCount
        ? "One-click applications are enabled for eligible schemes."
        : "No schemes match your current CGPA threshold.";

    if (!schemes.length) {
        scholarshipList.innerHTML = `<p class="muted">No scholarship schemes are currently published.</p>`;
        return;
    }

    scholarshipList.innerHTML = schemes.map((scheme) => {
        const alreadyApplied = Boolean(scheme.application_status);
        const disabled = !scheme.eligible || alreadyApplied;
        const label = alreadyApplied ? `Status: ${scheme.application_status}` : (scheme.eligible ? "Apply Now" : "Not Eligible");
        return `
          <article class="record-item">
            <div>
              <span class="record-item__meta">Minimum CGPA ${escapeHtml(scheme.eligibility_cgpa)}</span>
              <h3>${escapeHtml(scheme.name)}</h3>
              <p>${escapeHtml(scheme.description || "Scholarship details available through student welfare.")}</p>
            </div>
            <div class="record-item__side">
              <span class="record-pill ${scheme.eligible ? "record-pill--good" : "record-pill--pending"}">${scheme.eligible ? "Eligible" : "Review"}</span>
              <button class="btn btn--compact" type="button" data-scholarship-id="${scheme.id}" ${disabled ? "disabled" : ""}>${escapeHtml(label)}</button>
            </div>
          </article>
        `;
    }).join("");
}

function renderGrievances(items) {
    $("grievance-count").textContent = items.length;
    if (!items.length) {
        $("grievance-timeline").innerHTML = `<p class="muted">No grievances filed yet.</p>`;
        return;
    }

    $("grievance-timeline").innerHTML = items.map((item) => `
      <article class="timeline-item">
        <div class="timeline-item__dot"></div>
        <div>
          <span class="record-item__meta">${escapeHtml(item.timestamp || "Submitted")}</span>
          <h3>${escapeHtml(item.category)} - ${escapeHtml(item.status || "pending")}</h3>
          <p>${escapeHtml(item.description)}</p>
          ${item.resolution ? `<p class="timeline-item__resolution">${escapeHtml(item.resolution)}</p>` : ""}
        </div>
      </article>
    `).join("");
}

function renderWithdrawalWorkflow(data) {
    const guide = data.guide || {};
    const request = data.request || {};
    const steps = guide.steps || [];
    const forms = guide.forms || [];
    const checklist = data.has_request ? (data.checklist || []) : (guide.documents || []);

    $("withdrawal-step-count").textContent = steps.length;
    $("withdrawal-checklist-count").textContent = checklist.length;

    if (data.has_request) {
        $("status-content").innerHTML = `
          <strong>Reference:</strong> ${escapeHtml(request.reference_no || "Pending")}<br>
          <strong>Status:</strong> <span class="status-label">${escapeHtml(request.status || "pending")}</span><br>
          <strong>Reason:</strong> ${escapeHtml(request.reason || "Not recorded")}<br><br>
          According to the official procedure, initial verification generally takes 1-2 working days after submission.`;
    } else {
        $("status-content").innerHTML = `
          <strong>No active withdrawal request.</strong><br><br>
          Review the official steps, required documents, and forms before starting the workflow.`;
    }

    $("withdrawal-checklist").innerHTML = checklist.length ? checklist.map((item) => `
      <article class="record-item">
        <div>
          <span class="record-item__meta">${escapeHtml(item.mandatory ? "Required" : (item.status || "Pending"))}</span>
          <h3>${escapeHtml(item.label || item.name)}</h3>
          <p>${escapeHtml(item.description)}</p>
        </div>
      </article>
    `).join("") : `<p class="muted">No document requirements are configured.</p>`;

    $("withdrawal-steps").innerHTML = steps.length ? steps.map((step) => `
      <article class="timeline-item">
        <div class="timeline-item__dot"></div>
        <div>
          <span class="record-item__meta">Step ${escapeHtml(step.step_number)} - ${escapeHtml(step.department)}</span>
          <h3>${escapeHtml(step.title)}</h3>
          <p>${escapeHtml(step.description)}</p>
          <p class="timeline-item__resolution">${escapeHtml(step.timeline_text)}</p>
        </div>
      </article>
    `).join("") : `<p class="muted">No official steps are configured.</p>`;

    $("withdrawal-forms").innerHTML = forms.length ? forms.map((form) => `
      <article class="record-item">
        <div>
          <span class="record-item__meta">${escapeHtml(form.issuing_department)}</span>
          <h3>${escapeHtml(form.name)}</h3>
          <p>${escapeHtml(form.description)}</p>
        </div>
        <div class="record-item__side">
          <span class="record-pill record-pill--pending">Form</span>
        </div>
      </article>
    `).join("") : `<p class="muted">No forms are configured.</p>`;
}

async function loadLifecycleModules() {
    if (!state.studentId) return;
    const [exams, scholarships, grievances, withdrawal] = await Promise.all([
        fetchExams(state.studentId),
        fetchScholarships(state.studentId),
        fetchGrievances(state.studentId),
        fetchWithdrawalStatus(state.studentId),
    ]);
    renderExams(exams);
    renderScholarships(scholarships);
    renderGrievances(grievances);
    renderWithdrawalWorkflow(withdrawal);
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
        loadLifecycleModules().catch((err) => console.error("[Lifecycle Load Error]", err));
        document.body.classList.remove("auth-view");

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

function logoutSession() {
    if (state.recognition && state.isListening) {
        state.recognition.stop();
    }
    if ("speechSynthesis" in window) {
        window.speechSynthesis.cancel();
    }

    state.isVerified = false;
    state.sessionId = null;
    state.studentId = null;
    state.studentName = null;
    state.course = null;
    state.profile = null;
    state.conversationState = null;
    state.latestBotReply = "";

    verifyForm.reset();
    clearVerifyError();
    studentBadge.innerHTML = "";
    messagesEl.innerHTML = "";
    quickReplies.hidden = true;
    hideTyping();

    messageInput.disabled = false;
    messageInput.placeholder = "Ask about CGPA, attendance, scholarship, hostel, or withdrawal...";
    messageInput.value = "";
    messageInput.style.height = "auto";
    sendBtn.disabled = true;
    updateCharCount();

    backpaperStatus.textContent = "";
    $("grievance-status").textContent = "";
    documentStatus.textContent = "";
    $("ocr-results").innerHTML = `<p class="muted">OCR fields and warnings will appear after upload.</p>`;
    fileUpload.value = "";

    document.body.classList.add("auth-view");
    switchTab("verify-screen", null);
    studentIdInput.focus();
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

    if (isBot) {
        state.latestBotReply = text;
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

backpaperForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!state.studentId) return;
    const examId = Number(backpaperExam.value);
    if (!examId) {
        backpaperStatus.textContent = "Choose an eligible exam first.";
        return;
    }

    backpaperStatus.textContent = "Registering backpaper...";
    try {
        const data = await apiJson("/api/student/backpaper", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ student_id: state.studentId, exam_id: examId }),
        });
        backpaperStatus.textContent = data.message;
        renderExams(await fetchExams(state.studentId));
    } catch (err) {
        backpaperStatus.textContent = err.message;
    }
});

scholarshipList.addEventListener("click", async (e) => {
    const btn = e.target.closest("[data-scholarship-id]");
    if (!btn || !state.studentId) return;
    btn.disabled = true;
    btn.textContent = "Applying...";
    try {
        await apiJson("/api/student/scholarships/apply", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ student_id: state.studentId, scholarship_id: Number(btn.dataset.scholarshipId) }),
        });
        renderScholarships(await fetchScholarships(state.studentId));
    } catch (err) {
        btn.textContent = err.message;
    }
});

grievanceForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!state.studentId) return;
    const description = grievanceDescription.value.trim();
    if (description.length < 5) {
        $("grievance-status").textContent = "Please enter at least 5 characters.";
        return;
    }

    $("grievance-status").textContent = "Submitting grievance...";
    try {
        const data = await apiJson("/api/student/grievances", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                student_id: state.studentId,
                category: $("grievance-category").value,
                description,
            }),
        });
        $("grievance-status").textContent = data.message;
        grievanceDescription.value = "";
        renderGrievances(await fetchGrievances(state.studentId));
    } catch (err) {
        $("grievance-status").textContent = err.message;
    }
});

function renderOcrResults(data) {
    const ocr = data.ocr_data || {};
    const warnings = data.fraud_flags || [];
    $("ocr-results").innerHTML = `
      <div class="ocr-header">
        <span class="record-pill ${statusClass(data.overall_status)}">${escapeHtml(data.overall_status)}</span>
        <span class="record-pill ${statusClass(data.verification_status)}">${escapeHtml(data.verification_status)}</span>
      </div>
      <dl class="ocr-fields">
        <div><dt>Name</dt><dd>${escapeHtml(ocr.extracted_name || "-")}</dd></div>
        <div><dt>Student ID</dt><dd>${escapeHtml(ocr.extracted_student_id || "-")}</dd></div>
        <div><dt>Document</dt><dd>${escapeHtml(ocr.document_type || "-")}</dd></div>
        <div><dt>Confidence</dt><dd>${Math.round(Number(ocr.confidence_score || 0) * 100)}%</dd></div>
        <div><dt>Image Quality</dt><dd>${Math.round(Number(ocr.image_quality_score || 0) * 100)}%</dd></div>
        <div><dt>Signature</dt><dd>${ocr.signature_detected ? "Detected" : "Missing"}</dd></div>
      </dl>
      <div class="fraud-box ${warnings.length ? "fraud-box--warn" : "fraud-box--clean"}">
        <strong>${warnings.length ? "Fraud warnings" : "Fraud screening clean"}</strong>
        <p>${escapeHtml(warnings.join("; ") || "No tampering, duplicate, or quality warnings detected.")}</p>
      </div>
    `;
}

documentForm.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!state.studentId) return;
    if (!fileUpload.files.length) {
        documentStatus.textContent = "Choose a PDF, JPG, or PNG document.";
        return;
    }

    const formData = new FormData();
    formData.append("student_id", state.studentId);
    formData.append("file", fileUpload.files[0]);

    documentSubmit.disabled = true;
    documentStatus.textContent = "Scanning document...";
    $("scan-preview").classList.add("scan-preview--active");

    try {
        await new Promise((resolve) => setTimeout(resolve, 650));
        const data = await apiJson("/api/documents/upload", {
            method: "POST",
            body: formData,
        });
        documentStatus.textContent = data.message;
        renderOcrResults(data);
        fileUpload.value = "";
    } catch (err) {
        documentStatus.textContent = err.message;
    } finally {
        documentSubmit.disabled = false;
        $("scan-preview").classList.remove("scan-preview--active");
    }
});

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
                fetchWithdrawalStatus(state.studentId).then(renderWithdrawalWorkflow).catch(() => {
                    $("status-content").innerHTML = `
                      <strong>Status:</strong> <span class="status-label">pending</span><br><br>
                      Your withdrawal request has been submitted and is currently being processed by the Registrar's Office.`;
                });
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

logoutBtn.addEventListener("click", () => {
    logoutSession();
});

function setVoiceStatus(text) {
    voiceStatus.textContent = text;
}

function setupVoiceControls() {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    const speechSupported = "speechSynthesis" in window;

    if (!SpeechRecognition) {
        voiceListenBtn.disabled = true;
        setVoiceStatus("Voice input unavailable");
    } else {
        state.recognition = new SpeechRecognition();
        state.recognition.lang = "en-IN";
        state.recognition.interimResults = false;
        state.recognition.continuous = false;

        state.recognition.addEventListener("start", () => {
            state.isListening = true;
            voiceListenBtn.setAttribute("aria-pressed", "true");
            voiceListenBtn.textContent = "Stop";
            setVoiceStatus("Listening...");
        });

        state.recognition.addEventListener("result", (event) => {
            const transcript = Array.from(event.results)
                .map((result) => result[0]?.transcript || "")
                .join(" ")
                .trim();
            if (!transcript) return;
            messageInput.value = transcript;
            updateCharCount();
            setVoiceStatus("Transcript ready");
            if (state.sessionId) {
                sendMessage(transcript);
            }
        });

        state.recognition.addEventListener("end", () => {
            state.isListening = false;
            voiceListenBtn.setAttribute("aria-pressed", "false");
            voiceListenBtn.textContent = "Mic";
            if (voiceStatus.textContent === "Listening...") setVoiceStatus("Voice ready");
        });

        state.recognition.addEventListener("error", () => {
            setVoiceStatus("Voice input blocked");
        });
    }

    if (!speechSupported) {
        voiceSpeakBtn.disabled = true;
        if (!SpeechRecognition) setVoiceStatus("Voice unavailable");
    }
}

voiceListenBtn.addEventListener("click", () => {
    if (!state.recognition) return;
    if (state.isListening) {
        state.recognition.stop();
    } else {
        state.recognition.start();
    }
});

voiceSpeakBtn.addEventListener("click", () => {
    if (!("speechSynthesis" in window)) return;
    const text = state.latestBotReply || "Verify your identity, then ask Amity Advisor for help.";
    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = "en-IN";
    utterance.rate = 0.96;
    utterance.onstart = () => setVoiceStatus("Speaking...");
    utterance.onend = () => setVoiceStatus("Voice ready");
    utterance.onerror = () => setVoiceStatus("Speech blocked");
    window.speechSynthesis.speak(utterance);
});

(function init() {
    setTheme("light");
    updateCharCount();
    setupVoiceControls();
    studentIdInput.focus();
})();
