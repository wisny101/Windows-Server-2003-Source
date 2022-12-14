/***************************** Module Header ******************************\
* Module Name: csrstubs.c
*
* Copyright (c) 1985 - 1999, Microsoft Corporation
*
* Routines to call CSR
*
* 02-27-95 JimA             Created.
*
* Note: This file has been partitioned with #if defines so that the LPC
* marshalling code can be inside 64bit code when running under wow64 (32bit on
* 64bit NT). In wow64, the system DLLs for 32bit processes are 32bit.
*
* The marshalling code can only be depedent on functions in NTDLL.
\**************************************************************************/

#include "precomp.h"
#pragma hdrstop

#include "csrmsg.h"
#include "csrhlpr.h"
#include "strid.h"
#include <dbt.h>
#include <regstr.h>
#include <winsta.h>     // for WinStationGetTermSrvCountersValue
#include <allproc.h>    // for TS_COUNTER

#define ALIGN_DOWN(length, type) \
    ((ULONG)(length) & ~(sizeof(type) - 1))

#define ALIGN_UP(length, type) \
    (ALIGN_DOWN(((ULONG)(length) + sizeof(type) - 1), type))

CONST WCHAR gszReliabilityKey[] = L"\\Registry\\Machine\\" REGSTR_PATH_RELIABILITY;
CONST WCHAR gszReliabilityPolicyKey[] = L"\\Registry\\Machine\\Software\\Policies\\Microsoft\\Windows NT\\Reliability";

#if defined(BUILD_CSRWOW64)

#undef RIPERR0
#undef RIPNTERR0
#undef RIPMSG0

#define RIPNTERR0(status, flags, szFmt) {if (NtCurrentTeb()) NtCurrentTeb()->LastErrorValue = RtlNtStatusToDosError(status);}
#define RIPERR0(idErr, flags, szFmt) {if (NtCurrentTeb()) NtCurrentTeb()->LastErrorValue = (idErr);}
#define RIPMSG0(flags, szFmt)

#endif

#define SET_LAST_ERROR_RETURNED()   if (a->dwLastError) RIPERR0(a->dwLastError, RIP_VERBOSE, "")

#if !defined(BUILD_WOW6432)

NTSTATUS
APIENTRY
CallUserpExitWindowsEx(
    IN UINT uFlags,
    OUT PBOOL pfSuccess)
{

    USER_API_MSG m;
    PEXITWINDOWSEXMSG a = &m.u.ExitWindowsEx;

    a->uFlags = uFlags;
    CsrClientCallServer( (PCSR_API_MSG)&m,
                         NULL,
                         CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                              UserpExitWindowsEx
                                            ),
                         sizeof( *a )
                       );

    if (NT_SUCCESS( m.ReturnValue ) || m.ReturnValue == STATUS_CANT_WAIT) {
        SET_LAST_ERROR_RETURNED();
        *pfSuccess = a->fSuccess;
    } else {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "");
        *pfSuccess = FALSE;
    }

    return m.ReturnValue;

}

#endif

#if !defined(BUILD_CSRWOW64)

typedef struct _EXITWINDOWSDATA {
    UINT uFlags;
} EXITWINDOWSDATA, *PEXITWINDOWSDATA;

__inline void GetShutdownType(LPWSTR pszBuff, int cch, DWORD dwFlags)
{
    if ((dwFlags & (EWX_POWEROFF | EWX_WINLOGON_OLD_POWEROFF)) != 0) {
        LoadString(hmodUser, STR_SHUTDOWN_POWEROFF, pszBuff, cch);
    } else if ((dwFlags & (EWX_REBOOT | EWX_WINLOGON_OLD_REBOOT)) != 0) {
        LoadString(hmodUser, STR_SHUTDOWN_REBOOT, pszBuff, cch);
    } else if ((dwFlags & (EWX_SHUTDOWN | EWX_WINLOGON_OLD_SHUTDOWN)) != 0) {
        LoadString(hmodUser, STR_SHUTDOWN_SHUTDOWN, pszBuff, cch);
    } else {
        LoadString(hmodUser, STR_UNKNOWN, pszBuff, cch);
    }
}

/***************************************************************************\
* CsrTestShutdownPrivilege
*
* Looks at the user token to determine if they have shutdown privilege
*
* Returns TRUE if the user has the privilege, otherwise FALSE
*
\***************************************************************************/
BOOL
CsrTestShutdownPrivilege(
    HANDLE UserToken
    )
{
    NTSTATUS    Status;
    LUID        LuidPrivilege = RtlConvertLongToLuid(SE_SHUTDOWN_PRIVILEGE);
    LUID        TokenPrivilege;
    ULONG       BytesRequired;
    ULONG       i;
    BOOL        bHasPrivilege = FALSE;
    BOOL        bNetWork = FALSE;
    PSID        NetworkSid = NULL;
    PTOKEN_PRIVILEGES Privileges = NULL;
    SID_IDENTIFIER_AUTHORITY NtAuthority = SECURITY_NT_AUTHORITY;

    Status = RtlAllocateAndInitializeSid(&NtAuthority,
                                          1, SECURITY_NETWORK_RID,
                                          0, 0, 0, 0, 0, 0, 0,
                                          &NetworkSid );

    if (!NT_SUCCESS(Status)) {
        goto Cleanup;
    }

    // Ok for this call to fail, in that case we assume local shutdown.
    if (CheckTokenMembership(UserToken, NetworkSid, &bNetWork)) {
        if (bNetWork) {
            LuidPrivilege = RtlConvertLongToLuid(SE_REMOTE_SHUTDOWN_PRIVILEGE);
        }
    }

    Status = NtQueryInformationToken(
                 UserToken,
                 TokenPrivileges,
                 NULL,
                 0,
                 &BytesRequired
                 );

    if (Status != STATUS_BUFFER_TOO_SMALL) {
        goto Cleanup;
    }

    Privileges = (PTOKEN_PRIVILEGES)UserLocalAlloc(HEAP_ZERO_MEMORY,
                                                   BytesRequired);
    if (Privileges == NULL) {
        goto Cleanup;
    }

    Status = NtQueryInformationToken(
                 UserToken,
                 TokenPrivileges,
                 Privileges,
                 BytesRequired,
                 &BytesRequired
                 );

    if (!NT_SUCCESS(Status)) {
        goto Cleanup;
    }

    for (i=0; i<Privileges->PrivilegeCount; i++) {
        TokenPrivilege = *((LUID UNALIGNED *) &Privileges->Privileges[i].Luid);
        if (RtlEqualLuid(&TokenPrivilege, &LuidPrivilege)) {
            bHasPrivilege = TRUE;
            break;
        }
    }

Cleanup:
    if (NetworkSid) {
        RtlFreeSid(NetworkSid);
    }

    if (Privileges) {
        UserLocalFree(Privileges);
    }
    return bHasPrivilege;
}

FUNCLOG1(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, RecordShutdownReason, PSHUTDOWN_REASON, psr)
BOOL RecordShutdownReason(
    PSHUTDOWN_REASON psr)
{
    PCSR_CAPTURE_HEADER CaptureBuffer = NULL;
    HANDLE  hToken = NULL;
    DWORD   dwEventID;
    DWORD   dwTotalLen = 0;     // length for the capture buffer.
    DWORD   dwCntPointers = 0;  // number of message pointers for the capture buffer.
    DWORD   dwProcessNameLen = MAX_PATH + 1;
    DWORD   dwShutdownTypeLen = SHUTDOWN_TYPE_LEN;
    BOOL    bRet = FALSE;
    LPWSTR  lpszBuf = NULL;
    USER_API_MSG m;
    NTSTATUS status;
    PRECORDSHUTDOWNREASONMSG a = &(m.u.RecordShutdownReason);

    // Check privilege. We dont want a user without shutdown privilege to call this.
    status = NtOpenThreadToken(NtCurrentThread(),TOKEN_QUERY, FALSE, &hToken);
    if (!NT_SUCCESS(status)) {
        status = NtOpenThreadToken(NtCurrentThread(),TOKEN_QUERY, TRUE, &hToken);
        if (!NT_SUCCESS(status)) {
            status = NtOpenProcessToken(NtCurrentProcess(),TOKEN_QUERY, &hToken);
            if (!NT_SUCCESS(status)) {
                RIPNTERR0(status, RIP_WARNING, "Cannot get token in RecordShutdownReason");
                goto Cleanup;
            }
        }
    }

    if (!CsrTestShutdownPrivilege(hToken)) {
        NtClose(hToken);
        RIPERR0(ERROR_ACCESS_DENIED, RIP_WARNING, "Access denied in RecordShutdownReason");
        goto Cleanup;
    }
    NtClose(hToken);

    // Validate the structure
    if (psr == NULL || psr->cbSize != sizeof(SHUTDOWN_REASON)) {
        RIPERR1(ERROR_INVALID_PARAMETER, RIP_WARNING, "Bad psr %p in RecordShutdownReason", psr);
        goto Cleanup;
    }

    dwCntPointers = 3;
    dwTotalLen = dwProcessNameLen * sizeof(WCHAR) + dwShutdownTypeLen * sizeof(WCHAR) + sizeof(SHUTDOWN_REASON);

    // Initialize all lengthes to 0
    a->dwProcessNameLen = a->dwShutdownTypeLen = a->dwCommentLen = 0;

    // Add Comment if we have one.
    if (psr->lpszComment && wcslen(psr->lpszComment)) {
        dwCntPointers++;
        a->dwCommentLen = wcslen(psr->lpszComment) + 1;
        dwTotalLen += a->dwCommentLen * sizeof(WCHAR);
    }

    // Adjust for the possible round up.
    dwTotalLen += dwCntPointers * (sizeof(PVOID) - 1);

    CaptureBuffer = CsrAllocateCaptureBuffer(dwCntPointers, dwTotalLen);
    if (CaptureBuffer == NULL) {
        goto Cleanup;
    }

    // lpszBuf is shared for both process name and shutdown type.
    // Make sure the len is the maximum of all of them.
    lpszBuf = (LPWSTR)UserLocalAlloc(0, (dwProcessNameLen >= dwShutdownTypeLen ?
                            dwProcessNameLen : dwShutdownTypeLen) * sizeof(WCHAR));
    if (!lpszBuf) {
        goto Cleanup;
    }

    // Fill the process name
    if (!GetCurrentProcessName(lpszBuf, dwProcessNameLen)) {
        RIPMSG0(RIP_WARNING, "Failed to GetCurrentProcessName in RecordShutdownReason");
        goto Cleanup;
    }
    lpszBuf[MAX_PATH] = 0;
    a->dwProcessNameLen = wcslen(lpszBuf)+1;
    CsrAllocateMessagePointer(CaptureBuffer, ALIGN_UP(a->dwProcessNameLen * sizeof(WCHAR), PVOID), &a->pwchProcessName);
    wcscpy(a->pwchProcessName, lpszBuf);

    // Fill the shutdown type.
    GetShutdownType(lpszBuf, dwShutdownTypeLen, psr->uFlags);
    lpszBuf[SHUTDOWN_TYPE_LEN-1] = 0;
    a->dwShutdownTypeLen = wcslen(lpszBuf)+1;
    CsrAllocateMessagePointer(CaptureBuffer, ALIGN_UP(a->dwShutdownTypeLen * sizeof(WCHAR), PVOID), &a->pwchShutdownType);
    wcscpy(a->pwchShutdownType, lpszBuf);

    // copy over the SHUTDOWN_REASON.
    CsrAllocateMessagePointer(CaptureBuffer, ALIGN_UP(sizeof(SHUTDOWN_REASON), PVOID), &a->psr);
    memcpy(a->psr, psr, sizeof(SHUTDOWN_REASON));

    if (psr->lpszComment && !wcslen(psr->lpszComment)) {
        a->psr->lpszComment = NULL;
    }

    if (psr->lpszComment && wcslen(psr->lpszComment)){
        CsrAllocateMessagePointer(CaptureBuffer, ALIGN_UP(a->dwCommentLen * sizeof(WCHAR), PVOID), &a->pwchComment);
        wcscpy(a->pwchComment, psr->lpszComment);
    }

    switch (psr->dwEventType) {
    case SR_EVENT_EXITWINDOWS:
        if (psr->fShutdownCancelled) {
            dwEventID = WARNING_EW_SHUTDOWN_CANCELLED;
        } else {
            dwEventID = STATUS_SHUTDOWN_CLEAN;
        }
        break;
    case SR_EVENT_INITIATE_CLEAN:
        dwEventID = STATUS_SHUTDOWN_CLEAN;
        break;
    case SR_EVENT_INITIATE_CLEAN_ABORT:
        dwEventID = WARNING_ISSE_SHUTDOWN_CANCELLED;
        break;
    case SR_EVENT_DIRTY:
        dwEventID = WARNING_DIRTY_REBOOT;
        break;
    default:
        goto Cleanup;
    }

    a->dwEventID = dwEventID;
    a->dwEventType = psr->dwEventType;
    a->fShutdownCancelled = psr->fShutdownCancelled;

    status = CsrClientCallServer((PCSR_API_MSG)&m,
                         CaptureBuffer,
                         CSR_MAKE_API_NUMBER(USERSRV_SERVERDLL_INDEX,
                                              UserpRecordShutdownReason
                                            ),
                         sizeof(*a)
                       );

    bRet = NT_SUCCESS(status);

Cleanup:
    if (CaptureBuffer) {
        CsrFreeCaptureBuffer(CaptureBuffer);
    }

    if (lpszBuf) {
        UserLocalFree(lpszBuf);
    }

    return bRet;
}

UINT GetLoggedOnUserCount(
    VOID)
{
    int iCount = 0;
    BOOLEAN bSuccess;

    TS_COUNTER TSCountersDyn[2];

    TSCountersDyn[0].counterHead.dwCounterID = TERMSRV_CURRENT_DISC_SESSIONS;
    TSCountersDyn[1].counterHead.dwCounterID = TERMSRV_CURRENT_ACTIVE_SESSIONS;

    // access the termsrv counters to find out how many users are logged onto the system
    bSuccess = WinStationGetTermSrvCountersValue(SERVERNAME_CURRENT, 2, TSCountersDyn);

    if (bSuccess) {
        if (TSCountersDyn[0].counterHead.bResult)
            iCount += TSCountersDyn[0].dwValue;

        if (TSCountersDyn[1].counterHead.bResult)
            iCount += TSCountersDyn[1].dwValue;
    }

    return iCount;
}

BOOL IsSeShutdownNameEnabled()
{
    BOOL bRet = FALSE;  // assume the privilege is not held
    NTSTATUS Status;
    HANDLE hToken;

    // try to get the thread token
    Status = NtOpenThreadToken(GetCurrentThread(),
                               TOKEN_QUERY,
                               FALSE,
                               &hToken);
    if (!NT_SUCCESS(Status)) {
        // try the process token if we failed to get the thread token
        Status = NtOpenProcessToken(GetCurrentProcess(),
                                    TOKEN_QUERY,
                                    &hToken);
    }

    if (NT_SUCCESS(Status)) {
        DWORD cbSize = 0;
        TOKEN_PRIVILEGES* ptp;

        NtQueryInformationToken(hToken,
                                TokenPrivileges,
                                NULL,
                                0,
                                &cbSize);
        if (cbSize) {
            ptp = (TOKEN_PRIVILEGES*)UserLocalAlloc(0, cbSize);
        } else {
            ptp = NULL;
        }

        if (ptp) {
            Status = NtQueryInformationToken(hToken,
                                             TokenPrivileges,
                                             ptp,
                                             cbSize,
                                             &cbSize);
            if (NT_SUCCESS(Status)) {
                DWORD i;
                for (i = 0; i < ptp->PrivilegeCount; i++) {
                    if (((ptp->Privileges[i].Luid.HighPart == 0) && (ptp->Privileges[i].Luid.LowPart == SE_SHUTDOWN_PRIVILEGE)) &&
                        (ptp->Privileges[i].Attributes & (SE_PRIVILEGE_ENABLED_BY_DEFAULT | SE_PRIVILEGE_ENABLED))) {
                        // found the privilege and it is enabled
                        bRet = TRUE;
                        break;
                    }
                }
            }

            UserLocalFree(ptp);
        }

        NtClose(hToken);
    }

    return bRet;
}

BOOL NeedsDisplayWarning (UINT uNumUsers, UINT uExitWindowsFlags)
{

    //  If EWX_SYSTEM_CALLER then there's nobody on this session.
    //  Add one from the number of users.

    if ((uExitWindowsFlags & EWX_SYSTEM_CALLER) && (uNumUsers > 0))
    {
        ++uNumUsers;
    }

    //  If number of users > 1 or EWX_WINLOGON_CALLER display warning.

    return (uNumUsers > 1) || (uExitWindowsFlags & EWX_WINLOGON_CALLER);
}

FUNCLOG1(LOG_GENERAL, BOOL, APIENTRY, DisplayExitWindowsWarnings, UINT, uExitWindowsFlags)
BOOL APIENTRY DisplayExitWindowsWarnings(UINT uExitWindowsFlags)
{
    BOOL bContinue = TRUE;
    BOOL fIsRemote = ISREMOTESESSION();
    UINT uNumUsers = GetLoggedOnUserCount();
    UINT uID = 0;

    // it would be nice to check the HKCU\ControlPanel\Desktop\AutoEndTask value and not display any UI if it is set,
    // but since we are called from services it is probably better to not go mucking about in the per-user hive

    if (uExitWindowsFlags & (EWX_POWEROFF | EWX_WINLOGON_OLD_POWEROFF | EWX_SHUTDOWN | EWX_WINLOGON_OLD_SHUTDOWN)) {
        if (fIsRemote) {
            if (NeedsDisplayWarning(uNumUsers, uExitWindowsFlags)) {
                // Warn the user if remote shut down w/ active users
                uID = IDS_SHUTDOWN_REMOTE_OTHERUSERS;
            } else {
                // Warn the user of remote shut down (cut our own legs off!)
                uID = IDS_SHUTDOWN_REMOTE;
            }
        }  else {
            if (NeedsDisplayWarning(uNumUsers, uExitWindowsFlags)) {
                //  Warn the user if more than one user session active
                uID = IDS_SHUTDOWN_OTHERUSERS;
            }
        }
    } else if (uExitWindowsFlags & (EWX_REBOOT | EWX_WINLOGON_OLD_REBOOT)) {
        //  Warn the user if more than one user session active.
        if (NeedsDisplayWarning(uNumUsers, uExitWindowsFlags)) {
            uID = IDS_RESTART_OTHERUSERS;
        }
    }

    if (uID != 0) {
        TCHAR szTitle[MAX_PATH];
        TCHAR szMessage[MAX_PATH];
        DWORD dwTimeout = INFINITE;
        UNICODE_STRING UnicodeString;
        extern CONST WCHAR szWindowsKey[];
        static CONST WCHAR szTimeout[] = L"ShutdownWarningDialogTimeout";
        OBJECT_ATTRIBUTES OA;
        HANDLE hKey;
        DWORD cbSize;
        struct {
            KEY_VALUE_PARTIAL_INFORMATION KeyInfo;
            DWORD dwTimeout;
        } KeyTimeout;

        RtlInitUnicodeString(&UnicodeString, szWindowsKey);
        InitializeObjectAttributes(&OA, &UnicodeString, OBJ_CASE_INSENSITIVE, NULL, NULL);

        if (NT_SUCCESS(NtOpenKey(&hKey, KEY_READ, &OA))) {
            NTSTATUS rc;

            RtlInitUnicodeString(&UnicodeString, szTimeout);

            rc = NtQueryValueKey(hKey,
                                 &UnicodeString,
                                 KeyValuePartialInformation,
                                 &KeyTimeout,
                                 sizeof KeyTimeout,
                                 &cbSize);
            if (NT_SUCCESS(rc)) {
                dwTimeout = *((PDWORD)KeyTimeout.KeyInfo.Data);
                RIPMSGF1(RIP_VERBOSE, "ShutdownWarningTimeout: set by the reg: %d", dwTimeout);
            }

            NtClose(hKey);
        }

        LoadString(hmodUser, IDS_EXITWINDOWS_TITLE, szTitle, sizeof(szTitle)/sizeof(szTitle[0]));
        LoadString(hmodUser, uID, szMessage, sizeof(szMessage)/sizeof(szMessage[0]));

        // We want to display the message box to be displayed to the user, and since this can be called from winlogon/services
        // we need to pass the MB_SERVICE_NOTIFICATION flag.
        if (MessageBoxTimeout(NULL, szMessage, szTitle,
                              MB_ICONEXCLAMATION | MB_YESNO | MB_SERVICE_NOTIFICATION | MB_SYSTEMMODAL | MB_SETFOREGROUND,
                              0, dwTimeout) == IDNO) {
            bContinue = FALSE;
        }
    }

    return bContinue;
}

DWORD ExitWindowsThread(PVOID pvParam);

BOOL WINAPI ExitWindowsWorker(
    UINT uFlags,
    BOOL fSecondThread)
{
    EXITWINDOWSDATA ewd;
    HANDLE hThread;
    DWORD dwThreadId;
    DWORD dwExitCode;
    DWORD idWait;
    MSG msg;
    BOOL fSuccess;
    NTSTATUS Status;

    /*
     * Force a connection so apps will have a windowstation
     * to log off of.
     */
    if (PtiCurrent() == NULL) {
        return FALSE;
    }

    /*
     * Check for UI restrictions
     */
    if (!NtUserCallOneParam((ULONG_PTR)uFlags, SFI_PREPAREFORLOGOFF)) {
        RIPMSG0(RIP_WARNING, "ExitWindows called by a restricted thread\n");
        return FALSE;
    }

    Status = CallUserpExitWindowsEx(uFlags, &fSuccess);

    if (NT_SUCCESS( Status )) {
        return fSuccess;
    } else if (Status == STATUS_CANT_WAIT && !fSecondThread) {
        ewd.uFlags = uFlags;
        hThread = CreateThread(NULL, 0, ExitWindowsThread, &ewd,
                0, &dwThreadId);
        if (hThread == NULL) {
            return FALSE;
        }

        while (1) {
            idWait = MsgWaitForMultipleObjectsEx(1, &hThread,
                    INFINITE, QS_ALLINPUT, 0);

            /*
             * If the thread was signaled, we're done.
             */
            if (idWait == WAIT_OBJECT_0) {
                break;
            }

            /*
             * Process any waiting messages
             */
            while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                DispatchMessage(&msg);
            }
        }
        GetExitCodeThread(hThread, &dwExitCode);
        NtClose(hThread);
        if (dwExitCode == ERROR_SUCCESS) {
            return TRUE;
        } else {
            RIPERR0(dwExitCode, RIP_VERBOSE, "");
            return FALSE;
        }
    } else {
        RIPNTERR0(Status, RIP_VERBOSE, "");
        return FALSE;
    }
}

DWORD ExitWindowsThread(
    PVOID pvParam)
{
    PEXITWINDOWSDATA pewd = pvParam;
    DWORD dwExitCode;

    if (ExitWindowsWorker(pewd->uFlags, TRUE)) {
        dwExitCode = 0;
    } else {
        dwExitCode = GetLastError();
    }

    ExitThread(dwExitCode);
    return 0;
}

FUNCLOG2(LOG_GENERAL, BOOL, WINAPI, ExitWindowsEx, UINT, uFlags, DWORD, dwReasonCode)
BOOL WINAPI ExitWindowsEx(
    UINT uFlags,
    DWORD dwReasonCode)
{
    BOOL bSuccess;
    BOOL bShutdown = (uFlags & SHUTDOWN_FLAGS) != 0;
    SHUTDOWN_REASON sr;

    /*
     * Check to see if we should bring up UI warning that there are other
     * Terminal Server users connected to this machine. We only do this if the
     * caller has not specified the EWX_FORCE option.
     */
    if (bShutdown && !(uFlags & EWX_FORCE)) {
        /*
         * We don't want to display the warning dialog twice! (this function
         * can be called by an application and again by winlogon in response to
         * the first call)
         */
        if (!gfLogonProcess || (uFlags & EWX_WINLOGON_INITIATED)) {
            /*
             * Don't put up UI if termsrv is our caller. Termsrv uses this api to shutdown winlogon
             * on session 0 when a shutdown was initiated from a different session.
             */
            if (!(uFlags & EWX_TERMSRV_INITIATED)) {
                /*
                 * There are a bunch of lame apps (including InstallShield v5.1) that call ExitWindowsEx and then when it fails
                 * they go and enable the SE_SHUTDOWN_NAME privilege and then us call again. The problem is that we end up prompting the
                 * user twice in these cases. So before we put up any UI we check for the SE_SHUTDOWN_NAME privilege.
                 */
                if (IsSeShutdownNameEnabled()) {
                    if (!DisplayExitWindowsWarnings(uFlags & ~(EWX_WINLOGON_CALLER | EWX_SYSTEM_CALLER))) {
                        /*
                         * We need to log a cancel event if SET is enabled.
                         */
                        if (IsSETEnabled()) {
                            SHUTDOWN_REASON sr;
                            sr.cbSize = sizeof(SHUTDOWN_REASON);
                            sr.uFlags = uFlags;
                            sr.dwReasonCode = 0;
                            sr.fShutdownCancelled = TRUE;
                            sr.dwEventType = SR_EVENT_EXITWINDOWS;
                            sr.lpszComment = NULL;
                            RecordShutdownReason(&sr);
                        }

                        /*
                         * We only want to return the real error code if our caller was winlogon. We lie
                         * to everyone else and tell them that everything succeeded. If we return failure
                         * when the user cancel's the operation, a some of apps just call ExitWindowsEx
                         * again, causing another dialog.
                         */
                        if (uFlags & EWX_WINLOGON_INITIATED) {
                            SetLastError(ERROR_CANCELLED);
                            return FALSE;
                        } else {
                            return TRUE;
                        }
                    }
                }
            }
        }
    }

    sr.cbSize = sizeof(SHUTDOWN_REASON);
    sr.uFlags = uFlags;
    sr.dwReasonCode = dwReasonCode;
    sr.fShutdownCancelled = FALSE;
    sr.dwEventType = SR_EVENT_EXITWINDOWS;
    sr.lpszComment = NULL;

    /*
     * If this is winlogon initiating the shutdown, we need to log before
     * calling ExitWindowsWorker. Otherwise, if the user or an app cancels the
     * shutdown, the cancel event will be logged before the initial shutdown
     * event.
     */
    if (gfLogonProcess && bShutdown && (uFlags & EWX_WINLOGON_INITIATED) != 0) {
        if (IsSETEnabled()) {
            RecordShutdownReason(&sr);
        }
    }

    bSuccess = ExitWindowsWorker(uFlags, FALSE);

    /*
     * Log this shutdown if:
     * 1) We're not winlogon (if we are, we might have logged above).
     * 2) The shutdown (inititally, at least) succeeded.
     * 3) We're actually shutting down (i.e., not logging off).
     * 4) The registry key telling us to log is set.
     */
    if (!gfLogonProcess && bSuccess && bShutdown && IsSETEnabled()) {
        RecordShutdownReason(&sr);
    }

    return bSuccess;
}

#endif

#if !defined(BUILD_WOW6432)

BOOL WINAPI EndTask(
    HWND hwnd,
    BOOL fShutdown,
    BOOL fForce)
{
    USER_API_MSG m;
    PENDTASKMSG a = &m.u.EndTask;

    UNREFERENCED_PARAMETER(fShutdown);
    a->hwnd = hwnd;
    a->fForce = fForce;
    CsrClientCallServer( (PCSR_API_MSG)&m,
                         NULL,
                         CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                              UserpEndTask
                                            ),
                         sizeof( *a )
                       );
    if (NT_SUCCESS( m.ReturnValue )) {
        SET_LAST_ERROR_RETURNED();
        return a->fSuccess;
    } else {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "");
        return FALSE;
    }
}

VOID
APIENTRY
Logon(
    BOOL fLogon)
{
    USER_API_MSG m;
    PLOGONMSG a = &m.u.Logon;

    a->fLogon = fLogon;
    CsrClientCallServer( (PCSR_API_MSG)&m,
                         NULL,
                         CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                              UserpLogon
                                            ),
                         sizeof(*a)
                       );
}

NTSTATUS
APIENTRY
CallUserpRegisterLogonProcess(
    IN DWORD dwProcessId)
{

    USER_API_MSG m;
    PLOGONMSG a = &m.u.Logon;
    NTSTATUS Status;

    m.u.IdLogon = dwProcessId;
    Status = CsrClientCallServer( (PCSR_API_MSG)&m,
                                  NULL,
                                  CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                                       UserpRegisterLogonProcess),
                                  sizeof(*a));

    return Status;
}

#endif

#if !defined(BUILD_CSRWOW64)

FUNCLOG2(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, RegisterLogonProcess, DWORD, dwProcessId, BOOL, fSecure)
BOOL RegisterLogonProcess(
    DWORD dwProcessId,
    BOOL fSecure)
{
    gfLogonProcess = (BOOL)NtUserCallTwoParam(dwProcessId, fSecure,
            SFI__REGISTERLOGONPROCESS);

    /*
     * Now, register the logon process into winsrv.
     */
    if (gfLogonProcess) {
        CallUserpRegisterLogonProcess(dwProcessId);
    }

    return gfLogonProcess;
}

#endif

#if !defined(BUILD_WOW6432)

BOOL
WINAPI
RegisterServicesProcess(
    DWORD dwProcessId)
{
    USER_API_MSG m;
    PREGISTERSERVICESPROCESSMSG a = &m.u.RegisterServicesProcess;

    a->dwProcessId = dwProcessId;
    CsrClientCallServer( (PCSR_API_MSG)&m,
                         NULL,
                         CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                              UserpRegisterServicesProcess
                                            ),
                         sizeof( *a )
                       );
    if (NT_SUCCESS( m.ReturnValue )) {
        SET_LAST_ERROR_RETURNED();
        return a->fSuccess;
    } else {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "");
        return FALSE;
    }
}

HDESK WINAPI GetThreadDesktop(
    DWORD dwThreadId)
{
    USER_API_MSG m;
    PGETTHREADCONSOLEDESKTOPMSG a = &m.u.GetThreadConsoleDesktop;

    a->dwThreadId = dwThreadId;
    CsrClientCallServer( (PCSR_API_MSG)&m,
                         NULL,
                         CSR_MAKE_API_NUMBER( USERSRV_SERVERDLL_INDEX,
                                              UserpGetThreadConsoleDesktop
                                            ),
                         sizeof( *a )
                       );
    if (NT_SUCCESS( m.ReturnValue )) {
        return NtUserGetThreadDesktop(dwThreadId, a->hdeskConsole);
    } else {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "");
        return NULL;
    }
}


/**************************************************************************\
* DeviceEventWorker
*
* This is a private (not publicly exported) interface that the user-mode
* pnp manager calls when it needs to send a WM_DEVICECHANGE message to a
* specific window handle. The user-mode pnp manager is a service within
* services.exe and as such is not on the interactive window station and
* active desktop, so it can't directly call SendMessage. For broadcasted
* messages (messages that go to all top-level windows), the user-mode pnp
* manager calls BroadcastSystemMessage directly.
*
* PaulaT 06/04/97
*
\**************************************************************************/
ULONG
WINAPI
DeviceEventWorker(
    IN HWND    hWnd,
    IN WPARAM  wParam,
    IN LPARAM  lParam,
    IN DWORD   dwFlags,
    OUT PDWORD pdwResult)
{
    USER_API_MSG m;
    PDEVICEEVENTMSG a = &m.u.DeviceEvent;
    PCSR_CAPTURE_HEADER CaptureBuffer = NULL;
    int cb = 0;

    a->hWnd     = hWnd;
    a->wParam   = wParam;
    a->lParam   = lParam;
    a->dwFlags  = dwFlags;
    a->dwResult = 0;

    //
    // If lParam is specified, it must be marshalled (see the defines
    // for this structure in dbt.h - the structure always starts with
    // DEV_BROADCAST_HDR structure).
    //

    if (lParam) {

        cb = ((PDEV_BROADCAST_HDR)lParam)->dbch_size;

        CaptureBuffer = CsrAllocateCaptureBuffer(1, cb);
        if (CaptureBuffer == NULL) {
            return STATUS_NO_MEMORY;
        }

        CsrCaptureMessageBuffer(CaptureBuffer,
                                (PCHAR)lParam,
                                cb,
                                (PVOID *)&a->lParam);

        //
        // This ends up calling SrvDeviceEvent routine in the server.
        //

        CsrClientCallServer((PCSR_API_MSG)&m,
                            CaptureBuffer,
                            CSR_MAKE_API_NUMBER(USERSRV_SERVERDLL_INDEX,
                                                UserpDeviceEvent),
                            sizeof(*a));

        CsrFreeCaptureBuffer(CaptureBuffer);

    } else {

        //
        // This ends up calling SrvDeviceEvent routine in the server.
        //

        CsrClientCallServer((PCSR_API_MSG)&m,
                            NULL,
                            CSR_MAKE_API_NUMBER(USERSRV_SERVERDLL_INDEX,
                                                UserpDeviceEvent),
                            sizeof(*a));
    }


    if (NT_SUCCESS(m.ReturnValue)) {
        *pdwResult = (DWORD)a->dwResult;
    } else {
        RIPMSG0(RIP_WARNING, "DeviceEventWorker failed.");
    }

    return m.ReturnValue;
}


#if DBG

VOID
APIENTRY
CsrWin32HeapFail(
    IN DWORD dwFlags,
    IN BOOL  bFail)
{
    USER_API_MSG m;
    PWIN32HEAPFAILMSG a = &m.u.Win32HeapFail;

    a->dwFlags = dwFlags;
    a->bFail = bFail;

    CsrClientCallServer((PCSR_API_MSG)&m,
                        NULL,
                        CSR_MAKE_API_NUMBER(USERSRV_SERVERDLL_INDEX,
                                            UserpWin32HeapFail),
                        sizeof(*a));

    if (!NT_SUCCESS(m.ReturnValue)) {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "UserpWin32HeapFail failed");
    }
}

UINT
APIENTRY
CsrWin32HeapStat(
    PDBGHEAPSTAT    phs,
    DWORD   dwLen)
{
    USER_API_MSG m;
    PWIN32HEAPSTATMSG a = &m.u.Win32HeapStat;
    PCSR_CAPTURE_HEADER CaptureBuffer = NULL;

    a->dwLen = dwLen;

    CaptureBuffer = CsrAllocateCaptureBuffer(1, dwLen);
    if (CaptureBuffer == NULL) {
        return 0;
    }

    CsrCaptureMessageBuffer(CaptureBuffer,
                            (PCHAR)phs,
                            dwLen,
                            (PVOID *)&a->phs);

    CsrClientCallServer((PCSR_API_MSG)&m,
                        CaptureBuffer,
                        CSR_MAKE_API_NUMBER(USERSRV_SERVERDLL_INDEX,
                                            UserpWin32HeapStat),
                        sizeof(*a));

    if (!NT_SUCCESS(m.ReturnValue)) {
        RIPNTERR0(m.ReturnValue, RIP_VERBOSE, "UserpWin32HeapStat failed");
        a->dwMaxTag = 0;
        goto ErrExit;
    }
    RtlMoveMemory(phs, a->phs, dwLen);

ErrExit:
    CsrFreeCaptureBuffer(CaptureBuffer);

    return a->dwMaxTag;
}

#endif // DBG


#endif

#if !defined(BUILD_CSRWOW64)

/******************************************************************************\
* CsrBroadcastSystemMessageExW
*
* Routine Description:
*
*   This function is a private API used by the csrss server
*
*   This function converts the csrss server thread into a GUI thread, then
*   performs a BroadcastSystemMessageExW(), and finally restore the thread's
*   desktop.
*
* Arguments:
*
*   dwFlags - Broadcast System message flags
*
*   lpdwRecipients - Intended recipients of the message
*
*   uiMessage - Message type
*
*   wParam - first message parameter
*
*   lParam - second message parameter
*
*   pBSMInfo - BroadcastSystemMessage information
*
* Return Value:
*
*   Appropriate NTSTATUS code
*
\******************************************************************************/
FUNCLOG6(LOG_GENERAL, NTSTATUS, APIENTRY, CsrBroadcastSystemMessageExW, DWORD, dwFlags, LPDWORD, lpdwRecipients, UINT, uiMessage, WPARAM, wParam, LPARAM, lParam, PBSMINFO, pBSMInfo)
NTSTATUS
APIENTRY
CsrBroadcastSystemMessageExW(
    DWORD dwFlags,
    LPDWORD lpdwRecipients,
    UINT uiMessage,
    WPARAM wParam,
    LPARAM lParam,
    PBSMINFO pBSMInfo
    )
{
    USERTHREAD_USEDESKTOPINFO utudi;
    long result;
    NTSTATUS Status;

    /*
     * Caller must be from the csrss server
     */
    if ( !gfServerProcess ) {
        return( STATUS_ACCESS_DENIED );
    }

    /*
     * Since this thread is a csrss thread, the thread is not a
     * GUI thread and does not have a desktop associated with it.
     * Must set the thread's desktop to the active desktop in
     * order to call BroadcastSystemMessageExW
     */

    utudi.hThread = NULL;
    utudi.drdRestore.pdeskRestore = NULL;

    Status = NtUserSetInformationThread( NtCurrentThread(),
                                         UserThreadUseActiveDesktop,
                                         &utudi,
                                         sizeof(utudi) );

    if ( NT_SUCCESS( Status ) ) {
        result = BroadcastSystemMessageExW(
                        dwFlags,
                        lpdwRecipients,
                        uiMessage,
                        wParam,
                        lParam,
                        pBSMInfo );

        /*
         * Restore the previous desktop of the thread
         */
        Status = NtUserSetInformationThread( NtCurrentThread(),
                                             UserThreadUseDesktop,
                                             &utudi,
                                             sizeof(utudi) );

        if ( NT_SUCCESS( Status ) && ( result <= 0 ) ) {
            Status = STATUS_UNSUCCESSFUL;
        }
    }

    return( Status );
}

#endif
