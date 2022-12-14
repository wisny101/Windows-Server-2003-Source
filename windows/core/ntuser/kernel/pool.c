/**************************** Module Header ********************************\
* Module Name: pool.c
*
* Copyright (c) 1985 - 1999, Microsoft Corporation
*
* Pool reallocation routines
*
* History:
* 03-04-95 JimA       Created.
\***************************************************************************/

#include "precomp.h"
#pragma hdrstop

DWORD gdwPoolFlags;
DWORD gSessionPoolMask;

#ifdef POOL_INSTR

    /*
     * Globals used by RecordStackTrace
     */

    PVOID     gRecordedStackTrace[RECORD_STACK_TRACE_SIZE];
    PEPROCESS gpepRecorded;
    PETHREAD  gpetRecorded;


    DWORD gdwAllocFailIndex;        // the index of the allocation that's
                                    // going to fail

    DWORD gdwAllocsToFail = 1;      // how many allocs to fail

    DWORD gdwFreeRecords;

    /*
     * Targeted tag failures
     */
    LPDWORD gparrTagsToFail;
    SIZE_T  gdwTagsToFailCount;

    /*
     * Support to keep records of failed pool allocations
     */
    DWORD gdwFailRecords;
    DWORD gdwFailRecordCrtIndex;
    DWORD gdwFailRecordTotalFailures;

    PPOOLRECORD gparrFailRecord;

    /*
     * Support to keep records of pool free
     */
    DWORD gdwFreeRecords;
    DWORD gdwFreeRecordCrtIndex;
    DWORD gdwFreeRecordTotalFrees;

    PPOOLRECORD gparrFreeRecord;

    FAST_MUTEX* gpAllocFastMutex;   // mutex to syncronize pool allocations

    Win32AllocStats gAllocList;

    CONST char gszTailAlloc[] = "Win32kAlloc";

#define USESESSION(dwFlags) (((dwFlags & DAP_NONSESSION) != 0) ? 0 : gSessionPoolMask)

#endif

/***************************************************************************\
* Win32QueryPoolSize
*
* Returns the size of the given pool block.
*
* 08-17-2001    JasonSch        Created.
\***************************************************************************/
SIZE_T Win32QueryPoolSize(
    PVOID p)
{
    /*
     * If POOL_HEAVY_ALLOCS is not defined then the pointer is what
     * we allocated.
     */
    if (!(gdwPoolFlags & POOL_HEAVY_ALLOCS)) {
        BOOLEAN notUsed;
        return ExQueryPoolBlockSize(p, &notUsed);
    } else {
        PWin32PoolHead ph;

        ph = (PWin32PoolHead)((DWORD*)p - (sizeof(Win32PoolHead) / sizeof(DWORD)));
        return ph->size;
    }
}

PVOID Win32AllocPoolWithTagZInit(SIZE_T uBytes, ULONG uTag)
{
    PVOID   pv;

    pv = Win32AllocPool(uBytes, uTag);
    if (pv) {
        RtlZeroMemory(pv, uBytes);
    }

    return pv;
}

PVOID Win32AllocPoolWithTagZInitWithPriority(SIZE_T uBytes, ULONG uTag, EX_POOL_PRIORITY priority)
{
    PVOID   pv;

    pv = Win32AllocPoolWithPriority(uBytes, uTag, priority);
    if (pv) {
        RtlZeroMemory(pv, uBytes);
    }

    return pv;
}

PVOID Win32AllocPoolWithQuotaTagZInit(SIZE_T uBytes, ULONG uTag)
{
    PVOID   pv;

    pv = Win32AllocPoolWithQuota(uBytes, uTag);
    if (pv) {
        RtlZeroMemory(pv, uBytes);
    }

    return pv;
}

PVOID UserReAllocPoolWithTag(
    PVOID pSrc,
    SIZE_T uBytesSrc,
    SIZE_T uBytes,
    ULONG iTag)
{
    PVOID pDest;

    pDest = UserAllocPool(uBytes, iTag);
    if (pDest != NULL) {

        /*
         * If the block is shrinking, don't copy too many bytes.
         */
        if (uBytesSrc > uBytes) {
            uBytesSrc = uBytes;
        }

        RtlCopyMemory(pDest, pSrc, uBytesSrc);

        UserFreePool(pSrc);
    }

    return pDest;
}

PVOID UserReAllocPoolWithQuotaTag(
    PVOID pSrc,
    SIZE_T uBytesSrc,
    SIZE_T uBytes,
    ULONG iTag)
{
    PVOID pDest;

    pDest = UserAllocPoolWithQuota(uBytes, iTag);
    if (pDest != NULL) {

        /*
         * If the block is shrinking, don't copy too many bytes.
         */
        if (uBytesSrc > uBytes)
            uBytesSrc = uBytes;

        RtlCopyMemory(pDest, pSrc, uBytesSrc);

        UserFreePool(pSrc);
    }

    return pDest;
}

/*
 * Allocation routines for rtl functions
 */

PVOID UserRtlAllocMem(
    SIZE_T uBytes)
{
    return UserAllocPool(uBytes, TAG_RTL);
}

VOID UserRtlFreeMem(
    PVOID pMem)
{
    UserFreePool(pMem);
}

#ifdef POOL_INSTR

VOID RecordStackTrace(
    VOID)
{
    RtlZeroMemory(gRecordedStackTrace, RECORD_STACK_TRACE_SIZE * sizeof(PVOID));

    RtlWalkFrameChain(gRecordedStackTrace, RECORD_STACK_TRACE_SIZE, 0);

    gpepRecorded = PsGetCurrentProcess();
    gpetRecorded = PsGetCurrentThread();
}

/***************************************************************************\
* RecordFailAllocation
*
* Records failed allocations
*
* 3-22-99 CLupu      Created.
\***************************************************************************/
VOID RecordFailAllocation(
    ULONG  tag,
    SIZE_T size)
{
    UserAssert(gdwPoolFlags & POOL_KEEP_FAIL_RECORD);

    gparrFailRecord[gdwFailRecordCrtIndex].ExtraData = LongToPtr( tag );
    gparrFailRecord[gdwFailRecordCrtIndex].size = size;

    gdwFailRecordTotalFailures++;

    RtlZeroMemory(gparrFailRecord[gdwFailRecordCrtIndex].trace,
                  RECORD_STACK_TRACE_SIZE * sizeof(PVOID));

    RtlWalkFrameChain(gparrFailRecord[gdwFailRecordCrtIndex].trace,
                      RECORD_STACK_TRACE_SIZE,
                      0);

    gdwFailRecordCrtIndex++;

    if (gdwFailRecordCrtIndex >= gdwFailRecords) {
        gdwFailRecordCrtIndex = 0;
    }
}

/***************************************************************************\
* RecordFreePool
*
* Records free pool
*
* 3-22-99 CLupu      Created.
\***************************************************************************/
VOID RecordFreePool(
    PVOID  p,
    SIZE_T size)
{
    UserAssert(gdwPoolFlags & POOL_KEEP_FREE_RECORD);

    gparrFreeRecord[gdwFreeRecordCrtIndex].ExtraData = p;
    gparrFreeRecord[gdwFreeRecordCrtIndex].size = size;

    gdwFreeRecordTotalFrees++;

    RtlZeroMemory(gparrFreeRecord[gdwFreeRecordCrtIndex].trace,
                  RECORD_STACK_TRACE_SIZE * sizeof(PVOID));

    RtlWalkFrameChain(gparrFreeRecord[gdwFreeRecordCrtIndex].trace,
                      RECORD_STACK_TRACE_SIZE,
                      0);

    gdwFreeRecordCrtIndex++;

    if (gdwFreeRecordCrtIndex >= gdwFreeRecords) {
        gdwFreeRecordCrtIndex = 0;
    }
}

/***************************************************************************\
* HeavyAllocPool
*
* This will make UserAllocPool to fail if we do not provide enough memory
* for the specified tag.
*
* 12-02-96 CLupu      Created.
\***************************************************************************/
PVOID HeavyAllocPool(
    SIZE_T           uBytes,
    ULONG            tag,
    DWORD            dwFlags,
    EX_POOL_PRIORITY priority)
{
    PDWORD p;
    PWin32PoolHead ph;
    POOL_TYPE poolType;

    if (!(gdwPoolFlags & POOL_HEAVY_ALLOCS)) {
        if (dwFlags & DAP_USEQUOTA) {
            poolType = ((dwFlags & DAP_NONPAGEDPOOL) ? USESESSION(dwFlags) | NonPagedPool | POOL_QUOTA_FAIL_INSTEAD_OF_RAISE
                       : gSessionPoolMask | PagedPool | POOL_QUOTA_FAIL_INSTEAD_OF_RAISE);

            p = ExAllocatePoolWithQuotaTag(poolType, uBytes, tag);
        } else {
            poolType = ((dwFlags & DAP_NONPAGEDPOOL) ? USESESSION(dwFlags) | NonPagedPool
                       : gSessionPoolMask | PagedPool);

            if (dwFlags & DAP_PRIORITY) {
                p = ExAllocatePoolWithTagPriority(poolType, uBytes, tag, priority);
            } else {
                p = ExAllocatePoolWithTag(poolType, uBytes, tag);
            }

        }

        if (p != NULL && (dwFlags & DAP_ZEROINIT)) {
            RtlZeroMemory(p, uBytes);
        }

        return p;
    }

    /*
     * Check for overflow.
     */
    if (uBytes >= MAXULONG - sizeof(Win32PoolHead) - sizeof(gszTailAlloc)) {
        if (gdwPoolFlags & POOL_KEEP_FAIL_RECORD) {
            RecordFailAllocation(tag, 0);
        }

        return NULL;
    }

    /*
     * Acquire the mutex when we play with the list of allocations.
     */
    KeEnterCriticalRegion();
    ExAcquireFastMutexUnsafe(gpAllocFastMutex);

#ifdef POOL_INSTR_API
    /*
     * Fail the allocation if the flag is set. Don't fail allocations that
     * will certainly get us to bugcheck in DBG (i.e. GLOBALTHREADLOCK).
     */
    if (gdwPoolFlags & POOL_FAIL_ALLOCS
#if DBG
        && (tag != TAG_GLOBALTHREADLOCK)
#endif
        ) {


        SIZE_T dwInd;

        for (dwInd = 0; dwInd < gdwTagsToFailCount; dwInd++) {
            if (tag == gparrTagsToFail[dwInd]) {
                break;
            }
        }

        if (dwInd < gdwTagsToFailCount) {
            if (gdwPoolFlags & POOL_KEEP_FAIL_RECORD) {
                RecordFailAllocation(tag, uBytes);
            }

            RIPMSG0(RIP_WARNING,
                    "Pool allocation failed because of global restriction");
            p = NULL;
            goto exit;
        }
    }
#endif

#if DBG
    if ((gdwPoolFlags & POOL_FAIL_BY_INDEX) && (tag != TAG_GLOBALTHREADLOCK)) {
        /*
         * Count the calls to HeavyAllocPool.
         */
        gdwAllocCrt++;

        if (gdwAllocCrt >= gdwAllocFailIndex &&
            gdwAllocCrt < gdwAllocFailIndex + gdwAllocsToFail) {

            RecordStackTrace();

            KdPrint(("\n--------------------------------------------------\n"));
            KdPrint((
                    "\nPool allocation %d failed because of registry settings",
                    gdwAllocCrt));
            KdPrint(("\n--------------------------------------------------\n\n"));

            if (gdwPoolFlags & POOL_KEEP_FAIL_RECORD) {
                RecordFailAllocation(tag, uBytes);
            }
            p = NULL;
            goto exit;
        }
    }
#endif

    /*
     * Reserve space for the header
     */
    uBytes += sizeof(Win32PoolHead);

    if (gdwPoolFlags & POOL_TAIL_CHECK) {
        uBytes += sizeof(gszTailAlloc);
    }

    if (dwFlags & DAP_USEQUOTA) {
        poolType = ((dwFlags & DAP_NONPAGEDPOOL) ? USESESSION(dwFlags) | NonPagedPool | POOL_QUOTA_FAIL_INSTEAD_OF_RAISE
                   : gSessionPoolMask | PagedPool | POOL_QUOTA_FAIL_INSTEAD_OF_RAISE);

        p = ExAllocatePoolWithQuotaTag(poolType, uBytes, tag);
    } else {
        poolType = ((dwFlags & DAP_NONPAGEDPOOL) ? USESESSION(dwFlags)| NonPagedPool
                   : gSessionPoolMask | PagedPool);

        if (dwFlags & DAP_PRIORITY) {
            p = ExAllocatePoolWithTagPriority(poolType, uBytes, tag, priority);
        } else {
            p = ExAllocatePoolWithTag(poolType, uBytes, tag);
        }
    }

    /*
     * Return if ExAllocate... failed.
     */
    if (p == NULL) {
        if (gdwPoolFlags & POOL_KEEP_FAIL_RECORD) {
            uBytes -= sizeof(Win32PoolHead);

            if (gdwPoolFlags & POOL_TAIL_CHECK) {
                uBytes -= sizeof(gszTailAlloc);
            }

            RecordFailAllocation(tag, uBytes);
        }

        goto exit;
    }

    if (gdwPoolFlags & POOL_TAIL_CHECK) {
        uBytes -= sizeof(gszTailAlloc);

        RtlCopyMemory(((BYTE*)p) + uBytes, gszTailAlloc, sizeof(gszTailAlloc));
    }

    uBytes -= sizeof(Win32PoolHead);

    /*
     * Get the pointer to the header.
     */
    ph = (PWin32PoolHead)p;

    p += (sizeof(Win32PoolHead) / sizeof(DWORD));

    /*
     * Update the global allocations info.
     */
    gAllocList.dwCrtMem += uBytes;

    if (gAllocList.dwMaxMem < gAllocList.dwCrtMem) {
        gAllocList.dwMaxMem = gAllocList.dwCrtMem;
    }

    (gAllocList.dwCrtAlloc)++;

    if (gAllocList.dwMaxAlloc < gAllocList.dwCrtAlloc) {
        gAllocList.dwMaxAlloc = gAllocList.dwCrtAlloc;
    }

    /*
     * Grab the stack traces if the flags say so
     */
    if (gdwPoolFlags & POOL_CAPTURE_STACK) {
        ph->pTrace = ExAllocatePoolWithTag(gSessionPoolMask | PagedPool,
                                           POOL_ALLOC_TRACE_SIZE * sizeof(PVOID),
                                           TAG_STACK);

        if (ph->pTrace != NULL) {
            RtlZeroMemory(ph->pTrace, POOL_ALLOC_TRACE_SIZE * sizeof(PVOID));
            RtlWalkFrameChain(ph->pTrace, POOL_ALLOC_TRACE_SIZE, 0);
        }
    } else {
        ph->pTrace = NULL;
    }

    /*
     * Save the info in the header and return the pointer after the header.
     */
    ph->size = uBytes;

    /*
     * now, link it into the list for this tag (if any)
     */
    ph->pPrev = NULL;
    ph->pNext = gAllocList.pHead;

    if (gAllocList.pHead != NULL) {
        gAllocList.pHead->pPrev = ph;
    }

    gAllocList.pHead = ph;

    if (dwFlags & DAP_ZEROINIT) {
        RtlZeroMemory(p, uBytes);
    }

exit:
    /*
     * Release the mutex
     */
    ExReleaseFastMutexUnsafe(gpAllocFastMutex);
    KeLeaveCriticalRegion();

    return p;
}

/***************************************************************************\
* HeavyFreePool
*
* 12-02-96 CLupu      Created.
\***************************************************************************/
VOID HeavyFreePool(
    PVOID p)
{
    SIZE_T         uBytes;
    PWin32PoolHead ph;

    /*
     * If POOL_HEAVY_ALLOCS is not defined
     * then the pointer is what we allocated
     */
    if (!(gdwPoolFlags & POOL_HEAVY_ALLOCS)) {
        ExFreePool(p);
        return;
    }

    /*
     * Acquire the mutex when we play with the list of allocations
     */
    KeEnterCriticalRegion();
    ExAcquireFastMutexUnsafe(gpAllocFastMutex);

    ph = (PWin32PoolHead)((DWORD*)p - (sizeof(Win32PoolHead) / sizeof(DWORD)));

    uBytes = ph->size;

    /*
     * Check the tail
     */
    if (gdwPoolFlags & POOL_TAIL_CHECK) {
        if (!RtlEqualMemory((BYTE*)p + uBytes, gszTailAlloc, sizeof(gszTailAlloc))) {
            RIPMSG1(RIP_ERROR, "POOL CORRUPTION for %#p", p);
        }
    }

    gAllocList.dwCrtMem -= uBytes;

    UserAssert(gAllocList.dwCrtAlloc > 0);

    (gAllocList.dwCrtAlloc)--;

    /*
     * now, remove it from the linked list
     */
    if (ph->pPrev == NULL) {
        if (ph->pNext == NULL) {

            UserAssert(gAllocList.dwCrtAlloc == 0);

            gAllocList.pHead = NULL;
        } else {
            ph->pNext->pPrev = NULL;
            gAllocList.pHead = ph->pNext;
        }
    } else {
        ph->pPrev->pNext = ph->pNext;
        if (ph->pNext != NULL) {
            ph->pNext->pPrev = ph->pPrev;
        }
    }

    /*
     * Free the stack traces
     */
    if (ph->pTrace != NULL) {
        ExFreePool(ph->pTrace);
    }

    if (gdwPoolFlags & POOL_KEEP_FREE_RECORD) {
        RecordFreePool(ph, ph->size);
    }

    ExFreePool(ph);

    /*
     * Release the mutex
     */
    ExReleaseFastMutexUnsafe(gpAllocFastMutex);
    KeLeaveCriticalRegion();
}

/***************************************************************************\
* CleanupPoolAllocations
*
* 12-02-96 CLupu      Created.
\***************************************************************************/
VOID CleanupPoolAllocations(
    VOID)
{
    PWin32PoolHead pHead;
    PWin32PoolHead pNext;

    if (gAllocList.dwCrtAlloc != 0) {
        if (gdwPoolFlags & POOL_BREAK_FOR_LEAKS) {
            FRE_RIPMSG0(RIP_ERROR,
                        "There is still pool memory not freed in win32k.sys.\n"
                        "Use !userkdx.dpa -vs to dump it");
        }

        pHead = gAllocList.pHead;
        while (pHead != NULL) {
            pNext = pHead->pNext;

            UserFreePool(pHead + 1);

            pHead = pNext;
        }
    }
}

/***************************************************************************\
* CleanUpPoolLimitations
*
\***************************************************************************/
VOID CleanUpPoolLimitations(
    VOID)
{
    if (gpAllocFastMutex != NULL) {
        ExFreePool(gpAllocFastMutex);
        gpAllocFastMutex = NULL;
    }

    if (gparrFailRecord != NULL) {
        ExFreePool(gparrFailRecord);
        gparrFailRecord = NULL;
    }

    if (gparrFreeRecord != NULL) {
        ExFreePool(gparrFreeRecord);
        gparrFreeRecord = NULL;
    }

    if (gparrTagsToFail != NULL) {
        ExFreePool(gparrTagsToFail);
        gparrTagsToFail = NULL;
    }
}

/***************************************************************************\
* InitPoolLimitations
*
* 12-02-96 CLupu      Created.
\***************************************************************************/
NTSTATUS InitPoolLimitations(
    VOID)
{
    UNICODE_STRING      UnicodeString;
    OBJECT_ATTRIBUTES   ObjectAttributes;
    HANDLE              hkey;
    NTSTATUS            Status;
    WCHAR               achKeyValue[512];
    DWORD               dwData;
    ULONG               ucb;

    /*
     * Initialize a critical section structure that will be used to protect
     * all the HeavyAllocPool and HeavyFreePool calls.
     */
    gpAllocFastMutex = ExAllocatePoolWithTag(NonPagedPool,
                                             sizeof(FAST_MUTEX),
                                             TAG_DEBUG);
    if (gpAllocFastMutex == NULL) {
        RIPMSG0(RIP_WARNING, "InitPoolLimitations failed to allocate mutex");
        return STATUS_NO_MEMORY;
    }

    ExInitializeFastMutex(gpAllocFastMutex);

    /*
     * Allocate from session pool only for Full TS, that is Terminal Server
     * in app server mode. For normal Server (Remote Administration) or
     * workstation don't limit to session pool.
     */
    if ((SharedUserData->SuiteMask & VER_SUITE_TERMINAL) &&
        !(SharedUserData->SuiteMask & VER_SUITE_SINGLEUSERTS)) {
        gSessionPoolMask = SESSION_POOL_MASK;

        if (gbRemoteSession) {
            gdwPoolFlags |= POOL_HEAVY_ALLOCS;
        }
    } else {
        gSessionPoolMask = 0;
    }

#if DBG
    gdwPoolFlags |= (POOL_HEAVY_ALLOCS | POOL_CAPTURE_STACK | POOL_BREAK_FOR_LEAKS);
#endif


    /*
     * Open the key containing the limits.
     */
    RtlInitUnicodeString(
            &UnicodeString,
            L"\\Registry\\Machine\\System\\CurrentControlSet\\Control\\Session Manager\\SubSystems\\Pool");

    InitializeObjectAttributes(
            &ObjectAttributes, &UnicodeString, OBJ_CASE_INSENSITIVE, NULL, NULL);

    Status = ZwOpenKey(&hkey, KEY_READ, &ObjectAttributes);
    if (!NT_SUCCESS(Status)) {

#if DBG
        /*
         * More default settings if the Pool key doesn't exist
         */
        if (gbRemoteSession) {

            gparrFailRecord = ExAllocatePoolWithTag(PagedPool,
                                                    32 * sizeof(POOLRECORD),
                                                    TAG_DEBUG);

            if (gparrFailRecord != NULL) {
                gdwFailRecords = 32;
                gdwPoolFlags |= POOL_KEEP_FAIL_RECORD;
            }

            gparrFreeRecord = ExAllocatePoolWithTag(PagedPool,
                                                    32 * sizeof(POOLRECORD),
                                                    TAG_DEBUG);

            if (gparrFreeRecord != NULL) {
                gdwFreeRecords = 32;
                gdwPoolFlags |= POOL_KEEP_FREE_RECORD;
            }
        }
#endif

        return STATUS_SUCCESS;
    }

    if (gbRemoteSession) {
        /*
         * Break in the debugger for memory leaks?
         */
        RtlInitUnicodeString(&UnicodeString, L"BreakForPoolLeaks");

        Status = ZwQueryValueKey(
                hkey,
                &UnicodeString,
                KeyValuePartialInformation,
                achKeyValue,
                sizeof(achKeyValue),
                &ucb);

        if (NT_SUCCESS(Status) &&
                ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

            dwData = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);

            if (dwData != 0) {
                gdwPoolFlags |= POOL_BREAK_FOR_LEAKS;
            } else {
                gdwPoolFlags &= ~POOL_BREAK_FOR_LEAKS;
            }
        }

        /*
         * Heavy allocs/frees for remote sessions ?
         */
        RtlInitUnicodeString(&UnicodeString, L"HeavyRemoteSession");

        Status = ZwQueryValueKey(
                hkey,
                &UnicodeString,
                KeyValuePartialInformation,
                achKeyValue,
                sizeof(achKeyValue),
                &ucb);

        if (NT_SUCCESS(Status) &&
                ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

            dwData = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);

            if (dwData == 0) {
                gdwPoolFlags &= ~POOL_HEAVY_ALLOCS;
            }
        }
    } else {

        /*
         * Heavy allocs/frees for main session ?
         */
        RtlInitUnicodeString(&UnicodeString, L"HeavyConsoleSession");

        Status = ZwQueryValueKey(
                hkey,
                &UnicodeString,
                KeyValuePartialInformation,
                achKeyValue,
                sizeof(achKeyValue),
                &ucb);

        if (NT_SUCCESS(Status) &&
                ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

            dwData = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);

            if (dwData != 0) {
                gdwPoolFlags |= POOL_HEAVY_ALLOCS;
            }
        }
    }

    if (!(gdwPoolFlags & POOL_HEAVY_ALLOCS)) {
        ZwClose(hkey);
        return STATUS_SUCCESS;
    }

    /*
     * Check for stack traces
     */
    RtlInitUnicodeString(&UnicodeString, L"StackTraces");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        dwData = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);

        if (dwData == 0) {
            gdwPoolFlags &= ~POOL_CAPTURE_STACK;
        } else {
            gdwPoolFlags |= POOL_CAPTURE_STACK;
        }
    }

    /*
     * Use tail checks ?
     */
    RtlInitUnicodeString(&UnicodeString, L"UseTailString");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        dwData = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);

        if (dwData != 0) {
            gdwPoolFlags |= POOL_TAIL_CHECK;
        }
    }

    /*
     * Keep a record of frees ? By default keep the last 32.
     */
#if DBG
    gdwFreeRecords = 32;
#endif

    RtlInitUnicodeString(&UnicodeString, L"KeepFreeRecords");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        gdwFreeRecords = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);
    }

    if (gdwFreeRecords != 0) {

        gparrFreeRecord = ExAllocatePoolWithTag(PagedPool,
                                                gdwFreeRecords * sizeof(POOLRECORD),
                                                TAG_DEBUG);

        if (gparrFreeRecord != NULL) {
            gdwPoolFlags |= POOL_KEEP_FREE_RECORD;
        }
    }

    /*
     * Keep a record of failed allocations ? By default keep the last 32.
     */
#if DBG
    gdwFailRecords = 32;
#endif

    RtlInitUnicodeString(&UnicodeString, L"KeepFailRecords");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        gdwFailRecords = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);
    }

    if (gdwFailRecords != 0) {

        gparrFailRecord = ExAllocatePoolWithTag(PagedPool,
                                                gdwFailRecords * sizeof(POOLRECORD),
                                                TAG_DEBUG);

        if (gparrFailRecord != NULL) {
            gdwPoolFlags |= POOL_KEEP_FAIL_RECORD;
        }
    }

#if DBG
    /*
     * Open the key containing the allocation that should fail.
     */
    RtlInitUnicodeString(&UnicodeString, L"AllocationIndex");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        gdwAllocFailIndex = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);
    }


    RtlInitUnicodeString(&UnicodeString, L"AllocationsToFail");

    Status = ZwQueryValueKey(
            hkey,
            &UnicodeString,
            KeyValuePartialInformation,
            achKeyValue,
            sizeof(achKeyValue),
            &ucb);

    if (NT_SUCCESS(Status) &&
            ((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Type == REG_DWORD) {

        gdwAllocsToFail = *((PDWORD)((PKEY_VALUE_PARTIAL_INFORMATION)achKeyValue)->Data);
    }

    if (gdwAllocFailIndex != 0 && gdwAllocsToFail > 0) {
        gdwPoolFlags |= POOL_FAIL_BY_INDEX;
    }
#endif

    ZwClose(hkey);

    return STATUS_SUCCESS;
}
#endif

#ifdef POOL_INSTR_API
BOOL _Win32PoolAllocationStats(
    LPDWORD parrTags,
    SIZE_T tagsCount,
    SIZE_T* lpdwMaxMem,
    SIZE_T* lpdwCrtMem,
    LPDWORD lpdwMaxAlloc,
    LPDWORD lpdwCrtAlloc)
{
    BOOL bRet = FALSE;

    /*
     * Do nothing if heavy allocs/frees are disabled.
     */
    if (!(gdwPoolFlags & POOL_HEAVY_ALLOCS)) {
        return FALSE;
    }

    *lpdwMaxMem   = gAllocList.dwMaxMem;
    *lpdwCrtMem   = gAllocList.dwCrtMem;
    *lpdwMaxAlloc = gAllocList.dwMaxAlloc;
    *lpdwCrtAlloc = gAllocList.dwCrtAlloc;

    /*
     * Acquire the mutex when we play with the list of allocations.
     */
    KeEnterCriticalRegion();
    ExAcquireFastMutexUnsafe(gpAllocFastMutex);

    if (gparrTagsToFail != NULL) {
        ExFreePool(gparrTagsToFail);
        gparrTagsToFail = NULL;
        gdwTagsToFailCount = 0;
    }

    if (tagsCount != 0) {
        gdwPoolFlags |= POOL_FAIL_ALLOCS;

        if (tagsCount > MAX_TAGS_TO_FAIL) {
            gdwTagsToFailCount = 0xFFFFFFFF;
            RIPMSG0(RIP_WARNING, "All pool allocations in WIN32K.SYS will fail.");
            bRet = TRUE;
            goto exit;
        }
    } else {
        gdwPoolFlags &= ~POOL_FAIL_ALLOCS;

        RIPMSG0(RIP_WARNING, "Pool allocations in WIN32K.SYS back to normal.");
        bRet = TRUE;
        goto exit;
    }

    gparrTagsToFail = ExAllocatePoolWithTag(PagedPool,
                                            sizeof(DWORD) * tagsCount,
                                            TAG_DEBUG);

    if (gparrTagsToFail == NULL) {
        gdwPoolFlags &= ~POOL_FAIL_ALLOCS;
        RIPMSG0(RIP_WARNING, "Pool allocations in WIN32K.SYS back to normal !");
        goto exit;
    }

    try {
        ProbeForRead(parrTags, sizeof(DWORD) * tagsCount, DATAALIGN);
        RtlCopyMemory(gparrTagsToFail, parrTags, sizeof(DWORD) * tagsCount);
    } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
          if (gparrTagsToFail != NULL) {
              ExFreePool(gparrTagsToFail);
              gparrTagsToFail = NULL;

              gdwPoolFlags &= ~POOL_FAIL_ALLOCS;
              RIPMSG0(RIP_WARNING, "Pool allocations in WIN32K.SYS back to normal.");
              goto exit;
          }
    }
    gdwTagsToFailCount = tagsCount;

    RIPMSG0(RIP_WARNING, "Specific pool allocations in WIN32K.SYS will fail.");

exit:
    /*
     * Release the mutex
     */
    ExReleaseFastMutexUnsafe(gpAllocFastMutex);
    KeLeaveCriticalRegion();

    return bRet;
}

#endif

#ifdef TRACE_MAP_VIEWS

FAST_MUTEX*   gpSectionFastMutex;
PWin32Section gpSections;

#define EnterSectionCrit()                          \
    KeEnterCriticalRegion();                        \
    ExAcquireFastMutexUnsafe(gpSectionFastMutex);

#define LeaveSectionCrit()                          \
    ExReleaseFastMutexUnsafe(gpSectionFastMutex);   \
    KeLeaveCriticalRegion();


/***************************************************************************\
* CleanUpSections
*
\***************************************************************************/
VOID CleanUpSections(
    VOID)
{
    if (gpSectionFastMutex) {
        ExFreePool(gpSectionFastMutex);
        gpSectionFastMutex = NULL;
    }
}

NTSTATUS InitSectionTrace(
    VOID)
{
    gpSectionFastMutex = ExAllocatePoolWithTag(NonPagedPool,
                                               sizeof(FAST_MUTEX),
                                               TAG_DEBUG);

    if (gpSectionFastMutex == NULL) {
        RIPMSG0(RIP_WARNING, "InitSectionTrace failed to allocate mutex");
        return STATUS_NO_MEMORY;
    }

    ExInitializeFastMutex(gpSectionFastMutex);

    return STATUS_SUCCESS;
}

NTSTATUS _Win32CreateSection(
    PVOID*              pSectionObject,
    ACCESS_MASK         DesiredAccess,
    POBJECT_ATTRIBUTES  ObjectAttributes,
    PLARGE_INTEGER      pInputMaximumSize,
    ULONG               SectionPageProtection,
    ULONG               AllocationAttributes,
    HANDLE              FileHandle,
    PFILE_OBJECT        FileObject,
    DWORD               SectionTag)
{
    PWin32Section pSection;
    NTSTATUS      Status;

    Status = MmCreateSection(
                    pSectionObject,
                    DesiredAccess,
                    ObjectAttributes,
                    pInputMaximumSize,
                    SectionPageProtection,
                    AllocationAttributes,
                    FileHandle,
                    FileObject);

    if (NT_SUCCESS(Status)) {
        ObDeleteCapturedInsertInfo(*pSectionObject);
    } else {
        RIPMSG1(RIP_WARNING, "MmCreateSection failed with Status 0x%x.", Status);
        *pSectionObject = NULL;
        return Status;
    }

    pSection = UserAllocPoolZInit(sizeof(Win32Section), TAG_SECTION);

    if (pSection == NULL) {
        ObDereferenceObject(*pSectionObject);
        RIPMSG0(RIP_WARNING, "Failed to allocate memory for section.");
        *pSectionObject = NULL;
        return STATUS_UNSUCCESSFUL;
    }

    EnterSectionCrit();

    pSection->pNext = gpSections;
    if (gpSections != NULL) {
        UserAssert(gpSections->pPrev == NULL);
        gpSections->pPrev = pSection;
    }

    pSection->SectionObject = *pSectionObject;
    pSection->SectionSize   = *pInputMaximumSize;
    pSection->SectionTag    = SectionTag;

    gpSections = pSection;

#ifdef MAP_VIEW_STACK_TRACE
    RtlZeroMemory(pSection->trace, MAP_VIEW_STACK_TRACE_SIZE * sizeof(PVOID));

    RtlWalkFrameChain(pSection->trace, MAP_VIEW_STACK_TRACE_SIZE, 0);

#endif

    LeaveSectionCrit();

    return STATUS_SUCCESS;
}

NTSTATUS _ZwWin32CreateSection(
    PVOID*              pSectionObject,
    ACCESS_MASK         DesiredAccess,
    POBJECT_ATTRIBUTES  ObjectAttributes,
    PLARGE_INTEGER      pInputMaximumSize,
    ULONG               SectionPageProtection,
    ULONG               AllocationAttributes,
    HANDLE              FileHandle,
    PFILE_OBJECT        FileObject,
    DWORD               SectionTag)
{
    PWin32Section pSection;
    NTSTATUS      Status;
    HANDLE        SectionHandle;

    UNREFERENCED_PARAMETER(FileObject);

    Status = ZwCreateSection(
                    &SectionHandle,
                    DesiredAccess,
                    ObjectAttributes,
                    pInputMaximumSize,
                    SectionPageProtection,
                    AllocationAttributes,
                    FileHandle);

    if (!NT_SUCCESS(Status)) {
        RIPMSG1(RIP_WARNING, "ZwCreateSection failed with Statu %x", Status);
        *pSectionObject = NULL;
        return Status;
    }

    Status = ObReferenceObjectByHandle(
                    SectionHandle,
                    DesiredAccess,
                    *(POBJECT_TYPE *)MmSectionObjectType,
                    KernelMode,
                    pSectionObject,
                    NULL);

    ZwClose(SectionHandle);

    if (!NT_SUCCESS(Status)) {
        RIPMSG1(RIP_WARNING,
                "ObReferenceObjectByHandle failed with Status 0x%x",
                Status);
        *pSectionObject = NULL;
        return Status;
    }

    pSection = UserAllocPoolZInit(sizeof(Win32Section), TAG_SECTION);
    if (pSection == NULL) {
        ObDereferenceObject(*pSectionObject);
        RIPMSG0(RIP_WARNING, "Failed to allocate memory for section");
        *pSectionObject = NULL;
        return STATUS_UNSUCCESSFUL;
    }

    EnterSectionCrit();

    pSection->pNext = gpSections;
    if (gpSections != NULL) {
        UserAssert(gpSections->pPrev == NULL);
        gpSections->pPrev = pSection;
    }

    pSection->SectionObject = *pSectionObject;
    pSection->SectionSize   = *pInputMaximumSize;
    pSection->SectionTag    = SectionTag;

    gpSections = pSection;

#ifdef MAP_VIEW_STACK_TRACE
    RtlZeroMemory(pSection->trace, MAP_VIEW_STACK_TRACE_SIZE * sizeof(PVOID));

    RtlWalkFrameChain(pSection->trace, MAP_VIEW_STACK_TRACE_SIZE, 0);

#endif

    LeaveSectionCrit();

    return STATUS_SUCCESS;
}

VOID _Win32DestroySection(
    PVOID Section)
{
    PWin32Section ps;

    EnterSectionCrit();

    ps = gpSections;

    while (ps != NULL) {
        if (ps->SectionObject == Section) {

            /*
             * Make sure there is no view mapped for this section
             */
            if (ps->pFirstView != NULL) {
                RIPMSG1(RIP_ERROR, "Section %#p still has views", ps);
            }

            /*
             * now, remove it from the linked list of this tag
             */
            if (ps->pPrev == NULL) {

                UserAssert(ps == gpSections);

                gpSections = ps->pNext;

                if (ps->pNext != NULL) {
                    ps->pNext->pPrev = NULL;
                }
            } else {
                ps->pPrev->pNext = ps->pNext;
                if (ps->pNext != NULL) {
                    ps->pNext->pPrev = ps->pPrev;
                }
            }
            ObDereferenceObject(Section);
            UserFreePool(ps);
            LeaveSectionCrit();
            return;
        }
        ps = ps->pNext;
    }

    RIPMSG1(RIP_ERROR, "Cannot find Section %#p", Section);
    LeaveSectionCrit();
}

NTSTATUS _Win32MapViewInSessionSpace(
    PVOID   Section,
    PVOID*  pMappedBase,
    PSIZE_T pViewSize)
{
    NTSTATUS      Status;
    PWin32Section ps;
    PWin32MapView pMapView;

    /*
     * First try to map the view
     */
    Status = MmMapViewInSessionSpace(Section, pMappedBase, pViewSize);

    if (!NT_SUCCESS(Status)) {
        RIPMSG1(RIP_WARNING, "MmMapViewInSessionSpace failed with Status %x",
                Status);
        *pMappedBase = NULL;
        return Status;
    }

    /*
     * Now add a record for this view
     */
    pMapView = UserAllocPoolZInit(sizeof(Win32MapView), TAG_SECTION);

    if (pMapView == NULL) {
        RIPMSG0(RIP_WARNING, "_Win32MapViewInSessionSpace: Memory failure");

        MmUnmapViewInSessionSpace(*pMappedBase);
        *pMappedBase = NULL;
        return STATUS_NO_MEMORY;
    }

    pMapView->pViewBase = *pMappedBase;
    pMapView->ViewSize  = *pViewSize;

    EnterSectionCrit();

    ps = gpSections;

    while (ps != NULL) {
        if (ps->SectionObject == Section) {

            pMapView->pSection = ps;

            pMapView->pNext = ps->pFirstView;

            if (ps->pFirstView != NULL) {
                ps->pFirstView->pPrev = pMapView;
            }
            ps->pFirstView = pMapView;

#ifdef MAP_VIEW_STACK_TRACE
            RtlZeroMemory(pMapView->trace, MAP_VIEW_STACK_TRACE_SIZE * sizeof(PVOID));

            RtlWalkFrameChain(pMapView->trace, MAP_VIEW_STACK_TRACE_SIZE, 0);

#endif

            LeaveSectionCrit();
            return STATUS_SUCCESS;
        }
        ps = ps->pNext;
    }

    RIPMSG1(RIP_ERROR, "_Win32MapViewInSessionSpace: Could not find section for %#p",
            Section);

    LeaveSectionCrit();

    return STATUS_UNSUCCESSFUL;
}

NTSTATUS _Win32UnmapViewInSessionSpace(
    PVOID MappedBase)
{
    PWin32Section ps;
    PWin32MapView pv;
    NTSTATUS      Status;

    EnterSectionCrit();

    ps = gpSections;

    while (ps != NULL) {

        pv = ps->pFirstView;

        while (pv != NULL) {

            UserAssert(pv->pSection == ps);

            if (pv->pViewBase == MappedBase) {
                /*
                 * now, remove it from the linked list
                 */
                if (pv->pPrev == NULL) {

                    UserAssert(pv == ps->pFirstView);

                    ps->pFirstView = pv->pNext;

                    if (pv->pNext != NULL) {
                        pv->pNext->pPrev = NULL;
                    }
                } else {
                    pv->pPrev->pNext = pv->pNext;
                    if (pv->pNext != NULL) {
                        pv->pNext->pPrev = pv->pPrev;
                    }
                }

                UserFreePool(pv);

                Status = MmUnmapViewInSessionSpace(MappedBase);

                LeaveSectionCrit();

                return Status;
            }
            pv = pv->pNext;
        }
        ps = ps->pNext;
    }

    RIPMSG1(RIP_ERROR,
            "_Win32UnmapViewInSessionSpace: Could not find view for 0x%p",
            MappedBase);

    LeaveSectionCrit();

    return STATUS_UNSUCCESSFUL;
}
#endif
