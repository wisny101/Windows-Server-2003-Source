/**************************************************************************\
* Module Name: cltxt.h
*
* Neutral Client/Server call related routines involving text.
*
* Copyright (c) 1985 - 1999, Microsoft Corporation
*
* Created: 04-Dec-90
*
* History:
*   04-Dec-90 created by SMeans
*
\**************************************************************************/

#ifdef UNICODE
  #define IS_ANSI FALSE
#else
  #define IS_ANSI TRUE
  #if IS_ANSI != CW_FLAGS_ANSI
  # error("IS_ANSI != CW_FLAGS_ANSI)
  #endif
#endif
#include "ntsend.h"
#include "powrprof.h"

/***************************************************************************\
* CreateWindowEx (API)
*
* A complete Thank cannot be generated for CreateWindowEx because its last
* parameter (lpParam) is polymorphic depending on the window's class.  If
* the window class is "MDIClient" then lpParam points to a CLIENTCREATESTRUCT.
*
* History:
* 04-23-91 DarrinM      Created.
* 04-Feb-92 IanJa       Unicode/ANSI neutral
\***************************************************************************/

#ifdef UNICODE
FUNCLOG12(LOG_GENERAL, HWND, WINAPI, CreateWindowExW, DWORD, dwExStyle, LPCTSTR, lpClassName, LPCTSTR, lpWindowName, DWORD, dwStyle, int, X, int, Y, int, nWidth, int, nHeight, HWND, hWndParent, HMENU, hMenu, HINSTANCE, hModule, LPVOID, lpParam)
#else
FUNCLOG12(LOG_GENERAL, HWND, WINAPI, CreateWindowExA, DWORD, dwExStyle, LPCTSTR, lpClassName, LPCTSTR, lpWindowName, DWORD, dwStyle, int, X, int, Y, int, nWidth, int, nHeight, HWND, hWndParent, HMENU, hMenu, HINSTANCE, hModule, LPVOID, lpParam)
#endif // UNICODE
HWND WINAPI CreateWindowEx(
    DWORD dwExStyle,
    LPCTSTR lpClassName,
    LPCTSTR lpWindowName,
    DWORD dwStyle,
    int X,
    int Y,
    int nWidth,
    int nHeight,
    HWND hWndParent,
    HMENU hMenu,
    HINSTANCE hModule,
    LPVOID lpParam)
{
    return _CreateWindowEx(dwExStyle,
                           lpClassName,
                           lpWindowName,
                           dwStyle,
                           X,
                           Y,
                           nWidth,
                           nHeight,
                           hWndParent,
                           hMenu,
                           hModule,
                           lpParam,
                           IS_ANSI | CW_FLAGS_VERSIONCLASS);
}

/***************************************************************************\
* fnHkINLPCWPSTRUCT
*
* This gets thunked through the message thunks, so it has the format
* of a c/s message thunk call.
*
* 05-09-91 ScottLu      Created.
* 04-Feb-92 IanJa       Unicode/ANSI neutral
\***************************************************************************/

LRESULT TEXT_FN(fnHkINLPCWPSTRUCT)(
    PWND pwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam,
    ULONG_PTR xParam)
{
    CWPSTRUCT cwp;

    cwp.hwnd = HW(pwnd);
    cwp.message = message;
    cwp.wParam = wParam;
    cwp.lParam = lParam;

    return TEXT_FN(DispatchHook)(MAKELONG(HC_ACTION, WH_CALLWNDPROC),
            (GetClientInfo()->CI_flags & CI_INTERTHREAD_HOOK) != 0,
            (LPARAM)&cwp, (HOOKPROC)xParam);
}

LRESULT TEXT_FN(fnHkINLPCWPRETSTRUCT)(
    PWND pwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam,
    ULONG_PTR xParam)
{
    CWPRETSTRUCT cwp;
    PCLIENTINFO pci = GetClientInfo();

    cwp.hwnd = HW(pwnd);
    cwp.message = message;
    cwp.wParam = wParam;
    cwp.lParam = lParam;
    cwp.lResult = KERNEL_LRESULT_TO_LRESULT(pci->dwHookData);

    return TEXT_FN(DispatchHook)(MAKELONG(HC_ACTION, WH_CALLWNDPROCRET),
            (GetClientInfo()->CI_flags & CI_INTERTHREAD_HOOK) != 0,
            (LPARAM)&cwp, (HOOKPROC)xParam);
}

/***************************************************************************\
* DispatchHook
*
* This routine exists simply to remember the hook type in the CTI structure
* so that later inside of CallNextHookEx we know how to thunk the hook
* call.
*
* 05-09-91 ScottLu      Created.
* 04-Feb-92 IanJa       Unicode/ANSI neutral
\***************************************************************************/

LRESULT TEXT_FN(DispatchHook)(
    int dw,
    WPARAM wParam,
    LPARAM lParam,
    HOOKPROC pfn)
{
    int dwHookSave;
    LRESULT nRet;
    PCLIENTINFO pci;
#if IS_ANSI
    WPARAM wParamSave;
#endif
    /* -FE-
     * * THIS VARIABLE SHOULD BE THREAD AWARE *
     */
    static EVENTMSG CachedEvent = {0,0,0,(DWORD)0,(HWND)0};

    /*
     * First save the current hook stored in the CTI structure in case we're
     * being recursed into. dw contains MAKELONG(nCode, nFilterType).
     */
    pci = GetClientInfo();
    dwHookSave = pci->dwHookCurrent;
    pci->dwHookCurrent = (dw & 0xFFFF0000) | IS_ANSI;

#if IS_ANSI       // TEXT_FN(DispatchHook)()
    if (IS_DBCS_ENABLED()) {
        PMSG pMsg;
        PEVENTMSG pEMsg;
        switch (HIWORD(dw)) {
        case WH_JOURNALPLAYBACK:
            switch (LOWORD(dw)) {
            case HC_SKIP:
                CachedEvent.message = 0;
                break;
            case HC_GETNEXT:
            case HC_NOREMOVE:
                pEMsg = (PEVENTMSG)lParam;
                if (CachedEvent.message != 0 && pEMsg != NULL) {
                    RtlCopyMemory((PEVENTMSG)lParam,&CachedEvent,sizeof(EVENTMSG));
                    return 0;
                }
                break;
            }
            break;
        case WH_MSGFILTER:
        case WH_SYSMSGFILTER:
        case WH_GETMESSAGE:
            pMsg = (PMSG)lParam;
            if (pMsg) {
                /*
                 * Save original message.
                 */
                wParamSave = pMsg->wParam;
                switch (pMsg->message) {
                case WM_CHAR:
                case EM_SETPASSWORDCHAR:
                    /*
                     * Here... pMsg->wParam contains..
                     *
                     * HIWORD(wParam)         = Information for DBCS messgaing.
                     * HIBYTE(LOWORD(wParam)) = Dbcs LeadingByte Byte.
                     * LOBYTE(LOWORD(wParam)) = Dbcs TrailingByte or Sbcs character.
                     *
                     */
                    if (pMsg->wParam & WMCR_IR_DBCSCHAR) {
                        /*
                         * Mask off DBCS messaging infomation area.
                         * (Look up only DBCS character code data).
                         */
                        pMsg->wParam &= 0x0000FFFF;
                    } else {
                        if (IS_DBCS_MESSAGE(LOWORD(pMsg->wParam))) {
                            PKERNEL_MSG pDbcsMsg = GetCallBackDbcsInfo();
                            /*
                             * Copy this message to CLIENTINFO for next GetMessage
                             * or PeekMesssage() call.
                             */
                            COPY_MSG_TO_KERNELMSG(pDbcsMsg,pMsg);
                            /*
                             * Only Dbcs Trailingbyte is nessesary for pushed message. we'll
                             * pass this message when GetMessage/PeekMessage is called at next.
                             */
                            pDbcsMsg->wParam = (WPARAM)((pMsg->wParam & 0x0000FF00) >> 8);
                            /*
                             * Return DbcsLeading byte to Apps.
                             */
                            pMsg->wParam = (WPARAM)(pMsg->wParam & 0x000000FF);
                        } else {
                            /*
                             * This is SBCS char, make sure it.
                             */
                            pMsg->wParam &= 0x000000FF;
                        }
                    }
                }
            }
        }
GetNextHookData:
        ;
    }
#endif

    /*
     * Call the hook. dw contains MAKELONG(nCode, nFilterType).
     */
    nRet = pfn(LOWORD(dw), wParam, lParam);

#if IS_ANSI
    if (IS_DBCS_ENABLED()) {
        PMSG pMsg;
        PEVENTMSG pEMsg;
        switch (HIWORD(dw)) {
        case WH_JOURNALPLAYBACK:
            switch (LOWORD(dw)) {
            case HC_GETNEXT:
            case HC_NOREMOVE:
                pEMsg = (PEVENTMSG)lParam;
                if ((nRet == 0) && pEMsg) {
                    WPARAM dwAnsi = LOWORD(pEMsg->paramL);
                    switch(pEMsg->message) {
                    case WM_CHAR:
                    case EM_SETPASSWORDCHAR:
                        /*
                         * Chech wParam is DBCS character or not.
                         */
                        if (IS_DBCS_MESSAGE((dwAnsi))) {
                            /*
                             * DO NOT NEED TO MARK FOR IR_DBCSCHAR
                             */
                        } else {
                            PBYTE pchDbcsCF = GetDispatchDbcsInfo();

                            /*
                             * If we have cached Dbcs LeadingByte character,
                             * build a DBCS character with the TrailingByte
                             * in wParam.
                             */
                            if (*pchDbcsCF) {
                                WORD DbcsLeadChar = (WORD)(*pchDbcsCF);
                                /*
                                 * HIBYTE(LOWORD(dwAnsi)) = Dbcs LeadingByte.
                                 * LOBYTE(LOWORD(dwAnsi)) = Dbcs TrailingByte.
                                 */
                                dwAnsi |= (DbcsLeadChar << 8);

                                /*
                                 * Invalidate cached data.
                                 */
                                *pchDbcsCF = 0;
                            } else if (IsDBCSLeadByteEx(THREAD_CODEPAGE(),LOBYTE(dwAnsi))) {
                                /*
                                 * If this is DBCS LeadByte character, we
                                 * should wait DBCS TrailingByte to convert
                                 * this to Unicode. then we cache it here.
                                 */
                                *pchDbcsCF = LOBYTE(dwAnsi);

                                /*
                                 * Get DBCS TrailByte.
                                 */
                                pfn(HC_SKIP,0,0);
                                goto GetNextHookData;
                            }
                        }

                        /*
                         * Convert to Unicode.
                         */
                        RtlMBMessageWParamCharToWCS(pEMsg->message, &dwAnsi);

                        /*
                         * Restore converted Unicode to EVENTMSG.
                         */
                        pEMsg->paramL = (UINT)dwAnsi;

                        /*
                         * Keep this EVENTMSG to local buffer.
                         */
                        RtlCopyMemory(&CachedEvent, pEMsg, sizeof(EVENTMSG));
                    }
                }
            }
            break;
        case WH_MSGFILTER:
        case WH_SYSMSGFILTER:
        case WH_GETMESSAGE:
            pMsg = (PMSG)lParam;
            if (pMsg) {
                switch (pMsg->message) {
                case WM_CHAR:
                case EM_SETPASSWORDCHAR:
                    if (GetCallBackDbcsInfo()->wParam) {
                        PKERNEL_MSG pmsgDbcs = GetCallBackDbcsInfo();
                        /*
                         * Get pushed message.
                         *
                         * Backup current message. this backupped message will be used
                         * when Apps peek (or get) message from thier WndProc.
                         * (see GetMessageA(), PeekMessageA()...)
                         *
                         * pmsg->hwnd    = pmsgDbcs->hwnd;
                         * pmsg->message = pmsgDbcs->message;
                         * pmsg->wParam  = pmsgDbcs->wParam;
                         * pmsg->lParam  = pmsgDbcs->lParam;
                         * pmsg->time    = pmsgDbcs->time;
                         * pmsg->pt      = pmsgDbcs->pt;
                         */
                        COPY_KERNELMSG_TO_MSG(pMsg,pmsgDbcs);
                        /*
                         * Invalidate pushed message in CLIENTINFO.
                         */
                        pmsgDbcs->wParam = 0;
                        /*
                         * Call the hook with DBCS TrailByte..
                         */
                        nRet = pfn(LOWORD(dw), wParam, lParam);
                    }
                    /*
                     * Restore original message..
                     * #96571 [hiroyama]
                     * Other messages than WM_CHAR and EM_SETPASSWORDCHAR can be
                     * modifed by a hooker.
                     * Wparam for WM_CHAR and EM_SETPASSWORDCHAR must be restored.
                     * *by design*
                     */
                    pMsg->wParam = wParamSave;
                }
            }
        }
    }
#endif

    /*
     * Restore the hook number and return the return code.
     */
    pci->dwHookCurrent = dwHookSave;
    return nRet;
}


/***************************************************************************\
* GetWindowLong, SetWindowLong, GetClassLong
*
* History:
* 02-Feb-92 IanJa       Neutral version.
\***************************************************************************/

#ifdef UNICODE
FUNCLOG2(LOG_GENERAL, LONG_PTR, APIENTRY, GetWindowLongPtrW, HWND, hwnd, int, nIndex)
#else
FUNCLOG2(LOG_GENERAL, LONG_PTR, APIENTRY, GetWindowLongPtrA, HWND, hwnd, int, nIndex)
#endif // UNICODE
LONG_PTR APIENTRY GetWindowLongPtr(
    HWND hwnd,
    int nIndex)
{
    PWND pwnd;

    pwnd = ValidateHwnd(hwnd);
    if (pwnd == NULL) {
        return 0;
    }

    try {
        return _GetWindowLongPtr(pwnd, nIndex, IS_ANSI);
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
        RIPERR1(ERROR_INVALID_WINDOW_HANDLE,
                RIP_WARNING,
                "Window %x no longer valid",
                hwnd);
        return 0;
    }
}

#ifdef UNICODE
FUNCLOG3(LOG_GENERAL, LONG_PTR, APIENTRY, SetWindowLongPtrW, HWND, hWnd, int, nIndex, LONG_PTR, dwNewLong)
#else
FUNCLOG3(LOG_GENERAL, LONG_PTR, APIENTRY, SetWindowLongPtrA, HWND, hWnd, int, nIndex, LONG_PTR, dwNewLong)
#endif // UNICODE
LONG_PTR APIENTRY SetWindowLongPtr(
    HWND hWnd,
    int nIndex,
    LONG_PTR dwNewLong)
{
    return _SetWindowLongPtr(hWnd, nIndex, dwNewLong, IS_ANSI);
}

#ifdef _WIN64
LONG APIENTRY GetWindowLong(
    HWND hwnd,
    int nIndex)
{
    PWND pwnd;

    pwnd = ValidateHwnd(hwnd);
    if (pwnd == NULL) {
        return 0;
    }

    try {
        return _GetWindowLong(pwnd, nIndex, IS_ANSI);
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
        RIPERR1(ERROR_INVALID_WINDOW_HANDLE,
                RIP_WARNING,
                "Window %x no longer valid",
                hwnd);
        return 0;
    }
}

LONG APIENTRY SetWindowLong(
    HWND hWnd,
    int nIndex,
    LONG dwNewLong)
{
    return _SetWindowLong(hWnd, nIndex, dwNewLong, IS_ANSI);
}
#endif

#ifdef UNICODE
FUNCLOG2(LOG_GENERAL, ULONG_PTR, APIENTRY, GetClassLongPtrW, HWND, hWnd, int, nIndex)
#else
FUNCLOG2(LOG_GENERAL, ULONG_PTR, APIENTRY, GetClassLongPtrA, HWND, hWnd, int, nIndex)
#endif // UNICODE

ULONG_PTR APIENTRY GetClassLongPtr(
    HWND hWnd,
    int nIndex)
{
    PWND pwnd;

    pwnd = ValidateHwnd(hWnd);
    if (pwnd == NULL) {
        return 0;
    }

    try {
        return _GetClassLongPtr(pwnd, nIndex, IS_ANSI);
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
        RIPERR1(ERROR_INVALID_WINDOW_HANDLE,
                RIP_WARNING,
                "Window %x no longer valid",
                hWnd);
        return 0;
    }
}

#ifdef _WIN64
DWORD  APIENTRY GetClassLong(HWND hWnd, int nIndex)
{
    PWND pwnd;

    pwnd = ValidateHwnd(hWnd);

    if (pwnd == NULL)
        return 0;

    try {
        return _GetClassLong(pwnd, nIndex, IS_ANSI);
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
        RIPERR1(ERROR_INVALID_WINDOW_HANDLE,
                RIP_WARNING,
                "Window %x no longer valid",
                hWnd);
        return 0;
    }
}
#endif


#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, BOOL, APIENTRY, PeekMessageW, LPMSG, lpMsg, HWND, hWnd, UINT, wMsgFilterMin, UINT, wMsgFilterMax, UINT, wRemoveMsg)
#else
FUNCLOG5(LOG_GENERAL, BOOL, APIENTRY, PeekMessageA, LPMSG, lpMsg, HWND, hWnd, UINT, wMsgFilterMin, UINT, wMsgFilterMax, UINT, wRemoveMsg)

#endif // UNICODE

BOOL APIENTRY PeekMessage(
    LPMSG lpMsg,
    HWND hWnd,
    UINT wMsgFilterMin,
    UINT wMsgFilterMax,
    UINT wRemoveMsg)
{
    CLIENTTHREADINFO *pcti;
    PCLIENTINFO pci;
    UINT fsWakeMaskFilter;
    UINT fsWakeMask;
    UINT cSpinLimit;

    pci = GetClientInfo();

    if (hWnd != NULL) {
        goto lbCallServer;
    }

#if IS_ANSI
    /*
     * If we have a DBCS TrailingByte that should be returned to App,
     * we should pass it, never can fail....
     */
    UserAssert(IS_DBCS_ENABLED() || GetCallBackDbcsInfo()->wParam == 0);
    if (GetCallBackDbcsInfo()->wParam) {    // accesses fs:xxx, but no speed penalty
        /*
         * Check message filter... WM_CHAR should be in the Range...
         */
        if ((!wMsgFilterMin && !wMsgFilterMax) ||
            (wMsgFilterMin <= WM_CHAR && wMsgFilterMax >=WM_CHAR)) {
            goto lbCallServer;
        }
    }
#endif

    if (   (pci->dwTIFlags & TIF_16BIT)
        && !(wRemoveMsg & PM_NOYIELD)
        && ((gpsi->nEvents != 0) || (pci->dwTIFlags & (TIF_FIRSTIDLE | TIF_DELAYEDEVENT)))) {

        goto lbCallServer;
    }

    /*
     * If we can't see the client thread info, we need to go to the kernel.
     */
    if ((pcti = CLIENTTHREADINFO(pci)) == NULL) {
        goto lbCallServer;
    }

    fsWakeMaskFilter = HIWORD(wRemoveMsg);

#if DBG
    /*
     * New for NT5: HIWORD(wRemoveMsg) contains a QS_ mask. This is
     * validated for real in the kernel side.
     */
    if (fsWakeMaskFilter & ~QS_VALID) {
        RIPMSG1(RIP_WARNING,
                "PeekMessage: Invalid QS_ bits: 0x%x",
                fsWakeMaskFilter);
    }
#endif

    /*
     * If any appropriate input is available, we need to go to the kernel.
     */
    if (wMsgFilterMax == 0 && fsWakeMaskFilter == 0) {
        fsWakeMask = (QS_ALLINPUT | QS_EVENT | QS_ALLPOSTMESSAGE);
    } else {
        fsWakeMask = CalcWakeMask(wMsgFilterMin, wMsgFilterMax, fsWakeMaskFilter);
    }
    if ((pcti->fsChangeBits | pcti->fsWakeBits) & fsWakeMask) {
        goto lbCallServer;
    }

    /*
     * If this thread has the queue locked, we have to go to the kernel or
     * other threads on the same queue may be prevented from getting input
     * messages.
     */
    if (pcti->CTIF_flags & CTIF_SYSQUEUELOCKED) {
        goto lbCallServer;
    }

    /*
     * This is the peek message count (not going idle count). If it gets
     * to be 100 or greater, call the server. This'll cause this app to be
     * put at background priority until it sleeps. This is really important
     * for compatibility because win3.1 peek/getmessage usually takes a trip
     * through the win3.1 scheduler and runs the next task.
     */
    pci->cSpins++;

    if ((pci->cSpins >= CSPINBACKGROUND) && !(pci->dwTIFlags & TIF_SPINNING)) {
        goto lbCallServer;
    }

    /*
     * We have to go to the server if someone is waiting on this event.
     * We used to just wait until the spin cound got large but for some
     * apps like terminal.  They always just call PeekMessage and after
     * just a few calls they would blink their caret which bonks the spincount
     */
    if (pci->dwTIFlags & TIF_WAITFORINPUTIDLE) {
        goto lbCallServer;
    }

    /*
     * Make sure we go to the kernel at least once a second so that
     * hung app painting won't occur.
     */
    if ((NtGetTickCount() - pcti->timeLastRead) > 1000) {
        NtUserGetThreadState(UserThreadStatePeekMessage);
    }

    /*
     * Determine the maximum number of spins before we yield. Yields
     * are performed more frequently for 16 bit apps.
     */
    if ((pci->dwTIFlags & TIF_16BIT) && !(wRemoveMsg & PM_NOYIELD)) {
        cSpinLimit = CSPINBACKGROUND / 10;
    } else {
        cSpinLimit = CSPINBACKGROUND;
    }

    /*
     * If the PeekMessage() is just spinning, then we should sleep
     * just enough so that we allow other processes to gain CPU time.
     * A problem was found when an OLE app tries to communicate to a
     * background app (via SendMessage) running at the same priority as a
     * background/spinning process.  This will starve the CPU from those
     * processes.  Sleep on every re-cycle of the spin-count.  This will
     * assure that apps doing peeks are degraded.
     *
     */
    if ((pci->dwTIFlags & TIF_SPINNING) && (pci->cSpins >= cSpinLimit)) {
        pci->cSpins = 0;
        NtYieldExecution();
    }

    return FALSE;

lbCallServer:

    return _PeekMessage(lpMsg,
                        hWnd,
                        wMsgFilterMin,
                        wMsgFilterMax,
                        wRemoveMsg,
                        IS_ANSI);
}


#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, LRESULT, APIENTRY, DefWindowProcW, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam)
#else
FUNCLOG4(LOG_GENERAL, LRESULT, APIENTRY, DefWindowProcA, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam)
#endif // UNICODE
LRESULT APIENTRY DefWindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam)
{
    LRESULT lRet;

    BEGIN_USERAPIHOOK()
        BOOL fOverride = IsMsgOverride(message, &guah.mmDWP);
        if (fOverride) {
            /*
             * This message is being overridden, so we need to callback to
             * the process. During this callback, the override may call the
             * real DWP for processing.
             */

#ifdef UNICODE
            lRet = guah.pfnDefWindowProcW(hwnd, message, wParam, lParam);
#else
            lRet = guah.pfnDefWindowProcA(hwnd, message, wParam, lParam);
#endif
        } else {
            /*
             * This message is not being overridden, so we can just call the
             * real DWP for processing.
             */

#ifdef UNICODE
            lRet = RealDefWindowProcW(hwnd, message, wParam, lParam);
#else
            lRet = RealDefWindowProcA(hwnd, message, wParam, lParam);
#endif
        }

    END_USERAPIHOOK()

    return lRet;
}


LRESULT APIENTRY TEXT_FN(RealDefWindowProc)(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam)
{
    PWND pwnd;

    if ((pwnd = ValidateHwnd(hwnd)) == NULL) {
        switch (message) {
        case WM_CTLCOLORBTN:
        case WM_CTLCOLORSTATIC:
        case WM_CTLCOLORDLG:
        case WM_CTLCOLORMSGBOX:

            /*
             * Draw default colors
             */
            break;
        default:
            return 0;
        }
    }

    return RealDefWindowProcWorker(pwnd, message, wParam, lParam, IS_ANSI);
}


LRESULT APIENTRY TEXT_FN(DispatchDefWindowProc)(
    PWND pwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam,
    ULONG_PTR pfn)
{
    HWND hwnd = KHWND_TO_HWND(GetClientInfo()->CallbackWnd.hwnd);

    UNREFERENCED_PARAMETER(pwnd);
    UNREFERENCED_PARAMETER(pfn);

    return DefWindowProc(hwnd, message, wParam, lParam);
}

#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, LRESULT, APIENTRY, SendMessageW, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam)
#else
FUNCLOG4(LOG_GENERAL, LRESULT, APIENTRY, SendMessageA, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam)
#endif // UNICODE
LRESULT APIENTRY SendMessage(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam)
{
    PWND pwnd;

    /*
     * Prevent apps from setting hi 16 bits so we can use them internally.
     */
    if (message & RESERVED_MSG_BITS) {
        RIPERR1(ERROR_INVALID_PARAMETER,
                RIP_WARNING,
                "Invalid parameter \"message\" (%ld) to SendMessage",
                message);

        return 0;
    }

    /*
     * Thunk through a special sendmessage for -1 hwnd's so that the general
     * purpose thunks don't allow -1 hwnd's.
     */
    if (hwnd == (HWND)-1 || hwnd == (HWND)0x0000FFFF) {
        /*
         * Get a real hwnd so the thunks will validation ok. Note that since
         * -1 hwnd is really rare, calling GetDesktopWindow() here is not a
         * big deal.
         */
        hwnd = GetDesktopWindow();

        /*
         * Always send broadcast requests straight to the server. Note: if
         * the xParam needs to be used, must update SendMsgTimeout,
         * FNID_SENDMESSAGEFF uses it to id who it is from.
         */
        return CsSendMessage(hwnd,
                             message,
                             wParam,
                             lParam,
                             0L,
                             FNID_SENDMESSAGEFF,
                             IS_ANSI);
    }

    if ((pwnd = ValidateHwnd(hwnd)) == NULL) {
        return 0;
    }

    return SendMessageWorker(pwnd, message, wParam, lParam, IS_ANSI);
}


#ifdef UNICODE
FUNCLOG7(LOG_GENERAL, LRESULT, APIENTRY, SendMessageTimeoutW, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam, UINT, fuFlags, UINT, uTimeout, PULONG_PTR, lpdwResult)
#else
FUNCLOG7(LOG_GENERAL, LRESULT, APIENTRY, SendMessageTimeoutA, HWND, hwnd, UINT, message, WPARAM, wParam, LPARAM, lParam, UINT, fuFlags, UINT, uTimeout, PULONG_PTR, lpdwResult)
#endif // UNICODE
LRESULT APIENTRY SendMessageTimeout(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam,
    UINT fuFlags,
    UINT uTimeout,
    PULONG_PTR lpdwResult)
{
    return SendMessageTimeoutWorker(hwnd,
                                    message,
                                    wParam,
                                    lParam,
                                    fuFlags,
                                    uTimeout,
                                    lpdwResult,
                                    IS_ANSI);
}


/***************************************************************************\
* SendDlgItemMessage
*
* Translates the message, calls SendDlgItemMessage on server side. The
* dialog item's ID is passed as the xParam. On the server side, a stub
* rearranges the parameters to put the ID where it belongs and calls
* xxxSendDlgItemMessage.
*
* 04-17-91 DarrinM Created.
\***************************************************************************/

#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, LRESULT, WINAPI, SendDlgItemMessageW, HWND, hwnd, int, id, UINT, message, WPARAM, wParam, LPARAM, lParam)
#else
FUNCLOG5(LOG_GENERAL, LRESULT, WINAPI, SendDlgItemMessageA, HWND, hwnd, int, id, UINT, message, WPARAM, wParam, LPARAM, lParam)
#endif // UNICODE

LRESULT WINAPI SendDlgItemMessage(
    HWND hwnd,
    int id,
    UINT message,
    WPARAM wParam,
    LPARAM lParam)
{
    if (hwnd == (HWND)-1 || hwnd == (HWND)0x0000FFFF) {
        return 0;
    }

    if (hwnd = GetDlgItem(hwnd, id)) {
        return SendMessage(hwnd, message, wParam, lParam);
    }

    return 0L;
}

/***************************************************************************\
* GetDlgItemText
*
* History:
*    04 Feb 1992 GregoryW  Neutral ANSI/Unicode version
\***************************************************************************/
#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, UINT, DUMMYCALLINGTYPE, GetDlgItemTextW, HWND, hwnd, int, id, LPTSTR, lpch, int, cchMax)
#else
FUNCLOG4(LOG_GENERAL, UINT, DUMMYCALLINGTYPE, GetDlgItemTextA, HWND, hwnd, int, id, LPTSTR, lpch, int, cchMax)
#endif // UNICODE

UINT GetDlgItemText(
    HWND hwnd,
    int id,
    LPTSTR lpch,
    int cchMax)
{
    if ((hwnd = GetDlgItem(hwnd, id)) != NULL) {
        return GetWindowText(hwnd, lpch, cchMax);
    }

    /*
     * If we couldn't find the window, just null terminate lpch so that the
     * app doesn't AV if it tries to run through the text.
     */
    if (cchMax) {
        *lpch = (TCHAR)0;
    }

    return 0;
}


/***************************************************************************\
* SetDlgItemText
*
* History:
*    04 Feb 1992 GregoryW  Neutral ANSI/Unicode version
\***************************************************************************/
#ifdef UNICODE
FUNCLOG3(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, SetDlgItemTextW , HWND, hwnd, int, id, LPCTSTR, lpch)
#else
FUNCLOG3(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, SetDlgItemTextA , HWND, hwnd, int, id, LPCTSTR, lpch)
#endif // UNICODE

BOOL SetDlgItemText(
    HWND hwnd,
    int id,
    LPCTSTR lpch)
{
    if ((hwnd = GetDlgItem(hwnd, id)) != NULL) {
        return SetWindowText(hwnd, lpch);
    }

    return FALSE;
}


#ifdef UNICODE
FUNCLOG3(LOG_GENERAL, int, WINAPI, GetWindowTextW, HWND, hwnd, LPTSTR, lpName, int, nMaxCount)
#else
FUNCLOG3(LOG_GENERAL, int, WINAPI, GetWindowTextA, HWND, hwnd, LPTSTR, lpName, int, nMaxCount)
#endif // UNICODE

int WINAPI GetWindowText(
    HWND hwnd,
    LPTSTR lpName,
    int nMaxCount)
{
    PWND pwnd;

    /*
     * Don't try to fill a non-existent buffer
     */
    if (lpName == NULL || nMaxCount == 0) {
        return 0;
    }

    try {
        /*
         * Initialize string empty, in case SendMessage aborts validation
         */
        *lpName = TEXT('\0');

        /*
         * Make sure we have a valid window.
         */
        if ((pwnd = ValidateHwnd(hwnd)) == NULL) {
            return 0;
        }

        /*
         * This process comparison is bogus, but it is what win3.1 does.
         */
        if (TestWindowProcess(pwnd)) {
            return (int)SendMessageWorker(pwnd, WM_GETTEXT, nMaxCount, (LPARAM)lpName, IS_ANSI);
        } else {
            return (int)DefWindowProcWorker(pwnd, WM_GETTEXT, nMaxCount, (LPARAM)lpName, IS_ANSI);
        }
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
        RIPERR1(ERROR_INVALID_WINDOW_HANDLE,
                RIP_WARNING,
                "Window %x no longer valid",
                hwnd);
        return 0;
    }
}

#ifdef UNICODE
FUNCLOG1(LOG_GENERAL, int, WINAPI, GetWindowTextLengthW, HWND, hwnd)
#else
FUNCLOG1(LOG_GENERAL, int, WINAPI, GetWindowTextLengthA, HWND, hwnd)
#endif // UNICODE
int WINAPI GetWindowTextLength(
    HWND hwnd)
{
    PWND pwnd;

    /*
     * Make sure we have a valid window.
     */
    if ((pwnd = ValidateHwnd(hwnd)) == NULL) {
        return 0;
    }

    /*
     * This process comparison is bogus, but it is what win3.1 does.
     */
    if (TestWindowProcess(pwnd)) {
        return (int)SendMessageWorker(pwnd, WM_GETTEXTLENGTH, 0, 0, IS_ANSI);
    } else {
        return (int)DefWindowProcWorker(pwnd, WM_GETTEXTLENGTH, 0, 0, IS_ANSI);
    }
}


#ifdef UNICODE
FUNCLOG2(LOG_GENERAL, BOOL, WINAPI, SetWindowTextW , HWND, hwnd, LPCTSTR, pString)
#else
FUNCLOG2(LOG_GENERAL, BOOL, WINAPI, SetWindowTextA , HWND, hwnd, LPCTSTR, pString)
#endif // UNICODE
BOOL WINAPI SetWindowText(
    HWND hwnd,
    LPCTSTR pString)
{
    LRESULT lReturn;
    PWND pwnd;

    /*
     * Make sure we have a valid window.
     */
    if ((pwnd = ValidateHwnd(hwnd)) == NULL) {
        return FALSE;
    }

    /*
     * This process comparison is bogus, but it is what win3.1 does.
     */
    if (TestWindowProcess(pwnd)) {
        lReturn = SendMessageWorker(pwnd, WM_SETTEXT, 0, (LPARAM)pString, IS_ANSI);
    } else {
        lReturn = DefWindowProcWorker(pwnd, WM_SETTEXT, 0, (LPARAM)pString, IS_ANSI);
    }
    return (lReturn >= 0);
}


LRESULT APIENTRY DispatchMessage(CONST MSG *lpMsg)
{
    extern LRESULT DispatchMessageWorker(CONST MSG *lpMsg, BOOL fAnsi);

    return DispatchMessageWorker(lpMsg, IS_ANSI);
}

#if IS_ANSI
VOID CopyLogFontAtoW(
    PLOGFONTW pdest,
    PLOGFONTA psrc)
{
    LPSTR lpstrFont = (LPSTR)(&psrc->lfFaceName);
    LPWSTR lpstrFontW = (LPWSTR)(&pdest->lfFaceName);

    RtlCopyMemory((LPBYTE)pdest, psrc, sizeof(LOGFONTA) - LF_FACESIZE);
    RtlZeroMemory(pdest->lfFaceName, LF_FACESIZE * sizeof(WCHAR));
    MBToWCS(lpstrFont, -1, &lpstrFontW, LF_FACESIZE, FALSE);
}

VOID CopyLogFontWtoA(
    PLOGFONTA pdest,
    PLOGFONTW psrc)
{
    LPSTR lpstrFont = (LPSTR)(&pdest->lfFaceName);

    RtlCopyMemory((LPBYTE)pdest, (LPBYTE)psrc, sizeof(LOGFONTA) - LF_FACESIZE);
    RtlZeroMemory(pdest->lfFaceName, LF_FACESIZE);
    WCSToMB(psrc->lfFaceName, -1, &lpstrFont, LF_FACESIZE, FALSE);
}
#else

/**************************************************************************\
* SetVideoTimeout
*
* Updates the video timeout values in the current power profile.
*
* 15-Apr-1999 JerrySh   Created.
\**************************************************************************/

typedef BOOLEAN (*PFNGETACTIVEPWRSCHEME)(PUINT);
typedef BOOLEAN (*PFNSETACTIVEPWRSCHEME)(UINT, PGLOBAL_POWER_POLICY, PPOWER_POLICY);
typedef BOOLEAN (*PFNREADPWRSCHEME)(UINT, PPOWER_POLICY);

BOOL SetVideoTimeout(
    DWORD dwVideoTimeout)
{
    POWER_POLICY pp;
    UINT uiID;
    BOOL fRet = FALSE;

    if (GetActivePwrScheme(&uiID)) {
        if (ReadPwrScheme(uiID, &pp)) {
            pp.user.VideoTimeoutDc = dwVideoTimeout;
            pp.user.VideoTimeoutAc = dwVideoTimeout;

            fRet = SetActivePwrScheme(uiID, NULL, &pp);
        }
    }

    return fRet;
}
#endif

/***************************************************************************\
* SystemParametersInfo
*
*
\***************************************************************************/

#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, BOOL, APIENTRY, SystemParametersInfoW, UINT, wFlag, UINT, wParam, PVOID, lParam, UINT, flags)
#else
FUNCLOG4(LOG_GENERAL, BOOL, APIENTRY, SystemParametersInfoA, UINT, wFlag, UINT, wParam, PVOID, lParam, UINT, flags)
#endif // UINCODE
BOOL APIENTRY SystemParametersInfo(
    UINT wFlag,
    UINT wParam,
    PVOID lParam,
    UINT flags)
{
    BOOL bRet;

    BEGIN_USERAPIHOOK()
#ifdef UNICODE
        bRet = guah.pfnSystemParametersInfoW(wFlag, wParam, lParam, flags);
#else
        bRet = guah.pfnSystemParametersInfoA(wFlag, wParam, lParam, flags);
#endif
    END_USERAPIHOOK()

    return bRet;
}

BOOL APIENTRY TEXT_FN(RealSystemParametersInfo)(
    UINT wFlag,
    UINT wParam,
    PVOID lParam,
    UINT flags)
{
#if IS_ANSI
    NONCLIENTMETRICSW ClientMetricsW;
    ICONMETRICSW      IconMetricsW;
    LOGFONTW          LogFontW;
    WCHAR             szTemp[MAX_PATH];
    UINT              oldwParam = wParam;
#endif
    INTERNALSETHIGHCONTRAST ihc;
    IN_STRING         strlParam;
    PVOID             oldlParam = lParam;

    /*
     * Make sure cleanup will work successfully
     */
    strlParam.fAllocated = FALSE;

    BEGINCALL();

    switch (wFlag) {
    case SPI_SETSCREENSAVERRUNNING:     // same as SPI_SCREENSAVERRUNNING
        MSGERROR();

    case SPI_SETDESKPATTERN:
        if (wParam == 0x0000FFFF) {
            wParam = (UINT)-1;
        }

        /*
         * lParam not a string (and already copied).
         */
        if (wParam == (UINT)-1) {
            break;
        }

        /*
         * lParam is possibly 0 or -1 (filled in already) or a string.
         */
        if (lParam != (PVOID)0 && lParam != (PVOID)-1) {
            COPYLPTSTR(&strlParam, (LPTSTR)lParam);
            lParam = strlParam.pstr;
        }
        break;

    case SPI_SETDESKWALLPAPER: {

            /*
             * lParam is possibly 0, -1 or -2 (filled in already) or a string.
             * Get a pointer to the string so we can use it later.  We're
             * going to a bit of normalizing here for consistency.
             *
             * If the caller passes in 0, -1 or -2, we're going to set
             * the wParam to -1, and use the lParam to pass the string
             * representation of the wallpaper.
             */
            if ((lParam != (PVOID) 0) &&
                (lParam != (PVOID)-1) &&
                (lParam != (PVOID)-2)) {

                COPYLPTSTR(&strlParam, (LPTSTR)lParam);
                lParam = strlParam.pstr;
                wParam = 0;

            } else {
                wParam = (UINT)-1;
            }
        }
        break;

    /*
     * Bug 257718 - joejo
     * Add SPI_GETDESKWALLPAPER to SystemParametersInfo
     */
    case SPI_GETDESKWALLPAPER:
        if ((lParam == NULL) || (wParam == 0))
            MSGERROR();
#if IS_ANSI
        lParam = szTemp;
        wParam = ARRAY_SIZE(szTemp);
#else
        /*
         * Bug 283318 - joejo
         * Leave space for a null termination
         */
        wParam--;
#endif

        break;


    case SPI_GETANIMATION:
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(ANIMATIONINFO)) {
            MSGERROR();
        }
        break;

    case SPI_GETNONCLIENTMETRICS:
#if IS_ANSI
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(NONCLIENTMETRICSA)) {
            MSGERROR();
        }
        lParam = &ClientMetricsW;
#else
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(NONCLIENTMETRICSW)) {
            MSGERROR();
        }
#endif
        break;

    case SPI_GETMINIMIZEDMETRICS:
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(MINIMIZEDMETRICS)) {
            MSGERROR();
        }
        break;

    case SPI_GETICONMETRICS:
#if IS_ANSI
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(ICONMETRICSA)) {
            MSGERROR();
        }
        lParam = &IconMetricsW;
#else
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(ICONMETRICSW)) {
            MSGERROR();
        }
#endif
        break;

    case SPI_GETHIGHCONTRAST:
#if IS_ANSI
        {
            LPHIGHCONTRASTA pHC = (HIGHCONTRASTA *)lParam;
            if (!pHC || pHC->cbSize != sizeof(HIGHCONTRASTA)) {
                MSGERROR();
            }

            if (!pcHighContrastScheme) {
                pcHighContrastScheme = UserLocalAlloc(HEAP_ZERO_MEMORY,
                                                      MAX_SCHEME_NAME_SIZE * sizeof(WCHAR));
                if (!pcHighContrastScheme) {
                    MSGERROR();
                }
            }

            if (!pwcHighContrastScheme) {
                pwcHighContrastScheme = UserLocalAlloc(HEAP_ZERO_MEMORY,
                                                       MAX_SCHEME_NAME_SIZE * sizeof(WCHAR));
                if (!pwcHighContrastScheme) {
                    MSGERROR();
                }
            }
            ((LPHIGHCONTRASTW)(lParam))->lpszDefaultScheme = pwcHighContrastScheme;
        }
#else
        {
            LPHIGHCONTRASTW pHC = (HIGHCONTRASTW *)lParam;
            if (!pHC || (pHC->cbSize != sizeof(HIGHCONTRASTW))) {
                MSGERROR();
            }
            if (!pwcHighContrastScheme) {
                pwcHighContrastScheme = UserLocalAlloc(HEAP_ZERO_MEMORY,
                                                       MAX_SCHEME_NAME_SIZE * sizeof(WCHAR));
                if (!pwcHighContrastScheme) {
                    MSGERROR();
                }
            }
            pHC->lpszDefaultScheme = pwcHighContrastScheme;
        }
#endif

        break;

#if IS_ANSI
    case SPI_GETICONTITLELOGFONT:
        lParam = &LogFontW;
        break;
#endif

    case SPI_SETANIMATION:
        if (lParam == NULL || *((DWORD *)lParam) != sizeof(ANIMATIONINFO)) {
            MSGERROR();
        }
        break;

    case SPI_SETHIGHCONTRAST:
        ihc.cbSize = sizeof (HIGHCONTRASTW);
        {
            LPHIGHCONTRAST pHC = (HIGHCONTRAST *)lParam;
            if (lParam == NULL || pHC->cbSize != sizeof(HIGHCONTRAST)) {
                MSGERROR();
            }

            lParam = &ihc;
            ihc.dwFlags = pHC->dwFlags;
            COPYLPTSTR(&strlParam, pHC->lpszDefaultScheme);
            ihc.usDefaultScheme = *strlParam.pstr;
        }
        break;

    case SPI_SETNONCLIENTMETRICS:
        {
            PNONCLIENTMETRICS psrc = (PNONCLIENTMETRICS)lParam;

            if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(NONCLIENTMETRICS)) {
                MSGERROR();
            }

            if (psrc->iCaptionWidth > 256) {
                psrc->iCaptionWidth = 256;
            }

            if (psrc->iCaptionHeight > 256) {
                psrc->iCaptionHeight = 256;
            }

#if IS_ANSI
            ClientMetricsW.cbSize           = psrc->cbSize;
            ClientMetricsW.iBorderWidth     = psrc->iBorderWidth;
            ClientMetricsW.iScrollWidth     = psrc->iScrollWidth;
            ClientMetricsW.iScrollHeight    = psrc->iScrollHeight;
            ClientMetricsW.iCaptionWidth    = psrc->iCaptionWidth;
            ClientMetricsW.iCaptionHeight   = psrc->iCaptionHeight;
            ClientMetricsW.iSmCaptionWidth  = psrc->iSmCaptionWidth;
            ClientMetricsW.iSmCaptionHeight = psrc->iSmCaptionHeight;
            ClientMetricsW.iMenuWidth       = psrc->iMenuWidth;
            ClientMetricsW.iMenuHeight      = psrc->iMenuHeight;

            CopyLogFontAtoW(&(ClientMetricsW.lfCaptionFont), &(psrc->lfCaptionFont));
            CopyLogFontAtoW(&(ClientMetricsW.lfSmCaptionFont), &(psrc->lfSmCaptionFont));
            CopyLogFontAtoW(&(ClientMetricsW.lfMenuFont), &(psrc->lfMenuFont));
            CopyLogFontAtoW(&(ClientMetricsW.lfStatusFont), &(psrc->lfStatusFont));
            CopyLogFontAtoW(&(ClientMetricsW.lfMessageFont), &(psrc->lfMessageFont));

            lParam = &ClientMetricsW;
#endif

            wParam = sizeof(NONCLIENTMETRICSW);
        }
        break;

    case SPI_SETMINIMIZEDMETRICS:
        if ((lParam == NULL) || (*((DWORD *)(lParam)) != sizeof(MINIMIZEDMETRICS)))
            MSGERROR();
        wParam = sizeof(MINIMIZEDMETRICS);
        break;

    case SPI_SETICONMETRICS:
#if IS_ANSI
        {
            PICONMETRICSA psrc = (PICONMETRICSA)lParam;

            if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(ICONMETRICSA)) {
                MSGERROR();
            }

            RtlCopyMemory(&IconMetricsW, psrc, sizeof(ICONMETRICSA) - sizeof(LOGFONTA));

            CopyLogFontAtoW(&(IconMetricsW.lfFont), &(psrc->lfFont));
            lParam = &IconMetricsW;
        }
#else
        if (lParam == NULL || *((DWORD *)(lParam)) != sizeof(ICONMETRICSW)) {
            MSGERROR();
        }
#endif
        wParam = sizeof(ICONMETRICSW);
        break;

    case SPI_SETICONTITLELOGFONT:
#if IS_ANSI
        CopyLogFontAtoW(&LogFontW, lParam);
        lParam = &LogFontW;
#endif
        wParam = sizeof(LOGFONTW);
        break;

    case SPI_GETFILTERKEYS:
        {
            if ((((LPFILTERKEYS)lParam)->cbSize == 0) ||
                    (((LPFILTERKEYS)lParam)->cbSize) > sizeof(FILTERKEYS)) {
                MSGERROR();
            }
        }
        break;

    case SPI_GETSTICKYKEYS:
        {
            if ((((LPSTICKYKEYS)lParam)->cbSize == 0) ||
                    (((LPSTICKYKEYS)lParam)->cbSize) > sizeof(STICKYKEYS)) {
                MSGERROR();
            }
        }
        break;

    case SPI_GETTOGGLEKEYS:
        {
            if ((((LPTOGGLEKEYS)lParam)->cbSize == 0) ||
                    (((LPTOGGLEKEYS)lParam)->cbSize) > sizeof(TOGGLEKEYS)) {
                MSGERROR();
            }
        }
        break;

    case SPI_GETMOUSEKEYS:
        {
            if ((((LPMOUSEKEYS)lParam)->cbSize == 0) ||
                    (((LPMOUSEKEYS)lParam)->cbSize) > sizeof(MOUSEKEYS)) {
                MSGERROR();
            }
        }
        break;

    case SPI_GETACCESSTIMEOUT:
        {
            if ((((LPACCESSTIMEOUT)lParam)->cbSize == 0) ||
                    (((LPACCESSTIMEOUT)lParam)->cbSize) > sizeof(ACCESSTIMEOUT)) {
                MSGERROR();
            }
        }
        break;

    case SPI_GETSOUNDSENTRY:
        if ((((LPSOUNDSENTRY)lParam)->cbSize == 0) ||
                (((LPSOUNDSENTRY)lParam)->cbSize) > sizeof(SOUNDSENTRY)) {
            MSGERROR();
        }
        break;
    }

    retval = NtUserSystemParametersInfo(wFlag, wParam, lParam, flags);

    switch (wFlag) {
#if IS_ANSI
    case SPI_GETNONCLIENTMETRICS:
        {
            PNONCLIENTMETRICSA pdst = (PNONCLIENTMETRICSA)oldlParam;

            pdst->cbSize           = sizeof(NONCLIENTMETRICSA);
            pdst->iBorderWidth     = ClientMetricsW.iBorderWidth;
            pdst->iScrollWidth     = ClientMetricsW.iScrollWidth;
            pdst->iScrollHeight    = ClientMetricsW.iScrollHeight;
            pdst->iCaptionWidth    = ClientMetricsW.iCaptionWidth;
            pdst->iCaptionHeight   = ClientMetricsW.iCaptionHeight;
            pdst->iSmCaptionWidth  = ClientMetricsW.iSmCaptionWidth;
            pdst->iSmCaptionHeight = ClientMetricsW.iSmCaptionHeight;
            pdst->iMenuWidth       = ClientMetricsW.iMenuWidth;
            pdst->iMenuHeight      = ClientMetricsW.iMenuHeight;

            CopyLogFontWtoA(&(pdst->lfCaptionFont), &(ClientMetricsW.lfCaptionFont));
            CopyLogFontWtoA(&(pdst->lfSmCaptionFont), &(ClientMetricsW.lfSmCaptionFont));
            CopyLogFontWtoA(&(pdst->lfMenuFont), &(ClientMetricsW.lfMenuFont));
            CopyLogFontWtoA(&(pdst->lfStatusFont), &(ClientMetricsW.lfStatusFont));
            CopyLogFontWtoA(&(pdst->lfMessageFont), &(ClientMetricsW.lfMessageFont));
        }
        break;

    case SPI_GETICONMETRICS:
        {
            PICONMETRICSA pdst = (PICONMETRICSA)oldlParam;

            RtlCopyMemory(pdst, &IconMetricsW, sizeof(ICONMETRICSA) - sizeof(LOGFONTA));
            pdst->cbSize = sizeof(ICONMETRICSA);

            CopyLogFontWtoA(&(pdst->lfFont), &(IconMetricsW.lfFont));
        }
        break;

    case SPI_GETICONTITLELOGFONT:
        CopyLogFontWtoA((PLOGFONTA)oldlParam, &LogFontW);
        break;

    case SPI_GETHIGHCONTRAST:
        WCSToMB(pwcHighContrastScheme, -1, &pcHighContrastScheme, MAX_SCHEME_NAME_SIZE, FALSE);
        ((LPHIGHCONTRASTA)(lParam))->lpszDefaultScheme = pcHighContrastScheme;
        break;

#endif

    case SPI_GETDESKWALLPAPER:
        {
#if IS_ANSI
            INT cchAnsiCopy = WCSToMB(lParam,
                                      -1,
                                      (LPSTR*)&oldlParam,
                                      oldwParam - 1,
                                      FALSE);

            cchAnsiCopy = min(cchAnsiCopy, (INT)(oldwParam - 1));
            ((LPSTR)oldlParam)[cchAnsiCopy] = 0;
#else
            ((LPWSTR)oldlParam)[wParam] = (WCHAR)0;
#endif
            break;
        }
    case SPI_SETLOWPOWERTIMEOUT:
    case SPI_SETPOWEROFFTIMEOUT:
        if (retval && (flags & SPIF_UPDATEINIFILE)) {
            retval = SetVideoTimeout(wParam);
        }
        break;
    }

    ERRORTRAP(FALSE);
    CLEANUPLPTSTR(strlParam);
    ENDCALL(BOOL);
}


#ifdef UNICODE
FUNCLOG2(LOG_GENERAL, HANDLE, APIENTRY, GetPropW, HWND, hwnd, LPCTSTR, pString)
#else
FUNCLOG2(LOG_GENERAL, HANDLE, APIENTRY, GetPropA, HWND, hwnd, LPCTSTR, pString)
#endif // UNICODE
HANDLE APIENTRY GetProp(HWND hwnd, LPCTSTR pString)
{
    PWND pwnd;
    int iString;

    if (IS_PTR(pString)) {
        iString = (int)GlobalFindAtom(pString);
        if (iString == 0)
            return NULL;
    } else
        iString = PTR_TO_ID(pString);

    pwnd = ValidateHwnd(hwnd);

    if (pwnd == NULL)
        return NULL;

    return _GetProp(pwnd, (LPWSTR)UIntToPtr( iString ), FALSE);
}


/***************************************************************************\
* RegisterClassW(API)
*
* History:
* 28-Jul-1992 ChandanC Created.
\***************************************************************************/
ATOM
WINAPI
TEXT_FN(RegisterClass)(
    CONST WNDCLASS *lpWndClass )
{
    WNDCLASSEX wc;

    /*
     * On 64-bit plaforms we'll have 32-bits of padding between style and
     * lpfnWndProc in WNDCLASS, so start the copy from the first 64-bit
     * aligned field and hand copy the rest.
     */
    RtlCopyMemory(&(wc.lpfnWndProc), &(lpWndClass->lpfnWndProc), sizeof(WNDCLASS) - FIELD_OFFSET(WNDCLASS, lpfnWndProc));
    wc.style = lpWndClass->style;
    wc.hIconSm = NULL;
    wc.cbSize = sizeof(WNDCLASSEX);

    return TEXT_FN(RegisterClassExWOW)(&wc, NULL, 0, CSF_VERSIONCLASS);
}

/***************************************************************************\
* RegisterClassExW(API)
*
* History:
* 28-Jul-1992 ChandanC Created.
\***************************************************************************/
ATOM
WINAPI
TEXT_FN(RegisterClassEx)(
    CONST WNDCLASSEX *lpWndClass)
{
    if (lpWndClass->cbSize != sizeof(WNDCLASSEX)) {
        RIPERR1(ERROR_INVALID_PARAMETER,
                RIP_WARNING,
                "RegisterClassEx: cbsize is wrong %lX",
                lpWndClass->cbSize);

        return 0;
    } else {
        return TEXT_FN(RegisterClassExWOW)((LPWNDCLASSEX)lpWndClass,
                NULL, 0, CSF_VERSIONCLASS);
    }
}

/***************************************************************************\
* GetMenuItemInfoInternal
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
BOOL TEXT_FN(GetMenuItemInfoInternal) (HMENU hMenu, UINT uID, BOOL fByPosition,
    LPMENUITEMINFOW lpInfo)
{
     PITEM pItem;
     PMENU pMenu;
     PMENU pMenuT;

     pMenu = VALIDATEHMENU(hMenu);
     if (pMenu == NULL) {
        VALIDATIONFAIL(hMenu);
     }

     pMenuT = pMenu;         // need to check the ORIGINAL menu if popup

     pItem = MNLookUpItem(pMenu, uID, fByPosition, &pMenu);
    if (pItem == NULL) {
        /*
         * Don't display a warning. The explorer makes a lot of calls
         *  that fail here.
         * VALIDATIONFAIL(uID);
         */
        SetLastError(ERROR_MENU_ITEM_NOT_FOUND);
        return FALSE;

    }

    if (lpInfo->fMask & MIIM_STATE) {
        lpInfo->fState = pItem->fState & MFS_MASK;
    }

    if (lpInfo->fMask & MIIM_ID) {
        lpInfo->wID = pItem->wID;
    }

    if ((lpInfo->fMask & MIIM_SUBMENU) && (pItem->spSubMenu != NULL)) {
        lpInfo->hSubMenu = PtoH(REBASEPTR(pMenu, pItem->spSubMenu));
    } else {
        lpInfo->hSubMenu = NULL;
    }

    if (lpInfo->fMask & MIIM_CHECKMARKS) {
        lpInfo->hbmpChecked  = KHBITMAP_TO_HBITMAP(pItem->hbmpChecked);
        lpInfo->hbmpUnchecked= KHBITMAP_TO_HBITMAP(pItem->hbmpUnchecked);
    }

    if (lpInfo->fMask & MIIM_DATA) {
       lpInfo->dwItemData = KERNEL_ULONG_PTR_TO_ULONG_PTR(pItem->dwItemData);
    }

    if (lpInfo->fMask & MIIM_FTYPE) {
        lpInfo->fType = pItem->fType & MFT_MASK;
        if (TestMF(pMenuT,MFRTL))
            lpInfo->fType |= MFT_RIGHTORDER;
    }

    if ( lpInfo->fMask & MIIM_BITMAP) {
        lpInfo->hbmpItem = KHBITMAP_TO_HBITMAP(pItem->hbmp);
    }

    if (lpInfo->fMask & MIIM_STRING) {
        if ((lpInfo->cch == 0)
            || (lpInfo->dwTypeData == NULL)

            /*
             * If this is an old caller (MIIM_TYPE set), and this item
             *  has a bitmap or it's ownerdraw, then don't attempt to
             *  copy a string since they probably didn't pass a pointer
            */

            || ((lpInfo->fMask & MIIM_TYPE)
                    && ((lpInfo->fType & MFT_OWNERDRAW)
                            /*
                             * Bug 278750 - jojoe
                             *
                             * Soemone forgot to check for separator in the list
                             * of menuitems that do NOT return string data!
                             */
                            || (lpInfo->fType & MFT_SEPARATOR)
                            || ((pItem->hbmp != NULL)  && ((pItem->hbmp < HBMMENU_POPUPFIRST) || (pItem->hbmp > HBMMENU_POPUPLAST)))))) {



            /*
             * When DBCS is enabled, one UNICODE character may occupy two bytes.
             * GetMenuItemInfoA should return the byte count, rather than the character count.
             * On NT5, pItem->lpstr is guaranteed to be a valid string, if it is not NULL.
             */
            if (IS_ANSI && IS_DBCS_ENABLED() && pItem->lpstr != NULL) {
                NTSTATUS Status;
                ULONG cch;

                Status = RtlUnicodeToMultiByteSize(&cch, REBASEPTR(pMenu, pItem->lpstr), pItem->cch * sizeof(WCHAR));
                UserAssert(NT_SUCCESS(Status)); // RtlUnicodeToMultiByteSize is not expected to fail
                lpInfo->cch = cch;
            } else {
                lpInfo->cch = pItem->cch;
            }
            lpInfo->dwTypeData = NULL;


        } else {
            int cch = 0;

            if (pItem->lpstr != NULL) {

                // originally:
                // cch = min(lpInfo->cch - 1, (pItem->cch * sizeof(WORD)));
                cch = pItem->cch;
                UserAssert(cch >= 0);
                if (IS_DBCS_ENABLED()) {
                    /* pItem->cch contains Unicode character counts,
                     * we guess max DBCS string size for the Unicode string.
                     */
                    cch *= DBCS_CHARSIZE;
                }
                cch = min(lpInfo->cch - 1, (DWORD)cch);

#if IS_ANSI
                cch = WCSToMB(REBASEPTR(pMenu, pItem->lpstr), pItem->cch,
                        (LPSTR *)&(lpInfo->dwTypeData), cch, FALSE);
#else
                wcsncpy(lpInfo->dwTypeData, (LPWSTR)REBASEPTR(pMenu, pItem->lpstr),
    cch);
#endif
            }

#if IS_ANSI
            *((LPSTR)lpInfo->dwTypeData + cch) = (CHAR)0;
#else
            *(lpInfo->dwTypeData + cch) = (WCHAR)0;
#endif
            lpInfo->cch = cch;
        }
     }

     return TRUE;

     VALIDATIONERROR(FALSE);

}
/***************************************************************************\
* GetMenuString()
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, int, DUMMYCALLINGTYPE, GetMenuStringW, HMENU, hMenu, UINT, wID, LPTSTR, lpsz, int, cchMax, UINT, flags)
#else
FUNCLOG5(LOG_GENERAL, int, DUMMYCALLINGTYPE, GetMenuStringA, HMENU, hMenu, UINT, wID, LPTSTR, lpsz, int, cchMax, UINT, flags)
#endif // UNICODE
int GetMenuString(HMENU hMenu, UINT wID, LPTSTR lpsz, int cchMax, UINT flags)
{
    MENUITEMINFOW    miiLocal;

    miiLocal.fMask      = MIIM_STRING;
    miiLocal.dwTypeData = (LPWSTR)lpsz;
    miiLocal.cch        = cchMax;

    if (cchMax != 0) {
        *lpsz = (TCHAR)0;
    }

    if (TEXT_FN(GetMenuItemInfoInternal)(hMenu, wID, (BOOL)(flags & MF_BYPOSITION), &miiLocal)) {
        return miiLocal.cch;
    } else {
        return 0;
    }
}

/***************************************************************************\
* GetMenuItemInfo
*
*  1) converts a MENUITEMINFO95 or a new-MENUITEMINFO-with-old-flags to a new
*     MENUITEMINFO -- this way all internal code can assume one look for the
*     structure
*  2) calls the internal GetMenuItemInfo which performs validation and work
*  3) converts the new MENUITEMINFO back to the original MENUITEMINFO
*
* History:
*  07-22-96 GerardoB - Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, GetMenuItemInfoW, HMENU, hMenu, UINT, wID, BOOL, fByPos, LPMENUITEMINFO, lpmii)
#else
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, GetMenuItemInfoA, HMENU, hMenu, UINT, wID, BOOL, fByPos, LPMENUITEMINFO, lpmii)
#endif // UNICODE

BOOL GetMenuItemInfo(HMENU hMenu, UINT wID, BOOL fByPos, LPMENUITEMINFO lpmii)
{
    UINT cbCallercbSize = lpmii->cbSize;
    MENUITEMINFOW miiLocal;


    if (!ValidateMENUITEMINFO((LPMENUITEMINFOW)lpmii, &miiLocal, MENUAPI_GET)) {
        return FALSE;
    }

    if (!TEXT_FN(GetMenuItemInfoInternal)(hMenu, wID, fByPos, &miiLocal)) {
        return FALSE;
    }

    /*
     * Copy the structure and map old flags back. Only requested fields were
     *   modified, so it's OK  to copy all fields back.
     */
    RtlCopyMemory(lpmii, &miiLocal, SIZEOFMENUITEMINFO95);
    lpmii->cbSize = cbCallercbSize;
    if (cbCallercbSize > SIZEOFMENUITEMINFO95) {
        lpmii->hbmpItem = miiLocal.hbmpItem;
    }

    if (lpmii->fMask & MIIM_TYPE) {
        if ((miiLocal.hbmpItem != NULL) && (miiLocal.dwTypeData == NULL)) {
            lpmii->fType |= MFT_BITMAP;
            lpmii->dwTypeData = (LPTSTR)miiLocal.hbmpItem;
        } else if (miiLocal.cch == 0) {
            lpmii->dwTypeData = NULL;
        }
        lpmii->fMask &= ~(MIIM_FTYPE | MIIM_BITMAP | MIIM_STRING);
    }

    return TRUE;
}
/***************************************************************************\
* SetMenuItemInfo
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, SetMenuItemInfoW, HMENU, hMenu, UINT, uID, BOOL, fByPosition, LPCMENUITEMINFO, lpmii)
#else
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, SetMenuItemInfoA, HMENU, hMenu, UINT, uID, BOOL, fByPosition, LPCMENUITEMINFO, lpmii)
#endif // UNICODE
BOOL SetMenuItemInfo(HMENU hMenu, UINT uID, BOOL fByPosition, LPCMENUITEMINFO lpmii)
{

    MENUITEMINFOW miiLocal;

    if (!ValidateMENUITEMINFO((LPMENUITEMINFOW)lpmii, &miiLocal, MENUAPI_SET)) {
        return FALSE;
    }

    return (ThunkedMenuItemInfo(hMenu, uID, fByPosition, FALSE, &miiLocal, IS_ANSI));
}
/***************************************************************************\
* InsertMenuItem
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
BOOL InsertMenuItem (HMENU hMenu, UINT uID, BOOL fByPosition, LPCMENUITEMINFO lpmii)
{

    MENUITEMINFOW miiLocal;

    if (!ValidateMENUITEMINFO((LPMENUITEMINFOW)lpmii, &miiLocal, MENUAPI_SET)) {
        return FALSE;
    }

    return (ThunkedMenuItemInfo(hMenu, uID, fByPosition, TRUE, &miiLocal, IS_ANSI));
}

/***************************************************************************\
* InsertMenu
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, InsertMenuW, HMENU, hMenu, UINT, uPosition, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#else
FUNCLOG5(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, InsertMenuA, HMENU, hMenu, UINT, uPosition, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#endif // UNICODE
BOOL InsertMenu(HMENU hMenu, UINT uPosition, UINT uFlags, UINT_PTR uIDNewItem, LPCTSTR lpNewItem)
{
    MENUITEMINFOW miiLocal;

    SetMenuItemInfoStruct(hMenu, uFlags, uIDNewItem, (LPWSTR)lpNewItem, &miiLocal);
    return ThunkedMenuItemInfo(hMenu, uPosition, (BOOL) (uFlags & MF_BYPOSITION), TRUE, (LPMENUITEMINFOW)&miiLocal, IS_ANSI);
}

/***************************************************************************\
* AppendMenu
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, AppendMenuW, HMENU, hMenu, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#else
FUNCLOG4(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, AppendMenuA, HMENU, hMenu, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#endif // UNICODE
BOOL AppendMenu(HMENU hMenu, UINT uFlags, UINT_PTR uIDNewItem, LPCTSTR lpNewItem)
{
    MENUITEMINFOW miiLocal;

    SetMenuItemInfoStruct(hMenu, uFlags, uIDNewItem, (LPWSTR)lpNewItem, &miiLocal);
    return ThunkedMenuItemInfo(hMenu, MFMWFP_NOITEM, MF_BYPOSITION, TRUE, (LPMENUITEMINFOW)&miiLocal, IS_ANSI);
}
/***************************************************************************\
* ModifyMenu
*
* History:
*  07-22-96 GerardoB - Added header and Fixed up for 5.0
\***************************************************************************/
#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, ModifyMenuW, HMENU, hMenu, UINT, uPosition, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#else
FUNCLOG5(LOG_GENERAL, BOOL, DUMMYCALLINGTYPE, ModifyMenuA, HMENU, hMenu, UINT, uPosition, UINT, uFlags, UINT_PTR, uIDNewItem, LPCTSTR, lpNewItem)
#endif // UNICODE
BOOL ModifyMenu(HMENU hMenu, UINT uPosition, UINT uFlags, UINT_PTR uIDNewItem, LPCTSTR lpNewItem)
{
    MENUITEMINFOW miiLocal;

    SetMenuItemInfoStruct(hMenu, uFlags, uIDNewItem, (LPWSTR)lpNewItem, &miiLocal);
    return ThunkedMenuItemInfo(hMenu, uPosition, (BOOL) (uFlags & MF_BYPOSITION), FALSE, (LPMENUITEMINFOW)&miiLocal, IS_ANSI);
}

#ifdef UNICODE
FUNCLOG6(LOG_GENERAL, LONG, WINUSERAPI, BroadcastSystemMessageExW, DWORD, dwFlags, LPDWORD, lpdwRecipients, UINT, uiMessage, WPARAM, wParam, LPARAM, lParam, PBSMINFO, pBSMInfo)
#else
FUNCLOG6(LOG_GENERAL, LONG, WINUSERAPI, BroadcastSystemMessageExA, DWORD, dwFlags, LPDWORD, lpdwRecipients, UINT, uiMessage, WPARAM, wParam, LPARAM, lParam, PBSMINFO, pBSMInfo)
#endif // UNICODE

/***************************************************************************\
* BroadcastSystemMessageEx
*
* History:
*
\***************************************************************************/
WINUSERAPI LONG BroadcastSystemMessageEx(
    DWORD dwFlags,
    LPDWORD lpdwRecipients,
    UINT uiMessage,
    WPARAM wParam,
    LPARAM lParam,
    PBSMINFO pBSMInfo)
{
    return BroadcastSystemMessageWorker(dwFlags,
                                        lpdwRecipients,
                                        uiMessage,
                                        wParam,
                                        lParam,
                                        pBSMInfo,
                                        IS_ANSI);
}

#ifdef UNICODE
FUNCLOG5(LOG_GENERAL, LONG, WINUSERAPI, BroadcastSystemMessageW, DWORD, dwFlags, LPDWORD, lpdwRecipients, UINT, uiMessage, WPARAM, wParam, LPARAM, lParam)
#else
FUNCLOG5(LOG_GENERAL, LONG, WINUSERAPI, BroadcastSystemMessageA, DWORD, dwFlags, LPDWORD, lpdwRecipients, UINT, uiMessage, WPARAM, wParam, LPARAM, lParam)
#endif // UNICODE

/***************************************************************************\
* BroadcastSystemMessage
*
* History:
*  07-22-96 GerardoB - Added header
\***************************************************************************/
WINUSERAPI LONG BroadcastSystemMessage(
    DWORD dwFlags,
    LPDWORD lpdwRecipients,
    UINT uiMessage,
    WPARAM wParam,
    LPARAM lParam)
{
    return BroadcastSystemMessageWorker(dwFlags,
                                        lpdwRecipients,
                                        uiMessage,
                                        wParam,
                                        lParam,
                                        NULL,
                                        IS_ANSI);
}

#ifdef UNICODE
FUNCLOG3(LOG_GENERAL, UINT, WINUSERAPI, GetWindowModuleFileNameW, HWND, hwnd, LPTSTR, pszFileName, UINT, cchFileNameMax)
#else
FUNCLOG3(LOG_GENERAL, UINT, WINUSERAPI, GetWindowModuleFileNameA, HWND, hwnd, LPTSTR, pszFileName, UINT, cchFileNameMax)
#endif // UNICODE

WINUSERAPI UINT WINAPI
GetWindowModuleFileName(
    HWND hwnd,
    LPTSTR pszFileName,
    UINT cchFileNameMax)
{
    PWND pwnd;

    pwnd = ValidateHwnd(hwnd);

    if (pwnd == NULL) {
        return 0;
    }

    return GetModuleFileName(KHANDLE_TO_HANDLE(pwnd->hModule),
                             pszFileName,
                             cchFileNameMax);
}

/***************************************************************************\
* RegisterDeviceNotification
*
* History:
*  01-23-97 PaulaT - Added header
\***************************************************************************/
WINUSERAPI HDEVNOTIFY WINAPI
RegisterDeviceNotification(
    IN HANDLE hRecipient,
    IN LPVOID NotificationFilter,
    IN DWORD Flags)
{
    extern HDEVNOTIFY RegisterDeviceNotificationWorker(IN HANDLE hRecipient,
                                                       IN LPVOID NotificationFilter,
                                                       IN DWORD Flags);

    // translate strings in NotificationFilter (if any)

    return RegisterDeviceNotificationWorker(hRecipient,
                                            NotificationFilter,
                                            Flags);
}



/***************************************************************************\
* GetMonitorInfo
*
* History:
* 31-Mar-1997 adams     Doesn't call into kernel.
* 06-Jul-1998 MCostea   Has to call into kernel #190510
\***************************************************************************/
#ifdef UNICODE
FUNCLOG2(LOG_GENERAL, BOOL, WINUSERAPI, GetMonitorInfoW, HMONITOR, hMonitor, LPMONITORINFO, lpmi)
#else
FUNCLOG2(LOG_GENERAL, BOOL, WINUSERAPI, GetMonitorInfoA, HMONITOR, hMonitor, LPMONITORINFO, lpmi)
#endif // UNICODE

BOOL WINUSERAPI
GetMonitorInfo(HMONITOR hMonitor, LPMONITORINFO lpmi)
{
    PMONITOR    pMonitor;
    BOOL        bRetVal;
    int         cbSize;

    pMonitor = VALIDATEHMONITOR(hMonitor);
    if (!pMonitor) {
        return FALSE;
    }

    cbSize = lpmi->cbSize;
    if (cbSize == sizeof(MONITORINFO)) {
        /*
         * Check for this first, since it is the most
         * common size. All the work for filling in
         * MONITORINFO fields is done after the else-if
         * statements.
         */

    } else if (cbSize == sizeof(MONITORINFOEX)) {
        /*
         * The ANSI version has to translate the szDevice field
         */
        ULONG_PTR pName;
#if IS_ANSI
        WCHAR szDevice[CCHDEVICENAME];
        pName = (ULONG_PTR)szDevice;
#else
        pName = (ULONG_PTR)(((LPMONITORINFOEX)lpmi)->szDevice);
#endif
        bRetVal = (BOOL)NtUserCallTwoParam((ULONG_PTR)(hMonitor),
                           pName,
                           SFI_GETHDEVNAME);
        if (!bRetVal) {
            return FALSE;
        }
#if IS_ANSI
        WideCharToMultiByte(
            CP_ACP, 0,                                  // ANSI -> Unicode
            (LPWSTR)pName, -1,                          // source & length
            (LPSTR)((LPMONITORINFOEX)lpmi)->szDevice,   // destination & length
            ARRAY_SIZE(((LPMONITORINFOEX)lpmi)->szDevice),
            NULL, NULL);

#endif
    } else {
        RIPERR1(ERROR_INVALID_PARAMETER,
                RIP_WARNING,
                "Invalid lpmi->cbSize, %d", lpmi->cbSize);

        return FALSE;
    }

    lpmi->dwFlags = (pMonitor == GetPrimaryMonitor()) ? MONITORINFOF_PRIMARY : 0;
    lpmi->rcMonitor = pMonitor->rcMonitor;
    lpmi->rcWork = pMonitor->rcWork;

    return TRUE;
}

#ifdef GENERIC_INPUT
#ifdef UNICODE
FUNCLOG4(LOG_GENERAL, UINT, WINUSERAPI, GetRawInputDeviceInfoW, HANDLE, hDevice, UINT, uiCommand, LPVOID, pData, PUINT, pcbSize)
#else
FUNCLOG4(LOG_GENERAL, UINT, WINUSERAPI, GetRawInputDeviceInfoA, HANDLE, hDevice, UINT, uiCommand, LPVOID, pData, PUINT, pcbSize)
#endif // UNICODE
UINT WINUSERAPI
GetRawInputDeviceInfo(
    HANDLE hDevice,
    UINT uiCommand,
    LPVOID pData,
    PUINT pcbSize)
{
#if IS_ANSI
    UINT uiRet;
    LPVOID lpParam = pData;
    WCHAR wszPath[MAX_PATH];
    UINT cbBufferSize = 0;

    if (uiCommand == RIDI_DEVICENAME) {
        if (pData) {
            lpParam = wszPath;
            cbBufferSize = *pcbSize;
        }
    }

    uiRet = NtUserGetRawInputDeviceInfo(hDevice, uiCommand, lpParam, pcbSize);
    if (uiCommand == RIDI_DEVICENAME) {
        if (uiRet == (UINT)-1 && pData != NULL) {
            /* Insufficient buffer */
            if (GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
                *pcbSize *= DBCS_CHARSIZE;
            }
        } else if (uiRet == 0 && pData == NULL) {
            /* The app wants the buffer size for the device name */
            *pcbSize *= DBCS_CHARSIZE;
        } else {
            uiRet = WCSToMB(lpParam, uiRet, (LPSTR*)&pData, cbBufferSize, FALSE);

            /* TODO:
             * Handle the case if cbBufferSize was not enough.
             */
        }
    }

    return uiRet;
#else
    return NtUserGetRawInputDeviceInfo(hDevice, uiCommand, pData, pcbSize);
#endif
}
#endif
