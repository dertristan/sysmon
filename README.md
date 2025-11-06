# sysmon.ps1

A tiny (yet experimental) PowerShell system monitor that displays live CPU, RAM, and GPU stats directly in your terminal — no GUI needed.

---

### 🖥️ Example Output

Here is what it looks like in action:

![System Monitor Screenshot](img/screenshot.png)

---

### 📊 What It Shows

* **CPU Total** — overall system CPU usage
* **Core X** — per-core utilization (each bar = activity level)
* **Memory** — RAM usage (used vs total in MB)
* **GPU Usage** — currently **not functional** on most systems and will show `N/A`
* **Top 5 CPU Processes** — five processes with the highest total CPU time since startup

💡 *Tip:* The “CPU” number per process (e.g., `149.6 CPU`) shows the **total accumulated CPU seconds** since the process started — it does not reset between updates.

---

### ⚙️ Usage

1. Open PowerShell
