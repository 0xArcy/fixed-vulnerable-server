(() => {
    const API_BASE = "/api";

    const loginCard = document.getElementById("loginCard");
    const dashboardCard = document.getElementById("dashboardCard");
    const loginForm = document.getElementById("loginForm");
    const recordForm = document.getElementById("recordForm");
    const logoutBtn = document.getElementById("logoutBtn");

    const loginMessage = document.getElementById("loginMessage");
    const recordMessage = document.getElementById("recordMessage");
    const welcomeText = document.getElementById("welcomeText");

    const apiStatus = document.getElementById("apiStatus");
    const dbStatus = document.getElementById("dbStatus");
    const tokenSample = document.getElementById("tokenSample");
    const recordsBody = document.getElementById("recordsBody");

    let accessToken = localStorage.getItem("mb_access_token") || "";

    function setFeedback(element, text, type = "") {
        element.textContent = text;
        element.className = `feedback ${type}`.trim();
    }

    async function apiRequest(path, options = {}) {
        const headers = new Headers(options.headers || {});

        if (!headers.has("Content-Type") && options.body) {
            headers.set("Content-Type", "application/json");
        }

        if (accessToken) {
            headers.set("Authorization", `Bearer ${accessToken}`);
        }

        const response = await fetch(`${API_BASE}${path}`, {
            method: options.method || "GET",
            headers,
            body: options.body,
        });

        const text = await response.text();
        let payload = null;
        try {
            payload = text ? JSON.parse(text) : null;
        } catch (error) {
            payload = { error: "Unexpected response format." };
        }

        if (!response.ok) {
            const message = payload && payload.error ? payload.error : "Request failed.";
            throw new Error(message);
        }

        return payload;
    }

    function setAuthState(isAuthenticated) {
        loginCard.classList.toggle("hidden", isAuthenticated);
        dashboardCard.classList.toggle("hidden", !isAuthenticated);
    }

    function renderRecords(records) {
        recordsBody.innerHTML = "";

        if (!records || records.length === 0) {
            const row = document.createElement("tr");
            row.innerHTML = "<td colspan='4'>No records stored yet.</td>";
            recordsBody.appendChild(row);
            return;
        }

        records.forEach((record) => {
            const row = document.createElement("tr");
            const createdAt = new Date(record.createdAt).toLocaleString();
            row.innerHTML = `
                <td>${record.label}</td>
                <td>${record.accountLast4}</td>
                <td><code>${record.accountToken.slice(0, 24)}...</code></td>
                <td>${createdAt}</td>
            `;
            recordsBody.appendChild(row);
        });
    }

    async function refreshDashboard() {
        const [health, db, me, records, sample] = await Promise.all([
            apiRequest("/health"),
            apiRequest("/db-status"),
            apiRequest("/auth/me"),
            apiRequest("/records"),
            apiRequest("/tokenization/example"),
        ]);

        apiStatus.textContent = health.status === "ok" ? "TLS API healthy" : "Unhealthy";
        dbStatus.textContent = db.database_reachable ? "MongoDB connected over TLS" : "MongoDB unreachable";
        tokenSample.textContent = `${sample.tokenized.slice(0, 24)}...`;
        welcomeText.textContent = `Authenticated as ${me.username} (${me.role}).`;

        renderRecords(records.records || []);
    }

    async function trySessionRestore() {
        if (!accessToken) {
            setAuthState(false);
            return;
        }

        try {
            setAuthState(true);
            await refreshDashboard();
        } catch (error) {
            accessToken = "";
            localStorage.removeItem("mb_access_token");
            setAuthState(false);
        }
    }

    loginForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setFeedback(loginMessage, "Authenticating...");

        const form = new FormData(loginForm);
        const username = String(form.get("username") || "").trim();
        const password = String(form.get("password") || "");

        try {
            const payload = await apiRequest("/auth/login", {
                method: "POST",
                body: JSON.stringify({ username, password }),
            });

            accessToken = payload.accessToken || "";
            localStorage.setItem("mb_access_token", accessToken);
            setFeedback(loginMessage, "Authenticated.", "ok");
            setAuthState(true);
            await refreshDashboard();
            loginForm.reset();
        } catch (error) {
            setFeedback(loginMessage, error.message, "error");
        }
    });

    recordForm.addEventListener("submit", async (event) => {
        event.preventDefault();
        setFeedback(recordMessage, "Saving tokenized record...");

        const form = new FormData(recordForm);
        const payload = {
            label: String(form.get("label") || "").trim(),
            accountNumber: String(form.get("accountNumber") || "").trim(),
            note: String(form.get("note") || "").trim(),
        };

        try {
            await apiRequest("/records", {
                method: "POST",
                body: JSON.stringify(payload),
            });

            setFeedback(recordMessage, "Record saved in tokenized form.", "ok");
            recordForm.reset();
            await refreshDashboard();
        } catch (error) {
            setFeedback(recordMessage, error.message, "error");
        }
    });

    logoutBtn.addEventListener("click", () => {
        accessToken = "";
        localStorage.removeItem("mb_access_token");
        setAuthState(false);
    });

    trySessionRestore();
})();
