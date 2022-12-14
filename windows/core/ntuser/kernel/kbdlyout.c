/**************************** Module Header ********************************\
* Module Name: kbdlyout.c
*
* Copyright (c) 1985 - 1999, Microsoft Corporation
*
* Keyboard Layout API
*
* History:
* 04-14-92 IanJa      Created
\***************************************************************************/

#include "precomp.h"
#pragma hdrstop

/*
 * Workers (forward declarations)
 */
BOOL xxxInternalUnloadKeyboardLayout(PWINDOWSTATION, PKL, UINT);
VOID ReorderKeyboardLayouts(PWINDOWSTATION, PKL);

/****************************************************************************\
* HKLtoPKL
*
* pti   - thread to look in
* hkl   - HKL_NEXT or HKL_PREV
*         Finds the the next/prev LOADED layout, NULL if none.
*         (Starts from the pti's active layout, may return pklActive itself)
*       - a real HKL (Keyboard Layout handle):
*         Finds the kbd layout struct (loaded or not), NULL if no match found.
*
* History:
* 1997-02-05 IanJa     added pti parameter
\****************************************************************************/
PKL HKLtoPKL(
    PTHREADINFO pti,
    HKL hkl)
{
    PKL pklActive;
    PKL pkl;

    UserAssert(pti != NULL);
    if ((pklActive = pti->spklActive) == NULL) {
        return NULL;
    }

    pkl = pklActive;

    if (hkl == (HKL)HKL_PREV) {
        do {
            pkl = pkl->pklPrev;
            if (!(pkl->dwKL_Flags & KL_UNLOADED)) {
                return pkl;
            }
        } while (pkl != pklActive);
        return NULL;
    } else if (hkl == (HKL)HKL_NEXT) {
        do {
            pkl = pkl->pklNext;
            if (!(pkl->dwKL_Flags & KL_UNLOADED)) {
                return pkl;
            }
        } while (pkl != pklActive);
        return NULL;
    }

    /*
     * Find the pkl for this hkl.
     * If the kbd layout isn't specified (in the HIWORD), ignore it and look
     * for a Locale match only.  (Mohamed Hamid's fix for Word bug)
     */
    if (HandleToUlong(hkl) & 0xffff0000) {
        do {
            if (pkl->hkl == hkl) {
                return pkl;
            }
            pkl = pkl->pklNext;
        } while (pkl != pklActive);
    } else {
        do {
            if (LOWORD(HandleToUlong(pkl->hkl)) == LOWORD(HandleToUlong(hkl))) {
                return pkl;
            }
            pkl = pkl->pklNext;
        } while (pkl != pklActive);
    }

    return NULL;
}


/***************************************************************************\
* ReadLayoutFile
*
* Maps layout file into memory and initializes layout table.
*
* History:
* 01-10-95 JimA         Created.
\***************************************************************************/

#define GET_HEADER_FIELD(x) \
    ((fWin64Header) ? (NtHeader64->x) : (NtHeader32->x))

/*
 * Note that this only works for sections < 64K
 * Implicitly assumes pBaseVirt, pBaseDst and dwDataSize.
 */

#if DBG
BOOL gfEnableChecking = TRUE;
#else
BOOL gfEnableChecking = FALSE;
#endif

#define EXIT_READ(p) \
    RIPMSGF1(RIP_WARNING, #p " is @ invalid address %p", p); \
    if (gfEnableChecking) { \
        goto exitread; \
    }

#define VALIDATE_PTR(p) \
    if ((PBYTE)(p) < (PBYTE)pBaseDst || (PBYTE)(p) + sizeof *(p) > (PBYTE)pBaseDst + dwDataSize) { \
        EXIT_READ(p); \
    }

#define FIXUP_PTR(p) \
    if (p) { \
        p = (PVOID)((PBYTE)pBaseVirt + (WORD)(ULONG_PTR)(p)); \
        VALIDATE_PTR(p); \
    } \
    TAGMSGF1(DBGTAG_KBD, #p " validation finished %p", p);

PKBDTABLES ReadLayoutFile(
    PKBDFILE pkf,
    HANDLE hFile,
    UINT offTable,
    UINT offNlsTable
    )
{
    HANDLE hmap = NULL;
    OBJECT_ATTRIBUTES ObjectAttributes;
    SIZE_T ulViewSize = 0;
    NTSTATUS Status;
    PIMAGE_DOS_HEADER DosHdr = NULL;
    BOOLEAN fWin64Header;
    PIMAGE_NT_HEADERS32 NtHeader32;
    PIMAGE_NT_HEADERS64 NtHeader64;
    PIMAGE_SECTION_HEADER SectionTableEntry;
    ULONG NumberOfSubsections;
    ULONG OffsetToSectionTable;
    PBYTE pBaseDst = NULL, pBaseVirt = NULL;
    PKBDTABLES pktNew = NULL;
    DWORD dwDataSize;
    PKBDNLSTABLES pknlstNew = NULL;
    BOOL fSucceeded = FALSE;

    TAGMSGF1(DBGTAG_KBD, "entering for '%ls'", pkf->awchDllName);

    /*
     * Mask off hiword.
     */
    UserAssert((offTable & ~0xffff) == 0);
    UserAssert((offNlsTable & ~0xffff) == 0);

    /*
     * Initialize KbdNlsTables with NULL.
     */
    pkf->pKbdNlsTbl = NULL;

    InitializeObjectAttributes(&ObjectAttributes,
                               NULL,
                               OBJ_KERNEL_HANDLE,
                               NULL,
                               NULL);

    /*
     * Map the layout file into memory
     */
    Status = ZwCreateSection(&hmap, SECTION_MAP_READ, &ObjectAttributes,
                             NULL, PAGE_READONLY, SEC_COMMIT, hFile);
    if (!NT_SUCCESS(Status)) {
        RIPMSGF3(RIP_WARNING, "failed to create a section for %ls, hFile=%p, stat=%08x", pkf->awchDllName, hFile, Status);
        goto exitread;
    }

    Status = ZwMapViewOfSection(hmap, NtCurrentProcess(), &DosHdr, 0, 0, NULL,
                                &ulViewSize, ViewUnmap, 0, PAGE_READONLY);
    if (!NT_SUCCESS(Status)) {
        RIPMSGF1(RIP_WARNING, "failed to map the view for %ls", pkf->awchDllName);
        goto exitread;
    }

    if (ulViewSize < sizeof *DosHdr || ulViewSize > (128 * 1024)) {
        RIPMSGF1(RIP_WARNING, "ViewSize is too small or large %08x", ulViewSize);
        goto exitread;
    }

    /*
     * We find the .data section in the file header and by
     * subtracting the virtual address from offTable find
     * the offset in the section of the layout table.
     */
    UserAssert(sizeof *NtHeader64 >= sizeof *NtHeader32);

    try {
        NtHeader64 = (PIMAGE_NT_HEADERS64)((PBYTE)DosHdr + (ULONG)DosHdr->e_lfanew);
        NtHeader32 = (PIMAGE_NT_HEADERS32)NtHeader64;


#if defined(_WIN64)
        if ((PBYTE)NtHeader64 < (PBYTE)DosHdr ||           // signed Overflow
                (PBYTE)NtHeader64 + sizeof *NtHeader64  >= (PBYTE)DosHdr + ulViewSize) {
            RIPMSGF1(RIP_WARNING, "Header is out of Range %p", NtHeader64);
            goto exitread;
        }

        fWin64Header = (NtHeader64->FileHeader.Machine == IMAGE_FILE_MACHINE_IA64) ||
                       (NtHeader64->FileHeader.Machine == IMAGE_FILE_MACHINE_AMD64);
#else
        if ((PBYTE)NtHeader32 < (PBYTE)DosHdr ||           // signed Overflow
                (PBYTE)NtHeader32 + sizeof *NtHeader32  >= (PBYTE)DosHdr + ulViewSize) {
            RIPMSGF1(RIP_WARNING, "Header is out of Range %p", NtHeader32);
            goto exitread;
        }

        fWin64Header = FALSE;
#endif

        TAGMSGF2(DBGTAG_KBD, "DLL='%ls', Is64=%d", pkf->awchDllName, fWin64Header);

        /*
         * At this point the object table is read in (if it was not
         * already read in) and may displace the image header.
         */
        NumberOfSubsections = GET_HEADER_FIELD(FileHeader.NumberOfSections);

        OffsetToSectionTable = sizeof(ULONG) +                   // Signature
                               sizeof(IMAGE_FILE_HEADER) +       // FileHeader
                               GET_HEADER_FIELD(FileHeader.SizeOfOptionalHeader);

        SectionTableEntry = (PIMAGE_SECTION_HEADER)((PBYTE)NtHeader32 +
                            OffsetToSectionTable);


        while (NumberOfSubsections > 0) {
            /*
             * Validate the SectionTableEntry.
             */
            if ((PBYTE)SectionTableEntry < (PBYTE)DosHdr ||
                (PBYTE)SectionTableEntry + sizeof *SectionTableEntry >= (PBYTE)DosHdr + ulViewSize) {
                RIPMSGF1(RIP_WARNING, "SectionTableEntry @ %p is not within the view section.",
                         SectionTableEntry);
                goto exitread;
            }

            /*
             * Is this the .data section that we are looking for?
             */
            if (strcmp(SectionTableEntry->Name, ".data") == 0) {
                break;
            }

            SectionTableEntry++;
            NumberOfSubsections--;
        }

        if (NumberOfSubsections == 0) {
            RIPMSGF1(RIP_WARNING, "number of sections is 0 for %ls.", pkf->awchDllName);
            goto exitread;
        }

        /*
         * We found the section, now compute starting offset and the table size.
         */
        offTable -= SectionTableEntry->VirtualAddress;
        dwDataSize = SectionTableEntry->Misc.VirtualSize;

        /*
         * Validate the offTable to see if it fits in the section.
         */
        if (offTable >= dwDataSize) {
            RIPMSGF3(RIP_WARNING, "illegal offTable=0x%x or offNlsTable=0x%x, dwDataSize=0x%x",
                     offTable, offNlsTable, dwDataSize);
            goto exitread;
        }

        /*
         * Validate the .data size not exceeding our assumption (<64KB).
         */
        if (dwDataSize >= 0xffff) {
            RIPMSGF1(RIP_WARNING, "unexpected size in .data: 0x%x", dwDataSize);
            goto exitread;
        }

        /*
         * Validate we are not over-shooting our view
         */
        if ((PBYTE)DosHdr + SectionTableEntry->PointerToRawData + dwDataSize >=
            (PBYTE)DosHdr + ulViewSize) {
            RIPMSGF1(RIP_WARNING, "Layout Table @ %p is not within the view section.",
                     (PBYTE)DosHdr + SectionTableEntry->PointerToRawData);
            goto exitread;
        }

        /*
         * Allocate layout table and copy from file.
         */
        TAGMSGF2(DBGTAG_KBD, "data size for '%S' = %x", pkf->awchDllName, dwDataSize);
        pBaseDst = UserAllocPool(dwDataSize, TAG_KBDTABLE);

#if DBG
        if (pBaseDst == NULL) {
            RIPMSGF2(RIP_WARNING, "failed to allocate 0x%x bytes of memory for %ls", dwDataSize, pkf->awchDllName);
        }
#endif

        if (pBaseDst != NULL) {
            VK_TO_WCHAR_TABLE *pVkToWcharTable;
            VSC_LPWSTR *pKeyName;

            pkf->hBase = (HANDLE)pBaseDst;

            RtlMoveMemory(pBaseDst,
                          (PBYTE)DosHdr + SectionTableEntry->PointerToRawData,
                          dwDataSize);

            if (ISTS()) {
                pkf->Size = dwDataSize; // For shadow hotkey processing
            }

            /*
             * Compute table address and fixup pointers in table.
             */
            pktNew = (PKBDTABLES)(pBaseDst + offTable);

            /*
             * The address in the data section has the virtual address
             * added in, so we need to adjust the fixup pointer to
             * compensate.
             */
            pBaseVirt = pBaseDst - SectionTableEntry->VirtualAddress;

            FIXUP_PTR(pktNew->pCharModifiers);
            FIXUP_PTR(pktNew->pCharModifiers->pVkToBit);
            /*
             * Validate pVkToBit table.
             */
            {
                PVK_TO_BIT pVkToBit;

                for (pVkToBit = pktNew->pCharModifiers->pVkToBit; ; pVkToBit++) {
                    VALIDATE_PTR(pVkToBit);
                    if (pVkToBit->Vk == 0) {
                        break;
                    }
                }
            }

            FIXUP_PTR(pktNew->pVkToWcharTable);
#if DBG
            if (pktNew->pVkToWcharTable == NULL) {
                RIPMSGF1(RIP_WARNING, "KL %ls does not have pVkToWcharTable???", pkf->awchDllName);
            }
#endif
            if (pktNew->pVkToWcharTable) {
                /*
                 * Fix up and validate VkToWchar table.
                 */
                for (pVkToWcharTable = pktNew->pVkToWcharTable; ; pVkToWcharTable++) {
                    VALIDATE_PTR(pVkToWcharTable);
                    if (pVkToWcharTable->pVkToWchars == NULL) {
                        break;
                    }
                    FIXUP_PTR(pVkToWcharTable->pVkToWchars);
                }
            }

            FIXUP_PTR(pktNew->pDeadKey);
            /*
             * Validate pDeadKey array.
             */
            {
                PDEADKEY pDeadKey = pktNew->pDeadKey;
                while (pDeadKey) {
                    VALIDATE_PTR(pDeadKey);
                    if (pDeadKey->dwBoth == 0) {
                        break;
                    }
                    pDeadKey++;
                }
            }

            /*
             * Version 1 layouts support ligatures.
             */
            if (GET_KBD_VERSION(pktNew)) {
                FIXUP_PTR(pktNew->pLigature);
            }

            FIXUP_PTR(pktNew->pKeyNames);
            if (pktNew->pKeyNames == NULL) {
                RIPMSGF1(RIP_WARNING, "KL %ls does not have pKeyNames???", pkf->awchDllName);
            }

            if (pktNew->pKeyNames) {
                for (pKeyName = pktNew->pKeyNames; ; pKeyName++) {
                    VALIDATE_PTR(pKeyName);
                    if (pKeyName->vsc == 0) {
                        break;
                    }
                    FIXUP_PTR(pKeyName->pwsz);
                }
            }

            FIXUP_PTR(pktNew->pKeyNamesExt);
            if (pktNew->pKeyNamesExt) {
                for (pKeyName = pktNew->pKeyNamesExt; ; pKeyName++) {
                    VALIDATE_PTR(pKeyName);
                    if (pKeyName->vsc == 0) {
                        break;
                    }
                    FIXUP_PTR(pKeyName->pwsz);
                }
            }

            FIXUP_PTR(pktNew->pKeyNamesDead);
            if (pktNew->pKeyNamesDead) {
                LPWSTR *lpDeadKey;
                for (lpDeadKey = pktNew->pKeyNamesDead; ; lpDeadKey++) {
                    LPCWSTR lpwstr;

                    VALIDATE_PTR(lpDeadKey);
                    if (*lpDeadKey == NULL) {
                        break;
                    }
                    FIXUP_PTR(*lpDeadKey);
                    UserAssert(*lpDeadKey);
                    for (lpwstr = *lpDeadKey; ; lpwstr++) {
                        VALIDATE_PTR(lpwstr);
                        if (*lpwstr == L'\0') {
                            break;
                        }
                    }
                };
            }

            /*
             * Fix up and validate Virtual Scan Code to VK table.
             */
            if (pktNew->pusVSCtoVK == NULL) {
                RIPMSGF1(RIP_WARNING, "KL %ls does not have the basic VSC to VK table", pkf->awchDllName);
                goto exitread;
            }
            FIXUP_PTR(pktNew->pusVSCtoVK);
            VALIDATE_PTR(pktNew->pusVSCtoVK + pktNew->bMaxVSCtoVK);

            FIXUP_PTR(pktNew->pVSCtoVK_E0);
            if (pktNew->pVSCtoVK_E0) {
                PVSC_VK pVscVk;
                for (pVscVk = pktNew->pVSCtoVK_E0; pVscVk->Vk; pVscVk++) {
                    VALIDATE_PTR(pVscVk);
                }
            }

            FIXUP_PTR(pktNew->pVSCtoVK_E1);
            if (pktNew->pVSCtoVK_E1) {
                PVSC_VK pVscVk;
                for (pVscVk = pktNew->pVSCtoVK_E1; ; pVscVk++) {
                    VALIDATE_PTR(pVscVk);
                    if (pVscVk->Vk == 0) {
                        break;
                    }
                }
            }

            if (offNlsTable) {
                /*
                 * Compute table address and fixup pointers in table.
                 */
                offNlsTable -= SectionTableEntry->VirtualAddress;
                pknlstNew = (PKBDNLSTABLES)(pBaseDst + offNlsTable);

                VALIDATE_PTR(pknlstNew);

                /*
                 * Fixup and validate the address.
                 */
                FIXUP_PTR(pknlstNew->pVkToF);
                if (pknlstNew->pVkToF) {
                    VALIDATE_PTR(&pknlstNew->pVkToF[pknlstNew->NumOfVkToF - 1]);
                }


                FIXUP_PTR(pknlstNew->pusMouseVKey);
                if (pknlstNew->pusMouseVKey) {
                    VALIDATE_PTR(&pknlstNew->pusMouseVKey[pknlstNew->NumOfMouseVKey - 1]);
                }

                /*
                 * Save the pointer.
                 */
                pkf->pKbdNlsTbl = pknlstNew;

            #if DBG_FE
                {
                    UINT NumOfVkToF = pknlstNew->NumOfVkToF;

                    DbgPrint("NumOfVkToF - %d\n",NumOfVkToF);

                    while(NumOfVkToF) {
                        DbgPrint("VK = %x\n",pknlstNew->pVkToF[NumOfVkToF-1].Vk);
                        NumOfVkToF--;
                    }
                }
            #endif  // DBG_FE
            }
        }

    } except(W32ExceptionHandler(FALSE, RIP_WARNING)) {
          RIPMSGF1(RIP_WARNING, "took exception reading from %ls", pkf->awchDllName);
          goto exitread;
    }

    fSucceeded = TRUE;
exitread:

    if (!fSucceeded && pBaseDst) {
        UserFreePool(pBaseDst);
    }

    /*
     * Unmap and release the mapped section.
     */
    if (DosHdr) {
        ZwUnmapViewOfSection(NtCurrentProcess(), DosHdr);
    }

    if (hmap != NULL) {
        ZwClose(hmap);
    }

    TAGMSGF1(DBGTAG_KBD, "returning pkl = %p", pktNew);

    if (!fSucceeded) {
        return NULL;
    }

    return pktNew;
}

PKBDTABLES PrepareFallbackKeyboardFile(PKBDFILE pkf)
{
    PBYTE pBaseDst;

    pBaseDst = UserAllocPool(sizeof(KBDTABLES), TAG_KBDTABLE);
    if (pBaseDst != NULL) {
        RtlCopyMemory(pBaseDst, &KbdTablesFallback, sizeof KbdTablesFallback);
        // Note: Unlike ReadLayoutFile(),
        // we don't need to fix up pointers in struct KBDFILE.
    }
    pkf->hBase = (HANDLE)pBaseDst;
    pkf->pKbdNlsTbl = NULL;
    return (PKBDTABLES)pBaseDst;
}


/***************************************************************************\
* LoadKeyboardLayoutFile
*
* History:
* 10-29-95 GregoryW         Created.
\***************************************************************************/

PKBDFILE LoadKeyboardLayoutFile(
    HANDLE hFile,
    UINT offTable,
    UINT offNlsTable,
    LPCWSTR pwszKLID,
    LPWSTR pwszDllName,
    DWORD dwType,
    DWORD dwSubType)
{
    PKBDFILE pkf = gpkfList;

    TAGMSG4(DBGTAG_KBD | RIP_THERESMORE, "LoadKeyboardLayoutFile: new KL=%S, dllName='%S', %d:%d",
            pwszKLID, pwszDllName ? pwszDllName : L"",
            dwType, dwSubType);
    UNREFERENCED_PARAMETER(pwszKLID);

    /*
     * Search for the existing layout file.
     */
    if (pkf) {
        do {
            TAGMSG3(DBGTAG_KBD | RIP_THERESMORE, "LoadKeyboardLayoutFile: looking at dll=%S, %d:%d",
                    pkf->awchDllName,
                    pkf->pKbdTbl->dwType, pkf->pKbdTbl->dwSubType);
            if (pwszDllName && _wcsicmp(pkf->awchDllName, pwszDllName) == 0) {
                /*
                 * The layout is already loaded.
                 */
                TAGMSG1(DBGTAG_KBD, "LoadKeyboardLayoutFile: duplicated KBDFILE found(#1). pwszDllName='%ls'\n", pwszDllName);
                return pkf;
            }
            pkf = pkf->pkfNext;
        } while (pkf);
    }
    TAGMSG1(DBGTAG_KBD, "LoadKeyboardLayoutFile: layout %S is not yet loaded.", pwszDllName);

    /*
     * Allocate a new Keyboard File structure.
     */
    pkf = (PKBDFILE)HMAllocObject(NULL, NULL, TYPE_KBDFILE, sizeof(KBDFILE));
    if (!pkf) {
        RIPMSG0(RIP_WARNING, "Keyboard Layout File: out of memory");
        return (PKBDFILE)NULL;
    }

    /*
     * Load layout table.
     */
    if (hFile != NULL) {
        /*
         * Load NLS layout table also...
         */
        wcsncpycch(pkf->awchDllName, pwszDllName, ARRAY_SIZE(pkf->awchDllName));
        pkf->awchDllName[ARRAY_SIZE(pkf->awchDllName) - 1] = 0;
        pkf->pKbdTbl = ReadLayoutFile(pkf, hFile, offTable, offNlsTable);
        if (dwType || dwSubType) {
            pkf->pKbdTbl->dwType = dwType;
            pkf->pKbdTbl->dwSubType = dwSubType;
        }
    } else {
        /*
         * We failed to open the keyboard layout file in client side
         * because the dll was missing.
         * If this ever happens, we used to fail creating
         * a window station, but we should allow a user
         * at least to boot the system.
         */
        TAGMSG1(DBGTAG_KBD, "LoadKeyboardLayoutFile: hFile is NULL for %ls, preparing the fallback.", pwszDllName);
        pkf->pKbdTbl = PrepareFallbackKeyboardFile(pkf);
        // Note: pkf->pKbdNlsTbl has been NULL'ed in PrepareFallbackKeyboardFile()
    }

    if (pkf->pKbdTbl == NULL) {
        RIPMSG0(RIP_WARNING, "LoadKeyboardLayoutFile: pkf->pKbdTbl is NULL.");
        HMFreeObject(pkf);
        return (PKBDFILE)NULL;
    }

    /*
     * Put keyboard layout file at front of list.
     */
    pkf->pkfNext = gpkfList;
    gpkfList = pkf;

    return pkf;
}

/***************************************************************************\
* RemoveKeyboardLayoutFile
*
* History:
* 10-29-95 GregoryW         Created.
\***************************************************************************/
VOID RemoveKeyboardLayoutFile(
    PKBDFILE pkf)
{
    PKBDFILE pkfPrev, pkfCur;

    // FE: NT4 SP4 #107809
    if (gpKbdTbl == pkf->pKbdTbl) {
        gpKbdTbl = &KbdTablesFallback;
    }
    if (gpKbdNlsTbl == pkf->pKbdNlsTbl) {
        gpKbdNlsTbl = NULL;
    }

    /*
     * Good old linked list management 101
     */
    if (pkf == gpkfList) {
        /*
         * Head of the list.
         */
        gpkfList = pkf->pkfNext;
        return;
    }
    pkfPrev = gpkfList;
    pkfCur = gpkfList->pkfNext;
    while (pkf != pkfCur) {
        pkfPrev = pkfCur;
        pkfCur = pkfCur->pkfNext;
    }
    /*
     * Found it!
     */
    pkfPrev->pkfNext = pkfCur->pkfNext;
}

/***************************************************************************\
* DestroyKF
*
* Called when a keyboard layout file is destroyed due to an unlock.
*
* History:
* 24-Feb-1997 adams     Created.
\***************************************************************************/

void
DestroyKF(PKBDFILE pkf)
{
    if (!HMMarkObjectDestroy(pkf))
        return;

    RemoveKeyboardLayoutFile(pkf);
    UserFreePool(pkf->hBase);
    HMFreeObject(pkf);
}

INT GetThreadsWithPKL(
    PTHREADINFO **ppptiList,
    PKL pkl)
{
    PTHREADINFO     ptiT, *pptiT, *pptiListAllocated;
    INT             cThreads, cThreadsAllocated;
    PWINDOWSTATION  pwinsta;
    PDESKTOP        pdesk;
    PLIST_ENTRY     pHead, pEntry;

    if (ppptiList != NULL)
        *ppptiList = NULL;

    cThreads = 0;

    /*
     * allocate a first list for 128 entries
     */
    cThreadsAllocated = 128;
    pptiListAllocated = UserAllocPool(cThreadsAllocated * sizeof(PTHREADINFO),
                            TAG_SYSTEM);

    if (pptiListAllocated == NULL) {
        RIPMSG0(RIP_WARNING, "GetPKLinThreads: out of memory");
        return 0;
    }

    // for all the winstations
    for (pwinsta = grpWinStaList; pwinsta != NULL ; pwinsta = pwinsta->rpwinstaNext) {

        // for all the desktops in that winstation
        for (pdesk = pwinsta->rpdeskList; pdesk != NULL ; pdesk = pdesk->rpdeskNext) {

            pHead = &pdesk->PtiList;

            // for all the threads in that desktop
            for (pEntry = pHead->Flink; pEntry != pHead; pEntry = pEntry->Flink) {

                ptiT = CONTAINING_RECORD(pEntry, THREADINFO, PtiLink);

                if (ptiT == NULL) {
                    continue;
                }

                if (pkl && (pkl != ptiT->spklActive)) { // #99321 cmp pkls, not hkls?
                    continue;
                }

                /*
                 * WindowsBug 349045
                 * Unload IMEs only for the normal apps.... leave them as is if they are
                 * loaded for services.
                 * Note, this is not really a clean fix, but some customers demand it.
                 */
                UserAssert(PsGetCurrentProcessId() == gpidLogon);
                if (ptiT->ppi->Process != gpepCSRSS && ptiT->ppi->Process != PsGetCurrentProcess()) {
                    /*
                     * By the time this routine is called (solely by WinLogon), all the other
                     * applications should be gone or terminated. So skipping like above
                     * leaves IMEs loaded in the services.
                     */
                    continue;
                }

                if (cThreads == cThreadsAllocated) {

                    cThreadsAllocated += 128;

                    pptiT = UserReAllocPool(pptiListAllocated,
                                    cThreads * sizeof(PTHREADINFO),
                                    cThreadsAllocated * sizeof(PTHREADINFO),
                                    TAG_SYSTEM);

                    if (pptiT == NULL) {
                        RIPMSG0(RIP_ERROR, "GetPKLinThreads: Out of memory");
                        UserFreePool(pptiListAllocated);
                        return 0;
                    }

                    pptiListAllocated = pptiT;

                }

                pptiListAllocated[cThreads++] = ptiT;
            }
        }
    }

    /*
     * add CSRSS threads
     */
    for (ptiT = PpiFromProcess(gpepCSRSS)->ptiList; ptiT != NULL; ptiT = ptiT->ptiSibling) {

        if (pkl && (pkl != ptiT->spklActive)) { // #99321 cmp pkls, not hkls?
            continue;
        }

        if (cThreads == cThreadsAllocated) {

            cThreadsAllocated += 128;

            pptiT = UserReAllocPool(pptiListAllocated,
                            cThreads * sizeof(PTHREADINFO),
                            cThreadsAllocated * sizeof(PTHREADINFO),
                            TAG_SYSTEM);

            if (pptiT == NULL) {
                RIPMSG0(RIP_ERROR, "GetPKLinThreads: Out of memory");
                UserFreePool(pptiListAllocated);
                return 0;
            }

            pptiListAllocated = pptiT;

        }

        pptiListAllocated[cThreads++] = ptiT;
    }

    if (cThreads == 0) {
        UserFreePool(pptiListAllocated);
    } else if (ppptiList != NULL) {
        *ppptiList = pptiListAllocated;
    } else {
        UserFreePool(pptiListAllocated);
    }

    return cThreads;
}


VOID xxxSetPKLinThreads(
    PKL pklNew,
    PKL pklToBeReplaced)
{
    PTHREADINFO *pptiList;
    INT cThreads, i;

    UserAssert(pklNew != pklToBeReplaced);

    CheckLock(pklNew);
    CheckLock(pklToBeReplaced);

    cThreads = GetThreadsWithPKL(&pptiList, pklToBeReplaced);

    /*
     * Will the foreground thread's keyboard layout change?
     */
    if (pklNew && gptiForeground && gptiForeground->spklActive == pklToBeReplaced) {
        ChangeForegroundKeyboardTable(pklToBeReplaced, pklNew);
    }

    if (pptiList != NULL) {
        if (pklToBeReplaced == NULL) {
            for (i = 0; i < cThreads; i++) {
                Lock(&pptiList[i]->spklActive, pklNew);
            }
        } else {
            /*
             * This is a replace. First, deactivate the *replaced* IME by
             * activating the pklNew. Second, unload the *replaced* IME.
             */
            xxxImmActivateAndUnloadThreadsLayout(pptiList, cThreads, NULL,
                                                 pklNew, HandleToUlong(pklToBeReplaced->hkl));
        }
        UserFreePool(pptiList);
    }

    /*
     * If this is a replace, link the new layout immediately after the
     * layout being replaced.  This maintains ordering of layouts when
     * the *replaced* layout is unloaded.  The input locale panel in the
     * regional settings applet depends on this.
     */
    if (pklToBeReplaced) {
        if (pklToBeReplaced->pklNext == pklNew) {
            /*
             * Ordering already correct.  Nothing to do.
             */
            return;
        }
        /*
         * Move new layout immediately after layout being replaced.
         *   1. Remove new layout from current position.
         *   2. Update links in new layout.
         *   3. Link new layout into desired position.
         */
        pklNew->pklPrev->pklNext = pklNew->pklNext;
        pklNew->pklNext->pklPrev = pklNew->pklPrev;

        pklNew->pklNext = pklToBeReplaced->pklNext;
        pklNew->pklPrev = pklToBeReplaced;

        pklToBeReplaced->pklNext->pklPrev = pklNew;
        pklToBeReplaced->pklNext = pklNew;
    }
}

VOID xxxFreeImeKeyboardLayouts(
    PWINDOWSTATION pwinsta)
{
    PTHREADINFO *pptiList;
    INT cThreads;

    if (pwinsta->dwWSF_Flags & WSF_NOIO)
        return;

    /*
     * should make GetThreadsWithPKL aware of pwinsta?
     */
    cThreads = GetThreadsWithPKL(&pptiList, NULL);
    if (pptiList != NULL) {
        xxxImmUnloadThreadsLayout(pptiList, cThreads, NULL, IFL_UNLOADIME);
        UserFreePool(pptiList);
    }

    return;
}

/***************************************************************************\
* xxxLoadKeyboardLayoutEx
*
* History:
\***************************************************************************/

HKL xxxLoadKeyboardLayoutEx(
    PWINDOWSTATION pwinsta,
    HANDLE hFile,
    HKL hklToBeReplaced,
    UINT offTable,
    PKBDTABLE_MULTI_INTERNAL pKbdTableMulti,
    LPCWSTR pwszKLID,
    UINT KbdInputLocale,
    UINT Flags)
{
    PKL pkl, pklFirst, pklToBeReplaced;
    PKBDFILE pkf;
    CHARSETINFO cs;
    TL tlpkl;
    PTHREADINFO ptiCurrent;
    UNICODE_STRING strLcidKF;
    UNICODE_STRING strKLID;
    LCID lcidKF;
    BOOL bCharSet;
    PIMEINFOEX piiex;


    TAGMSG1(DBGTAG_KBD, "xxxLoadKeyboardLayoutEx: new KL: pwszKLID=\"%ls\"", pwszKLID);

    /*
     * If the windowstation does not do I/O, don't load the
     * layout.  Also check KdbInputLocale for #307132
     */
    if ((KbdInputLocale == 0) || (pwinsta->dwWSF_Flags & WSF_NOIO)) {
        return NULL;
    }

    /*
     * If hklToBeReplaced is non-NULL make sure it's valid.
     *    NOTE: may want to verify they're not passing HKL_NEXT or HKL_PREV.
     */
    ptiCurrent = PtiCurrent();
    if (hklToBeReplaced && !(pklToBeReplaced = HKLtoPKL(ptiCurrent, hklToBeReplaced))) {
        return NULL;
    }
    if (KbdInputLocale == HandleToUlong(hklToBeReplaced)) {
        /*
         * Replacing a layout/lang pair with itself.  Nothing to do.
         */
        return pklToBeReplaced->hkl;
    }

    if (Flags & KLF_RESET) {
        /*
         * Only WinLogon can use this flag
         */
        if (PsGetThreadProcessId(ptiCurrent->pEThread) != gpidLogon) {
             RIPERR0(ERROR_INVALID_FLAGS, RIP_WARNING,
                     "Invalid flag passed to LoadKeyboardLayout" );
             return NULL;
        }
        xxxFreeImeKeyboardLayouts(pwinsta);
        /*
         * Make sure we don't lose track of the left-over layouts
         * They have been unloaded, but are still in use by some threads).
         * The FALSE will prevent xxxFreeKeyboardLayouts from unlocking the
         * unloaded layouts.
         */
        xxxFreeKeyboardLayouts(pwinsta, FALSE);
    }

    /*
     * Does this hkl already exist?
     */
    pkl = pklFirst = pwinsta->spklList;

    if (pkl) {
        do {
            if (pkl->hkl == (HKL)IntToPtr( KbdInputLocale )) {
               /*
                * The hkl already exists.
                */

               /*
                * If it is unloaded (but not yet destroyed because it is
                * still is use), recover it.
                */
               if (pkl->dwKL_Flags & KL_UNLOADED) {
                   // stop it from being destroyed if not is use.
                   PHE phe = HMPheFromObject(pkl);
                   // An unloaded layout must be marked for destroy.
                   UserAssert(phe->bFlags & HANDLEF_DESTROY);
                   phe->bFlags &= ~HANDLEF_DESTROY;
#if DBG
                   phe->bFlags &= ~HANDLEF_MARKED_OK;
#endif
                   pkl->dwKL_Flags &= ~KL_UNLOADED;
               } else if (!(Flags & KLF_RESET)) {
                   /*
                    * If it was already loaded and we didn't change all layouts
                    * with KLF_RESET, there is nothing to tell the shell about
                    */
                   Flags &= ~KLF_NOTELLSHELL;
               }

               goto AllPresentAndCorrectSir;
            }
            pkl = pkl->pklNext;
        } while (pkl != pklFirst);
    }

    if (IS_IME_KBDLAYOUT((HKL)IntToPtr( KbdInputLocale ))
#ifdef CUAS_ENABLE
        ||
        IS_CICERO_ENABLED_AND_NOT16BIT()
#endif // CUAS_ENABLE
       ) {
        /*
         * This is an IME keyboard layout, do a callback
         * to read the extended IME information structure.
         * Note: We can't fail the call so easily if
         *       KLF_RESET is specified.
         */
        piiex = xxxImmLoadLayout((HKL)IntToPtr( KbdInputLocale ));
        if (piiex == NULL && (Flags & (KLF_RESET | KLF_INITTIME)) == 0) {
            /*
             * Not Resetting, not creating a window station
             */
            RIPMSG1(RIP_WARNING,
                  "Keyboard Layout: xxxImmLoadLayout(%lx) failed", KbdInputLocale);
            return NULL;
        }
    } else {
        piiex = NULL;
    }

    /*
     * Get the system font's font signature.  These are 64-bit FS_xxx values,
     * but we are only asking for an  ANSI ones, so gSystemFS is just a DWORD.
     * gSystemFS is consulted when posting WM_INPUTLANGCHANGEREQUEST (input.c)
     */
    if (gSystemFS == 0) {
        LCID lcid;

        ZwQueryDefaultLocale(FALSE, &lcid);
        if (xxxClientGetCharsetInfo(lcid, &cs)) {
            gSystemFS = cs.fs.fsCsb[0];
            gSystemCPCharSet = (BYTE)cs.ciCharset;
        } else {
            gSystemFS = 0xFFFF;
            gSystemCPCharSet = ANSI_CHARSET;
        }
    }

    /*
     * Use the Keyboard Layout's LCID to calculate the charset, codepage etc,
     * so that characters from that layout don't just becomes ?s if the input
     * locale doesn't match.  This allows "dumb" applications to display the
     * text if the user chooses the right font.
     * We can't just use the HIWORD of KbdInputLocale because if a variant
     * keyboard layout was chosen, this will be something like F008 - have to
     * look inside the KF to get the real LCID of the kbdfile: this will be
     * something like L"00010419", and we want the last 4 digits.
     */
    RtlInitUnicodeString(&strLcidKF, pwszKLID + 4);
    RtlUnicodeStringToInteger(&strLcidKF, 16, (PULONG)&lcidKF);
    bCharSet = xxxClientGetCharsetInfo(lcidKF, &cs);

    /*
     * Keyboard Layout Handle object does not exist.  Load keyboard layout file,
     * if not already loaded.
     */
    if ((pkf = LoadKeyboardLayoutFile(hFile, LOWORD(offTable), HIWORD(offTable), pwszKLID, pKbdTableMulti->wszDllName, 0, 0)) == NULL) {
        goto freePiiex;
    }
    /*
     * Allocate a new Keyboard Layout structure (hkl)
     */
    pkl = (PKL)HMAllocObject(NULL, NULL, TYPE_KBDLAYOUT, sizeof(KL));
    if (!pkl) {
        RIPMSG0(RIP_WARNING, "Keyboard Layout: out of memory");
        UserFreePool(pkf->hBase);
        HMMarkObjectDestroy(pkf);
        HMUnlockObject(pkf);
freePiiex:
        if (piiex) {
            UserFreePool(piiex);
        }
        return NULL;
    }

    Lock(&pkl->spkfPrimary, pkf);

    /*
     * Load extra keyboard layouts.
     */
    UserAssert(pKbdTableMulti);
    if (pKbdTableMulti->multi.nTables) {
        RIPMSG0(RIP_WARNING, "xxxLoadKeyboardLayoutEx: going to read multiple tables.");
        /*
         * Allocate the array for extra keyboard layouts.
         */
        UserAssert(pKbdTableMulti->multi.nTables < KBDTABLE_MULTI_MAX); // check exists in the stub
        pkl->pspkfExtra = UserAllocPoolZInit(pKbdTableMulti->multi.nTables * sizeof(PKBDFILE), TAG_KBDTABLE);
        if (pkl->pspkfExtra) {
            UINT i;
            UINT n;

            /*
             * Load the extra keyboard layouts and lock them.
             */
            for (i = 0, n = 0; i < pKbdTableMulti->multi.nTables; ++i) {
                UserAssert(i < KBDTABLE_MULTI_MAX);
                if (pKbdTableMulti->files[i].hFile) {
                    // make sure dll name is null terminated.
                    pKbdTableMulti->multi.aKbdTables[i].wszDllName[ARRAY_SIZE(pKbdTableMulti->multi.aKbdTables[i].wszDllName) - 1] = 0;
                    // load it.
                    pkf = LoadKeyboardLayoutFile(pKbdTableMulti->files[i].hFile,
                                                 pKbdTableMulti->files[i].wTable,
                                                 pKbdTableMulti->files[i].wNls,
                                                 pwszKLID,
                                                 pKbdTableMulti->multi.aKbdTables[i].wszDllName,
                                                 pKbdTableMulti->multi.aKbdTables[i].dwType,
                                                 pKbdTableMulti->multi.aKbdTables[i].dwSubType);
                    if (pkf == NULL) {
                        // If allocation fails, simply exit this loop and continue KL creation.
                        RIPMSG0(RIP_WARNING, "xxxLoadKeyboardLayoutEx: failed to load the extra keyboard layout file(s).");
                        break;
                    }

                    Lock(&pkl->pspkfExtra[n], pkf);
                    ++n;
                } else {
                    RIPMSG2(RIP_WARNING, "xxxLoadKeyboardLayoutEx: pKbdTableMulti(%#p)->files[%x].hFile is NULL",
                            pKbdTableMulti, i);
                }
            }
            pkl->uNumTbl = n;
        }
    }

    /*
     * Link to itself in case we have to DestroyKL
     */
    pkl->pklNext = pkl;
    pkl->pklPrev = pkl;

    /*
     * Init KL
     */
    pkl->dwKL_Flags = 0;
    pkl->wchDiacritic = 0;
    pkl->hkl = (HKL)IntToPtr( KbdInputLocale );
    RtlInitUnicodeString(&strKLID, pwszKLID);
    RtlUnicodeStringToInteger(&strKLID, 16, &pkl->dwKLID);
    TAGMSG2(DBGTAG_KBD, "xxxLoadKeyboardLayoutEx: hkl %08p KLID:%08x", pkl->hkl, pkl->dwKLID);

    Lock(&pkl->spkf, pkl->spkfPrimary);
    pkl->dwLastKbdType = pkl->spkf->pKbdTbl->dwType;
    pkl->dwLastKbdSubType = pkl->spkf->pKbdTbl->dwSubType;

    pkl->spkf->pKbdTbl->fLocaleFlags |= KLL_LAYOUT_ATTR_FROM_KLF(Flags);

    pkl->piiex = piiex;

    if (bCharSet) {
        pkl->CodePage = (WORD)cs.ciACP;
        pkl->dwFontSigs = cs.fs.fsCsb[1];   // font signature mask (FS_xxx values)
        pkl->iBaseCharset = cs.ciCharset;   // charset value
    } else {
        pkl->CodePage = CP_ACP;
        pkl->dwFontSigs = FS_LATIN1;
        pkl->iBaseCharset = ANSI_CHARSET;
    }

    /*
     * Insert KL in the double-linked circular list, at the end.
     */
    pklFirst = pwinsta->spklList;
    if (pklFirst == NULL) {
        Lock(&pwinsta->spklList, pkl);
    } else {
        pkl->pklNext = pklFirst;
        pkl->pklPrev = pklFirst->pklPrev;
        pklFirst->pklPrev->pklNext = pkl;
        pklFirst->pklPrev = pkl;
    }

AllPresentAndCorrectSir:

    // FE_IME
    ThreadLockAlwaysWithPti(ptiCurrent, pkl, &tlpkl);

    if (hklToBeReplaced) {
        TL tlPKLToBeReplaced;
        ThreadLockAlwaysWithPti(ptiCurrent, pklToBeReplaced, &tlPKLToBeReplaced);
        xxxSetPKLinThreads(pkl, pklToBeReplaced);
        xxxInternalUnloadKeyboardLayout(pwinsta, pklToBeReplaced, KLF_INITTIME);
        ThreadUnlock(&tlPKLToBeReplaced);
    }

    if (Flags & KLF_REORDER) {
        ReorderKeyboardLayouts(pwinsta, pkl);
    }

    if (!(Flags & KLF_NOTELLSHELL) && IsHooked(PtiCurrent(), WHF_SHELL)) {
        xxxCallHook(HSHELL_LANGUAGE, (WPARAM)NULL, (LPARAM)0, WH_SHELL);
        gLCIDSentToShell = 0;
    }

    if (Flags & KLF_ACTIVATE) {
        TL tlPKL;
        ThreadLockAlwaysWithPti(ptiCurrent, pkl, &tlPKL);
        xxxInternalActivateKeyboardLayout(pkl, Flags, NULL);
        ThreadUnlock(&tlPKL);
    }

    if (Flags & KLF_RESET) {
        RIPMSG2(RIP_VERBOSE, "Flag & KLF_RESET, locking gspklBaseLayout(%08x) with new kl(%08x)",
                gspklBaseLayout ? gspklBaseLayout->hkl : 0,
                pkl->hkl);
        Lock(&gspklBaseLayout, pkl);
        xxxSetPKLinThreads(pkl, NULL);
    }

    /*
     * Use the hkl as the layout handle
     * If the KL is freed somehow, return NULL for safety. -- ianja --
     */
    pkl = ThreadUnlock(&tlpkl);
    if (pkl == NULL) {
        return NULL;
    }
    return pkl->hkl;
}

HKL xxxActivateKeyboardLayout(
    PWINDOWSTATION pwinsta,
    HKL hkl,
    UINT Flags,
    PWND pwnd)
{
    PKL pkl;
    TL tlPKL;
    HKL hklRet;
    PTHREADINFO ptiCurrent = PtiCurrent();

    CheckLock(pwnd);

    pkl = HKLtoPKL(ptiCurrent, hkl);
    if (pkl == NULL) {
        return 0;
    }

    if (Flags & KLF_REORDER) {
        ReorderKeyboardLayouts(pwinsta, pkl);
    }

    ThreadLockAlwaysWithPti(ptiCurrent, pkl, &tlPKL);
    hklRet = xxxInternalActivateKeyboardLayout(pkl, Flags, pwnd);
    ThreadUnlock(&tlPKL);
    return hklRet;
}

VOID ReorderKeyboardLayouts(
    PWINDOWSTATION pwinsta,
    PKL pkl)
{
    PKL pklFirst = pwinsta->spklList;

    if (pwinsta->dwWSF_Flags & WSF_NOIO) {
        RIPMSG1(RIP_WARNING, "ReorderKeyboardLayouts called for non-interactive windowstation %#p",
                pwinsta);
        return;
    }

    UserAssert(pklFirst != NULL);

    /*
     * If the layout is already at the front of the list there's nothing to do.
     */
    if (pkl == pklFirst) {
        return;
    }
    /*
     * Cut pkl from circular list:
     */
    pkl->pklPrev->pklNext = pkl->pklNext;
    pkl->pklNext->pklPrev = pkl->pklPrev;

    /*
     * Insert pkl at front of list
     */
    pkl->pklNext = pklFirst;
    pkl->pklPrev = pklFirst->pklPrev;

    pklFirst->pklPrev->pklNext = pkl;
    pklFirst->pklPrev = pkl;

    Lock(&pwinsta->spklList, pkl);
}

extern VOID AdjustPushStateForKL(PTHREADINFO ptiCurrent, PBYTE pbDone, PKL pklTarget, PKL pklPrev, PKL pklNew);
extern void ResetPushState(PTHREADINFO pti, UINT uVk);

VOID ManageKeyboardModifiers(PKL pklPrev, PKL pkl)
{
    PTHREADINFO ptiCurrent = PtiCurrent();

    if (ptiCurrent->pq) {
        if (pklPrev) {
            BYTE baDone[256 / 8];

            RtlZeroMemory(baDone, sizeof baDone);

            /*
             * Clear the toggle state if needed. First check the modifier keys
             * of pklPrev. Next check the modifier keys of pklNew.
             */
            TAGMSG2(DBGTAG_IMM, "Changing KL from %08lx to %08lx", pklPrev->hkl, pkl->hkl);
            AdjustPushStateForKL(ptiCurrent, baDone, pklPrev, pklPrev, pkl);
            AdjustPushStateForKL(ptiCurrent, baDone, pkl, pklPrev, pkl);

            if (pklPrev->spkf && (pklPrev->spkf->pKbdTbl->fLocaleFlags & KLLF_ALTGR)) {
                if (!TestRawKeyDown(VK_CONTROL)) {
                    /*
                     * If the previous keyboard has AltGr, and if the Ctrl key is not
                     * physically down, clear the left control.
                     * See xxxAltGr().
                     */
                    TAGMSG0(DBGTAG_KBD, "Clearing VK_LCONTROL for AltGr\n");
                    xxxKeyEvent(VK_LCONTROL | KBDBREAK, 0x1D | SCANCODE_SIMULATED, 0, 0,
#ifdef GENERIC_INPUT
                                NULL,
                                NULL,
#endif
                                FALSE);
                }
            }
        }
        else {
            /*
             * If the current keyboard is unknown, clear all the push state.
             */
            int i;
            for (i = 0; i < CBKEYSTATE; i++) {
                ptiCurrent->pq->afKeyState[i] &= KEYSTATE_TOGGLE_BYTEMASK;
                gafAsyncKeyState[i] &= KEYSTATE_TOGGLE_BYTEMASK;
                gafRawKeyState[i] &= KEYSTATE_TOGGLE_BYTEMASK;
            }
        }
    }
}

void SetGlobalKeyboardTableInfo(PKL pklNew)
{
    CheckCritIn();
    UserAssert(pklNew);

    /*
     * Set gpKbdTbl so foreground thread processes AltGr appropriately
     */
    gpKbdTbl = pklNew->spkf->pKbdTbl;
    if (gpKL != pklNew) {
        gpKL = pklNew;
    }
    if (ISTS()) {
        ghKbdTblBase = pklNew->spkf->hBase;
        guKbdTblSize = pklNew->spkf->Size;
    }

    TAGMSG1(DBGTAG_KBD, "SetGlobalKeyboardTableInfo:Changing KL NLS Table: new HKL=%#p\n", pklNew->hkl);
    TAGMSG1(DBGTAG_KBD, "SetGlobalKeyboardTableInfo: new gpKbdNlsTbl=%#p\n", pklNew->spkf->pKbdNlsTbl);

    gpKbdNlsTbl = pklNew->spkf->pKbdNlsTbl;
}

VOID ChangeForegroundKeyboardTable(PKL pklOld, PKL pklNew)
{
    CheckCritIn();
    UserAssert(pklNew != NULL);

    if ((pklOld == pklNew || (pklOld != NULL && pklOld->spkf == pklNew->spkf)) && gpKL) {
        return;
    }

    /*
     * Some keys (pressed to switch layout) may still be down.  When these come
     * back up, they may have different VK values due to the new layout, so the
     * original key will be left stuck down. (eg: an ISV layout from Attachmate
     * and the CAN/CSA layout, both of which redefine the right-hand Ctrl key's
     * VK so switching to that layout with right Ctrl+Shift will leave the Ctrl
     * stuck down).
     * The solution is to clear all the keydown bits whenever we switch layouts
     * (leaving the toggle bits alone to preserve CapsLock, NumLock etc.). This
     * also solves the AltGr problem, where the simulated Ctrl key doesn't come
     * back up if we switch to a non-AltGr layout before releasing AltGr - IanJa
     *
     * Clear down bits only if necessary --- i.e. if the VK value differs between
     * old and new keyboard layout. We have to take complex path for some of the
     * keys, like Ctrl or Alt, may have left and right equivalents. - HiroYama
     */
    ManageKeyboardModifiers(pklOld, pklNew);

    // Manage the VK_KANA toggle key for Japanese KL.
    // Since VK_HANGUL and VK_KANA share the same VK value and
    // VK_KANA is a toggle key, when keyboard layouts are switched,
    // VK_KANA toggle status should be restored.

    //
    // If:
    // 1) Old and New keyboard layouts are both Japanese, do nothing.
    // 2) Old and New keyboard layouts are not Japanese, do nothing.
    // 3) Old keyboard is Japanese and new one is not, clear the KANA toggle.
    // 4) New keyboard is Japanese and old one is not, restore the KANA toggle.
    //

    {
        enum { KANA_NOOP, KANA_SET, KANA_CLEAR } opKanaToggle = KANA_NOOP;

        if (JAPANESE_KBD_LAYOUT(pklNew->hkl)) {
            if (pklOld == NULL) {
                /*
                 * Let's honor the current async toggle state
                 * if the old KL is not specified.
                 */
                TAGMSG0(DBGTAG_KBD, "VK_KANA: previous KL is NULL, honoring the async toggle state.");
                gfKanaToggle = (TestAsyncKeyStateToggle(VK_KANA) != 0);
                opKanaToggle = gfKanaToggle ? KANA_SET : KANA_CLEAR;
            } else if (!JAPANESE_KBD_LAYOUT(pklOld->hkl)) {
                /*
                 * We're switching from non JPN KL to JPN.
                 * Need to restore the KANA toggle state.
                 */
                opKanaToggle = gfKanaToggle ? KANA_SET : KANA_CLEAR;
            }
        } else if (pklOld && JAPANESE_KBD_LAYOUT(pklOld->hkl)) {
            /*
             * Previous KL was Japanese, and we're switching to the other language.
             * Let's clear the KANA toggle status and preserve it for the future
             * switch back to the Japanese KL.
             */
            gfKanaToggle = (TestAsyncKeyStateToggle(VK_KANA) != 0);
            opKanaToggle = KANA_CLEAR;
        }

        if (opKanaToggle == KANA_SET) {
            TAGMSG0(DBGTAG_KBD, "VK_KANA is being set.\n");
            SetAsyncKeyStateToggle(VK_KANA);
            SetRawKeyToggle(VK_KANA);
            if (gptiForeground && gptiForeground->pq) {
                SetKeyStateToggle(gptiForeground->pq, VK_KANA);
            }
        } else if (opKanaToggle == KANA_CLEAR) {
            TAGMSG0(DBGTAG_KBD, "VK_KANA is beging cleared.\n");
            ClearAsyncKeyStateToggle(VK_KANA);
            ClearRawKeyToggle(VK_KANA);
            if (gptiForeground && gptiForeground->pq) {
                ClearKeyStateToggle(gptiForeground->pq, VK_KANA);
            }
        }

        if (opKanaToggle != KANA_NOOP) {
            UpdateKeyLights(TRUE);
        }
    }

    UserAssert(pklNew);
    SetGlobalKeyboardTableInfo(pklNew);
}


//
// Toggle and push state adjusters:
//
// ResetPushState, AdjustPushState, AdjustPushStateForKL
//

void ResetPushState(PTHREADINFO pti, UINT uVk)
{
    TAGMSG1(DBGTAG_IMM, "ResetPushState: has to reset the push state of vk=%x\n", uVk);
    if (uVk != 0) {
        ClearAsyncKeyStateDown(uVk);
        ClearAsyncKeyStateDown(uVk);
        ClearRawKeyDown(uVk);
        ClearRawKeyToggle(uVk);
        ClearKeyStateDown(pti->pq, uVk);
        ClearKeyStateToggle(pti->pq, uVk);
    }
}

void AdjustPushState(PTHREADINFO ptiCurrent, BYTE bBaseVk, BYTE bVkL, BYTE bVkR, PKL pklPrev, PKL pklNew)
{
    BOOLEAN fDownL = FALSE, fDownR = FALSE;
    BOOLEAN fVanishL = FALSE, fVanishR = FALSE;

    UINT uScanCode1, uScanCode2;

    if (bVkL) {
        fDownL = TestRawKeyDown(bVkL) || TestAsyncKeyStateDown(bVkL) || TestKeyStateDown(ptiCurrent->pq, bVkL);
        if (fDownL) {
            uScanCode1 = InternalMapVirtualKeyEx(bVkL, 0, pklPrev->spkf->pKbdTbl);
            uScanCode2 = InternalMapVirtualKeyEx(bVkL, 0, pklNew->spkf->pKbdTbl);
            fVanishL = (uScanCode1 && uScanCode2 == 0);
            if (fVanishL) {
                TAGMSG2(DBGTAG_KBD, "AdjustPushState: clearing %02x (%02x)", bVkL, uScanCode1);
                xxxKeyEvent((WORD)(bVkL | KBDBREAK), (WORD)(uScanCode1 | SCANCODE_SIMULATED), 0, 0,
#ifdef GENERIC_INPUT
                            NULL,
                            NULL,
#endif
                            FALSE);
            }
        }
    }

    if (bVkR) {
        fDownR = TestRawKeyDown(bVkR) || TestAsyncKeyStateDown(bVkR) || TestKeyStateDown(ptiCurrent->pq, bVkR);
        if (fDownR) {
            uScanCode1 = InternalMapVirtualKeyEx(bVkR, 0, pklPrev->spkf->pKbdTbl);
            uScanCode2 = InternalMapVirtualKeyEx(bVkR, 0, pklNew->spkf->pKbdTbl);
            fVanishR = (uScanCode1 && uScanCode2 == 0);
            if (fVanishR) {
                TAGMSG2(DBGTAG_KBD, "AdjustPushState: clearing %02x (%02x)", bVkR, uScanCode1);
                xxxKeyEvent((WORD)(bVkR | KBDBREAK), (WORD)(uScanCode1 | SCANCODE_SIMULATED), 0, 0,
#ifdef GENERIC_INPUT
                            NULL,
                            NULL,
#endif
                            FALSE);
            }
        }
    }

    UNREFERENCED_PARAMETER(bBaseVk);
}

VOID AdjustPushStateForKL(PTHREADINFO ptiCurrent, PBYTE pbDone, PKL pklTarget, PKL pklPrev, PKL pklNew)
{
    CONST VK_TO_BIT* pVkToBits;

    UserAssert(pklPrev);
    UserAssert(pklNew);

    if (pklTarget->spkf == NULL || pklPrev->spkf == NULL) {
        return;
    }

    pVkToBits = pklTarget->spkf->pKbdTbl->pCharModifiers->pVkToBit;

    for (; pVkToBits->Vk; ++pVkToBits) {
        BYTE bVkVar1 = 0, bVkVar2 = 0;

        //
        // Is it already processed ?
        //
        UserAssert(pVkToBits->Vk < 0x100);
        if (pbDone[pVkToBits->Vk >> 3] & (1 << (pVkToBits->Vk & 7))) {
            continue;
        }

        switch (pVkToBits->Vk) {
        case VK_SHIFT:
            bVkVar1 = VK_LSHIFT;
            bVkVar2 = VK_RSHIFT;
            break;
        case VK_CONTROL:
            bVkVar1 = VK_LCONTROL;
            bVkVar2 = VK_RCONTROL;
            break;
        case VK_MENU:
            bVkVar1 = VK_LMENU;
            bVkVar2 = VK_RMENU;
            break;
        }

        TAGMSG3(DBGTAG_IMM, "Adjusting VK=%x var1=%x var2=%x\n", pVkToBits->Vk, bVkVar1, bVkVar2);

        AdjustPushState(ptiCurrent, pVkToBits->Vk, bVkVar1, bVkVar2, pklPrev, pklNew);

        pbDone[pVkToBits->Vk >> 3] |= (1 << (pVkToBits->Vk & 7));
    }
}


__inline BOOL IsWinSrvInputThread(
    PTHREADINFO pti)
{
    UserAssert(pti);
    UserAssert(pti->TIF_flags & TIF_CSRSSTHREAD);

    if (gptiForeground && gptiForeground->rpdesk &&
            gptiForeground->rpdesk->dwConsoleThreadId == TIDq(pti)) {
        return TRUE;
    }

    return FALSE;
}

/*****************************************************************************\
* xxxInternalActivateKeyboardLayout
*
* pkl   - pointer to keyboard layout to switch the current thread to
* Flags - KLF_RESET
*         KLF_SETFORPROCESS
*         KLLF_SHIFTLOCK (any of KLLF_GLOBAL_ATTRS)
*         others are ignored
* pwnd  - If the current thread has no focus or active window, send the
*         WM_INPUTLANGCHANGE message to this window (unless it is NULL too)
*
* History:
* 1998-10-14 IanJa    Added pwnd parameter
\*****************************************************************************/
HKL xxxInternalActivateKeyboardLayout(
    PKL pkl,
    UINT Flags,
    PWND pwnd)
{
    HKL hklPrev;
    PKL pklPrev;
    TL  tlpklPrev;
    PTHREADINFO ptiCurrent = PtiCurrent();

    CheckLock(pkl);
    CheckLock(pwnd);

    /*
     * Remember what is about to become the "previously" active hkl
     * for the return value.
     */
    if (ptiCurrent->spklActive != (PKL)NULL) {
        pklPrev = ptiCurrent->spklActive;
        hklPrev = ptiCurrent->spklActive->hkl;
    } else {
        pklPrev = NULL;
        hklPrev = (HKL)0;
    }

    /*
     * ShiftLock/CapsLock is a global feature applying to all layouts
     * Only Winlogon and the Input Locales cpanel applet set KLF_RESET.
     */
    if (Flags & KLF_RESET) {
        gdwKeyboardAttributes = KLL_GLOBAL_ATTR_FROM_KLF(Flags);
    }

    /*
     * Early out
     */
    if (!(Flags & KLF_SETFORPROCESS) && (pkl == ptiCurrent->spklActive)) {
        return hklPrev;
    }

    /*
     * Clear out diacritics when switching kbd layouts #102838
     */
    pkl->wchDiacritic = 0;

    /*
     * Update the active layout in the pti.  KLF_SETFORPROCESS will always be set
     * when the keyboard layout switch is initiated by the keyboard hotkey.
     */

    /*
     * Lock the previous keyboard layout for it's used later.
     */
    ThreadLockWithPti(ptiCurrent, pklPrev, &tlpklPrev);

    /*
     * Is this is a console thread, apply this change to any process in it's
     * window.  This can really help character-mode apps!  (#58025)
     */
    if (ptiCurrent->TIF_flags & TIF_CSRSSTHREAD) {
        Lock(&ptiCurrent->spklActive, pkl);
        try {
            ptiCurrent->pClientInfo->CodePage = pkl->CodePage;
        } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
           goto UnlockAndGo;
        }
    } else if ((Flags & KLF_SETFORPROCESS) && !(ptiCurrent->TIF_flags & TIF_16BIT)) {
        /*
         * For 16 bit app., only the calling thread will have its active layout updated.
         */
       PTHREADINFO ptiT;

       if (IS_IME_ENABLED()) {
           /*
            * Only allow *NOT* CSRSS to make this call
            */
           UserAssert(PsGetCurrentProcess() != gpepCSRSS);
           // pti->pClientInfo is updated in xxxImmActivateThreadsLayout()
           if (!xxxImmActivateThreadsLayout(ptiCurrent->ppi->ptiList, NULL, pkl)) {
               RIPMSG1(RIP_WARNING, "no layout change necessary via xxxImmActivateThreadLayout() for process %lx", ptiCurrent->ppi);
               goto UnlockAndGo;
           }
       } else {
           BOOL fKLChanged = FALSE;

           for (ptiT = ptiCurrent->ppi->ptiList; ptiT != NULL; ptiT = ptiT->ptiSibling) {
               if (ptiT->spklActive != pkl && (ptiT->TIF_flags & TIF_INCLEANUP) == 0) {
                   Lock(&ptiT->spklActive, pkl);
                   UserAssert(ptiT->pClientInfo != NULL);
                   try {
                       ptiT->pClientInfo->CodePage = pkl->CodePage;
                       ptiT->pClientInfo->hKL = pkl->hkl;
                   } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
                       goto UnlockAndGo;
                   }

                   fKLChanged = TRUE;
               }
           }
           if (!fKLChanged) {
              RIPMSG1(RIP_WARNING, "no layout change necessary for process %lx ?", ptiCurrent->ppi);
              goto UnlockAndGo;
           }
       }

    } else {
        if (IS_IME_ENABLED()) {
            xxxImmActivateLayout(ptiCurrent, pkl);
        } else {
            Lock(&ptiCurrent->spklActive, pkl);
        }
        UserAssert(ptiCurrent->pClientInfo != NULL);
        if ((ptiCurrent->TIF_flags & TIF_INCLEANUP) == 0) {
            try {
                ptiCurrent->pClientInfo->CodePage = pkl->CodePage;
                ptiCurrent->pClientInfo->hKL = pkl->hkl;
            } except (W32ExceptionHandler(FALSE, RIP_WARNING)) {
                   goto UnlockAndGo;
            }
        }
    }

    /*
     * If (
     *  1a. The process is not CSRSS. or
     *   b. it's CSRSS input thread.
     *  2. and, the process is foreground.
     * )
     * update gpKbdTbl for the proper AltGr processing,
     * and let the shell hook (primarily Internat.exe)
     * know the foreground app's new keyboard layout.
     */

//    if ((ptiCurrent->TIF_flags & TIF_CSRSSTHREAD) == 0 || IsWinSrvInputThread(ptiCurrent)) {

        if (gptiForeground && (gptiForeground->ppi == ptiCurrent->ppi)) {
            ChangeForegroundKeyboardTable(pklPrev, pkl);

            /*
             * Call the Shell hook with the new language.
             * Only call the hook if we are the foreground process, to prevent
             * background apps from changing the indicator.  (All console apps
             * are part of the same process, but I have never seen a cmd window
             * app change the layout, let alone in the background)
             */
            if (gLCIDSentToShell != pkl->hkl && (ptiCurrent != gptiRit)) {
               if (IsHooked(ptiCurrent, WHF_SHELL)) {
                   gLCIDSentToShell = pkl->hkl;
                   xxxCallHook(HSHELL_LANGUAGE, (WPARAM)NULL, (LPARAM)pkl->hkl, WH_SHELL);
               }
            }
        }
//    }

    /*
     * Tell the app what happened
     */
    if (ptiCurrent->pq) {
        PWND pwndT;
        TL tlpwndT;

        /*
         * If we have no Focus window, use the Active window.
         * eg: Console full-screen has NULL focus window.
         */
        pwndT = ptiCurrent->pq->spwndFocus;
        if (pwndT == NULL) {
            pwndT = ptiCurrent->pq->spwndActive;
            if (pwndT == NULL) {
                pwndT = pwnd;
            }
        }

        if (pwndT != NULL) {
            ThreadLockAlwaysWithPti( ptiCurrent, pwndT, &tlpwndT);
            xxxSendMessage(pwndT, WM_INPUTLANGCHANGE, (WPARAM)pkl->iBaseCharset, (LPARAM)pkl->hkl);
            ThreadUnlock(&tlpwndT);
        }
    }

    /*
     * Tell IME to send mode update notification
     */
    if (ptiCurrent && ptiCurrent->spwndDefaultIme &&
            (ptiCurrent->TIF_flags & TIF_CSRSSTHREAD) == 0) {
        if (IS_IME_KBDLAYOUT(pkl->hkl)
#ifdef CUAS_ENABLE
            ||
            IS_CICERO_ENABLED_AND_NOT16BIT()
#endif // CUAS_ENABLE
           ) {
            BOOL fForProcess = (ptiCurrent->TIF_flags & KLF_SETFORPROCESS) && !(ptiCurrent->TIF_flags & TIF_16BIT);
            TL tlpwndIme;

            TAGMSG1(DBGTAG_IMM, "Sending IMS_SENDNOTIFICATION to pwnd=%#p", ptiCurrent->spwndDefaultIme);

            ThreadLockAlwaysWithPti(ptiCurrent, ptiCurrent->spwndDefaultIme, &tlpwndIme);
            xxxSendMessage(ptiCurrent->spwndDefaultIme, WM_IME_SYSTEM, IMS_SENDNOTIFICATION, fForProcess);
            ThreadUnlock(&tlpwndIme);
        }
    }

UnlockAndGo:
    ThreadUnlock(&tlpklPrev);

    return hklPrev;
}

BOOL xxxUnloadKeyboardLayout(
    PWINDOWSTATION pwinsta,
    HKL hkl)
{
    PKL pkl;

    /*
     * Validate HKL and check to make sure an app isn't attempting to unload a system
     * preloaded layout.
     */
    pkl = HKLtoPKL(PtiCurrent(), hkl);
    if (pkl == NULL) {
        return FALSE;
    }

    return xxxInternalUnloadKeyboardLayout(pwinsta, pkl, 0);
}

HKL _GetKeyboardLayout(
    DWORD idThread)
{
    PTHREADINFO ptiT;
    PLIST_ENTRY pHead, pEntry;

    CheckCritIn();

    /*
     * If idThread is NULL return hkl of the current thread
     */
    if (idThread == 0) {
        PKL pklActive = PtiCurrentShared()->spklActive;

        if (pklActive == NULL) {
            return (HKL)0;
        }
        return pklActive->hkl;
    }
    /*
     * Look for idThread
     */
    pHead = &PtiCurrent()->rpdesk->PtiList;
    for (pEntry = pHead->Flink; pEntry != pHead; pEntry = pEntry->Flink) {
        ptiT = CONTAINING_RECORD(pEntry, THREADINFO, PtiLink);
        if (GETPTIID(ptiT) == (HANDLE)LongToHandle(idThread)) {
            if (ptiT->spklActive == NULL) {
                return (HKL)0;
            }
            return ptiT->spklActive->hkl;
        }
    }
    /*
     * idThread doesn't exist
     */
    return (HKL)0;
}

UINT _GetKeyboardLayoutList(
    PWINDOWSTATION pwinsta,
    UINT nItems,
    HKL *ccxlpBuff)
{
    UINT nHKL = 0;
    PKL pkl, pklFirst;

    if (!pwinsta) {
        return 0;
    }

    pkl = pwinsta->spklList;

    /*
     * Windowstations that do not take input could have no layouts
     */
    if (pkl == NULL) {
        // SetLastError() ????
        return 0;
    }

    /*
     * The client/server thunk sets nItems to 0 if ccxlpBuff == NULL
     */
    UserAssert(ccxlpBuff || (nItems == 0));

    pklFirst = pkl;
    if (nItems) {
        try {
            do {
               if (!(pkl->dwKL_Flags & KL_UNLOADED)) {
                   if (nItems-- == 0) {
                       break;
                   }
                   nHKL++;
                   *ccxlpBuff++ = pkl->hkl;
               }
               pkl = pkl->pklNext;
            } while (pkl != pklFirst);
        } except (EXCEPTION_EXECUTE_HANDLER) {
            RIPERR1(ERROR_INVALID_PARAMETER, RIP_ERROR,
                    "_GetKeyBoardLayoutList: exception writing ccxlpBuff %lx", ccxlpBuff);
            return 0;
        }
    } else do {
        if (!(pkl->dwKL_Flags & KL_UNLOADED)) {
            nHKL++;
        }
        pkl = pkl->pklNext;
    } while (pkl != pklFirst);

    return nHKL;
}

/*
 * Layouts are locked by each thread using them and possibly by:
 *    - pwinsta->spklList (head of windowstation's list)
 *    - gspklBaseLayout   (default layout for new threads)
 * The layout is marked for destruction when gets unloaded, so that it will be
 * unlinked and freed as soon as an Unlock causes the lock count to go to 0.
 * If it is reloaded before that time, it is unmarked for destruction. This
 * ensures that laoded layouts stay around even when they go out of use.
 */
BOOL xxxInternalUnloadKeyboardLayout(
    PWINDOWSTATION pwinsta,
    PKL pkl,
    UINT Flags)
{
    PTHREADINFO ptiCurrent = PtiCurrent();
    TL tlpkl;

    UserAssert(pkl);

    /*
     * Never unload the default layout, unless we are destroying the current
     * windowstation or replacing one user's layouts with another's.
     */
    if ((pkl == gspklBaseLayout) && !(Flags & KLF_INITTIME)) {
        return FALSE;
    }

    /*
     * Keeps pkl good, but also allows destruction when unlocked later
     */
    ThreadLockAlwaysWithPti(ptiCurrent, pkl, &tlpkl);

    /*
     * Mark it for destruction so it gets removed when the lock count reaches 0
     * Mark it KL_UNLOADED so that it appears to be gone from the toggle list
     */
    HMMarkObjectDestroy(pkl);
    pkl->dwKL_Flags |= KL_UNLOADED;

    /*
     * If unloading this thread's active layout, helpfully activate the next one
     * (Don't bother if KLF_INITTIME - unloading all previous user's layouts)
     */
    if (!(Flags & KLF_INITTIME)) {
        UserAssert(ptiCurrent->spklActive != NULL);
        if (ptiCurrent->spklActive == pkl) {
            PKL pklNext;
            pklNext = HKLtoPKL(ptiCurrent, (HKL)HKL_NEXT);
            if (pklNext != NULL) {
                TL tlPKL;
                ThreadLockAlwaysWithPti(ptiCurrent, pklNext, &tlPKL);
                xxxInternalActivateKeyboardLayout(pklNext, Flags, NULL);
                ThreadUnlock(&tlPKL);
            }
        }
    }

    /*
     * If this pkl == pwinsta->spklList, give it a chance to be destroyed by
     * unlocking it from pwinsta->spklList.
     */
    if (pwinsta->spklList == pkl) {
        UserAssert(pkl != NULL);
        if (pkl != pkl->pklNext) {
            pkl = Lock(&pwinsta->spklList, pkl->pklNext);
            UserAssert(pkl != NULL); // gspklBaseLayout and ThreadLocked pkl
        }
    }

    /*
     * This finally destroys the unloaded layout if it is not in use anywhere
     */
    ThreadUnlock(&tlpkl);

    /*
     * Update keyboard list.
     */
    if (IsHooked(ptiCurrent, WHF_SHELL)) {
        xxxCallHook(HSHELL_LANGUAGE, (WPARAM)NULL, (LPARAM)0, WH_SHELL);
        gLCIDSentToShell = 0;
    }

    return TRUE;
}

VOID xxxFreeKeyboardLayouts(
    PWINDOWSTATION pwinsta, BOOL bUnlock)
{
    PKL pkl;

    /*
     * Unload all of the windowstation's layouts.
     * They may still be locked by some threads (eg: console), so this
     * may not destroy them all, but it will mark them all KL_UNLOADED.
     * Set KLF_INITTIME to ensure that the default layout (gspklBaseLayout)
     * gets unloaded too.
     * Note: it's much faster to unload non-active layouts, so start with
     * the next loaded layout, leaving the active layout till last.
     */
    while ((pkl = HKLtoPKL(PtiCurrent(), (HKL)HKL_NEXT)) != NULL) {
        xxxInternalUnloadKeyboardLayout(pwinsta, pkl, KLF_INITTIME);
    }

    /*
     * The WindowStation is being destroyed, or one user's layouts are being
     * replaced by another user's, so it's OK to Unlock spklList.
     * Any layout still in the double-linked circular KL list will still be
     * pointed to by gspklBaseLayout: this is important, since we don't want
     * to leak any KL or KBDFILE objects by losing pointers to them.
     * There are no layouts when we first come here (during bootup).
     */
    if (bUnlock) {
        Unlock(&pwinsta->spklList);
    }
}

/***************************************************************************\
* DestroyKL
*
* Destroys a keyboard layout. Note that this function does not
* follow normal destroy function semantics. See IanJa.
*
* History:
* 25-Feb-1997 adams     Created.
\***************************************************************************/

VOID DestroyKL(
    PKL pkl)
{
    PKBDFILE pkf;

    /*
     * Cut it out of the pwinsta->spklList circular bidirectional list.
     * We know pwinsta->spklList != pkl, since pkl is unlocked.
     */
    pkl->pklPrev->pklNext = pkl->pklNext;
    pkl->pklNext->pklPrev = pkl->pklPrev;

    /*
     * Unlock its pkf
     */
    pkf = Unlock(&pkl->spkf);
    if (pkf && (pkf = Unlock(&pkl->spkfPrimary))) {
        DestroyKF(pkf);
    }

    if (pkl->pspkfExtra) {
        UINT i;

         for (i = 0; i < pkl->uNumTbl && pkl->pspkfExtra[i]; ++i) {
             pkf = Unlock(&pkl->pspkfExtra[i]);
             if (pkf) {
                 DestroyKF(pkf);
             }
         }
         UserFreePool(pkl->pspkfExtra);
    }

    if (pkl->piiex != NULL) {
        UserFreePool(pkl->piiex);
    }

    if (pkl == gpKL) {
        /*
         * Nuke gpKL.
         */
        gpKL = NULL;
    }

    /*
     * Free the pkl itself.
     */
    HMFreeObject(pkl);
}

/***************************************************************************\
* CleanupKeyboardLayouts
*
* Frees the all keyboard layouts in this session.
*
\***************************************************************************/
VOID CleanupKeyboardLayouts()
{
    /*
     * Unlock the keyboard layouts
     */
    if (gspklBaseLayout != NULL) {

        PKL pkl;
        PKL pklNext;

        pkl = gspklBaseLayout->pklNext;

        while (pkl->pklNext != pkl) {
            pklNext = pkl->pklNext;

            DestroyKL(pkl);

            pkl = pklNext;
        }

        UserAssert(pkl == gspklBaseLayout);

        if (!HMIsMarkDestroy(gspklBaseLayout)) {
            HMMarkObjectDestroy(gspklBaseLayout);
        }

        HYDRA_HINT(HH_KBDLYOUTGLOBALCLEANUP);

        if (Unlock(&gspklBaseLayout)) {
            DestroyKL(pkl);
        }
    }

    UserAssert(gpkfList == NULL);
}
