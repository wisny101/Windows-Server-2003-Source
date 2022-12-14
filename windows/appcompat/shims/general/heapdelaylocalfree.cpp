/*++

 Copyright (c) 2000-2002 Microsoft Corporation

 Module Name:

   HeapDelayLocalFree.cpp

 Abstract:

   Delay calls to LocalFree.

 History:

   09/19/2000   robkenny
   02/12/2002   robkenny    Convert InitializeCriticalSection to InitializeCriticalSectionAndSpinCount
                            and checking return status to verify that critical section was
                            actually created.

                            Shim was deallocating memory in SHIM_PROCESS_DETACH, which can
                            cause the shim to crash when the process is exiting, since there
                            is not guarantee that the shim will not be called from other
                            libraries afterwards.


--*/

#include "precomp.h"
#include "CharVector.h"

IMPLEMENT_SHIM_BEGIN(HeapDelayLocalFree)
#include "ShimHookMacro.h"

APIHOOK_ENUM_BEGIN
    APIHOOK_ENUM_ENTRY(LocalFree)
APIHOOK_ENUM_END

CRITICAL_SECTION            g_CritSec;
static VectorT<HLOCAL>     *g_DelayLocal            = NULL;
static DWORD                g_DelayBufferSize       = 20;

HLOCAL 
APIHOOK(LocalFree)(
    HLOCAL hMem   // handle to local memory object
)
{
    if (hMem == NULL)
        return NULL;

    if (g_DelayLocal)
    {
        EnterCriticalSection(&g_CritSec);

        // If the list is full
        if (g_DelayLocal->Size() > 0 &&
            g_DelayLocal->Size() >= g_DelayLocal->MaxSize())
        {
            HLOCAL & hDelayed = g_DelayLocal->Get(0);
#if DBG
            DPFN(eDbgLevelInfo, "LocalFree(0x%08x).", hDelayed);
#endif
            ORIGINAL_API(LocalFree)(hDelayed);

            g_DelayLocal->Remove(0);
        }

        g_DelayLocal->Append(hMem);
#if DBG
        DPFN(eDbgLevelInfo, "Delaying LocalFree(0x%08x).", hMem);
#endif
       
        LeaveCriticalSection(&g_CritSec);
        
        return NULL;
    }

    HLOCAL returnValue = ORIGINAL_API(LocalFree)(hMem);
    return returnValue;
}

BOOL ParseCommandLine(const char * /*commandLine*/)
{
    // Preallocate the event, prevents EnterCriticalSection
    // from throwing an exception in low-memory situations.
    if (!InitializeCriticalSectionAndSpinCount(&g_CritSec, 0x8000000))
    {
        return FALSE;
    }

    g_DelayLocal = new VectorT<HLOCAL>;

    if (g_DelayLocal)
    {
        // If we cannot resize the array, stop now
        if (!g_DelayLocal->Resize(g_DelayBufferSize))
        {
            delete g_DelayLocal;
            g_DelayLocal = NULL;

            // Turn off all hooks:
            return FALSE;
        }
    }

    return TRUE;
}

/*++

  Register hooked functions

--*/

BOOL
NOTIFY_FUNCTION(
    DWORD fdwReason
    )
{
    if (fdwReason == DLL_PROCESS_ATTACH)
    {
        return ParseCommandLine(COMMAND_LINE);
    }

    return TRUE;
}

/*++

 Register hooked functions

--*/

HOOK_BEGIN

    CALL_NOTIFY_FUNCTION

    APIHOOK_ENTRY(KERNEL32.DLL, LocalFree)

HOOK_END


IMPLEMENT_SHIM_END

