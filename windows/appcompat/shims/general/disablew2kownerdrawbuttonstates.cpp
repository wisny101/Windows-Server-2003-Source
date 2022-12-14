/*++

 Copyright (c) 2000 Microsoft Corporation

 Module Name:

    DisableW2KOwnerDrawButtonStates.cpp

 Abstract:

    Hooks all application-defined window procedures and filters out new
    owner-draw buttons states (introduced in Win2000).

 Notes:

    This shim can be reused for other shims that require WindowProc hooking.
    Copy all APIHook_* functions and simply replace the code in WindowProcHook
    and DialogProcHook.

 History:

    11/01/1999 markder  Created
    02/15/1999 markder  Reworked WndProc hooking mechanism so that it generically
                        hooks all WndProcs for the process.
    11/29/2000 andyseti Converted into GeneralPurpose shim.

--*/

#include "precomp.h"

IMPLEMENT_SHIM_BEGIN(DisableW2KOwnerDrawButtonStates)
#include "ShimHookMacro.h"


APIHOOK_ENUM_BEGIN
    APIHOOK_ENUM_ENTRY(RegisterClassA)
    APIHOOK_ENUM_ENTRY(RegisterClassW)
    APIHOOK_ENUM_ENTRY(RegisterClassExA)
    APIHOOK_ENUM_ENTRY(RegisterClassExW)
    APIHOOK_ENUM_ENTRY(CreateDialogParamA)
    APIHOOK_ENUM_ENTRY(CreateDialogParamW)
    APIHOOK_ENUM_ENTRY(CreateDialogIndirectParamA)
    APIHOOK_ENUM_ENTRY(CreateDialogIndirectParamW)
    APIHOOK_ENUM_ENTRY(CreateDialogIndirectParamAorW)
    APIHOOK_ENUM_ENTRY(SetWindowLongA)
    APIHOOK_ENUM_ENTRY(SetWindowLongW)
APIHOOK_ENUM_END


/*++

 Change WM_DRAWITEM behaviour

--*/

LRESULT CALLBACK 
WindowProcHook(
    WNDPROC pfnOld, // address of old WindowProc
    HWND hwnd,      // handle to window
    UINT uMsg,      // message identifier
    WPARAM wParam,  // first message parameter
    LPARAM lParam   // second message parameter
    )
{
    // Check for message we're interested in
    if (uMsg == WM_DRAWITEM)
    {
        if (((LPDRAWITEMSTRUCT) lParam)->itemState &
                ~(ODS_SELECTED |
                ODS_GRAYED |
                ODS_DISABLED |
                ODS_CHECKED |
                ODS_FOCUS | 
                ODS_DEFAULT |
                ODS_COMBOBOXEDIT |
                ODS_HOTLIGHT |
                ODS_INACTIVE)) 
        {
            LOGN(eDbgLevelError, "Removed Win2K-specific Owner-draw button flags.");

            // Remove all Win9x-incompatible owner draw button states.
            ((LPDRAWITEMSTRUCT) lParam)->itemState &=
               (ODS_SELECTED |
                ODS_GRAYED |
                ODS_DISABLED |
                ODS_CHECKED |
                ODS_FOCUS | 
                ODS_DEFAULT |
                ODS_COMBOBOXEDIT |
                ODS_HOTLIGHT |
                ODS_INACTIVE);
        }
    }

    return (*pfnOld)(hwnd, uMsg, wParam, lParam);    
}

INT_PTR CALLBACK 
DialogProcHook(
    DLGPROC   pfnOld,   // address of old DialogProc
    HWND      hwndDlg,  // handle to dialog box
    UINT      uMsg,     // message
    WPARAM    wParam,   // first message parameter
    LPARAM    lParam    // second message parameter
    )
{
    // Check for message we're interested in
    if (uMsg == WM_DRAWITEM)
    {
        if (((LPDRAWITEMSTRUCT) lParam)->itemState &
                ~(ODS_SELECTED |
                ODS_GRAYED |
                ODS_DISABLED |
                ODS_CHECKED |
                ODS_FOCUS | 
                ODS_DEFAULT |
                ODS_COMBOBOXEDIT |
                ODS_HOTLIGHT |
                ODS_INACTIVE)) 
        {
            LOGN(eDbgLevelError, "Removed Win2K-specific Owner-draw button flags.");
 
            // Remove all Win9x-incompatible owner draw button states.
            ((LPDRAWITEMSTRUCT) lParam)->itemState &=
               (ODS_SELECTED |
                ODS_GRAYED |
                ODS_DISABLED |
                ODS_CHECKED |
                ODS_FOCUS | 
                ODS_DEFAULT |
                ODS_COMBOBOXEDIT |
                ODS_HOTLIGHT |
                ODS_INACTIVE);
        }
    }

    return (*pfnOld)(hwndDlg, uMsg, wParam, lParam);    
}

/*++

 Hook all possible calls that can initialize or change a window's
 WindowProc (or DialogProc)

--*/

ATOM
APIHOOK(RegisterClassA)(
    CONST WNDCLASSA *lpWndClass  // class data
    )
{
    WNDCLASSA   wcNewWndClass   = *lpWndClass;

    wcNewWndClass.lpfnWndProc = (WNDPROC) HookCallback(lpWndClass->lpfnWndProc, WindowProcHook);
    if( NULL == wcNewWndClass.lpfnWndProc ) {
        DPFN(eDbgLevelInfo, "Failed to hook window proc via RegisterClassA.");
        return ORIGINAL_API(RegisterClassA)(lpWndClass);
    }

    DPFN(eDbgLevelInfo, "Hooked window proc via RegisterClassA.");

    return ORIGINAL_API(RegisterClassA)(&wcNewWndClass);
}

ATOM
APIHOOK(RegisterClassW)(
    CONST WNDCLASSW *lpWndClass  // class data
    )
{
    WNDCLASSW   wcNewWndClass   = *lpWndClass;

    wcNewWndClass.lpfnWndProc = (WNDPROC) HookCallback(lpWndClass->lpfnWndProc, WindowProcHook);
    if( NULL == wcNewWndClass.lpfnWndProc ) {
        DPFN(eDbgLevelInfo, "Failed to hook window proc via RegisterClassW.");
        return ORIGINAL_API(RegisterClassW)(lpWndClass);
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via RegisterClassW.");

    return ORIGINAL_API(RegisterClassW)(&wcNewWndClass);
}

ATOM
APIHOOK(RegisterClassExA)(
    CONST WNDCLASSEXA *lpwcx  // class data
    )
{
    WNDCLASSEXA   wcNewWndClass   = *lpwcx;

    wcNewWndClass.lpfnWndProc = (WNDPROC) HookCallback(lpwcx->lpfnWndProc, WindowProcHook);
    if( NULL == wcNewWndClass.lpfnWndProc ) {
        DPFN(eDbgLevelInfo, "Failed to hook window proc via RegisterClassExA.");
        return ORIGINAL_API(RegisterClassExA)(lpwcx);
    }


    DPFN( eDbgLevelInfo, "Hooked window proc via RegisterClassExA.");

    return ORIGINAL_API(RegisterClassExA)(&wcNewWndClass);
}

ATOM
APIHOOK(RegisterClassExW)(
    CONST WNDCLASSEXW *lpwcx  // class data
    )
{
    WNDCLASSEXW   wcNewWndClass   = *lpwcx;

    wcNewWndClass.lpfnWndProc = (WNDPROC) HookCallback(lpwcx->lpfnWndProc, WindowProcHook);
    if( NULL == wcNewWndClass.lpfnWndProc ) {
        DPFN(eDbgLevelInfo, "Failed to hook window proc via RegisterClassExW.");
        return ORIGINAL_API(RegisterClassExW)(lpwcx);
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via RegisterClassExW.");

    return ORIGINAL_API(RegisterClassExW)(&wcNewWndClass);
}

HWND
APIHOOK(CreateDialogParamA)(
    HINSTANCE hInstance,     // handle to module
    LPCSTR lpTemplateName,   // dialog box template
    HWND hWndParent,         // handle to owner window
    DLGPROC lpDialogFunc,    // dialog box procedure
    LPARAM dwInitParam       // initialization value
    )
{
    DLGPROC lpNewDialogFunc = (DLGPROC) HookCallback(lpDialogFunc, DialogProcHook);
    if( NULL == lpNewDialogFunc ) {
        DPFN( eDbgLevelInfo, "Failed to hook window proc via CreateDialogParamA.");

        return ORIGINAL_API(CreateDialogParamA)(  
            hInstance,
            lpTemplateName,
            hWndParent,
            lpDialogFunc,
            dwInitParam     );
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via CreateDialogParamA.");

    return ORIGINAL_API(CreateDialogParamA)(  
        hInstance,
        lpTemplateName,
        hWndParent,
        lpNewDialogFunc,
        dwInitParam     );
}

HWND
APIHOOK(CreateDialogParamW)(
    HINSTANCE hInstance,     // handle to module
    LPCWSTR lpTemplateName,  // dialog box template
    HWND hWndParent,         // handle to owner window
    DLGPROC lpDialogFunc,    // dialog box procedure
    LPARAM dwInitParam       // initialization value
    )
{
    DLGPROC lpNewDialogFunc = (DLGPROC) HookCallback(lpDialogFunc, DialogProcHook);
    if( NULL == lpNewDialogFunc ) {
        DPFN( eDbgLevelInfo, "Failed to hook window proc via CreateDialogParamW.");

        return ORIGINAL_API(CreateDialogParamW)(  
            hInstance,
            lpTemplateName,
            hWndParent,
            lpDialogFunc,
            dwInitParam     );
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via CreateDialogParamW.");

    return ORIGINAL_API(CreateDialogParamW)(  
        hInstance,
        lpTemplateName,
        hWndParent,
        lpNewDialogFunc,
        dwInitParam     );
}

HWND
APIHOOK(CreateDialogIndirectParamA)(
    HINSTANCE hInstance,        // handle to module
    LPCDLGTEMPLATE lpTemplate,  // dialog box template
    HWND hWndParent,            // handle to owner window
    DLGPROC lpDialogFunc,       // dialog box procedure
    LPARAM lParamInit           // initialization value
    )
{
    DLGPROC lpNewDialogFunc = (DLGPROC) HookCallback(lpDialogFunc, DialogProcHook);
    if( NULL == lpNewDialogFunc ) {
        DPFN( eDbgLevelInfo, "Failed to hook window proc via CreateDialogIndirectParamA.");

        return ORIGINAL_API(CreateDialogIndirectParamA)(  
            hInstance,
            lpTemplate,
            hWndParent,
            lpDialogFunc,
            lParamInit     );
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via CreateDialogIndirectParamA.");

    return ORIGINAL_API(CreateDialogIndirectParamA)(  
        hInstance,
        lpTemplate,
        hWndParent,
        lpNewDialogFunc,
        lParamInit     );
}

HWND
APIHOOK(CreateDialogIndirectParamW)(
    HINSTANCE hInstance,        // handle to module
    LPCDLGTEMPLATE lpTemplate,  // dialog box template
    HWND hWndParent,            // handle to owner window
    DLGPROC lpDialogFunc,       // dialog box procedure
    LPARAM lParamInit           // initialization value
    )
{
    DLGPROC lpNewDialogFunc = (DLGPROC) HookCallback(lpDialogFunc, DialogProcHook);
    if( NULL == lpNewDialogFunc ) {
        DPFN( eDbgLevelInfo, "Failed to hook window proc via CreateDialogIndirectParamW.");

        return ORIGINAL_API(CreateDialogIndirectParamW)(  
            hInstance,
            lpTemplate,
            hWndParent,
            lpDialogFunc,
            lParamInit     );
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via CreateDialogIndirectParamW.");

    return ORIGINAL_API(CreateDialogIndirectParamW)(  
        hInstance,
        lpTemplate,
        hWndParent,
        lpNewDialogFunc,
        lParamInit     );
}

HWND
APIHOOK(CreateDialogIndirectParamAorW)(
    HINSTANCE hInstance,        // handle to module
    LPCDLGTEMPLATE lpTemplate,  // dialog box template
    HWND hWndParent,            // handle to owner window
    DLGPROC lpDialogFunc,       // dialog box procedure
    LPARAM lParamInit           // initialization value
    )
{
    DLGPROC lpNewDialogFunc = (DLGPROC) HookCallback(lpDialogFunc, DialogProcHook);
    if( NULL == lpNewDialogFunc ) {
        DPFN( eDbgLevelInfo, "Failed to hook window proc via CreateDialogIndirectParamAorW.");

        return ORIGINAL_API(CreateDialogIndirectParamAorW)(  
            hInstance,
            lpTemplate,
            hWndParent,
            lpDialogFunc,
            lParamInit     );
    }

    DPFN( eDbgLevelInfo, "Hooked window proc via CreateDialogIndirectParamAorW.");

    return ORIGINAL_API(CreateDialogIndirectParamAorW)(  
        hInstance,
        lpTemplate,
        hWndParent,
        lpNewDialogFunc,
        lParamInit     );
}

LONG 
APIHOOK(SetWindowLongA)(
    HWND hWnd,
    int nIndex,           
    LONG dwNewLong    
    )
{
    if (nIndex == GWL_WNDPROC) 
    {

        LOGN( eDbgLevelError, "Hooked window proc via SetWindowLongA. Pre-hook: 0x%X. ", dwNewLong);

        LONG tmp = (LONG) HookCallback((PVOID)dwNewLong, WindowProcHook);
        if( NULL != tmp) {
            dwNewLong = tmp;
        }

        DPFN( eDbgLevelInfo, "Post-hook: 0x%X.", dwNewLong);

    } 
    else if (nIndex == DWL_DLGPROC) 
    {

        LOGN( eDbgLevelError, "Hooked dialog proc via SetWindowLongA. Pre-hook: 0x%X. ", dwNewLong);

        LONG tmp = (LONG) HookCallback((PVOID)dwNewLong, DialogProcHook);
        if( NULL != tmp) {
            dwNewLong = tmp;
        }

        DPFN( eDbgLevelInfo, "Post-hook: 0x%X.", dwNewLong);
    }

    return ORIGINAL_API(SetWindowLongA)(  
        hWnd,
        nIndex,
        dwNewLong );
}

LONG 
APIHOOK(SetWindowLongW)(
    HWND hWnd,
    int nIndex,           
    LONG dwNewLong    
    )
{
    if (nIndex == GWL_WNDPROC) 
    {
        LOGN( eDbgLevelError, "Hooked window proc via SetWindowLongW. Pre-hook: 0x%X. ", dwNewLong);

        LONG tmp = (LONG) HookCallback((PVOID)dwNewLong, WindowProcHook);
        if( NULL != tmp) {
            dwNewLong = tmp;
        }

        DPFN( eDbgLevelInfo, "Post-hook: 0x%X.", dwNewLong);
    } 
    else if (nIndex == DWL_DLGPROC) 
    {
        LOGN( eDbgLevelError, "Hooked dialog proc via SetWindowLongW. Pre-hook: 0x%X. ", dwNewLong);

        LONG tmp = (LONG) HookCallback((PVOID)dwNewLong, DialogProcHook);
        if( NULL != tmp) {
            dwNewLong = tmp;
        }

        DPFN( eDbgLevelInfo, "Post-hook: 0x%X.", dwNewLong);
    }

    return ORIGINAL_API(SetWindowLongW)(  
        hWnd,
        nIndex,
        dwNewLong );
}

/*++

 Register hooked functions

--*/

HOOK_BEGIN
    APIHOOK_ENTRY(USER32.DLL, RegisterClassA)
    APIHOOK_ENTRY(USER32.DLL, RegisterClassW);
    APIHOOK_ENTRY(USER32.DLL, RegisterClassExA);
    APIHOOK_ENTRY(USER32.DLL, RegisterClassExW);
    APIHOOK_ENTRY(USER32.DLL, CreateDialogParamA);
    APIHOOK_ENTRY(USER32.DLL, CreateDialogParamW);
    APIHOOK_ENTRY(USER32.DLL, CreateDialogIndirectParamA);
    APIHOOK_ENTRY(USER32.DLL, CreateDialogIndirectParamW);
    APIHOOK_ENTRY(USER32.DLL, CreateDialogIndirectParamAorW);
    APIHOOK_ENTRY(USER32.DLL, SetWindowLongA);
    APIHOOK_ENTRY(USER32.DLL, SetWindowLongW);

HOOK_END


IMPLEMENT_SHIM_END

