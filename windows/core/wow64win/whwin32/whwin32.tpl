;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Copyright (c) 1998-2000 Microsoft Corporation
;;
;; Module Name:
;;
;;   whwin32.tpl
;;
;; Abstract:
;;
;;   This template defines the thunks for the Win32 api set.
;;
;; Author:
;;
;;   6-Oct-98    mzoran
;;
;; Revision History:
;;   5-Apr-2000  samera     Thunk implementation for NtUserRawInput APIs.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[Macros]
MacroName=CallNameFromApiName
NumArgs=1
Begin=
@ApiName
End=

MacroName=ValidatecbSize
NumArgs=0
Begin=
if (WOW64_ISPTR(@ArgHostName) && ((@ArgHostTypeInd *)(@ArgHostName))->cbSize != sizeof(@ArgHostTypeInd)) { @Indent( @NL
   LOGPRINT((ERRORLOG, "@ApiName: @ArgType: An cbSize of %x was passed to API, but %x was expected\n",
            sizeof(@ArgHostTypeInd), ((@ArgHostTypeInd *)(@ArgHostName))->cbSize));  @NL
   RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
)} @NL
End=

[Types]

;; These types must be handled manually
TemplateName=LPARAM
Also=WPARAM
Also=MSG
Also=PMSG
Also=NPMSG
Also=LPMSG
Locals=
#error @ArgType must be handled manually. @NL
End=
PreCall=
#error @ArgType must be handled manually. @NL
End=
PostCall=
#error @ArgType must be handled manually. @NL
End=

TemplateName=KERNEL_PVOID
Also=KLPWSTR
Also=KLPSTR
Also=KHBITMAP
IndLevel=0
Direction=IN
PreCall=
@ArgName = (KERNEL_PVOID)UlongToPtr (@ArgHostName);
End=

TemplateName=KERNEL_PVOID
Also=KLPWSTR
Also=KLPSTR
Also=KHBITMAP
IndLevel=0
Direction=IN OUT
PreCall=
@ArgName = (KERNEL_PVOID)UlongToPtr (@ArgHostName);
End=
PostCall=
@ArgHostName = PtrToUlong (@ArgName);
End=

TemplateName=RAWINPUTHEADER
IndLevel=0
Direction=OUT
NoType=wParam
Locals=
@StructLocal
End=
PreCall=
@StructIN
@ArgName.wParam = @ArgHostName.wParam;
End=
PostCall=
@StructOUT
@ArgHostName.wParam = (NT32WPARAM)@ArgName.wParam;
End=

TemplateName=PRAWINPUTHEADER
IndLevel=0
Direction=OUT
NoType=wParam
Locals=
@StructPtrLocal
End=
PreCall=
@StructPtrIN
@ArgName.wParam = @ArgHostName.wParam;
End=
PostCall=
@StructPtrOUT
@ArgHostName->wParam = (NT32WPARAM)@ArgName->wParam;
End=

TemplateName=PRAWINPUTDEVICE
IndLevel=0
Direction=IN
Locals=
@StructPtrLocal
End=
PreCall=
@StructPtrIN
End=
PostCall=
@StructPtrOUT
End=

TemplateName=LPGCP_RESULTSW
IndLevel=0
Direction=IN OUT
Locals=
// @ArgName(@ArgType) in a IN OUT LPGCP_RESULTSW @NL
@TypeStructPtrINOUTLocal
End=
PreCall=
// @ArgName(@ArgType) in a IN OUT LPGCP_RESULTSW @NL
@TypeStructPtrINOUTPreCall
// The size really needs to be verified, but NtGdiGetCharacterPlacementW @NL
// is not verifying it.  To maintain maximal compatibility, it won't to verified @NL
// here either. @NL
// if (WOW64_ISPTR(@ArgName)) {
//    if(@ArgName->lStructSize != sizeof(NT32GCP_RESULTSW)) {
//        RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
//    } @NL
// } @NL
End=
PostCall=
// @ArgName(@ArgType) in a IN OUT LPGCP_RESULTSW @NL
@TypeStructPtrINOUTPostCall
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   WOWASSERT(@ArgName->lStructSize == sizeof(GCP_RESULTSW)); @NL
   ((NT32GCP_RESULTSW *)(@ArgHostName))->lStructSize = sizeof(NT32GCP_RESULTSW); @NL
)} @NL
End=

TemplateName=PCURSORDATA
IndLevel=0
Direction=IN
NoType=aspcur
NoType=aicur
NoType=ajifRate
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@TypeStructPtrINPreCall @NL
if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL

   SIZE_T cbData; @NL
   PVOID Data; @NL
   SIZE_T i; @NL
   NT32CURSORDATA *SrcCursorData; @NL
   PCURSORDATA DstCursorData; @NL
   NT32HCURSOR *SrcCursor; @NL
   HCURSOR *DstCursor; @NL
   @NL
   SrcCursorData = (NT32CURSORDATA *)@ArgHostName; @NL
   DstCursorData = (PCURSORDATA)@ArgName; @NL
   @NL
   if (SrcCursorData->CURSORF_flags & CURSORF_ACON) { @Indent( @NL

       // The kernel makes several checks that the data is small enough @NL
       // and all in the buffer. @NL
       // Repeat those checks here. @NL

       if (HIWORD(SrcCursorData->cpcur) | HIWORD(SrcCursorData->cicur)) { @Indent( @NL
           LOGPRINT((ERRORLOG, "@ApiName PCURSOR: Invalid PCURSOR\n")); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL

       if (((PVOID)SrcCursorData->aspcur == NULL) ||                                           @NL
           ((INT_PTR)SrcCursorData->ajifRate != (INT_PTR)(SrcCursorData->cpcur * sizeof(NT32HCURSOR))) ||     @NL
           ((INT_PTR)SrcCursorData->aicur != (INT_PTR)(SrcCursorData->ajifRate                 @NL
                                          + SrcCursorData->cicur * sizeof(NT32JIF)))) { @Indent(@NL
           LOGPRINT((ERRORLOG, "@ApiName PCURSOR: Invalid PCURSOR\n")); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL

       cbData = (SrcCursorData->cpcur * sizeof(HCURSOR)) + @NL
                (SrcCursorData->cicur * sizeof(JIF)) +     @NL
                (SrcCursorData->cicur * sizeof(DWORD));    @NL

       Data = Wow64AllocateTemp(cbData); @NL

       //                                       @NL
       // Initialize array offsets and sizes.   @NL
       //                                       @NL
       DstCursorData->cpcur = SrcCursorData->cpcur; @NL
       DstCursorData->cicur = SrcCursorData->cicur; @NL

       DstCursorData->aspcur = (PCURSOR *)Data; @NL

       // Even though these two fields are declared as pointers, they are @NL
       // actually passed to the kernel as offsets from the pointer in aspcur. @NL
       DstCursorData->ajifRate = (PJIF)(DstCursorData->cpcur * sizeof(HCURSOR)); @NL
       DstCursorData->aicur = (DWORD *)((PBYTE)DstCursorData->ajifRate + (DstCursorData->cicur * sizeof(JIF))); @NL

       //                               @NL
       // Copy data.                    @NL
       //                               @NL
       SrcCursor = (NT32HCURSOR *)SrcCursorData->aspcur;   @NL
       DstCursor = (HCURSOR *)Data;                        @NL

       for(i=0; i < SrcCursorData->cpcur; i++) { @Indent(  @NL
          DstCursor[i] = (HCURSOR)SrcCursor[i];            @NL
       })                                                  @NL

       // These arrays are not pointer dependent.                            @NL
       WOWASSERT(sizeof(JIF) == sizeof(NT32JIF));                            @NL
       RtlCopyMemory((PBYTE)DstCursor + (INT_PTR)DstCursorData->ajifRate,    @NL
                     (PBYTE)SrcCursor + (INT_PTR)SrcCursorData->ajifRate,    @NL
                     sizeof(JIF) * DstCursorData->cicur);                    @NL
       @NL

       WOWASSERT(sizeof(DWORD) == sizeof(NT32DWORD));                        @NL
       RtlCopyMemory((PBYTE)DstCursor + (INT_PTR)DstCursorData->aicur,       @NL
                     (PBYTE)SrcCursor + (INT_PTR)SrcCursorData->aicur,       @NL
                     sizeof(DWORD) * DstCursorData->cicur);                  @NL
       @NL

    )} @NL
    else { @Indent( @NL
       DstCursorData->aspcur = (PCURSOR *)NULL;   @NL
       DstCursorData->ajifRate = (PJIF)NULL;      @NL
       DstCursorData->aicur = (DWORD *)NULL;      @NL
       DstCursorData->cpcur = 0;                  @NL
       DstCursorData->cicur = 0;                  @NL
    )} @NL
)} @NL
End=
PostCall=
@TypeStructPtrINPostCall @NL
End=

TemplateName=PCURSORFIND
NoType=hcur
IndLevel=0
Direction=IN
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@TypeStructPtrINPreCall
//Align structure from 32bit apps. wow64 version of win32k.sys might be fixed to align the buffer @NL
if (@ArgName != (@ArgType)@ArgHostName ) { @NL
    LARGE_INTEGER Temp = *(UNALIGNED LARGE_INTEGER *)&(((struct NT32tagCURSORFIND *)(@ArgHostName))->hcur); @NL
    @ArgName->hcur = *(KHCURSOR *) &Temp;  @NL
} @NL
End=
PostCall=
End=

TemplateName=PCLSMENUNAME
NoType=pszClientAnsiMenuName
NoType=pwszClientUnicodeMenuName
IndLevel=0
Direction=IN
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@TypeStructPtrINPreCall
//Align structure from 32bit apps. wow64 version of win32k.sys might be fixed to align the buffer @NL
if (@ArgName != (@ArgType)@ArgHostName ) { @NL
    LARGE_INTEGER Temp = *(UNALIGNED LARGE_INTEGER *)&(((struct NT32tagCLSMENUNAME *)(@ArgHostName))->pszClientAnsiMenuName); @NL
    @ArgName->pszClientAnsiMenuName = *(KLPSTR *) &Temp;  @NL
    Temp = *(UNALIGNED LARGE_INTEGER *)&(((struct NT32tagCLSMENUNAME *)(@ArgHostName))->pwszClientUnicodeMenuName); @NL
    @ArgName->pwszClientUnicodeMenuName = *(KLPWSTR *) &Temp;  @NL
} @NL
End=
PostCall=
End=

TemplateName=PCLSMENUNAME
NoType=pusMenuName
IndLevel=0
Direction=OUT
Locals=
@TypeStructPtrOUTLocal
End=
PreCall=
@TypeStructPtrOUTPreCall
End=
PostCall=
@TypeStructPtrOUTPostCall
// The only API's to use this type as an out param are @NL
// NtUserUnregisterClass and NtUserSetClassLong.  @NL
// These APIs always returns NULL in the pusMenuName field(except when the API fails). @NL
if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
   ((NT32CLSMENUNAME*)(@ArgHostName))->pusMenuName = (NT32PUNICODE_STRING)NULL; @NL
)} @NL
End=

TemplateName=PCLSMENUNAME
NoType=pusMenuName
IndLevel=0
Direction=IN OUT
Locals=
UNICODE_STRING @ArgVal_pusMenuNameCopy; @NL
@TypeStructPtrINOUTLocal
End=
PreCall=
@TypeStructPtrINOUTPreCall
if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
   if (WOW64_ISPTR(((NT32CLSMENUNAME*)(@ArgHostName))->pusMenuName)) {
      Wow64ShallowThunkUnicodeString32TO64(&@ArgVal_pusMenuNameCopy, ((NT32CLSMENUNAME*)(@ArgHostName))->pusMenuName); @NL
      @ArgName->pusMenuName = &@ArgVal_pusMenuNameCopy;
   }
   else {
      @ArgName->pusMenuName = NULL;
   }
}
End=
PostCall=
@TypeStructPtrINOUTPostCall
// The only API's to use this type as an IN OUT param is NtUserSetClassLong.  @NL
// This APIs always returns NULL in the pusMenuName field(Except when the API fails). @NL
if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
   ((NT32CLSMENUNAME*)(@ArgHostName))->pusMenuName = (NT32PUNICODE_STRING)NULL; @NL
)} @NL
End=

TemplateName=GUID
IndLevel=0
PreCall=
RtlCopyMemory(&@ArgName, &@ArgHostName, sizeof(GUID)); @NL
End=
PostCall=
RtlCopyMemory(&@ArgHostName, &@ArgName, sizeof(GUID)); @NL
End=

TemplateName=HKL
IndLevel=0
Direction=IN OUT
PreCall=
@ArgName=(HKL)(LongToPtr(@ArgHostName)); @NL
End=
PostCall=
@ArgHostName=(NT32HKL)(@ArgName); @NL
End=

TemplateName=HKL
IndLevel=0
Direction=IN
PreCall=
@ArgName=(HKL)(LongToPtr(@ArgHostName)); @NL
End=

TemplateName=LPVIDEOMEMORY
IndLevel=0
NoType=lpHeap
Locals=
@TypeStructPtrINOUTLocal
End=
PreCall=
  @TypeStructPtrINOUTPreCall
  if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
      @ArgName->lpHeap = (struct _VMEMHEAP *)((struct NT32_VIDEOMEMORY *)(@ArgHostName))->lpHeap; @NL
  } @NL
End=
PostCall=
  @TypeStructPtrINOUTPostCall
  if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
      ((struct NT32_VIDEOMEMORY *)(@ArgHostName))->lpHeap = (__int32)(@ArgName->lpHeap); @NL
  } @NL    
End=

TemplateName=VIDEOMEMORY
IndLevel=1
NoType=lpHeap
Locals=
@TypeStructPtrINOUTLocal
End=
PreCall=
  @TypeStructPtrINOUTPreCall
  if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
      @ArgName->lpHeap = (struct _VMEMHEAP *)((struct NT32_VIDEOMEMORY *)(@ArgHostName))->lpHeap; @NL
  } @NL
End=
PostCall=
  @TypeStructPtrINOUTPostCall
  if (WOW64_ISPTR(@ArgHostName)) { @Indent( @NL
      ((struct NT32_VIDEOMEMORY *)(@ArgHostName))->lpHeap = (__int32)(@ArgName->lpHeap); @NL
  } @NL    
End=

TemplateName=DD_SURFACE_GLOBAL
IndLevel=1
NoType=lpVidMemHeap
PostCall=
@TypeStructPtrINOUTPostCall
if (WOW64_ISPTR(@ArgName)) { @NL
    ((struct NT32_DD_SURFACE_GLOBAL *)@ArgHostName)->dwUserMemSize = @ArgName->dwUserMemSize; @NL
} @NL
End=

TemplateName=PFLASHWINFO
IndLevel=0
Direction=IN
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   @ArgName->cbSize = sizeof(FLASHWINFO); @NL
)}
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=LPTRACKMOUSEEVENT
IndLevel=0
Direction=IN OUT
Locals=
@TypeStructPtrINOUTLocal
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINOUTPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   @ArgName->cbSize = sizeof(TRACKMOUSEEVENT); @NL
)}
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=LPMENUINFO
IndLevel=0
Direction=IN
NoType=dwMenuData
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   @ArgName->cbSize = sizeof(MENUINFO); @NL

   //dwMenuData is simply a storage locatation for application data.  The kernel does not @NL
   //look at it. This means the sign extension is irrelevant.@NL
   @ArgName->dwMenuData = (ULONG_PTR)((NT32MENUINFO *)(@ArgHostName))->dwMenuData; @NL

)}
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=WNDCLASSEX
IndLevel=1
Direction=IN
Locals=
@TypeStructPtrINLocal
PWCHAR pwchClassName, pwchMenuName;
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   SIZE_T Length;                     @NL
   
   @ArgName->cbSize = sizeof(WNDCLASSEX); @NL
   
   try {                                                                  @NL
   if ((PtrToUlong(@ArgName->lpszClassName) & (sizeof(WCHAR)-1)) != 0) {  @NL
                                                                          @NL
       if (ID(@ArgName->lpszClassName) == 0) {                            @NL
           Length = wcslen(@ArgName->lpszClassName);                      @NL
           Length <<= 1;                                                  @NL
           Length += sizeof(UNICODE_NULL);                                @NL
       
           pwchClassName = Wow64AllocateTemp(Length);                     @NL
       
           RtlCopyMemory(pwchClassName, @ArgName->lpszClassName, Length); @NL
           @ArgName->lpszClassName = pwchClassName;                       @NL
       }    
   }                                                                      @NL

   if ((PtrToUlong(@ArgName->lpszMenuName) & (sizeof(WCHAR)-1)) != 0) {   @NL
                                                                          @NL
       if (ID(@ArgName->lpszMenuName) == 0) {                             @NL
           Length = wcslen(@ArgName->lpszMenuName);                       @NL
           Length <<= 1;                                                  @NL
           Length += sizeof(UNICODE_NULL);                                @NL
       
           pwchMenuName = Wow64AllocateTemp(Length);                      @NL
       
           RtlCopyMemory(pwchMenuName, @ArgName->lpszMenuName, Length);   @NL
           @ArgName->lpszMenuName = pwchMenuName;                         @NL
       }                                                                  @NL
   }                                                                      @NL
   } except (EXCEPTION_EXECUTE_HANDLER) {                                 @NL
   }                                                                      @NL

)}
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=WNDCLASSEX
IndLevel=1
Direction=IN OUT
Locals=
@TypeStructPtrINOUTLocal
PWCHAR pwchClassName, pwchMenuName;
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINOUTPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   SIZE_T Length;                     @NL
   
   @ArgName->cbSize = sizeof(WNDCLASSEX); @NL
   
   try {                                                                  @NL
   if ((PtrToUlong(@ArgName->lpszClassName) & (sizeof(WCHAR)-1)) != 0) {  @NL
                                                                          @NL
       if (ID(@ArgName->lpszClassName) == 0) {                            @NL
           Length = wcslen(@ArgName->lpszClassName);                      @NL
           Length <<= 1;                                                  @NL
           Length += sizeof(UNICODE_NULL);                                @NL
                  
           pwchClassName = Wow64AllocateTemp(Length);                     @NL
       
           RtlCopyMemory(pwchClassName, @ArgName->lpszClassName, Length); @NL
           @ArgName->lpszClassName = pwchClassName;                       @NL
       }                                                                  @NL
   }                                                                      @NL

   if ((PtrToUlong(@ArgName->lpszMenuName) & (sizeof(WCHAR)-1)) != 0) {   @NL
   
       if (ID(@ArgName->lpszMenuName) == 0) {                             @NL
           Length = wcslen(@ArgName->lpszMenuName);                       @NL
           Length <<= 1;                                                  @NL
           Length += sizeof(UNICODE_NULL);                                @NL
                                                                          @NL
           pwchMenuName = Wow64AllocateTemp(Length);                      @NL
                                                                          @NL
           RtlCopyMemory(pwchMenuName, @ArgName->lpszMenuName, Length);   @NL
           @ArgName->lpszMenuName = pwchMenuName;                         @NL
       }    
   }                                                                      @NL
   } except (EXCEPTION_EXECUTE_HANDLER) {                                 @NL
   }                                                                      @NL

)}
End=
PostCall=
@TypeStructPtrINOUTPostCall
if (WOW64_ISPTR(@ArgName)) {@Indent( @NL
    WOWASSERT(sizeof(WNDCLASSEXW) == @ArgName->cbSize); @NL
    ((NT32WNDCLASSEX *)(@ArgHostName))->cbSize = sizeof(NT32WNDCLASSEXW); @NL
)} @NL
End=

TemplateName=PUNICODE_STRING
IndLevel=0
Direction=IN
Locals=
@TypeStructPtrINLocal
End=
PreCall=
@TypeStructPtrINPreCall
if ((WOW64_ISPTR (@ArgName)) && @Indent(                                   @NL
    (((ULONG_PTR)@ArgName->Buffer & (sizeof (WCHAR) - 1)) != 0) &&         @NL
    (ID(@ArgName->Buffer) == 0))) { @Indent(                               @NL
    PVOID LocalBuffer;                                                     @NL
    LocalBuffer = Wow64AllocateTemp (@ArgName->MaximumLength);             @NL
    RtlCopyMemory(LocalBuffer, @ArgName->Buffer, @ArgName->MaximumLength); @NL
    @ArgName->Buffer = LocalBuffer;                                        @NL
)}                                                                         @NL
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=PGUITHREADINFO
Also=PMENUBARINFO
Also=PCOMBOBOXINFO
IndLevel=0
Direction=IN OUT
Locals=
@TypeStructPtrINOUTLocal
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINOUTPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   @ArgName->cbSize = sizeof(@ArgTypeInd); @NL
)}
End=
PostCall=
@TypeStructPtrINOUTPostCall
if (WOW64_ISPTR(@ArgName)) {@Indent( @NL
    WOWASSERT(sizeof(@ArgTypeInd) == @ArgName->cbSize); @NL
    ((@ArgHostTypeInd *)(@ArgHostName))->cbSize = sizeof(@ArgHostTypeInd); @NL
)} @NL
End=

;; The kernel does not set the size on the outbound side!!!
TemplateName=PCURSORINFO
IndLevel=0
Direction=IN OUT
Locals=
@TypeStructPtrINOUTLocal
End=
PreCall=
@ValidatecbSize
@TypeStructPtrINOUTPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName)) { @Indent( @NL
   @ArgName->cbSize = sizeof(@ArgTypeInd); @NL
)}
End=
PostCall=
@TypeStructPtrINOUTPostCall
End=


TemplateName=LPMENUITEMINFOW
IndLevel=0
Direction=IN
NoType=dwItemData
Locals=
@TypeStructPtrINLocal
End=
PreCall=
if (WOW64_ISPTR(@ArgHostName) && @NL
    // User32!InsertMenu allways sets the cbSize to 0 @NL
    (((NT32MENUITEMINFOW*)(@ArgHostName))->cbSize != 0) && @NL
    ((NT32MENUITEMINFOW*)(@ArgHostName))->cbSize != sizeof(NT32MENUITEMINFOW)) { @Indent( @NL
    RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
)} @NL
@TypeStructPtrINPreCall
// Do Extra thunking. @NL
if (WOW64_ISPTR(@ArgName )) { @Indent( @NL
   @ArgName->cbSize = sizeof(MENUITEMINFOW); @NL

   // According to MSDN, dwItemData is a application defined data item. @NL
   // Unfortunatly, some kernel code was noticed that was testing if it is a valid handle. @NL
   // As a precaution, sign extend in the outbound case. @NL
   @ArgName->dwItemData = (ULONG_PTR)(LONG_PTR)(((NT32MENUITEMINFO *)(@ArgHostName))->dwItemData); @NL
)}
End=
PostCall=
@TypeStructPtrINPostCall
End=

TemplateName=PGETCLIPBDATA
IndLevel=0
Direction=OUT
Locals=
// Note: @ArgName(@ArgType) is an OUT PGETCLIPBDATA @NL
GETCLIPBDATA @ArgValCopy;@NL
End=
PreCall=
// Note: @ArgName(@ArgType) is an OUT PGETCLIPBDATA @NL
// This structure is a union of type handles of the same type. @NL
// Only copy one of them. @NL
if (WOW64_ISPTR(@ArgHostName)) {@Indent(@NL
    @ArgName = (@ArgType)&(@ArgValCopy);@NL
    @ArgName->uFmtRet = ((NT32GETCLIPBDATA*)(@ArgHostName))->uFmtRet; @NL
    @ArgName->fGlobalHandle = ((NT32GETCLIPBDATA*)(@ArgHostName))->fGlobalHandle; @NL
    @ArgName->hPalette = (HANDLE)((NT32GETCLIPBDATA*)(@ArgHostName))->hPalette; @NL
)} @NL
else { @Indent( @NL
    @ArgName = (@ArgType)@ArgHostName; @NL
}) @NL
End=
PostCall=
// Note: @ArgName(@ArgType) is an OUT PGETCLIPBDATA @NL
// This structure is a union of type handles of the same type. @NL
// Only copy one of them. @NL
if (WOW64_ISPTR(@ArgHostName)) {@Indent(@NL
    ((NT32GETCLIPBDATA*)(@ArgHostName))->uFmtRet = @ArgName->uFmtRet; @NL
    ((NT32GETCLIPBDATA*)(@ArgHostName))->fGlobalHandle = @ArgName->fGlobalHandle; @NL
    ((NT32GETCLIPBDATA*)(@ArgHostName))->hPalette = (NT32HANDLE)@ArgName->hPalette; @NL
)} @NL
End=

TemplateName=LPCBT_CREATEWND
IndLevel=0
Direction=IN OUT
Locals=
CBT_CREATEWND @ArgValCopy; @NL
@ForceType(Locals,@ArgName->lpcs,((NT32CBT_CREATEWND*)(@ArgHostName))->lpcs,LPCREATESTRUCTW,IN OUT)
End=
PreCall=
// Note: @ArgName(@ArgType) is an IN OUT CBT_CREATEWND @NL
if (WOW64_ISPTR(@ArgHostName)) {@Indent(@NL
    @ArgName = (@ArgType)(&@ArgValCopy); @NL
    @ArgName->hwndInsertAfter = (HWND)((NT32CBT_CREATEWND*)(@ArgHostName))->hwndInsertAfter; @NL
    @ForceType(PreCall,@ArgName->lpcs,((NT32CBT_CREATEWND*)(@ArgHostName))->lpcs,LPCREATESTRUCTW,IN OUT)
)} @NL
else {@Indent(
    @ArgName = (@ArgType)@ArgHostName;
)}
End=
PostCall=
// Note: @ArgName(@ArgType) is an IN OUT CBT_CREATEWND @NL
if (WOW64_ISPTR(@ArgHostName)) {@Indent( @NL
    ((NT32CBT_CREATEWND*)(@ArgHostName))->hwndInsertAfter = (NT32HWND)@ArgName->hwndInsertAfter; @NL
    @ForceType(PostCall,@ArgName->lpcs,((NT32CBT_CREATEWND*)(@ArgHostName))->lpcs,LPCREATESTRUCTW,IN OUT)
)} @NL
End=

TemplateName=WNDPROC
IndLevel=0
Direction=IN
PreCall=
@ArgName = (WNDPROC) NtWow64MapClientFnToKernelClientFn((PROC)@ArgHostName); @NL
End=

TemplateName=WNDPROC
IndLevel=0
Direction=IN OUT
PreCall=
@ArgName = (WNDPROC) NtWow64MapClientFnToKernelClientFn((PROC)@ArgHostName); @NL
End=
PostCall=
@ArgHostName = NtWow64MapKernelClientFnToClientFn((PROC)@ArgName); @NL
End=

[EFunc]


TemplateName=NtGdiAddRemoteFontToDC
Begin=
@GenPlaceHolderThunk(@ApiName)
End=

TemplateName=NtGdiAddFontMemResourceEx
Begin=
@GenPlaceHolderThunk(@ApiName)
End=

TemplateName=NtGdiCreateColorTransform
PreCall=
// The format of the data passed into this function cannot change since @NL
// accoring to Nideyuki Nagase this data is a on disk memory mapped file whose @NL
// format is defined by the International Color Consortium. @NL
End=

TemplateName=NtGdiCreateDIBSection
NoType=dwColorSpace
PreCall=
// dwColorSpace is a pointer to PCACHED_COLORSPACE which is pointer dependent.  @NL
// Fortunatly, the kernel only stores the pointer without looking at it.   @NL
// How it is converted does not make a difference. @NL
dwColorSpace = (ULONG_PTR)dwColorSpaceHost; @NL
End=

;; Metafiles can't change since it is a well established file format.
;; Unfortunatly, one of the headers that defined a metafile were changed.
;; This function can be uncommented out once it it fixed.
TemplateName=NtGdiCreateServerMetaFile
Begin=
@GenPlaceHolderThunk(@ApiName)
End=

TemplateName=NtGdiEnumFontChunk
NoType=idEnum
PreCall=
// This function returns variable length data, but the data is not @NL
// pointer dependent.  @NL
WOWASSERT(sizeof(ENUMFONTDATAW) == sizeof(NT32ENUMFONTDATAW)); @NL
@NL
// In reality, idEnum is a handle.  Sign extend it. @NL
idEnum = (ULONG_PTR)(LONG)idEnumHost; @NL
End=

TemplateName=NtGdiEnumFontClose
NoType=idEnum
PreCall=
// In reality, idEnum is a handle. Sign extend it. @NL
idEnum = (ULONG_PTR)(LONG)idEnumHost; @NL
End=

TemplateName=NtGdiEnumObjects
Locals=
ULONG NumObjects; @NL
End=
PreCall=
// Thunking is only needed for LOGBRUSH @NL
switch(iObjectType) { @Indent( @NL
   case OBJ_PEN: @NL @Indent(
       //LOGPEN is not pointer dependent, nothing to do @NL
       WOWASSERT(sizeof(LOGPEN) == sizeof(NT32LOGPEN)); @NL
       break; @NL
   )
   case OBJ_BRUSH: @NL @Indent(
       //LOGBRUSH is pointer dependent, thunking is needed. @NL
       if (cjBuf != 0 && NULL != pvBuf) { @Indent(
           NumObjects = cjBuf / sizeof(NT32LOGBRUSH); @NL
           cjBuf = NumObjects * sizeof(LOGBRUSH); @NL
           pvBuf = Wow64AllocateTemp(cjBuf); @NL
       )} @NL
       break; @NL
   )
   default: @NL @Indent(
       WOWASSERTMSG(FALSE, "Unknown object type\n"); @NL
       RtlRaiseStatus(STATUS_NOT_IMPLEMENTED);    @NL
   )
)} @NL
End=
PostCall=
// Thunking is only needed for LOGBRUSH @NL
if (iObjectType == OBJ_BRUSH && 0 != cjBuf && NULL != pvBuf) { @Indent( @NL
   ULONG c; @NL
   LOGBRUSH *Src = (LOGBRUSH *)pvBuf; @NL
   NT32LOGBRUSH *Dest = (NT32LOGBRUSH *)pvBufHost; @NL
   for(c=0; c<RetVal; c++) { @Indent( @NL
       @ForceType(PostCall,(Src+c),(Dest+c),PLOGBRUSH,OUT)
   )}
)} @NL
End=

TemplateName=NtGdiExtCreatePen
NoType=lClientHatch
NoType=lHatch
PreCall=
// Searching the NT tree reviels that lClientHatch can only be a HBITMAP(pClient GreCreateDIBBrush) @NL
// Sign extension is needed. @NL
lClientHatch = (ULONG_PTR)(LONG)lClientHatchHost; @NL
@NL
// lHatch can be a ULONG, HBITMAP, or PBITMAPINFOHEADER. HBITMAP and PBITNAPINFOHEADER @NL
// require sign extension.  ULONG does matter since the size between NT64 and NT32 are identical. @NL
lHatch = (ULONG_PTR)(LONG)lHatchHost; @NL
End=

TemplateName=NtGdiPolyTextOutW
NoType=pptw
Locals=
NT32POLYTEXTW *pptw32 = (NT32POLYTEXTW *)pptwHost;            @NL
PPOLYTEXTW pptwOrg;                                           @NL
ULONG PolyCount;                                              @NL
End=
PreCall=
    pptw = Wow64AllocateTemp (cStr * sizeof (POLYTEXTW));     @NL
    if (pptw == NULL) {                                       @NL
        return FALSE;                                         @NL
    }                                                         @NL
                                                              
    pptwOrg = pptw;                                           @NL
    for (PolyCount = 0 ; PolyCount < cStr ; PolyCount++) {    @NL
                                                              @NL
        try {                                                 @NL
            @ForceType(PreCall,(*pptw),(*pptw32),POLYTEXTW,IN)
        } except (EXCEPTION_EXECUTE_HANDLER) {                @NL
            return FALSE;                                     @NL
        }                                                     @NL
        pptw++;                                               @NL
        pptw32++;                                             @NL
    }                                                         @NL
    pptw = pptwOrg;                                           @NL
End=

TemplateName=NtGdiExtGetObjectW
Header=
@NoFormat(
int
whNT32GreExtGetObjectW(
    HANDLE h,
    int    cj,
    LPVOID pvOut
    )
{

    int iRet;
    int cjNew;
    PVOID pvBuff;

    union
    {
        BITMAP          bm;
        DIBSECTION      ds;
        LOGBRUSH        lb;
    } obj;

    LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle LO_TYPE: %I64X\n", (HANDLE)LO_TYPE(h)));

    switch(LO_TYPE(h)) {

    // Handle non pointer dependent types.
    case LO_PALETTE_TYPE:
        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_PALETTE_TYPE\n"));
        goto nonptrdep;

    case LO_FONT_TYPE:
        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_FONT_TYPE\n"));
        goto nonptrdep;

    case LO_ICMLCS_TYPE:
        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_ICMLCS_TYPE\n"));

nonptrdep:
        WOWASSERT(sizeof(NT32USHORT) == sizeof(USHORT));
        WOWASSERT(sizeof(NT32ENUMLOGFONTEXDVW) == sizeof(ENUMLOGFONTEXDVW));
        WOWASSERT(sizeof(NT32LOGCOLORSPACEEXW) == sizeof(LOGCOLORSPACEEXW));
        return NtGdiExtGetObjectW(h, cj, pvOut);

    // These types are all pointer dependent.

    case LO_BITMAP_TYPE:
        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_BITMAP_TYPE\n"));
        goto dibtype;

    case LO_DIBSECTION_TYPE:
        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_DIBSECTION_TYPE\n"));

dibtype:

        // The kernel does not validate the handle if the buffer is NULL.
        // The kernel bases the returned information on the size of the buffer pointed in.
        // Fortunatly, a DIBSECTION is a BITMAP with extra information. Thus, we always
        // ask for the DIBSECTION, but only return the full information is both the
        // client provided enought space for it and the kernel provided it.

        if (NULL == pvOut) {
            return sizeof(NT32BITMAP);
        }

        iRet = NtGdiExtGetObjectW(h, sizeof(DIBSECTION), &obj);

        WOWASSERT(0 == iRet || sizeof(BITMAP) == iRet || sizeof(DIBSECTION) == iRet);
        if (0 == iRet || cj < sizeof(NT32BITMAP)) {
           return 0;
        }

        if (cj < sizeof(NT32DIBSECTION) || iRet == sizeof(BITMAP)) {
            @ForceType(PostCall,(&(obj.bm)),((NT32BITMAP *)pvOut),LPBITMAP,OUT)
            return sizeof(NT32BITMAP);
        }

        @ForceType(PostCall,(&(obj.ds)),((NT32DIBSECTION *)pvOut),LPDIBSECTION,OUT)
        return sizeof(NT32DIBSECTION);

    case LO_BRUSH_TYPE:

        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_BRUSH_TYPE\n"));

        // The kernel does not look at the buffer size if pvOut is NULL
        if (NULL == pvOut) {
            iRet = NtGdiExtGetObjectW(h, cj, NULL);
            WOWASSERT(iRet == 0 || iRet == sizeof(LOGBRUSH));
            return (iRet == sizeof(LOGBRUSH)) ? sizeof(NT32LOGBRUSH) : 0;
        }

        iRet = NtGdiExtGetObjectW(h, sizeof(LOGBRUSH), &obj);

        WOWASSERT(0 == iRet || sizeof(LOGBRUSH) == iRet);
        if (0 == iRet || cj < sizeof(NT32LOGBRUSH)) {
            return 0;
        }

        @ForceType(PostCall,(&(obj.lb)),((NT32LOGBRUSH *)pvOut),LOGBRUSH*,OUT)
        return sizeof(NT32LOGBRUSH);

    case LO_PEN_TYPE:

        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_PEN_TYPE\n"));
        goto extpentype;

    case LO_EXTPEN_TYPE:

        LOGPRINT((TRACELOG, "NtGdiExtGetObjectW: handle was a LO_EXTPEN_TYPE\n"));

extpentype:

        WOWASSERT(sizeof(LOGPEN) == sizeof(NT32LOGPEN));

        // If the buffer is null, just pass the call to the kernel. The kernel does not look
        // at the count in this case.
        if (NULL == pvOut) {
            iRet = NtGdiExtGetObjectW(h, cj, NULL);
            WOWASSERT(0 == iRet || sizeof(LOGPEN) == iRet || iRet >= sizeof(EXTLOGPEN) - sizeof(DWORD));

            // Munge the return size if a EXTLOGPEN is being returned.  This occures if
            // the return size is >= EXTLOGPEN
            if (0 == iRet || sizeof(LOGPEN) == iRet) {
               return iRet;
            }

            // Here we are getting back a EXTLOGPEN, the size needs to be adjusted.
            return iRet - (sizeof(EXTLOGPEN) - sizeof(NT32EXTLOGPEN));
        }

        // Increase the buffer size if the app buffer is capable of holding a EXTLOGPEN
        cjNew = (cj >= sizeof(NT32EXTLOGPEN) - sizeof(NT32DWORD)) ? (cj + (sizeof(EXTLOGPEN) - sizeof(NT32EXTLOGPEN))) : cj;

        pvBuff = Wow64AllocateTemp(cjNew);

        iRet = NtGdiExtGetObjectW(h, cjNew, pvBuff);
        WOWASSERT(0 == iRet || sizeof(LOGPEN) == iRet || iRet >= sizeof(EXTLOGPEN) - sizeof(DWORD));

        //If the app passed in an incorrect buffer size, NtGdiExtGetObjectW will fail
        //and return 0.

        if (0 == iRet) {
           return 0;
        }

        if (sizeof(LOGPEN) == iRet) {
           RtlCopyMemory(pvOut, pvBuff, sizeof(LOGPEN));
           return iRet;
        }

        // iRet will be >= sizeof(EXTLOGPEN) at this point.  This means a EXTLOGPEN + some
        // extra non-pointer dependent data is being returned.
        {
           EXTLOGPEN *Src = pvBuff;
           NT32EXTLOGPEN *Dest = pvOut;
           ULONG i;
           
           WOWASSERT(cj + (sizeof(EXTLOGPEN) - sizeof(NT32EXTLOGPEN)) == iRet);
           
           if (WOW64_ISPTR(Dest)) {  
              try{ 
                    ((NT32EXTLOGPEN *)(Dest))->elpNumEntries = (NT32DWORD)Src->elpNumEntries;  
                    ((NT32EXTLOGPEN *)(Dest))->elpHatch = (NT32ULONG_PTR)Src->elpHatch;  
                    ((NT32EXTLOGPEN *)(Dest))->elpColor = (NT32COLORREF)Src->elpColor;  
                    ((NT32EXTLOGPEN *)(Dest))->elpBrushStyle = (NT32UINT)Src->elpBrushStyle;  
                    ((NT32EXTLOGPEN *)(Dest))->elpWidth = (NT32DWORD)Src->elpWidth;  
                    ((NT32EXTLOGPEN *)(Dest))->elpPenStyle = (NT32DWORD)Src->elpPenStyle;  
           
                    for(i=0; i < Src->elpNumEntries; i++) {
                        ((NT32EXTLOGPEN *)(Dest))->elpStyleEntry[i] = (NT32WORD)Src->elpStyleEntry[i];
                    }
               }
               except (EXCEPTION_EXECUTE_HANDLER) { 
                
                   #if defined _NTBASE_API_ 
                       return GetExceptionCode(); 
                   #elif defined _WIN32_API_ 
                       return 0; 
                   #endif
               }
           } 
            
           if (Src->elpNumEntries > 1){
               return sizeof(NT32EXTLOGPEN) + sizeof(NT32DWORD) * (Src->elpNumEntries-1);
           }
           
           return iRet - (sizeof(EXTLOGPEN) - sizeof(NT32EXTLOGPEN));
        }

    default:
       WOWASSERTMSG(FALSE, "Unsupported handle type passed into NtGdiExtGetObjectW\nThis should be safe to ignore\n");

    // ignore NULL & INVALID handles
    case (((1 << (TYPE_BITS + ALTTYPE_BITS)) - 1) << TYPE_SHIFT):
    case 0:
       return 0; //This is what the kernel does.
    }

}

int
whNT32GdiExtGetObjectW(
    HANDLE h,
    int    cj,
    LPVOID pvOut
    )
{

    union
    {
        NT32BITMAP          bm;
        NT32DIBSECTION      ds;
        NT32EXTLOGPEN       elp;
        NT32LOGPEN          l;
        NT32LOGBRUSH        lb;
        NT32LOGFONTW        lf;
        NT32ENUMLOGFONTEXDVW elf;
        NT32LOGCOLORSPACEEXW lcsp;
    } obj32;

    int iType = LO_TYPE(h);
    int ci, iRet;
    PVOID pvBuf = pvOut;

    // The kernel limits the size of the returned information, thus the same will be done here.
    if ((cj < 0) || (cj > sizeof(obj32))) {
        LOGPRINT((TRACELOG, "whNT32GdiExtGetObjectW: cj too big to GetObject\n"));
        cj = sizeof(obj32);
    }
    ci = cj;

    // Copied from ntgdi.c
    // make the getobject call on brush
    // still work even the app passes in
    // a cj < sizeof(LOGBRUSH)
    //
    if (iType == LO_BRUSH_TYPE) {
        cj = sizeof(NT32LOGBRUSH);
        pvBuf = pvOut ? &obj32 : NULL;
    }

    iRet = whNT32GreExtGetObjectW(h, cj, pvBuf);

    if (iType == LO_BRUSH_TYPE && pvBuf != NULL && iRet > 0) {
       cj = min(cj, ci);
       RtlCopyMemory(pvOut, pvBuf, min(cj,iRet));
    }

    return iRet;
}
)
End=
Begin=
@GenApiThunk(whNT32GdiExtGetObjectW)
End=

TemplateName=NtGdiGetFontData
PreCall=
// This function returns font data that an app can use to embed a font in a doc. @NL
// If this data changes, it is probably a bug since it would probably break word documents. @NL
End=

TemplateName=NtGdiGetFontResourceInfoInternalW
Case=(GFRI_NUMFONTS,PULONG)
Case=(GFRI_DESCRIPTION,PWCHAR)
Case=(GFRI_LOGFONTS,LOGFONTW*)
Case=(GFRI_ISTRUETYPE,PBOOL)
Case=(GFRI_ISREMOVED,PBOOL)
Begin=
@GenDebugNonPtrDepCases(@ApiName,iType)
End=

TemplateName=NtGdiGetStats
Case=(GS_NUM_OBJS_ALL,PULONG)
Case=(GS_HANDOBJ_CURRENT,PULONG)
Case=(GS_HANDOBJ_MAX,PULONG)
Case=(GS_HANDOBJ_ALLOC,PULONG)
Case=(GS_LOOKASIDE_INFO,PULONG)
Begin=
@GenDebugNonPtrDepCases(@ApiName,iIndex)
End=

TemplateName=NtGdiGetOutlineTextMetricsInternalW
NoType=potmw
Locals=
NT32OUTLINETEXTMETRIC NT32TextMetricTemp; @NL
BOOL bLengthOnly = FALSE; @NL
End=
PreCall=
// If cjotm is 0, the kernel internally sets potmw to NULL. @NL
// Important: the difference between a OUTLINETEXTMETRICW with strings and the @NL
// 32BIT OUTLINETEXTMETRICW is ALIGN4(sizeof(OUTLINETEXTMETRICW) - ALIGN4(sizeof(NT32OUTLINETEXTMETRICW) @NL
// @NL
@NL
#define OUTLINETEXTMETRICWDELTA (ALIGN4(sizeof(OUTLINETEXTMETRICW)) - ALIGN4(sizeof(NT32OUTLINETEXTMETRICW))) @NL
#define ADJUSTOTMWFIELD32M(p,f,o) (((NT32OUTLINETEXTMETRICW *)p)->f = (NT32PSTR)((PBYTE)(((NT32OUTLINETEXTMETRICW *)p)->f) - (o))) @NL
#define OTMWOFFSETTOPTR32(p,f) ((WCHAR*)((PBYTE)(p) + (ULONG)((NT32OUTLINETEXTMETRICW *)(p))->f)) @NL
#define OTMWOFFSETTOPTR64(p,f) ((WCHAR*)((PBYTE)(p) + (ULONGLONG)((OUTLINETEXTMETRICW *)(p))->f)) @NL
@NL
if (WOW64_ISPTR(potmwHost) && cjotm != 0) { @Indent(
   // Increase the size of the buffer by the difference between the size @NL
   // of the NT32 structures and the NT64 structures. @NL
   LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Caller is requesting actual data\n")); @NL
   if (cjotm <= sizeof(NT32OUTLINETEXTMETRICW)) cjotm = sizeof(OUTLINETEXTMETRICW); @NL
   else if (cjotm > sizeof(NT32OUTLINETEXTMETRICW) && cjotm < ALIGN4(sizeof(NT32OUTLINETEXTMETRICW))) RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
   else cjotm += OUTLINETEXTMETRICWDELTA; @NL
   potmw = Wow64AllocateTemp(cjotm); @NL
)} @NL
else {@Indent( @NL
    LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Caller is requesting the length only\n")); @NL
    bLengthOnly = TRUE; @NL
)} @NL
End=
PostCall=
// If cjotm < OUTLINETEXTMETRIC the api will not return the strings. @NL
WOWASSERT( @Indent( @NL
    (bLengthOnly && RetVal == 0) || //Error case @NL
    (bLengthOnly && RetVal >= sizeof(OUTLINETEXTMETRICW)) || //Struct and strings@NL
    (!bLengthOnly && RetVal == 0) || //Error case @NL
    (!bLengthOnly && RetVal == sizeof(OUTLINETEXTMETRICW) && cjotmHost <= sizeof(NT32OUTLINETEXTMETRICW)) || // struct only@NL
    (!bLengthOnly && RetVal >= ALIGN4(sizeof(OUTLINETEXTMETRICW)) && cjotmHost >= ALIGN4(sizeof(NT32OUTLINETEXTMETRICW))) //struct and strings @NL
)); @NL
if (RetVal != 0) { @Indent( @NL

    // Need to thunk the cjotma field of the TMDIFF structure.  This field contains the @NL
    // size of the ANSI version of the returned info.   Lucky, the kernel computes this @NL
    // in cjOTMAWSize by simply adding sizeof(OUTLINETEXTMETRICA)+4 + sizeof strings.  @NL
    // no crazy aligmnent mechanism as with the unicode version. @NL

    // Note that this is done after the standard genthnk thunking so the TMDIFF has @NL
    // already been copied back to the 32bit version. @NL
    if (ARGUMENT_PRESENT(ptmdHost)) { @Indent( @NL
        if (((NT32TMDIFF *)ptmdHost)->cjotma > 0) { @Indent( @NL
            LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Munging cjotma by subtracting %X\n", (ULONG)(sizeof(OUTLINETEXTMETRICA) - sizeof(NT32OUTLINETEXTMETRICA)))); @NL
            ((NT32TMDIFF *)ptmdHost)->cjotma -= sizeof(OUTLINETEXTMETRICA) - sizeof(NT32OUTLINETEXTMETRICA); @NL
        )} @NL
    )} @NL

    // Since the buffer length was forced to be a minumum of sizeof(OUTLINETEXTMETRICW), @NL
    // the returned size will always be at least sizeof(OUTLINETEXTMETRICW).             @NL
    // The kernel also places the strings at the end of the buffer if it has room.       @NL
    if (bLengthOnly) { @Indent( @NL
        LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Returning length - %X\n", (ULONG)OUTLINETEXTMETRICWDELTA)); @NL
        RetVal -=  OUTLINETEXTMETRICWDELTA; @NL
    )} @NL
    else { @Indent( @NL
       // Since we are retrieving the actual data here, the return size will be at least @NL
       // sizeof(OUTLINETEXTMETRICW) since the buffer length was forced to be it as a min. @NL
       // The returned data can either be the OUTLINETEXTMETRIC structure, or the structure @NL
       // followed by several string.   Copy the structure to a temp since it will always be @NL
       // returned. @NL
       @ForceType(PostCall,potmw,&NT32TextMetricTemp,OUTLINETEXTMETRICW*,OUT)
       NT32TextMetricTemp.otmSize -= OUTLINETEXTMETRICWDELTA; @NL

       // Copy the structure back to the user's buffer. @NL
       if (cjotmHost <= sizeof(NT32OUTLINETEXTMETRICW)) { @Indent( @NL
           LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Caller only wants part of main structure.\n")); @NL
           RetVal = min(cjotmHost, RetVal); @NL
           RtlCopyMemory((PVOID)potmwHost, &NT32TextMetricTemp, RetVal);  @NL
       )} @NL
       else { @Indent( @NL
          // Ok, here is a major trick.   The kernel always returns everything in one big chunk. @NL
          // The strings always follow the struct at ALIGN4(sizeof(OUTLINETEXTMETRICW)). @NL
          // Thus all that is needed is paste the converted section together with the pointer @NL
          // independent section and adjust the pointers by a fixed offset. @NL

          LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Caller want mains structure plus some data.\n")); @NL
          RtlCopyMemory((PVOID)potmwHost, &NT32TextMetricTemp, sizeof(NT32OUTLINETEXTMETRICW)); @NL

          // Copy the strings which are not pointer dependent. @NL
          LOGPRINT((TRACELOG, "NtGdiGetOutlineTextMetricsInternalW: Copying string block.\n")); @NL
          RtlCopyMemory((PBYTE)potmwHost + ALIGN4(sizeof(NT32OUTLINETEXTMETRICW)),
                        (PBYTE)potmw + ALIGN4(sizeof(OUTLINETEXTMETRICW)),
                        RetVal - ALIGN4(sizeof(OUTLINETEXTMETRICW))); @NL

          // Decrease the string offsets by the deltas. @NL
          WOWASSERT(((NT32OUTLINETEXTMETRICW *)potmwHost)->otmpFamilyName >= ALIGN4(sizeof(OUTLINETEXTMETRICW))); @NL
          WOWASSERT(((NT32OUTLINETEXTMETRICW *)potmwHost)->otmpFaceName >= ALIGN4(sizeof(OUTLINETEXTMETRICW))); @NL
          WOWASSERT(((NT32OUTLINETEXTMETRICW *)potmwHost)->otmpStyleName >= ALIGN4(sizeof(OUTLINETEXTMETRICW))); @NL
          WOWASSERT(((NT32OUTLINETEXTMETRICW *)potmwHost)->otmpFullName >= ALIGN4(sizeof(OUTLINETEXTMETRICW))); @NL

          ADJUSTOTMWFIELD32M(potmwHost,otmpFamilyName,OUTLINETEXTMETRICWDELTA); @NL
          ADJUSTOTMWFIELD32M(potmwHost,otmpFaceName,OUTLINETEXTMETRICWDELTA); @NL
          ADJUSTOTMWFIELD32M(potmwHost,otmpStyleName,OUTLINETEXTMETRICWDELTA); @NL
          ADJUSTOTMWFIELD32M(potmwHost,otmpFullName,OUTLINETEXTMETRICWDELTA); @NL
          RetVal -= OUTLINETEXTMETRICWDELTA; @NL

          // Test to ensure that the offsets were adjusted correctly @NL
          WOWASSERT(wcscmp(OTMWOFFSETTOPTR32(potmwHost,otmpFamilyName), OTMWOFFSETTOPTR64(potmw,otmpFamilyName)) == 0); @NL
          WOWASSERT(wcscmp(OTMWOFFSETTOPTR32(potmwHost,otmpFaceName), OTMWOFFSETTOPTR64(potmw,otmpFaceName)) == 0); @NL
          WOWASSERT(wcscmp(OTMWOFFSETTOPTR32(potmwHost,otmpStyleName), OTMWOFFSETTOPTR64(potmw,otmpStyleName)) == 0); @NL
          WOWASSERT(wcscmp(OTMWOFFSETTOPTR32(potmwHost,otmpFullName), OTMWOFFSETTOPTR64(potmw,otmpFullName)) == 0); @NL

       )} @NL
    )} @NL
#undef OUTLINETEXTMETRICWDELTA @NL
#undef ADJUSTOTMWFIELD32 @NL
#undef OTMWOFFSETTOPTR32 @NL
#undef OTMWOFFSETTOPTR64 @NL
)} @NL
End=

TemplateName=NtGdiOpenDCW
NoType=pDriverInfo2
Locals=
@Types(Locals,pDriverInfo2,DRIVER_INFO_2W*)
End=
PreCall=
@Types(PreCall,pDriverInfo2,DRIVER_INFO_2W*)
End=
PostCall=
@Types(PostCall,pDriverInfo2,DRIVER_INFO_2W*)
End=

TemplateName=NtGdiPolyPatBlt
NoType=pPoly
PreCall=
{ @Indent( @NL
   SIZE_T i; @NL
   LARGE_INTEGER Temp; @NL
   NT32POLYPATBLT *Src = (NT32POLYPATBLT *)pPolyHost;  @NL
   pPoly = (PPOLYPATBLT)Wow64AllocateTemp(sizeof(POLYPATBLT) * Count); @NL
   for(i=0; i < Count; i++) { @Indent( @NL
       pPoly[i].x = (int)Src[i].x; @NL
       pPoly[i].y = (int)Src[i].y; @NL
       pPoly[i].cx = (int)Src[i].cx; @NL
       pPoly[i].cy = (int)Src[i].cy; @NL
       //the structure might be unaligned @NL
       Temp = *(UNALIGNED LARGE_INTEGER *)&(Src[i].BrClr.hbr); @NL
       pPoly[i].BrClr.hbr = *(HBRUSH *)&Temp; @NL
   )} @NL
})
End=

TemplateName=NtGdiResetDC
NoType=pDriverInfo2
Locals=
@Types(Locals,pDriverInfo2,DRIVER_INFO_2W*)
End=
PreCall=
@Types(PreCall,pDriverInfo2,DRIVER_INFO_2W*)
End=
PostCall=
@Types(PostCall,pDriverInfo2,DRIVER_INFO_2W*)
End=

TemplateName=NtUserBuildHimcList
NoType=phimcFirst
PreCall=
phimcFirst = (WOW64_ISPTR(phimcFirstHost)) ? (HIMC *)Wow64AllocateTemp(sizeof(HIMC) * cHimcMax) : (HIMC *)phimcFirstHost; @NL
End=
PostCall=
if (!NT_ERROR(RetVal) && WOW64_ISPTR(phimcFirst)) { @Indent( @NL
   SIZE_T i; @NL
   NT32HIMC *Dest = (NT32HIMC *)phimcFirstHost; @NL
   for(i = 0; i < *pcHimcNeeded; i++) { @Indent( @NL
       Dest[i] = (NT32HIMC)phimcFirst[i]; @NL
   )} @NL
)}@NL
End=

TemplateName=NtUserLoadKeyboardLayoutEx
IndLevel=0
Direction=IN
NoType=pKbdTableMulti
PreCall=
pKbdTableMulti = (PKBDTABLE_MULTI_INTERNAL)UlongToPtr(pKbdTableMultiHost);
End=

TemplateName=NtUserCreateWindowStation
IndLevel=0
Direction=IN
NoType=pKbdTableMulti
PreCall=
pKbdTableMulti = (PKBDTABLE_MULTI_INTERNAL)UlongToPtr(pKbdTableMultiHost);
End=


TemplateName=NtUserBuildHwndList
NoType=phwndFirst
PreCall=
phwndFirst = WOW64_ISPTR(phwndFirstHost) ? (HWND *)Wow64AllocateTemp(sizeof(HWND) * cHwndMax) : (HWND *)phwndFirstHost; @NL
End=
PostCall=
if (!NT_ERROR(RetVal) && WOW64_ISPTR(phwndFirst)) { @Indent( @NL
   SIZE_T i; @NL
   NT32HWND *Dest = (NT32HWND *)phwndFirstHost; @NL
   for(i=0; i < *pcHwndNeeded; i++) { @Indent( @NL
       Dest[i] = (NT32HWND)phwndFirst[i]; @NL
   )} @NL
)} @NL
End=

TemplateName=NtUserBuildPropList
NoType=pPropSet
PreCall=
pPropSet = WOW64_ISPTR(pPropSetHost) ? (PPROPSET)Wow64AllocateTemp(sizeof(PROPSET) * cPropMax) : (PPROPSET)pPropSetHost; @NL
End=
PostCall=
if (!NT_ERROR(RetVal) && WOW64_ISPTR(pPropSet)) { @Indent( @NL
    SIZE_T i; @NL
    NT32PROPSET *Dest = (NT32PROPSET *)pPropSetHost; @NL
    for(i=0; i < *pcPropNeeded; i++) { @Indent( @NL
        Dest[i].hData = (NT32HANDLE)pPropSet[i].hData; @NL
        Dest[i].atom = (NT32ATOM)pPropSet[i].atom; @NL
    )} @NL
)} @NL
End=



TemplateName=NtUserInitBrushes
NoType=pahbrSystem
Locals=
// NtUserInitBrushes copies an array of brush handles into pahbrSystem @NL
HBRUSH ahbrSystem[COLOR_MAX]; @NL
End=
PreCall=
pahbrSystem = ahbrSystem; @NL
End=
PostCall=
{ @Indent( @NL
    int i; @NL
    for (i = 0; i < COLOR_MAX; i += 1) { @Indent( @NL
        ((NT32HBRUSH*)pahbrSystemHost)[i] = (NT32HBRUSH)(ahbrSystem[i]); @NL
    )} @NL
)} @NL
End=


TemplateName=NtUserChangeDisplaySettings
PreCall=
// According to MSDN, lParam can point to a RECT structure which @NL
// is not pointer dependent.  @NL
// But, looking at the code for user32 shows that this parameter @NL
// is currently unused. @NL
WOWASSERT(sizeof(RECT) == sizeof(NT32RECT));   @NL
End=

TemplateName=NtUserCreateWindowEx
PreCall=
// pParam points to creation parameters that are passed back    @NL
// in the WM_CREATE message of the window. It does not appear   @NL
// that any kernel code is looking at this data, so this        @NL
// data does not need to be thunked.                            @NL
End=

TemplateName=NtUserGetCPD
NoType=dwData
PreCall=
// dwData is a pointer to a WndProc.   Since this is a pointer, it would be sign extended. @NL
dwData = (ULONG_PTR)(LONG)dwDataHost; @NL
End=

TemplateName=NtUserGetKeyboardLayoutList
NoType=lpBuff
PreCall=
lpBuff = WOW64_ISPTR(lpBuffHost) ? (HKL *)Wow64AllocateTemp(sizeof(HKL) * nItems) : (HKL *)lpBuffHost; @NL
End=
PostCall=
if(WOW64_ISPTR(lpBuffHost)) {@Indent( @NL
   SIZE_T i; @NL
   NT32HKL *Dest = (NT32HKL *)lpBuffHost; @NL
   for(i=0;i<nItems;i++) { @Indent( @NL
       Dest[i] = (NT32HKL)lpBuff[i]; @NL
   )} @NL
)} @NL
End=


TemplateName=NtUserGetObjectInformation
Case=(UOI_FLAGS,PUSEROBJECTFLAGS)
Case=(UOI_NAME,PWCHAR)
Case=(UOI_TYPE,PWCHAR)
Case=(UOI_USER_SID,PSID)
Begin=
@GenDebugNonPtrDepCases(@ApiName,nIndex)
End=

TemplateName=NtUserInitializeClientPfnArrays
Begin=
@ApiProlog
@Indent(
    LOGPRINT((TRACELOG, "wh@ApiName(@ApiNum) api thunk: @IfArgs(@ArgList(@ArgName: %x@ArgMore(,)))\n"@IfArgs(, @ArgList((@ArgHostName)@ArgMore(,))))); @NL
    /* @NL
     * don't make the kernel call @NL
     * it is only used from csrss anyhow @NL
     */ @NL
    apfnClientAClient = (const PFNCLIENT *)ppfnClientAHost; @NL
    apfnClientWClient = (const PFNCLIENT *)ppfnClientWHost; @NL
    apfnClientWorkerClient = (const PFNCLIENTWORKER *)ppfnClientWorkerHost; @NL

    return STATUS_SUCCESS; @NL
)
}
End=

TemplateName=NtUserPaintDesktop
Header=
@NoFormat(
BOOL NtUserPaintDesktopInternal(
    IN HDC hdc)
{

   BOOL RetVal;
   ULONG hdclocal;
   // HACK, HACK. Try the API with sign extension first.
   RetVal = NtUserPaintDesktop(hdc);
   if (RetVal) {
      return RetVal;
   }

   // Try the API with zero extension.
   hdclocal = (ULONG)HandleToLong(hdc);
   return NtUserPaintDesktop((HDC)hdclocal);
}
)
End=
Begin=
@GenApiThunk(NtUserPaintDesktopInternal)
End=

TemplateName=NtUserSetObjectInformation
Case=(UOI_FLAGS,PUSEROBJECTFLAGS)
Begin=
@GenDebugNonPtrDepCases(@ApiName,nIndex)
End=

TemplateName=NtUserSetClassLong
Header=
LONG whNtUserSetClassLongInternal(IN  HWND hwnd,IN  int nIndex,OUT LONG dwNewLong,IN  BOOL bAnsi) { @Indent( @NL

    if (nIndex < 0) { @Indent( @NL

        ULONG_PTR RetVal64;  @NL
        if (nIndex == GCLP_MENUNAME) { @Indent( @NL
            CLSMENUNAME *pcmn;  @NL
            @ForceType(Locals, pcmn, ((NT32CLSMENUNAME*)dwNewLong), PCLSMENUNAME,IN OUT)   @NL
            @ForceType(PreCall, pcmn, ((NT32CLSMENUNAME*)dwNewLong), PCLSMENUNAME,IN OUT)  @NL
            RetVal64 = NtUserSetClassLongPtr(hwnd, nIndex, (ULONG_PTR)pcmn, bAnsi);        @NL
            @ForceType(PostCall, pcmn, ((NT32CLSMENUNAME*)dwNewLong), PCLSMENUNAME,IN OUT) @NL
            return (LONG)RetVal64;                                                         @NL
        }) @NL
        
        if (nIndex == GCLP_WNDPROC) { @Indent( @NL
            dwNewLong = (LONG)NtWow64MapClientFnToKernelClientFn((KPROC)((ULONG_PTR)dwNewLong)); @NL
        }) @NL

        RetVal64 = NtUserSetClassLongPtr(hwnd, nIndex, (ULONG_PTR)dwNewLong, bAnsi);   @NL
        if (nIndex == GCLP_WNDPROC) { @Indent( @NL
            RetVal64 = NtWow64MapKernelClientFnToClientFn((KPROC)RetVal64);  @NL
        }) @NL

        return (LONG)RetVal64; @NL

    }) @NL

    // The default case is to just call NtUserSetCallLong             @NL
    return NtUserSetClassLong(hwnd,nIndex,dwNewLong,bAnsi); @NL

} @NL
) @NL
End=
Begin=
@GenApiThunk(whNtUserSetClassLongInternal)
End=

TemplateName=NtUserSetWindowWord
Header=
@NoFormat(

#define NT32DWL_MSGRESULT   0
#define NT32DWL_DLGPROC     4
#define NT32DWL_USER        8

WORD whNtUserSetWindowWordInternal(
    IN HWND hwnd,
    IN int nIndex,
    IN WORD wNewWord) {

// This function is needed to translate values used by the 32bit SetWindowWord into the
// values used by the 64bit SetWindowWord.

  PWND pwnd;

  if (nIndex >= 0) {

      pwnd = Wow64ValidateHwnd(hwnd);
      if (!pwnd) {
         return 0;
      }

      if (TestWF(pwnd, WFDIALOGWINDOW)) {

          LOGPRINT((TRACELOG, "NtUserSetWindowWord: Window is a dialog box\n"));

          if (nIndex >= NT32DWL_USER && nIndex <= NT32DWL_USER+sizeof(WORD)) {
              nIndex = (nIndex - NT32DWL_USER) + DWLP_USER;
          }
          else if (nIndex >= NT32DWL_DLGPROC && nIndex <= NT32DWL_DLGPROC+sizeof(WORD)) {
              nIndex = (nIndex - NT32DWL_DLGPROC) + DWLP_DLGPROC;
          }
          else if (nIndex >= NT32DWL_MSGRESULT && nIndex <= NT32DWL_MSGRESULT+sizeof(WORD)) {
              nIndex = (nIndex - NT32DWL_MSGRESULT) + DWLP_MSGRESULT;
          }
          else if (nIndex < DLGWINDOWEXTRA) {
              LOGPRINT((ERRORLOG, "NtUserSetWindowWord: app is trying to set an invalid index for a dialog box\n"));
              LOGPRINT((ERRORLOG, "NtUserSetWindowWord: calling kernel will invalid index to set the error code.\n"));
              nIndex = DLGWINDOWEXTRA - 1; //This is an invalid index.
          }

          // Fall through and just use the specified index.
      }

  }

  return NtUserSetWindowWord(hwnd, nIndex, wNewWord);

}
)
End=
Begin=
@GenApiThunk(whNtUserSetWindowWordInternal)
End=

TemplateName=NtUserSetWindowLong
Header=
@NoFormat(
LONG whNtUserSetWindowLongInternal(IN HWND hwnd,IN int nIndex,IN LONG dwNewLong,IN BOOL bAnsi) {

    LONG RetVal;
    PWND pwnd;

    if (nIndex < 0) {
       RetVal = (DWORD) NtUserSetWindowLongPtr(hwnd, nIndex, (ULONG_PTR)dwNewLong, bAnsi);
       if (nIndex == GWLP_WNDPROC) {
           RetVal = (DWORD) NtWow64MapKernelClientFnToClientFn((KPROC)RetVal);
       }
       return RetVal;
    }

    pwnd = Wow64ValidateHwnd(hwnd);
    if (!pwnd) {
       return 0;
    }
    if (GETFNID(pwnd) != 0) {
        if (!TestWF(pwnd, WFDIALOGWINDOW)) {
             if (nIndex >= 0 &&
                    (nIndex < (int)(CBFNID(pwnd->fnid)-sizeof(WND)))) {
                switch (GETFNID(pwnd)) {
                case FNID_BUTTON:
                case FNID_COMBOBOX:
                case FNID_COMBOLISTBOX:
                case FNID_DIALOG:
                case FNID_LISTBOX:
                case FNID_STATIC:
                case FNID_EDIT:
#ifdef FE_IME @NL
                case FNID_IME:
#endif @NL
                    /*
                     * Allow the 0 index for controls to be set if it's
                     * still NULL or the window is being destroyed. This
                     * is where controls store their private data.
                     */
                    if (nIndex == 0) {
                        return (DWORD) NtUserSetWindowLongPtr(hwnd, nIndex, (ULONG_PTR)dwNewLong, bAnsi);
                    }
                    break;
                case FNID_MDICLIENT:
                    /*
                     * Allow the 0 index (which is reserved) to be set/get.
                     * Quattro Pro 1.0 uses this index!
                     */
                    if (nIndex == 0) {
                        return (DWORD) NtUserSetWindowLongPtr(hwnd, nIndex, (ULONG_PTR)dwNewLong, bAnsi);
                    }
                    if (nIndex == GWLP_MDIDATA) {
                        return (DWORD) NtUserSetWindowLongPtr(hwnd, nIndex, (ULONG_PTR)dwNewLong, bAnsi);
                    }
                    break;
                }
            }
        }
    }

    // Default case.  Just call NtUserSetWindowLong
    return NtUserSetWindowLong(hwnd, nIndex, dwNewLong, bAnsi);

}
)
End=
Begin=
@GenApiThunk(whNtUserSetWindowLongInternal)
End=

TemplateName=NtUserSendInput
NoType=pInputs
Locals=
UINT count; @NL
PINPUT pInput64; @NL
NT32INPUT *pInput32; @NL
PreCall=
if (cbSize != sizeof(NT32INPUT) || 0 == cInputs || !ARGUMENT_PRESENT(pInputsHost)) { @Indent( @NL
    RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
)} @NL
cbSize = sizeof(INPUT);@NL
pInputs = pInput64 = Wow64AllocateTemp(cInputs * cbSize); @NL
pInput32 = (NT32INPUT *)pInputsHost; @NL
for(count = 0; count < cInputs; count++,pInput64++,pInput32++) { @Indent( @NL
   switch(pInput64->type = pInput32->type) { @NL
   case INPUT_MOUSE: @NL @Indent(
       @ForceType(PreCall,pInput64->mi,pInput32->mi,MOUSEINPUT,IN)
       break;
   ) @NL
   case INPUT_KEYBOARD: @NL @Indent(
       @ForceType(PreCall,pInput64->ki,pInput32->ki,KEYBDINPUT,IN)
       break;
   ) @NL
   case INPUT_HARDWARE: @NL @Indent(
       @ForceType(PreCall,pInput64->hi,pInput32->hi,HARDWAREINPUT,IN)
       break;
   ) @NL
   default: @NL @Indent(
       LOGPRINT((ERRORLOG, "NtUserSendInputs call with invalid type of %x\n", pInput64->type)); @NL
       WOWASSERT(FALSE);
       break; @NL
   ) @NL
   } @NL
)} @NL
End=

TemplateName=NtUserThunkedMenuInfo
NoType=lpmi
Locals=
@Types(Locals,lpmi,LPMENUINFO)
End=
PreCall=
@Types(PreCall,lpmi,LPMENUINFO)
End=
PostCall=
@Types(PostCall,lpmi,LPMENUINFO)
End=

;; this list comes from windows\published\winuser.w
TemplateName=NtUserSystemParametersInfo
Header=
@NoFormat(
LPVOID 
whCreateAlignedCopy(
    LPVOID lpData, 
    UINT Alignment,
    SIZE_T Size)
{
    LPVOID lpAlignedData;
    if (WOW64_ISPTR(lpData) && ((SIZE_T)lpData % Alignment)) {
        lpAlignedData = Wow64AllocateTemp(Size);
        RtlCopyMemory(lpAlignedData, lpData, Size);
    }
    else {
        lpAlignedData = lpData;
    }
    return lpAlignedData;
}

VOID
whCopyBack(
    LPVOID lpData,
    LPVOID lpAlignedData,
    SIZE_T Size)
{
    if (WOW64_ISPTR(lpData) && WOW64_ISPTR(lpAlignedData) && (lpData != lpAlignedData))
        RtlCopyMemory(lpData, lpAlignedData, Size);
}
)
End=
Case=(SPI_GETBEEP,GET,PBOOL)
Case=(SPI_SETBEEP,NEITHER,X)
Case=(SPI_GETMOUSE,GET,LPINT,ARRAY_OF_3)
Case=(SPI_SETMOUSE,SET,LPINT,ARRAY_OF_3)
Case=(SPI_GETBORDER,GET,LPINT)
Case=(SPI_SETBORDER,NEITHER,X)
Case=(SPI_TIMEOUTS,NEITHER,X)
Case=(SPI_KANJIMENU,NEITHER,X)
Case=(SPI_GETKEYBOARDSPEED,GET,LPINT)
Case=(SPI_SETKEYBOARDSPEED,NEITHER,X)
Case=(SPI_LANGDRIVER,NEITHER,X)
Case=(SPI_ICONHORIZONTALSPACING,GET,LPINT)
Case=(SPI_GETSCREENSAVETIMEOUT,GET,LPINT)
Case=(SPI_SETSCREENSAVETIMEOUT,NEITHER,X)
Case=(SPI_GETSCREENSAVEACTIVE,GET,LPBOOL)
Case=(SPI_SETSCREENSAVEACTIVE,NEITHER,X)
Case=(SPI_GETGRIDGRANULARITY,NEITHER,X)
Case=(SPI_SETGRIDGRANULARITY,NEITHER,X)
Case=(SPI_SETDESKWALLPAPER,SET,PUNICODE_STRING)
Case=(SPI_SETDESKPATTERN,SET,LPWSTR)
Case=(SPI_GETKEYBOARDDELAY,GET,LPINT)
Case=(SPI_SETKEYBOARDDELAY,NEITHER,X)
Case=(SPI_ICONVERTICALSPACING,GET,LPINT)
Case=(SPI_GETICONTITLEWRAP,GET,LPINT)
Case=(SPI_SETICONTITLEWRAP,NEITHER,X)
Case=(SPI_GETMENUDROPALIGNMENT,GET,int*)
Case=(SPI_SETMENUDROPALIGNMENT,NEITHER,X)
Case=(SPI_SETDOUBLECLKWIDTH,NEITHER,X)
Case=(SPI_SETDOUBLECLKHEIGHT,NEITHER,X)
Case=(SPI_GETICONTITLELOGFONT,GET,LPLOGFONTW)
Case=(SPI_SETDOUBLECLICKTIME,NEITHER,X)
Case=(SPI_SETMOUSEBUTTONSWAP,NEITHER,X)
Case=(SPI_SETICONTITLELOGFONT,SET,LPLOGFONTW)
Case=(SPI_GETFASTTASKSWITCH,GET,PINT)
Case=(SPI_SETFASTTASKSWITCH,NEITHER,X)
Case=(SPI_SETDRAGFULLWINDOWS,NEITHER,X)
Case=(SPI_GETDRAGFULLWINDOWS,GET,PINT)
Case=(SPI_UNUSED39,NEITHER,X)
Case=(SPI_UNUSED40,NEITHER,X)
Case=(SPI_GETNONCLIENTMETRICS,GET,LPNONCLIENTMETRICS)
Case=(SPI_SETNONCLIENTMETRICS,SET,LPNONCLIENTMETRICS)
Case=(SPI_GETMINIMIZEDMETRICS,GET,LPMINIMIZEDMETRICS)
Case=(SPI_SETMINIMIZEDMETRICS,SET,LPMINIMIZEDMETRICS)
Case=(SPI_GETICONMETRICS,GET,LPICONMETRICS)
Case=(SPI_SETICONMETRICS,SET,LPICONMETRICS)
Case=(SPI_GETWORKAREA,GET,LPRECT)
Case=(SPI_SETWORKAREA,SET,LPRECT)
Case=(SPI_SETPENWINDOWS,NEITHER,X)
Case=(SPI_GETHIGHCONTRAST,GET,LPHIGHCONTRAST)
Case=(SPI_SETHIGHCONTRAST,SET,LPHIGHCONTRAST)
Case=(SPI_GETKEYBOARDPREF,GET,PBOOL)
Case=(SPI_SETKEYBOARDPREF,NEITHER,X)
Case=(SPI_GETSCREENREADER,GET,PBOOL)
Case=(SPI_SETSCREENREADER,NEITHER,X)
Case=(SPI_GETANIMATION,GET,LPANIMATIONINFO)
Case=(SPI_SETANIMATION,SET,LPANIMATIONINFO)
Case=(SPI_GETFONTSMOOTHING,GET,LPINT)
Case=(SPI_SETFONTSMOOTHING,NEITHER,X)
Case=(SPI_SETDRAGWIDTH,NEITHER,X)
Case=(SPI_SETDRAGHEIGHT,NEITHER,X)
Case=(SPI_SETHANDHELD,NEITHER,X)
Case=(SPI_GETLOWPOWERTIMEOUT,GET,LPINT)
Case=(SPI_GETPOWEROFFTIMEOUT,GET,LPINT)
Case=(SPI_SETLOWPOWERTIMEOUT,NEITHER,X)
Case=(SPI_SETPOWEROFFTIMEOUT,NEITHER,X)
Case=(SPI_GETLOWPOWERACTIVE,GET,LPBOOL)
Case=(SPI_GETPOWEROFFACTIVE,GET,LPBOOL)
Case=(SPI_SETLOWPOWERACTIVE,NEITHER,X)
Case=(SPI_SETPOWEROFFACTIVE,NEITHER,X)
Case=(SPI_SETCURSORS,NEITHER,X)
Case=(SPI_SETICONS,NEITHER,X)
Case=(SPI_GETDEFAULTINPUTLANG,GET,PHKL)     ; see below
Case=(SPI_SETDEFAULTINPUTLANG,SET,PHKL)     ; see below
Case=(SPI_SETLANGTOGGLE,NEITHER,X)
Case=(SPI_GETWINDOWSEXTENSION,NEITHER,X)
Case=(SPI_SETMOUSETRAILS,NEITHER,X)
Case=(SPI_GETMOUSETRAILS,NEITHER,X)
Case=(SPI_SETSCREENSAVERRUNNING,NEITHER,X)
Case=(SPI_GETFILTERKEYS,GET,LPFILTERKEYS)
Case=(SPI_SETFILTERKEYS,SET,LPFILTERKEYS)
Case=(SPI_GETTOGGLEKEYS,GET,LPTOGGLEKEYS)
Case=(SPI_SETTOGGLEKEYS,SET,LPTOGGLEKEYS)
Case=(SPI_GETMOUSEKEYS,GET,LPMOUSEKEYS)
Case=(SPI_SETMOUSEKEYS,SET,LPMOUSEKEYS)
Case=(SPI_SETSHOWSOUNDS,NEITHER,X)
Case=(SPI_GETSHOWSOUNDS,GET,PINT)
Case=(SPI_GETSTICKYKEYS,GET,LPSTICKYKEYS)
Case=(SPI_SETSTICKYKEYS,SET,LPSTICKYKEYS)
Case=(SPI_GETACCESSTIMEOUT,GET,LPACCESSTIMEOUT)
Case=(SPI_SETACCESSTIMEOUT,SET,LPACCESSTIMEOUT)
Case=(SPI_GETSERIALKEYS,NEITHER,X)
Case=(SPI_SETSERIALKEYS,NEITHER,X)
Case=(SPI_GETSOUNDSENTRY,Get,LPSOUNDSENTRY)    ; see below
Case=(SPI_SETSOUNDSENTRY,Set,LPSOUNDSENTRY)    ; see below
Case=(SPI_GETSNAPTODEFBUTTON,GET,LPBOOL)
Case=(SPI_SETSNAPTODEFBUTTON,NEITHER,X)
Case=(SPI_GETMOUSEHOVERWIDTH,GET,UINT*)
Case=(SPI_SETMOUSEHOVERWIDTH,NEITHER,X)
Case=(SPI_GETMOUSEHOVERHEIGHT,GET,UINT*)
Case=(SPI_SETMOUSEHOVERHEIGHT,NEITHER,X)
Case=(SPI_GETMOUSEHOVERTIME,GET,UINT*)
Case=(SPI_SETMOUSEHOVERTIME,NEITHER,X)
Case=(SPI_GETWHEELSCROLLLINES,GET,LPDWORD)
Case=(SPI_SETWHEELSCROLLLINES,NEITHER,X)
Case=(SPI_GETMENUSHOWDELAY,GET,LPDWORD)
Case=(SPI_SETMENUSHOWDELAY,NEITHER,X)
Case=(SPI_UNUSED108,NEITHER,X)
Case=(SPI_UNUSED109,NEITHER,X)
Case=(SPI_SETSHOWIMEUI,NEITHER,X)
Case=(SPI_GETSHOWIMEUI,GET,LPBOOL)
Case=(SPI_SETMOUSESPEED,NEITHER,X)
Case=(SPI_GETMOUSESPEED,GET,LPINT)
Case=(SPI_GETSCREENSAVERRUNNING,GET,LPBOOL)
Case=(SPI_GETDESKWALLPAPER,GET,LPWSTR)
Case=(SPI_GETACTIVEWINDOWTRACKING,GET,LPBOOL)
Case=(SPI_SETACTIVEWINDOWTRACKING,NEITHER,X)
Case=(SPI_GETMENUANIMATION,GET,LPBOOL)
Case=(SPI_SETMENUANIMATION,NEITHER,X)
Case=(SPI_GETCOMBOBOXANIMATION,GET,LPBOOL)
Case=(SPI_SETCOMBOBOXANIMATION,NEITHER,X)
Case=(SPI_GETLISTBOXSMOOTHSCROLLING,GET,LPBOOL)
Case=(SPI_SETLISTBOXSMOOTHSCROLLING,NEITHER,X)
Case=(SPI_GETGRADIENTCAPTIONS,GET,LPBOOL)
Case=(SPI_SETGRADIENTCAPTIONS,NEITHER,X)
Case=(SPI_GETKEYBOARDCUES,GET,LPBOOL)
Case=(SPI_SETKEYBOARDCUES,NEITHER,X)
;Case=(SPI_GETMENUUNDERLINES,GET,LPBOOL)    ; alias for GETKEYBOARDCUES
;Case=(SPI_SETMENUUNDERLINES,NEITHER,X)     ; alias for SETKEYBOARDCUES
Case=(SPI_GETACTIVEWNDTRKZORDER,GET,LPBOOL)
Case=(SPI_SETACTIVEWNDTRKZORDER,NEITHER,X)
Case=(SPI_GETHOTTRACKING,GET,LPBOOL)
Case=(SPI_SETHOTTRACKING,NEITHER,X)
Case=(SPI_UNUSED1010,GET,LPBOOL)
Case=(SPI_UNUSED1011,NEITHER,X)
Case=(SPI_GETMENUFADE,GET,LPBOOL)
Case=(SPI_SETMENUFADE,NEITHER,X)
Case=(SPI_GETSELECTIONFADE,GET,LPBOOL)
Case=(SPI_SETSELECTIONFADE,NEITHER,X)
Case=(SPI_GETTOOLTIPANIMATION,GET,LPBOOL)
Case=(SPI_SETTOOLTIPANIMATION,NEITHER,X)
Case=(SPI_GETTOOLTIPFADE,GET,LPBOOL)
Case=(SPI_SETTOOLTIPFADE,NEITHER,X)
Case=(SPI_GETCURSORSHADOW,GET,LPBOOL)
Case=(SPI_SETCURSORSHADOW,NEITHER,X)
Case=(SPI_GETUIEFFECTS,GET,LPBOOL)
Case=(SPI_SETUIEFFECTS,NEITHER,X)
Case=(SPI_GETFOREGROUNDLOCKTIMEOUT,GET,LPDWORD)
Case=(SPI_SETFOREGROUNDLOCKTIMEOUT,NEITHER,X)
Case=(SPI_GETACTIVEWNDTRKTIMEOUT,GET,LPDWORD)
Case=(SPI_SETACTIVEWNDTRKTIMEOUT,NEITHER,X)
Case=(SPI_GETFOREGROUNDFLASHCOUNT,GET,LPDWORD)
Case=(SPI_SETFOREGROUNDFLASHCOUNT,NEITHER,X)
Case=(SPI_GETCARETWIDTH,GET,LPDWORD)
Case=(SPI_SETCARETWIDTH,NEITHER,X)
Case=(SPI_GETFLATMENU,GET,PBOOL)
Case=(SPI_SETFLATMENU,NEITHER,X)
Case=(SPI_GETMOUSESONAR,GET,PBOOL)
Case=(SPI_SETMOUSESONAR,NEITHER,X)
Case=(SPI_GETMOUSECLICKLOCK,GET,PBOOL)
Case=(SPI_SETMOUSECLICKLOCK,NEITHER,X)
Case=(SPI_GETMOUSEVANISH,GET,PBOOL)
Case=(SPI_SETMOUSEVANISH,NEITHER,X)
Case=(SPI_GETDROPSHADOW,GET,PBOOL)
Case=(SPI_SETDROPSHADOW,NEITHER,X)
Case=(SPI_GETMOUSECLICKLOCKTIME,GET,LPDWORD)
Case=(SPI_SETMOUSECLICKLOCKTIME,NEITHER,X)
Case=(SPI_GETFONTSMOOTHINGTYPE,GET,LPDWORD)
Case=(SPI_SETFONTSMOOTHINGTYPE,NEITHER,X)
Case=(SPI_GETFONTSMOOTHINGCONTRAST,GET,LPDWORD)
Case=(SPI_SETFONTSMOOTHINGCONTRAST,NEITHER,X)
Case=(SPI_GETFOCUSBORDERWIDTH,GET,LPINT)
Case=(SPI_SETFOCUSBORDERWIDTH,NEITHER,X)
Case=(SPI_GETFOCUSBORDERHEIGHT,GET,LPINT)
Case=(SPI_SETFOCUSBORDERHEIGHT,NEITHER,X)
PreCall=
switch(wFlag) { @Indent(@NL
   case SPI_SETDEFAULTINPUTLANG: @NL @Indent(
       { @Indent(                                            @NL
           if (WOW64_ISPTR(lpData)) { @Indent(               @NL
               lpData = Wow64AllocateTemp(sizeof(HKL));      @NL
               *(HKL *)lpData = (HKL)*(NT32HKL *)lpDataHost; @NL
           )}                                                @NL
           break;                                            @NL
        )}                                                   @NL
   )
   case SPI_GETDEFAULTINPUTLANG: @NL @Indent(
       { @Indent(                                      @NL
           if (WOW64_ISPTR(lpData)) { @Indent(         @NL
              lpData = Wow64AllocateTemp(sizeof(HKL)); @NL
           )}                                          @NL
           break;                                      @NL
       )}                                              @NL
   )
   case SPI_GETSOUNDSENTRY: @NL @Indent(
       if (wParam != sizeof(NT32SOUNDSENTRY) || lpData == NULL) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_GETSOUNDSENTRY: Invalid parameters\n"); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       if (((NT32SOUNDSENTRY *)(lpData))->cbSize != sizeof(NT32SOUNDSENTRY)) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_GETSOUNDSENTRY: PSOUNDSENTRY: An cbSize of %x was passed to API, but %x was expected\n",
           sizeof(NT32SOUNDSENTRY), ((NT32SOUNDSENTRY *)(lpData))->cbSize));  @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       lpData = Wow64AllocateTemp(sizeof(SOUNDSENTRY)); @NL
       ((SOUNDSENTRY*)lpData)->cbSize = sizeof(SOUNDSENTRY); @NL

       break; @NL
   )
   case SPI_SETSOUNDSENTRY: @NL @Indent(
       if (wParam != sizeof(NT32SOUNDSENTRY) || lpData == NULL) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_SETSOUNDSENTRY: Invalid parameters\n"); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       if (((NT32SOUNDSENTRY *)(lpData))->cbSize != sizeof(NT32SOUNDSENTRY)) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_GETSOUNDSENTRY: PSOUNDSENTRY: An cbSize of %x was passed to API, but %x was expected\n",
           sizeof(NT32SOUNDSENTRY), ((NT32SOUNDSENTRY *)(lpData))->cbSize));  @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       { @Indent( @NL
           SOUNDSENTRY *SS,*SSCopy;           @NL
           NT32SOUNDSENTRY *SSHost = lpData;  @NL
           wParam = sizeof(SOUNDSENTRY); @NL
           SS = SSCopy = Wow64AllocateTemp(sizeof(SOUNDSENTRY)); @NL
           @ForceType(PreCall,SS,SSHost,LPSOUNDSENTRY,IN)
           SS->cbSize = sizeof(SOUNDSENTRY); @NL
           lpData = (PVOID)SS; @NL
       )}  @NL
       break; @NL
   )
   case SPI_SETSERIALKEYS: @NL 
   case SPI_GETSERIALKEYS: @NL @Indent(
       if (wParam != sizeof(NT32SERIALKEYS) || lpData == NULL) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_SETSERIALKEYS: Invalid parameters\n"); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       if (((NT32SERIALKEYS *)(lpData))->cbSize != sizeof(NT32SERIALKEYS)) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_GETSERIALKEYS: PSERIALKEYS: An cbSize of %x was passed to API, but %x was expected\n",
           sizeof(NT32SERIALKEYS), ((NT32SERIALKEYS *)(lpData))->cbSize));  @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       { @Indent( @NL
           SERIALKEYS *SS,*SSCopy;           @NL
           NT32SERIALKEYS *SSHost = lpData;  @NL
           wParam = sizeof(SERIALKEYS); @NL
           SS = SSCopy = Wow64AllocateTemp(sizeof(SERIALKEYS)); @NL
           @ForceType(PreCall,SS,SSHost,LPSERIALKEYS,IN)
           SS->cbSize = sizeof(SERIALKEYS); @NL
           lpData = (PVOID)SS; @NL
       )}  @NL
       break; @NL
   )
   case SPI_SETDESKWALLPAPER: @NL @Indent(
       { @Indent(                                      @NL
           if (WOW64_ISPTR(lpData)) { @Indent(         @NL
              PUNICODE_STRING lpData64 = Wow64AllocateTemp(sizeof(UNICODE_STRING)); @NL
              lpData64->Buffer = UlongToPtr(((PUNICODE_STRING32)lpData)->Buffer);@NL
              lpData64->Length = ((PUNICODE_STRING32)lpData)->Length;@NL
              lpData64->MaximumLength = ((PUNICODE_STRING32)lpData)->MaximumLength;@NL
              lpData = (PVOID)lpData64;                @NL
           )}                                          @NL
           break;                                      @NL
       )}                                              @NL
   )   
   case SPI_GETWORKAREA: @NL @Indent(
       {@Indent(                                                           @NL
           lpData = whCreateAlignedCopy(lpData, TYPE_ALIGNMENT(RECT), sizeof(RECT)); @NL
           break;                                                          @NL
       )}                                                                  @NL
   )
   case SPI_GETHIGHCONTRAST: @NL @Indent(
       if (lpData == NULL) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_SETHIGHCONTRASTW: Invalid parameters\n"); @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       if (((NT32HIGHCONTRASTW *)(lpData))->cbSize != sizeof(NT32HIGHCONTRASTW)) { @Indent( @NL
           LOGPRINT((ERRORLOG, "SPI_GETHIGHCONTRASTW: PHIGHCONTRASTW: An cbSize of %x was passed to API, but %x was expected\n",
           sizeof(NT32HIGHCONTRASTW), ((NT32HIGHCONTRASTW *)(lpData))->cbSize));  @NL
           RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
       )} @NL
       { @Indent( @NL
           HIGHCONTRASTW *SS,*SSCopy;           @NL
           NT32HIGHCONTRASTW *SSHost = lpData;  @NL
           wParam = sizeof(HIGHCONTRASTW); @NL
           SS = SSCopy = Wow64AllocateTemp(sizeof(HIGHCONTRASTW)); @NL
           @ForceType(PreCall,SS,SSHost,LPHIGHCONTRASTW,IN)
           SS->cbSize = sizeof(HIGHCONTRASTW); @NL
           lpData = (PVOID)SS; @NL
       )}  @NL
       break; @NL
   )
)}@NL
End=
PostCall=
switch(wFlag) { @Indent(@NL
   case SPI_GETDEFAULTINPUTLANG: @NL @Indent(
       if (WOW64_ISPTR(lpData)) { @Indent(                  @NL
           *(NT32HKL *)lpDataHost = (NT32HKL)*(HKL *)lpData; @NL
       )}                                                   @NL
       break;                                               @NL
   )
   case SPI_GETSOUNDSENTRY: @NL @Indent(
       { @Indent( @NL
           SOUNDSENTRY *SS = (SOUNDSENTRY *)lpData; @NL
           NT32SOUNDSENTRY *SSHost = (NT32SOUNDSENTRY *)lpDataHost;  @NL
           SS->cbSize = sizeof(NT32SOUNDSENTRY); @NL
           @ForceType(PostCall,SS,SSHost,LPSOUNDSENTRY,OUT)
       )} @NL
       break; @NL
   )
   case SPI_GETSERIALKEYS: @NL @Indent(
       { @Indent( @NL
           SERIALKEYS *SS = (SERIALKEYS *)lpData; @NL
           NT32SERIALKEYS *SSHost = (NT32SERIALKEYS *)lpDataHost;  @NL
           SS->cbSize = sizeof(NT32SERIALKEYS); @NL
           @ForceType(PostCall,SS,SSHost,LPSERIALKEYS,OUT)
       )} @NL
       break; @NL
   )
   case SPI_GETWORKAREA: @NL @Indent(
       { @Indent( @NL
           whCopyBack((LPVOID)lpDataHost, lpData, sizeof(RECT)); @NL
       )} @NL
       break; @NL
   )
   case SPI_GETHIGHCONTRAST: @NL @Indent(
       { @Indent( @NL
           HIGHCONTRASTW *SS = (HIGHCONTRASTW *)lpData; @NL
           NT32HIGHCONTRASTW *SSHost = (NT32HIGHCONTRASTW *)lpDataHost;  @NL
           SS->cbSize = sizeof(NT32HIGHCONTRASTW); @NL
           @ForceType(PostCall,SS,SSHost,LPHIGHCONTRASTW,OUT)
       )} @NL
       break; @NL
   )
)}@NL
End=
Begin=
@GenDebugNonPtrDepCases(@ApiName,wFlag)
End=

TemplateName=NtUserCreateInputContext
NoType=dwClientImcData
PreCall=
// dwClientImcData can have the special value of 0, but otherwise the kernel does not @NL
// look at the data. @NL
dwClientImcData = (ULONG_PTR)dwClientImcDataHost; @NL
End=

TemplateName=NtUserUpdateInputContext
NoType=UpdateValue
PreCall=
// UpdateType can either be a UpdateClientInputContext or a UpdateInUseImeWindow. @NL
// If UpdateType is UpdateClientInputContext, UpdateValue is an opaque type to the kernel. @NL
// Thus it is OK to sign extend or not sign extend. @NL
// If UpdateType is UpdateInUseImeWindow, UpdateValue is a HWND. Should be signed extended. @NL
// Thus, sign extend in either case. @NL
UpdateValue = (ULONG_PTR)(LONG)UpdateValueHost; @NL
End=

TemplateName=NtUserVkKeyScanEx
NoType=dwHKLorPKL
PreCall=
// dwHKLorPKL is either a HKL or a PKL.  Both of these need need to be sign extended. @NL
dwHKLorPKL = (ULONG_PTR)(LONG)dwHKLorPKLHost; @NL
End=

TemplateName=NtUserMapVirtualKeyEx
NoType=dwHKLorPKL
PreCall=
// dwHKLorPKL is either a HKL or a PKL.  Both of these need need to be sign extended. @NL
dwHKLorPKL = (ULONG_PTR)(LONG)dwHKLorPKLHost; @NL
End=

TemplateName=NtUserWaitForInputIdle
NoType=idProcess
PreCall=
// idProcess is a ULONG_PTR, but internally a HANDLE. @NL
// Sign extend it.  @NL
idProcess = (ULONG_PTR)(LONG)idProcessHost; @NL
End=

TemplateName=NtUserECQueryInputLangChange
NoType=wParam
PreCall=
// wParam is either LANGCHANGE_FORWARD or LANGCHANGE_BACKWARD @NL
// just use the default processing @NL
wParam = (WPARAM)wParamHost; @NL
End=

TemplateName=NtUserEnumDisplayMonitors
NoType=dwData
PreCall=
// dwData is app defined data.  It will be truncated back at the callback. @NL
dwData = (LPARAM)dwDataHost; @NL
End=


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;
;;   User32 Timer related functions.
;;
;;   A User32 Timer ID is a ULONG_PTR.  Fortunatly, if the timer is associated with
;;   a window the ID is application defined.   If NULL is passed for the window,
;;   the system creates a timer in the range [TIMERID_MIN,TIMERID_MAX] or [0x100, 0x7FFF].
;;   Thus it doesn't matter if the ID is sign extended or not.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TemplateName=NtUserSetTimer
NoType=nIDEvent
PreCall=
nIDEvent = (ULONG_PTR)nIDEventHost; @NL
End=
PostCall=
WOWASSERT(RetVal <= 0xFFFFFFFF); @NL
End=

TemplateName=NtUserSetSystemTimer
NoType=nIDEvent
PreCall=
nIDEvent = (ULONG_PTR)nIDEventHost; @NL
End=
PostCall=
WOWASSERT(RetVal <= 0xFFFFFFFF); @NL
End=

TemplateName=NtUserKillTimer
NoType=nIDEvent
PreCall=
nIDEvent = (ULONG_PTR)nIDEventHost; @NL
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  User32 does not define kernel entry points for several simple functions.
;;  Instead, a few entry points are defined which take a api number to call.
;;  Fortunatly, none of the functions are pointer dependent except the functions
;;  which are called only from CSRSS.
;;
;;  According to JerrySh, all the ULONG_PTR parameters through here should be
;;  sign-extendable including the handles.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtUserCallNoParam
Header=
@NL
#if defined(WOW64DOPROFILE)  @NL
#undef @ApiName_PROFILE_SUBLIST  @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif  @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
End=

TemplateName=NtUserCallOneParam
NoType=dwParam
Header=
@NoFormat(
// BUG BUG HACK HACK Remove before ship!
// This is a hack to get the sign extension right for GDI object untill
// the GDI handle manager is fixed.
ULONG_PTR NtUserCallOneParamInternal(
    IN ULONG_PTR dwParam,
    IN DWORD xpfnProc)
{
    if (SFI__WINDOWFROMDC == xpfnProc) {
        ULONG_PTR Retval;
        ULONG dwParamLocal;

        //Try the signed extended handle first.  If it fails, do the zero extended version.
        Retval = NtUserCallOneParam(dwParam, xpfnProc);
        if (Retval != 0) {
            // the call suceeded, return the result.
            return Retval;
        }

        // The call failed, fall through to the zero extended case
        dwParamLocal = dwParam;
        return NtUserCallOneParam((ULONG_PTR)dwParamLocal, xpfnProc);
    }

    return NtUserCallOneParam(dwParam, xpfnProc);
})
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
dwParam = (ULONG_PTR)(NT32LONG_PTR)dwParamHost; @NL
End=
Begin=
@GenApiThunk(NtUserCallOneParamInternal)
End=

TemplateName=NtUserCallHwnd
Also=NtUserCallHwndOpt
Header=
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif  @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
End=

TemplateName=NtUserCallHwndParam
NoType=dwParam
Header=
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
dwParam = (ULONG_PTR)(NT32LONG_PTR)dwParamHost; @NL
End=

TemplateName=NtUserCallHwndLock
Header=
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
End=

TemplateName=NtUserCallHwndParamLock
NoType=dwParam
Header=
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
dwParam = (ULONG_PTR)(NT32LONG_PTR)dwParamHost; @NL
End=

TemplateName=NtUserCallTwoParam
NoType=dwParam1
NoType=dwParam2
Header=
@NL
#if defined(WOW64DOPROFILE) @NL
#undef @ApiName_PROFILE_SUBLIST @NL
#define @ApiName_PROFILE_SUBLIST &@ApiNameProfileTable @NL
#endif @NL
@NL
End=
PreCall=
USER_LOG_SIMPLE(xpfnProc); @NL
USER_PROFILE_SIMPLE(xpfnProc); @NL
dwParam1 = (ULONG_PTR)(NT32LONG_PTR)dwParam1Host; @NL
dwParam2 = (ULONG_PTR)(NT32LONG_PTR)dwParam2Host; @NL
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; These functions may need revisiting
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtUserSetClipboardData
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserGetClipboardData
Begin=
@GenApiThunk(@ApiName)
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; These functions are messages related APIs
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TemplateName=NtUserCheckImeHotKey
NoType=lParam
PreCall=
// lParam is the LPARAM of a KEYXXX message.   @NL
// So just use the default processing. @NL
lParam = (LPARAM)lParamHost; @NL
End=

TemplateName=NtUserTranslateAccelerator
NoType=lpMsg
Locals=
// Only these messages are actually accepted. @NL
//    WM_SYSKEYDOWN:
//    WM_KEYDOWN:
//    WM_CHAR
//    WM_SYSCHAR
// No special thunking is required. @NL
MSG msg; @NL
End=
PreCall=
lpMsg = Wow64ShallowThunkMSG32TO64(&msg, (NT32MSG *)lpMsgHost); @NL
End=
PostCall=
// Message is an IN Message. @NL
switch(lpMsg->message) {@Indent(
   case WM_SYSKEYDOWN: @NL
   case WM_KEYDOWN: @NL
   case WM_CHAR: @NL
   case WM_SYSCHAR: @Indent( @NL
        break; @NL
   )@NL
   default: @Indent( @NL
        WOWASSERTMSG(!RetVal, "@ApiName translated unthunked message. Possible Error."); @NL
        break;
   )@NL
)}@NL
End=

TemplateName=NtUserTranslateMessage
NoType=lpMsg
Locals=
// Only these messages are actually accepted. @NL
//    WM_SYSKEYDOWN:
//    WM_SYSKEYUP:
//    WM_KEYDOWN:
//    WM_KEYUP:
// No special thunking is required. @NL
MSG msg; @NL
End=
PreCall=
lpMsg = Wow64ShallowThunkMSG32TO64(&msg, (NT32MSG *)lpMsgHost); @NL
End=
PostCall=
// Message is an IN Message. @NL
switch(lpMsg->message) {@Indent(
   case WM_SYSKEYDOWN: @NL
   case WM_SYSKEYUP: @NL
   case WM_KEYDOWN: @NL
   case WM_KEYUP: @Indent( @NL
        break; @NL
   )@NL
   default: @Indent( @NL
        WOWASSERTMSG(!RetVal, "@ApiName translated unthunked message. Possible Error."); @NL
        break;
   )@NL
)}@NL
End=

TemplateName=NtUserCallMsgFilter
NoType=lpMsg
Locals=
//This function invokes the WH_SYSMSGFILTER and WH_MSGFILTER hooks. @NL
//The kernel never deep probes the message, and the hook is not intersendable. @NL
//Thus it doesn't matter how the message is sign extended since the extra bits @NL
//are just going to be chopped off again. @NL
MSG msg; @NL
End=
PreCall=
// Thunk lpMsg. @NL
lpMsg = Wow64ShallowThunkMSG32TO64(&msg, (NT32MSG *)lpMsgHost); // Contains NULL guards. @NL
End=
Postcall=
// Thunk lpMsg. @NL
Wow64ShallowThunkMSG64TO32((NT32MSG *)lpMsgHost, lpMsg); // Contains NULL guards. @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserSendMessageCallback
NoType=dwData
NoType=lParam
NoType=wParam
Header=
@NoFormat(
typedef struct _NTUSERSENDMESSAGECALLBACK_PARMS {
    HWND hwnd;
    UINT wMsg;
    //WPARAM wParam;
    //LPARAM lParam;
    SENDASYNCPROC lpResultCallBack;
    ULONG_PTR dwData;
} NTUSERSENDMESSAGECALLBACK_PARMS, *PNTUSERSENDMESSAGECALLBACK_PARMS;

LONG_PTR whNT32NtUserSendMessageCallbackCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   PNTUSERSENDMESSAGECALLBACK_PARMS params = (PNTUSERSENDMESSAGECALLBACK_PARMS)pContext;

   return NtUserSendMessageCallback(params->hwnd, params->wMsg, wParam, lParam,
                                    params->lpResultCallBack, params->dwData);

}

BOOL whNT32NtUserSendMessageCallbackCall(HWND hwnd, UINT wMsg, WPARAM wParam, LPARAM lParam,
                                         SENDASYNCPROC lpResultCallBack, ULONG_PTR dwData) {

   NTUSERSENDMESSAGECALLBACK_PARMS params;

   params.hwnd = hwnd;
   params.wMsg = wMsg;
   params.lpResultCallBack = lpResultCallBack;
   params.dwData = dwData;

   return (Wow64DoMessageThunk(whNT32NtUserSendMessageCallbackCB, wMsg, wParam, lParam, &params)!=0);

}
)
End=
PreCall=
//dwData is a application defined data that is passed to the callback.  It doesn't matter @NL
//how it is sign extended. @NL
dwData = (ULONG_PTR)dwDataHost; @NL
// wParam and lParam will be thunked by message thunks. @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Begin=
@GenApiThunk(whNT32NtUserSendMessageCallbackCall)
End=


TemplateName=NtUserSendNotifyMessage
NoType=wParam
NoType=lParam
Header=
@NoFormat(

typedef struct _NTUSERSENDNOTIFYMESSAGE_PARMS {
    HWND hwnd;
    UINT wMsg;
    // WPARAM wParam;
    // LPARAM lParam;
} NTUSERSENDNOTIFYMESSAGE_PARMS, *PNTUSERSENDNOTIFYMESSAGE_PARMS;

LONG_PTR whNT32NtUserSendNotifyMessageCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   PNTUSERSENDNOTIFYMESSAGE_PARMS parms = (PNTUSERSENDNOTIFYMESSAGE_PARMS)pContext;

   return NtUserSendNotifyMessage(parms->hwnd, parms->wMsg, wParam, lParam);

}

BOOL whNT32NtUserSendNotifyMessageCall(HWND hwnd, UINT wMsg, WPARAM wParam, LPARAM lParam) {

   NTUSERSENDNOTIFYMESSAGE_PARMS params;

   params.hwnd = hwnd;
   params.wMsg = wMsg;

   return (Wow64DoMessageThunk(whNT32NtUserSendNotifyMessageCB, wMsg, wParam, lParam, &params)!=0);

}

)
End=
PreCall=
// wParam and lParam will be thunked by message thunks. @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Begin=
@GenApiThunk(whNT32NtUserSendNotifyMessageCall)
End=

TemplateName=NtUserPeekMessage
NoType=pmsg
Locals=
// Should only return posted messages which should not have any function pointers.  @NL
// It is ok to just chop information. @NL
MSG msg; @NL
End=
PreCall=
// Handle pmsg(OUT PMSG) @NL
pmsg = WOW64_ISPTR(pmsgHost) ? &msg : (PMSG) pmsgHost; @NL
End=
PostCall=
// Handle pmsg(OUT PMSG) @NL
if (RetVal) Wow64ShallowThunkMSG64TO32((NT32MSG *)pmsgHost, pmsg); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=


TemplateName=NtUserPostMessage
NoType=hwnd
NoType=wParam
NoType=lParam
Header=
@NoFormat(
typedef struct _NTUSERPOSTMESSAGE_PARMS {
    HWND hwnd;
    UINT wMsg;
    // WPARAM wParam;
    // LPARAM lParam;
} NTUSERPOSTMESSAGE_PARMS, *PNTUSERPOSTMESSAGE_PARMS;

LONG_PTR whNT32NtUserPostMessageCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   PNTUSERPOSTMESSAGE_PARMS parms = (PNTUSERPOSTMESSAGE_PARMS)pContext;

   return NtUserPostMessage(parms->hwnd, parms->wMsg, wParam, lParam);

}

BOOL whNT32NtUserPostMessageCall(HWND hwnd, UINT wMsg, WPARAM wParam, LPARAM lParam) {

   NTUSERPOSTMESSAGE_PARMS params;

   params.hwnd = hwnd;
   params.wMsg = wMsg;

   return (Wow64DoMessageThunk(whNT32NtUserPostMessageCB, wMsg, wParam, lParam, &params) != 0);

}
)
End=
PreCall=
// user has a bug where -1 is not handled correctly. @NL
hwnd = (hwndHost == (NT32HWND)0xFFFFFFFF) ? (HWND)0xFFFFFFFF : (HWND)hwndHost; @NL
// wParam and lParam will be thunked by message thunks. @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserPostThreadMessage
NoType=wParam
NoType=lParam
Header=
@NoFormat(
typedef struct _NTUSERPOSTTHREADMESSAGE_PARMS {
    DWORD id;
    UINT msg;
    // WPARAM wParam;
    // LPARAM lParam;
} NTUSERPOSTTHREADMESSAGE_PARMS, *PNTUSERPOSTTHREADMESSAGE_PARMS;

LONG_PTR whNT32NtUserPostThreadMessageCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   PNTUSERPOSTTHREADMESSAGE_PARMS parms = (PNTUSERPOSTTHREADMESSAGE_PARMS)pContext;

   return NtUserPostThreadMessage(parms->id, parms->msg, wParam, lParam);

}

BOOL whNT32NtUserPostThreadMessageCall(DWORD id, UINT msg, WPARAM wParam, LPARAM lParam) {

   NTUSERPOSTTHREADMESSAGE_PARMS params;

   params.id = id;
   params.msg = msg;

   return (Wow64DoMessageThunk(whNT32NtUserPostThreadMessageCB, msg, wParam, lParam, &params)!=0);

}
)
End=
PreCall=
// wParam and lParam will be thunked by message thunks. @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Begin=
@GenApiThunk(whNT32NtUserPostThreadMessageCall)
End=

TemplateName=NtUserQuerySendMessage
PreCall=
NoFormat(
// This private api allows the user to get a copy of the top message on the SentMessages queue.
// Fortunatly, wow appears to be the only code that uses it so it does not need to be supported.
)
End=
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtUserGetMessage
NoType=pmsg
Locals=
// Should only return posted messages which should not have any function pointers.  @NL
// It is ok to just chop information. @NL
MSG msg; @NL
End=
PreCall=
// Handle pmsg(OUT PMSG) @NL
pmsg = WOW64_ISPTR(pmsgHost) ? &msg : (PMSG) pmsgHost; @NL
End=
PostCall=
// Handle pmsg(OUT PMSG) @NL
// The kernel always writes out this structure, even if the API fails. @NL
// Note that this is different from NtUserPeekMessage! @NL
Wow64ShallowThunkMSG64TO32((NT32MSG *)pmsgHost, pmsg); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserRealInternalGetMessage
NoType=pmsg
Locals=
// Should only return posted messages which should not have any function pointers.  @NL
// It is ok to just chop information. @NL
MSG msg; @NL
End=
PreCall=
// Handle pmsg(OUT PMSG) @NL
pmsg = WOW64_ISPTR(pmsgHost) ? &msg : (PMSG) pmsgHost; @NL
End=
PostCall=
// Handle pmsg(OUT PMSG) @NL
// The kernel always writes out this structure, even if the API fails. @NL
// Note that this is different from NtUserPeekMessage! @NL
Wow64ShallowThunkMSG64TO32((NT32MSG *)pmsgHost, pmsg); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserDispatchMessage
NoType=pmsg
Header=
@NoFormat(
LONG_PTR whNT32NtUserDispatchMessageCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   MSG *msg = (MSG *)pContext;
   msg->wParam = wParam;
   msg->lParam = lParam;

   return NtUserDispatchMessage(msg);

}

LONG_PTR whNT32NtUserDispatchMessageCall(MSG *msg) {
   return Wow64DoMessageThunk(whNT32NtUserDispatchMessageCB, msg->message, msg->wParam, msg->lParam, msg);
}
)
End=
Locals=
// Message is sent through the message thunks to thunk WPARAM and LPARAM. @NL
MSG msg; @NL
End=
PreCall=
// Message is an IN message. @NL
pmsg = Wow64ShallowThunkMSG32TO64(&msg, (NT32MSG *)pmsgHost); @NL
End=
PostCall=
// Message is an IN message. @NL
End=
Begin=
@GenApiThunk(whNT32NtUserDispatchMessageCall)
End=

TemplateName=NtUserMessageCall
NoType=lParam
NoType=wParam
NoType=xParam
Header=
@NoFormat(

LONG_PTR whNT32NtUserMessageCallCB(WPARAM wParam, LPARAM lParam, PVOID pContext) {

   PNTUSERMESSAGECALL_PARMS parms = (PNTUSERMESSAGECALL_PARMS)pContext;

   return NtUserMessageCall(parms->hwnd, parms->msg, wParam, lParam, parms->xParam,
                            parms->xpfnProc, parms->bAnsi);

}

// Functions that are possible from NtUserMessageCall(xParam).

//    FNID(FNID_SCROLLBAR)                = xxxWrapSBWndProc - unreferenced;
//    FNID(FNID_ICONTITLE)                = xxxWrapDefWindowProc - unreferenced
//    FNID(FNID_MENU)                     = xxxWrapMenuWindowProc - unreferenced
//    FNID(FNID_DESKTOP)                  = xxxWrapDesktopWndProc - unreferenced
//    FNID(FNID_DEFWINDOWPROC)            = xxxWrapDefWindowProc - unreferenced
//    FNID(FNID_SENDMESSAGE)              = xxxWrapSendMessage - unreferenced
//    FNID(FNID_HKINLPCWPEXSTRUCT)        = fnHkINLPCWPEXSTRUCT - unrefereced, but is actually a hook call;
//    FNID(FNID_HKINLPCWPRETEXSTRUCT)     = fnHkINLPCWPRETEXSTRUCT - unrefereced, but is actually a hook call;
//    FNID(FNID_SENDMESSAGEFF)            = xxxSendMessageFF OPTIONAL IN OUT SNDMSGTIMEOUT*(ptr dep);
//    FNID(FNID_SENDMESSAGEEX)            = xxxSendMessageEx OPTIONAL IN OUT SNDMSGTIMEOUT*(ptr dep);
//    FNID(FNID_CALLWINDOWPROC)           = xxxWrapCallWindowProc - wndproc pointer.
//    FNID(FNID_SENDMESSAGEBSM)           = xxxWrapSendMessageBSM - INBROADCASTSYSTEMMSGPARAMS(non ptr dep)

// This is to ensure that the valid FNID entries have not been chagned.  If they are, this list will
// need to be reinspected.  The list of kernel functions is in.
#if (FNID_START != 0x0000029A && 0x000002B4)
#error the FNID list needs to be reinspected for parameters that are pointer dependent.
#endif

LONG_PTR whNT32NtUserMessageCall(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam, ULONG_PTR xParam,
                                 DWORD xpfnProc, BOOL bAnsi) {

  NTUSERMESSAGECALL_PARMS params;

  params.hwnd = hwnd;
  params.msg = msg;
  params.xpfnProc = xpfnProc;
  params.bAnsi = bAnsi;

  // SendMessage can have a timeout structure which needs to be thunked.
  // The timeout structure is optional.
  if (xParam && (FNID_SENDMESSAGEFF == xpfnProc || FNID_SENDMESSAGEEX == xpfnProc)) {

     SNDMSGTIMEOUT sndmsgto64; // sndmsgto is IN OUT
     NT32SNDMSGTIMEOUT *psndmsgto32;
     LONG_PTR retval;


     psndmsgto32 = (NT32SNDMSGTIMEOUT *)xParam;
     params.xParam = (ULONG_PTR)&sndmsgto64;

     sndmsgto64.fuFlags = psndmsgto32->fuFlags;
     sndmsgto64.uTimeout = psndmsgto32->uTimeout;
     sndmsgto64.lSMTOReturn = sndmsgto64.lSMTOResult = 0;

     retval = Wow64DoMessageThunk(whNT32NtUserMessageCallCB, msg, wParam, lParam, &params);

     psndmsgto32->lSMTOReturn = (NT32ULONG_PTR)sndmsgto64.lSMTOReturn;
     psndmsgto32->lSMTOResult = (NT32ULONG_PTR)sndmsgto64.lSMTOResult;

     return retval;

  }

  else {

      params.xParam = xParam;

      return Wow64DoMessageThunk(whNT32NtUserMessageCallCB, msg, wParam, lParam, &params);
  }
}
)
End=
PreCall=
if (xpfnProc == FNID_CALLWINDOWPROC) { @NL
    xParam = (ULONG_PTR) NtWow64MapClientFnToKernelClientFn((PROC)xParamHost); @NL
} else { @NL
    xParam = (ULONG_PTR)xParamHost; @NL
} @NL
// lParam and wParam will be handled by the message thunks. @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Begin=
@GenApiThunk(whNT32NtUserMessageCall)
End=

;; Code for NtUserCallNextHookEx
[Macros]
TemplateName=DoNtUserCallNextHookEx
NumArgs=3
Begin=
{ @Indent( @NL
   @MArg(1) wParamTemp; @NL
   @MArg(2) lParamTemp; @NL
   LPARAM RetVal; @NL

   @ForceType(Locals,wParamTemp,wParam,@MArg(1),IN)
   @ForceType(Locals,lParamTemp,lParam,@MArg(2),@MArg(3))

   @ForceType(PreCall,lParamTemp,lParam,@MArg(2),@MArg(3))
   @ForceType(PreCall,wParamTemp,wParam,@MArg(1),@MArg(3))

   RetVal = NtUserCallNextHookEx(nCode, (WPARAM)wParamTemp, (LPARAM)lParamTemp, bAnsi); @NL

   @ForceType(PostCall,wParamTemp,wParam,@MArg(1),IN)
   @ForceType(PostCall,lParamTemp,lParam,@MArg(2),@MArg(3))

   return RetVal; @NL
)} @NL
End=


[EFunc]

TemplateName=NtUserCallNextHookEx
NoType=wParam
NoType=lParam
PreCall=
// These parameters will be deep thunked in whNT32NtUserCallNextHookEx @NL
wParam = (WPARAM)wParamHost; @NL
lParam = (LPARAM)lParamHost; @NL
End=
Header=
@NL

LRESULT whNT32NtUserCallNextHookEx(int nCode, WPARAM wParam, LPARAM lParam, BOOL bAnsi) { @Indent(

   // WPARAM and LPARAM are the 32BIT versions of these parameters.  @NL
   // This function will complete the conversion to 64BIT. @NL

   @NL

   PCLIENTINFO pci;
   INT HookType;
   // Determine the hook type that is being called.  Modeled after CallNextHookEx. @NL
   @NL

   pci = Wow64GetClientInfo(); @NL
   HookType = (INT)(SHORT)HIWORD(pci->dwHookCurrent); @NL
   @NL

   LOGPRINT((TRACELOG, "whNT32NtUserCallNextHookEx: Calling hook %x\n", HookType));

   switch(HookType) { @Indent( @NL
      @NL

      case WH_CBT: @Indent( @NL

          //Multiple types of CBT hooks exists! @NL
          @NL

          switch(nCode) { @Indent( @NL

              case HCBT_CLICKSKIPPED: @NL @Indent( @NL

                //This hook has the same parameters as WH_MOUSE @NL

                 goto MouseHook; @NL
                 break; @NL

              ) @NL

              case  HCBT_CREATEWND: @NL @Indent( @NL

                 // LPARAM is an IN OUT LPCBT_CREATEWND  @NL
                 // Note: the kernel never dereferences lpCreateParams. @NL
                 // WPARAM is a handle to the window. @NL
                 @DoNtUserCallNextHookEx(HWND,LPCBT_CREATEWND,IN OUT)
                 break; @NL

              ) @NL

              case  HCBT_MOVESIZE: @NL @Indent( @NL

                 // WPARAM is an HWND @NL
                 // LPARAM is a IN LPRECT structure. @NL
                 @DoNtUserCallNextHookEx(HWND,LPRECT,IN)
                 break; @NL

              ) @NL


              case  HCBT_ACTIVATE: @NL @Indent( @NL

                 // WPARAM is an LPCBTACTIVATESTRUCT @NL
                 // LPARAM is a IN LPRECT structure. @NL

                 @DoNtUserCallNextHookEx(HWND,LPCBTACTIVATESTRUCT,IN)
                 break; @NL

              ) @NL

              case  HCBT_DESTROYWND: //(HWND, unused 0) @NL
              case  HCBT_QS: // (unused 0, unused 0) @NL
              case  HCBT_MINMAX: //(HWND, LOWORD SW_*) @NL
              case  HCBT_SETFOCUS: //(HWND, HWND) @Indent( @NL

                  // All of these hooks can have both parameters sign extended. @NL
                  return NtUserCallNextHookEx(nCode, (WPARAM)(LONG)wParam, (LPARAM)(LONG)lParam, bAnsi); @NL
                  break; @NL

              ) @NL

              case HCBT_KEYSKIPPED: //(UINT, UINT) @NL
              case HCBT_SYSCOMMAND: //(UINT, UINT) @Indent( @NL
                  // Both of these should be zero extended. @NL
                  return NtUserCallNextHookEx(nCode, (WPARAM)(UINT)wParam, (LPARAM)(UINT)lParam, bAnsi); @NL
              ) @NL

              default: @NL @Indent( @NL
                  LOGPRINT((ERRORLOG, "NtUserCallNextHookEx: called with invalid CBT hook type %x\n")); @NL
                  // Fail the API, but let the service dispatcher do the failing. @NL
                  RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL

                  return 0;
              )

          )} @NL

      ) @NL

      case WH_SHELL: @Indent( @NL

        // If nCode is HSELL_ACCESSIBILITYSTATE, the wParam contains is small unsigned value.  Sign  @NL
        // extending it will not hurt anything. In all other cases, wParam is a handle or ignored so @NL
        // always sign extend.                                                                       @NL
        // lParam is either a BOOL, a HANDLE, or a pointer.  So always sign extend lParam.           @NL

        WOWASSERT(sizeof(RECT) == sizeof(NT32RECT)); @NL

        // These codes are documented in MSDN @NL

        switch(nCode) { @Indent( @NL
           case HSHELL_ACCESSIBILITYSTATE: //(UINT wParam, UNUSED lParam)@NL
           case HSHELL_ACTIVATESHELLWINDOW: //(UNUSED, UNUSED)@NL
           case HSHELL_GETMINRECT: //(HWND wParam, PRECT lParam)@NL
           case HSHELL_LANGUAGE: //(HWND wParam, HKL lParam)@NL
           case HSHELL_REDRAW: //(HWND wParam, BOOL lParam)@NL
           case HSHELL_TASKMAN: //(UNUSED, UNUSED)@NL
           case HSHELL_WINDOWACTIVATED: //(HWND wParam, BOOL lParam)@NL
           case HSHELL_WINDOWCREATED: //(HWND wParam, BOOL lParam)@NL
           case HSHELL_WINDOWDESTROYED:  //(HWND wparam, BOOL lParam) @Indent( @NL
               break; @NL
           )
           default: @Indent( @NL
               LOGPRINT((ERRORLOG, "NtUserCallNextHookEx: WH_SHELL called with unknown nCode.")); @NL
               break; @NL
           )
        )}@NL

        return NtUserCallNextHookEx(nCode, (WPARAM)(LONG)wParam, (LPARAM)(LONG)lParam, bAnsi); @NL

      ) @NL

      case WH_FOREGROUNDIDLE: @Indent(
          //  WH_FORGROUNDIDEL has no parameters.            @NL
          //  Fall through and use the thunk for WH_KEYBOARD @NL
      )
      case WH_KEYBOARD:    @Indent(    @NL

          // WH_KEYBOARD represents a WM_KEYUP or a WM_KEYDOWN. @NL
          // Both of them have the same prototype.              @NL
          // (UINT nVirtKey, UINT KeyData)                      @NL

          return NtUserCallNextHookEx(nCode, (WPARAM)(UINT)wParam, (LPARAM)(UINT)lParam, bAnsi); @NL
          break; @NL

      ) @NL

      case WH_MSGFILTER:           @NL
      case WH_SYSMSGFILTER:        @NL
      case WH_GETMESSAGE: @Indent( @NL

          // All of these hooks take an lpMsg as their last parameter.  @NL
          // Since none of the messages here can have pointers,  NtUserCallNextHookEx @NL
          // does not deep probe the message and does not touch the lParam and wParam. @NL
          // Also, none of these messages are intersendable, so we don't need to worry @NL
          // about a 64bit process looking at the structures that the message points to. @NL
          // The 32bit process will truncate the upper bits in the thunks when the hook gets called back @NL
          // so sign extension doesn't matter either. @NL

          { @Indent( @NL

              MSG msg; @NL
              PMSG pMsg; @NL

              pMsg = Wow64ShallowThunkMSG32TO64(&msg, (NT32MSG *)lParam); @NL
              return NtUserCallNextHookEx(nCode, (WPARAM)wParam, (LPARAM)pMsg, bAnsi); @NL
          )} @NL
          break; @NL

      ) @NL


      // Need to return to this.
      case WH_JOURNALPLAYBACK: @NL
      case WH_JOURNALRECORD: @Indent( @NL


          // wParam is unused and lParam is a LPEVENTMSG, this structure is IN on a WH_JOURNALPLAYBACK @NL
          // it is an OUT on a WH_JOURNALRECORD @NL
          // The kernel has shared probing code here, and it copied the message as IN OUT in both @NL
          // cases so the same will be done here.  Also, this message has the WPARAM and LPARAM declared @NL
          // as UINT in the Win32 and Win64 so their is no need to worry about signed extending vs. zero extending. @NL

          { @Indent( @NL
              LPARAM RetVal; @NL
              EVENTMSG EventMsg; @NL
              LPEVENTMSG pEventMsg; @NL
              @NL
              pEventMsg = Wow64ShallowThunkEVENTMSG32TO64(&EventMsg, (NT32EVENTMSG*)lParam); @NL
              // WPARAM is undefined @NL
              RetVal = NtUserCallNextHookEx(nCode, (ULONG64)wParam, (LPARAM)pEventMsg, bAnsi); @NL
              Wow64ShallowThunkEVENTMSG64TO32((NT32EVENTMSG*)lParam, pEventMsg); @NL
              return RetVal; @NL
          )} @NL
          break; @NL

      ) @NL

      case WH_DEBUG: @Indent( @NL

          // Takes an IN lpDebugHookStruct. @NL
          // wparam is the hook being called. It is INT because -1 is a valid value. @NL
          // Currently, USER32 code for this message is not deep copying the message @NL
          // into the kernel. Thus, this code doesn't either.  This will need to be  @NL
          // revisited if user32 code changes. @NL
          { @Indent(   @NL
            DEBUGHOOKINFO dbginfo; @NL
            LPDEBUGHOOKINFO dbginfo64; @NL
            NT32DEBUGHOOKINFO *dbginfo32; @NL

            if (ARGUMENT_PRESENT(lParam)) {@Indent( @NL
               dbginfo64 = &dbginfo; @NL
               dbginfo32 = (NT32DEBUGHOOKINFO *)lParam; @NL
               dbginfo64->idThread = dbginfo32->idThread; @NL
               dbginfo64->idThreadInstaller = dbginfo32->idThreadInstaller; @NL
               dbginfo64->lParam = (LPARAM)dbginfo32->lParam; @NL
               dbginfo64->wParam = (WPARAM)dbginfo32->wParam; @NL
               dbginfo64->code = dbginfo32->code; @NL
            )} @NL
            else { @Indent( @NL
               dbginfo64 = NULL; @NL
            )} @NL
            return NtUserCallNextHookEx(nCode, (WPARAM)(INT)wParam, (LPARAM)dbginfo64, bAnsi); @NL
          )}
          break; @NL

      ) @NL

      case WH_KEYBOARD_LL: @Indent( @NL

          // Takes an UINT messageid, and IN lpKbdllHookStruct. @NL

          @DoNtUserCallNextHookEx(UINT,LPKBDLLHOOKSTRUCT,IN)
          break; @NL

      ) @NL

      case WH_MOUSE_LL: @Indent( @NL

          // Takes an UINT message id, and an IN lpMsllHookStruct. @NL

          @DoNtUserCallNextHookEx(UINT,LPMSLLHOOKSTRUCT,IN)
          break; @NL

      ) @NL

      case WH_MOUSE: @Indent( @NL

         MouseHook: @NL

         // This takes an UINT message id, and an lpMouseHookStruct. @NL

         @DoNtUserCallNextHookEx(UINT,LPMOUSEHOOKSTRUCT,IN)
         break; @NL

      ) @NL

      default: @Indent( @NL

         LOGPRINT((ERRORLOG, "NtUserCallNextHookEx: called with invalid hook type %x\n", HookType)); @NL
         // Fail the API@NL
         RtlRaiseStatus(STATUS_INVALID_PARAMETER); @NL
         return 0; @NL

      )@NL

      @NL
   )} @NL

)} @NL
@NL
End=
Begin=
@GenApiThunk(whNT32NtUserCallNextHookEx)
End=


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; This function is only called by the spooler.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtGdiGetSpoolMessage
Begin=
@GenUnsupportedNtApiThunk
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  These functions can only be called from CSR
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtGdiFullscreenControl
Also=NtUserHardErrorControl
Also=NtUserSetInformationThread
Also=NtUserConsoleControl
Also=NtUserRemoteConnect
Also=NtUserRemoteRedrawRectangle
Also=NtUserRemoteRedrawScreen
Also=NtUserRemoteStopScreenUpdates
Also=NtUserCtxDisplayIOCtl
Also=NtUserQueryInformationThread
Also=NtUserSetInformationProcess
Also=NtUserNotifyProcessCreate
Also=NtUserGetMediaChangeEvents
Begin=NtUserProcessConnect
@GenUnsupportedNtApiThunk
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;   NtUser Generic Input APIs.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtUserGetRawInputData
Locals=
UINT HeaderDiff6432;
End=
PreCall=
HeaderDiff6432 = sizeof (RAWINPUTHEADER) - sizeof (NT32RAWINPUTHEADER);
if (cbSizeHeaderHost == sizeof (NT32RAWINPUTHEADER)) {           @NL
                                                                 @NL
    cbSizeHeader = sizeof (RAWINPUTHEADER);                      @NL                                                             
    if (pData != NULL) {                                         @NL
        switch (uiCommand) {                                     @NL
        case RID_HEADER:                                         @NL
            *pcbSize = cbSizeHeader;                             @NL
            pData = Wow64AllocateTemp (cbSizeHeader);            @NL
            break;                                               @NL
            
        case RID_INPUT:                                          @NL
            *pcbSize += HeaderDiff6432;                          @NL
            pData = Wow64AllocateTemp (*pcbSize);                @NL
            break;                                               @NL
        }                                                        @NL
    }                                                            @NL
}                                                                @NL
End=
PostCall=
if (RetVal != -1) {                                              @NL
    switch (uiCommand) {                                         @NL
    case RID_HEADER:                                             @NL
        *pcbSize = sizeof (NT32RAWINPUTHEADER);                  @NL
        if (pData != NULL) {                                     @NL
            
            @ForceType(PostCall, ((PRAWINPUTHEADER)pData), ((NT32RAWINPUTHEADER *)pDataHost),PRAWINPUTHEADER,OUT)
            ((NT32RAWINPUTHEADER *)pDataHost)->dwSize = sizeof (NT32RAWINPUTHEADER); @NL
        }                                                        @NL
        break;                                                   @NL
    case RID_INPUT:                                              @NL
                                                                 @NL
        *pcbSize -= HeaderDiff6432;                              @NL
        if (pData != NULL) {                                     @NL
            @ForceType(PostCall, ((PRAWINPUTHEADER)pData), ((NT32RAWINPUTHEADER *)pDataHost),PRAWINPUTHEADER,OUT)
            ((NT32RAWINPUTHEADER *)pDataHost)->dwSize = sizeof (NT32RAWINPUTHEADER); @NL
                                                                 @NL
            pDataHost = (UINT)((NT32RAWINPUTHEADER *)pDataHost + 1);@NL
            pData = (PRAWINPUTHEADER)((PRAWINPUTHEADER)pData + 1);@NL
            RtlCopyMemory ((PVOID)pDataHost, pData,              @NL
                           RetVal - sizeof (RAWINPUTHEADER));    @NL
        }                                                        @NL
                                                                 @NL
        break;                                                   @NL
    }                                                            @NL
    if (RetVal > 0) {                                            @NL
        RetVal -= HeaderDiff6432;                                @NL
    }                                                            @NL
}                                                                @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserGetRawInputBuffer
NoType=pData
PreCall=
if (cbSizeHeaderHost == sizeof (NT32RAWINPUTHEADER)) {           @NL
                                                                 @NL
    cbSizeHeader = sizeof (RAWINPUTHEADER);                      @NL
}                                                                @NL
pData = (PRAWINPUT)pDataHost;                                               @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserGetRawInputDeviceList
Locals=
UINT nDevices;                                                   @NL
NT32RAWINPUTDEVICELIST *pRawInputDeviceList32 = (NT32RAWINPUTDEVICELIST *)pRawInputDeviceListHost; @NL
End=
PreCall=
if (cbSize == sizeof (NT32RAWINPUTDEVICELIST)) {                 @NL
                                                                 @NL
    cbSize = sizeof (RAWINPUTDEVICELIST);                        @NL
    if (pRawInputDeviceList != NULL) {                           @NL
        RetVal = NtUserGetRawInputDeviceList(NULL,               @NL
                                             &nDevices,          @NL
                                             sizeof (RAWINPUTDEVICELIST)); @NL
                                             
        if (RetVal == -1) {                                      @NL
            LOGPRINT((ERRORLOG, "whNtUserGetRawInputDeviceList: Failed to retreive number of devices.")); @NL
            return RetVal;                                       @NL
        }                                                        @NL
        
        pRawInputDeviceList = Wow64AllocateTemp (nDevices * sizeof (RAWINPUTDEVICELIST)); @NL
    }                                                            @NL
}                                                                @NL
End=
PostCall=
if (RetVal != -1) {                                              @NL
    if (pRawInputDeviceList != NULL) {                           @NL
        for (nDevices = 0; nDevices < *puiNumDevices; nDevices++) { @NL
            @ForceType(PostCall,((PRAWINPUTDEVICELIST)(&pRawInputDeviceList[nDevices])), &pRawInputDeviceList32[nDevices], PRAWINPUTDEVICELIST,OUT)
        }                                                        @NL
    }                                                            @NL
}                                                                @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserRegisterRawInputDevices
NoType=pRawInputDevices
Locals=
UINT nDevice;                                                    @NL
NT32RAWINPUTDEVICE *pRawInputDevices32;                          @NL
PRAWINPUTDEVICE pRawInputDevicesTemp;                            @NL
End=
PreCall=
pRawInputDevices = (PRAWINPUTDEVICE)pRawInputDevicesHost;        @NL
if (cbSize == sizeof (NT32RAWINPUTDEVICE)) {                     @NL
                                                                 @NL
    cbSize = sizeof (RAWINPUTDEVICE);                            @NL
    if (pRawInputDevices != NULL) {                              @NL
        pRawInputDevices = Wow64AllocateTemp (uiNumDevices * cbSize); @NL
                                                                 
        pRawInputDevicesTemp = pRawInputDevices;                 @NL
        pRawInputDevices32 = (NT32RAWINPUTDEVICE *)pRawInputDevicesHost;@NL
        for (nDevice = 0 ; nDevice < uiNumDevices ; nDevice++) { @NL
            @ForceType(PreCall,(*pRawInputDevicesTemp),(*pRawInputDevices32),RAWINPUTDEVICE,IN)
            pRawInputDevicesTemp++;                              @NL
            pRawInputDevices32++;                                @NL
        }                                                        @NL
    }                                                            @NL
}                                                                @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserGetRegisteredRawInputDevices
NoType=pRawInputDevices
Locals=
UINT nDevice;
NT32RAWINPUTDEVICE *pRawInputDevices32;                          @NL
End=
PreCall=
pRawInputDevices = (PRAWINPUTDEVICE)pRawInputDevicesHost;        @NL
if (cbSize == sizeof (NT32RAWINPUTDEVICE)) {                     @NL
    cbSize = sizeof (RAWINPUTDEVICE);                            @NL
}                                                                @NL
if (pRawInputDevices != NULL) {                                  @NL
    pRawInputDevices = Wow64AllocateTemp (*puiNumDevices * sizeof (RAWINPUTDEVICE));@NL
}                                                                @NL
End=
PostCall=
if (RetVal != -1) {                                              @NL
    if (pRawInputDevices != NULL) {                              @NL
                                                                 
        pRawInputDevices32 = (NT32RAWINPUTDEVICE *)pRawInputDevicesHost;@NL
        for (nDevice = 0 ; nDevice < *puiNumDevices ; nDevice++) { @NL
            @ForceType(PostCall,(*pRawInputDevices),(*pRawInputDevices32),RAWINPUTDEVICE,OUT)
            pRawInputDevices++;                                  @NL
            pRawInputDevices32++;                                @NL
        }                                                        @NL
    }                                                            @NL
}                                                                @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; WOW will not be supported on NT64 period.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtUserGetWOWClass
Begin=
@GenUnsupportedNtApiThunk
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  These functions are not implemented in the kernel
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtGdiUnmapMemFont
Begin=
@GenUnsupportedNtApiThunk
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; DDE functions.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

TemplateName=NtUserDdeGetQualityOfService
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserDdeInitialize
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtUserDdeSetQualityOfService
Begin=
@GenApiThunk(@ApiName)
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  DirectX will need alot more work to get it working.
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtGdiD3dContextCreate
NoType=hDirectDrawLocal
NoType=hSurfColor
NoType=hSurfZ
NoType=pdcci
Locals=
BYTE pdcciCopy[sizeof(D3DNTHAL_CONTEXTCREATEI)]; @NL
D3D8_CONTEXTCREATEDATA *pCCD; @NL
NT32D3D8_CONTEXTCREATEDATA *pCCDHost; @NL
pdcci = (D3DNTHAL_CONTEXTCREATEI *)pdcciCopy; @NL
pCCD=(D3D8_CONTEXTCREATEDATA *)pdcciCopy; @NL
pCCDHost=(NT32D3D8_CONTEXTCREATEDATA *)pdcciHost; @NL
End=
PreCall=
hDirectDrawLocal=(HANDLE)((unsigned)hDirectDrawLocalHost); @NL
hSurfColor=(HANDLE)((unsigned)hSurfColorHost); @NL
hSurfZ=(HANDLE)((unsigned)hSurfZHost); @NL
if(ARGUMENT_PRESENT(pdcciHost)) { @Indent( @NL
@ForceType(PreCall,pCCD->hDD,((unsigned)(pCCDHost->hDD)),HANDLE,IN)
@ForceType(PreCall,pCCD->hSurface,((unsigned)(pCCDHost->hSurface)),HANDLE,IN)
@ForceType(PreCall,pCCD->hDDSZ,((unsigned)(pCCDHost->hDDSZ)),HANDLE,IN)
@ForceType(PreCall,pCCD->dwPID,pCCDHost->dwPID,DWORD,IN)
@ForceType(PreCall,pCCD->dwhContext,pCCDHost->dwhContext,ULONG_PTR,IN)
@ForceType(PreCall,pCCD->ddrval,pCCDHost->ddrval,HRESULT,IN)
@ForceType(PreCall,pdcci->cjBuffer,pCCDHost->cjBuffer,ULONG,IN)
@ForceType(PreCall,pdcci->pvBuffer,pCCDHost->pvBuffer,PVOID,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(pdcciHost)) { @Indent( @NL
@ForceType(PostCall,pCCD->dwhContext,pCCDHost->dwhContext,ULONG_PTR,OUT)
@ForceType(PostCall,pCCD->ddrval,pCCDHost->ddrval,HRESULT,OUT)
@ForceType(PostCall,pdcci->cjBuffer,pCCDHost->cjBuffer,ULONG,OUT)
@ForceType(PostCall,pdcci->pvBuffer,pCCDHost->pvBuffer,PVOID,OUT)
)} @NL
End=

TemplateName=NtGdiD3dContextDestroy
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiD3dContextDestroyAll
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiD3dValidateTextureStageState
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiD3dDrawPrimitives2
NoType=hCmdBuf
NoType=hVBuf
NoType=pded
Header=
@NoFormat(
VOID
Wow64GdiDdThunkSurfaceHandlesPreCall(
    IN OUT HANDLE **pSurface,
    IN NT32HANDLE *pSurfaceHost,
    IN DWORD dwCount
)
{
    DWORD dwIndex;
    
    *pSurface=NULL;
    
    if(WOW64_ISPTR(pSurfaceHost) && (dwCount>0))
    {
        *pSurface=(HANDLE *)Wow64AllocateTemp(sizeof(HANDLE)*dwCount);
        if(*pSurface)
        {
            for(dwIndex=0;dwIndex<dwCount;dwIndex++)
            {
                (*pSurface)[dwIndex]=(HANDLE)((unsigned)(pSurfaceHost[dwIndex]));
            }       
        }    
    }
}    

VOID
Wow64GdiDdThunkSurfaceDescriptionPreCall(
    IN OUT DDSURFACEDESC ** pDdSurfaceDesc,
    IN struct NT32_DDSURFACEDESC * pDdSurfaceDesc32,
    IN DWORD bThunkAsSurfaceDesc2,
    IN DWORD dwCount
)
{
    DWORD dwIndex;
    DDSURFACEDESC  *pDDSD;
    DDSURFACEDESC2 *pDDSD2;
    struct NT32_DDSURFACEDESC2 *pDDSD2_32;
    
    *pDdSurfaceDesc = NULL;
    
    if( bThunkAsSurfaceDesc2 != 0 )
    {
        pDDSD2 = (DDSURFACEDESC2 *)Wow64AllocateTemp(sizeof(DDSURFACEDESC2)*dwCount);
        if( pDDSD2 )
        {
            *pDdSurfaceDesc = (DDSURFACEDESC *)pDDSD2;
            pDDSD2_32 = (struct NT32_DDSURFACEDESC2 *)pDdSurfaceDesc32;
            
            for(dwIndex=0; dwIndex<dwCount; dwIndex++)
            {
                @ForceType(PreCall,pDDSD2->dwSize,pDDSD2_32->dwSize,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwFlags,pDDSD2_32->dwFlags,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwHeight,pDDSD2_32->dwHeight,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwWidth,pDDSD2_32->dwWidth,DWORD,IN)
                if( (pDDSD2_32->dwFlags & DDSD_LINEARSIZE) == DDSD_LINEARSIZE )
                {
                    @ForceType(PreCall,pDDSD2->dwLinearSize,pDDSD2_32->dwLinearSize,DWORD,IN)
                } else
                {
                    @ForceType(PreCall,pDDSD2->lPitch,pDDSD2_32->lPitch,LONG,IN)                
                }
                @ForceType(PreCall,pDDSD2->dwBackBufferCount,pDDSD2_32->dwBackBufferCount,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwMipMapCount,pDDSD2_32->dwMipMapCount,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwAlphaBitDepth,pDDSD2_32->dwAlphaBitDepth,DWORD,IN)
                @ForceType(PreCall,pDDSD2->dwReserved,pDDSD2_32->dwReserved,DWORD,IN)
                @ForceType(PreCall,pDDSD2->lpSurface,pDDSD2_32->lpSurface,LPVOID,IN)
                if( (pDDSD2_32->dwFlags & DDSD_CKDESTOVERLAY) == DDSD_CKDESTOVERLAY )
                {
                    @ForceType(PreCall,pDDSD2->ddckCKDestOverlay,pDDSD2_32->ddckCKDestOverlay,DDCOLORKEY,IN)
                } else
                {
                    @ForceType(PreCall,pDDSD2->dwEmptyFaceColor,pDDSD2_32->dwEmptyFaceColor,DWORD,IN)                
                }
                @ForceType(PreCall,pDDSD2->ddckCKDestBlt,pDDSD2_32->ddckCKDestBlt,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD2->ddckCKSrcOverlay,pDDSD2_32->ddckCKSrcOverlay,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD2->ddckCKSrcBlt,pDDSD2_32->ddckCKSrcBlt,DDCOLORKEY,IN)
                if( (pDDSD2_32->dwFlags & DDSD_FVF) == DDSD_FVF )
                {
                    @ForceType(PreCall,pDDSD2->dwFVF,pDDSD2_32->dwFVF,DWORD,IN)
                } else
                {
                    @ForceType(PreCall,pDDSD2->ddpfPixelFormat,pDDSD2_32->ddpfPixelFormat,DDPIXELFORMAT,IN)                
                }
                @ForceType(PreCall,pDDSD2->ddsCaps,pDDSD2_32->ddsCaps,DDSCAPS2,IN)
                @ForceType(PreCall,pDDSD2->dwTextureStage,pDDSD2_32->dwTextureStage,DWORD,IN)
                
                pDDSD2++;
                pDDSD2_32++;
            }
        }
    } else
    {
        pDDSD = (DDSURFACEDESC *)Wow64AllocateTemp(sizeof(DDSURFACEDESC)*dwCount);
        if( pDDSD )
        {
            *pDdSurfaceDesc = (DDSURFACEDESC *)pDDSD;
            
            for(dwIndex=0; dwIndex<dwCount; dwIndex++)
            {
                @ForceType(PreCall,pDDSD->dwSize,pDdSurfaceDesc32->dwSize,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwFlags,pDdSurfaceDesc32->dwFlags,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwHeight,pDdSurfaceDesc32->dwHeight,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwWidth,pDdSurfaceDesc32->dwWidth,DWORD,IN)
                if( (pDdSurfaceDesc32->dwFlags & DDSD_LINEARSIZE) == DDSD_LINEARSIZE )
                {
                    @ForceType(PreCall,pDDSD->dwLinearSize,pDdSurfaceDesc32->dwLinearSize,DWORD,IN)
                } else
                {
                    @ForceType(PreCall,pDDSD->lPitch,pDdSurfaceDesc32->lPitch,LONG,IN)                
                }
                @ForceType(PreCall,pDDSD->dwBackBufferCount,pDdSurfaceDesc32->dwBackBufferCount,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwMipMapCount,pDdSurfaceDesc32->dwMipMapCount,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwAlphaBitDepth,pDdSurfaceDesc32->dwAlphaBitDepth,DWORD,IN)
                @ForceType(PreCall,pDDSD->dwReserved,pDdSurfaceDesc32->dwReserved,DWORD,IN)
                @ForceType(PreCall,pDDSD->lpSurface,pDdSurfaceDesc32->lpSurface,LPVOID,IN)
                @ForceType(PreCall,pDDSD->ddckCKDestOverlay,pDdSurfaceDesc32->ddckCKDestOverlay,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD->ddckCKDestBlt,pDdSurfaceDesc32->ddckCKDestBlt,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD->ddckCKSrcOverlay,pDdSurfaceDesc32->ddckCKSrcOverlay,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD->ddckCKSrcBlt,pDdSurfaceDesc32->ddckCKSrcBlt,DDCOLORKEY,IN)
                @ForceType(PreCall,pDDSD->ddpfPixelFormat,pDdSurfaceDesc32->ddpfPixelFormat,DDPIXELFORMAT,IN)                
                @ForceType(PreCall,pDDSD->ddsCaps,pDdSurfaceDesc32->ddsCaps,DDSCAPS,IN)
                
                pDDSD++;
                pDdSurfaceDesc32++;
            }
        }    
    }
}
    
VOID
Wow64GdiDdThunkSurfaceMorePreCall(
    IN OUT PDD_SURFACE_MORE * pDdSurfaceMore,
    IN struct NT32_DD_SURFACE_MORE * pDdSurfaceMore32,
    IN DWORD dwCount
)
{
    PDD_SURFACE_MORE pDdSurfaceMoreCopy = NULL;
    
    if( WOW64_ISPTR(pDdSurfaceMore32) && (dwCount>0) )
    {
        pDdSurfaceMoreCopy = (PDD_SURFACE_MORE)Wow64AllocateTemp(sizeof(DD_SURFACE_MORE)*dwCount);
        *pDdSurfaceMore = pDdSurfaceMoreCopy;
    }
    
    if( pDdSurfaceMoreCopy )
    {
        while((dwCount--) && (WOW64_ISPTR(pDdSurfaceMore32)))
        {
            // still need to thunk lpVideoPort
            pDdSurfaceMoreCopy->lpVideoPort = NULL;        

            @ForceType(PreCall,pDdSurfaceMoreCopy->dwMipMapCount,pDdSurfaceMore32->dwMipMapCount,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceMoreCopy->dwOverlayFlags,pDdSurfaceMore32->dwOverlayFlags,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceMoreCopy->ddsCapsEx,pDdSurfaceMore32->ddsCapsEx,DDSCAPSEX,IN)
            @ForceType(PreCall,pDdSurfaceMoreCopy->dwSurfaceHandle,pDdSurfaceMore32->dwSurfaceHandle,DWORD,IN)
        
            pDdSurfaceMore32++;
            pDdSurfaceMoreCopy++;
        }           
    }
}    

VOID
Wow64GdiDdThunkSurfaceGlobalPreCall(
    IN OUT PDD_SURFACE_GLOBAL * pDdSurfaceGlobal,
    IN struct NT32_DD_SURFACE_GLOBAL * pDdSurfaceGlobal32,
    IN DWORD dwCount
)
{
    PDD_SURFACE_GLOBAL pDdSurfaceGlobalCopy = NULL;
    LPVIDEOMEMORY lpVidMemHeapCopy = NULL;
    
    if( WOW64_ISPTR(pDdSurfaceGlobal32) && (dwCount>0) )
    {
        pDdSurfaceGlobalCopy = (PDD_SURFACE_GLOBAL)Wow64AllocateTemp(sizeof(DD_SURFACE_GLOBAL)*dwCount);
        *pDdSurfaceGlobal = pDdSurfaceGlobalCopy;
    }
    
    if( pDdSurfaceGlobalCopy )
    {
        while((dwCount--) && WOW64_ISPTR(pDdSurfaceGlobal32))
        {
            if( WOW64_ISPTR(pDdSurfaceGlobal32->lpVidMemHeap) )
            {
                struct NT32_VIDEOMEMORY * lpVidMemHeap32 = (struct NT32_VIDEOMEMORY *)(pDdSurfaceGlobal32->lpVidMemHeap);            
        
                lpVidMemHeapCopy = (LPVIDEOMEMORY)Wow64AllocateTemp(sizeof(VIDEOMEMORY));
                if(lpVidMemHeapCopy)
                {
                    @ForceType(PreCall,lpVidMemHeapCopy->dwFlags,lpVidMemHeap32->dwFlags,DWORD,IN)
                    @ForceType(PreCall,lpVidMemHeapCopy->fpStart,lpVidMemHeap32->fpStart,FLATPTR,IN)
                    @ForceType(PreCall,lpVidMemHeapCopy->ddsCaps,lpVidMemHeap32->ddsCaps,DDSCAPS,IN)
                    @ForceType(PreCall,lpVidMemHeapCopy->ddsCapsAlt,lpVidMemHeap32->ddsCapsAlt,DDSCAPS,IN)
        
                    if( (lpVidMemHeapCopy->dwFlags & VIDMEM_ISRECTANGULAR) == VIDMEM_ISRECTANGULAR )
                    {
                        @ForceType(PreCall,lpVidMemHeapCopy->dwWidth,lpVidMemHeap32->dwWidth,DWORD,IN)
                        @ForceType(PreCall,lpVidMemHeapCopy->dwHeight,lpVidMemHeap32->dwHeight,DWORD,IN)                    
                    } else
                    {
                        @ForceType(PreCall,lpVidMemHeapCopy->fpEnd,lpVidMemHeap32->fpEnd,FLATPTR,IN)
                            
                        // this actually is a pointer to a _VMEMHEAP structure and may need the structure thunked
                        @ForceType(PreCall,lpVidMemHeapCopy->lpHeap,lpVidMemHeap32->lpHeap,PVOID,IN)                    
                    }                    
                }            
            }
            pDdSurfaceGlobalCopy->lpVidMemHeap = lpVidMemHeapCopy;                    

            @ForceType(PreCall,pDdSurfaceGlobalCopy->dwBlockSizeY,pDdSurfaceGlobal32->dwBlockSizeY,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->fpVidMem,pDdSurfaceGlobal32->fpVidMem,FLATPTR,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->dwLinearSize,pDdSurfaceGlobal32->dwLinearSize,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->yHint,pDdSurfaceGlobal32->yHint,LONG,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->xHint,pDdSurfaceGlobal32->xHint,LONG,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->wHeight,pDdSurfaceGlobal32->wHeight,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->wWidth,pDdSurfaceGlobal32->wWidth,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->dwReserved1,pDdSurfaceGlobal32->dwReserved1,ULONG_PTR,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->ddpfSurface,pDdSurfaceGlobal32->ddpfSurface,DDPIXELFORMAT,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->fpHeapOffset,pDdSurfaceGlobal32->fpHeapOffset,FLATPTR,IN)
            @ForceType(PreCall,pDdSurfaceGlobalCopy->hCreatorProcess,((unsigned)(pDdSurfaceGlobal32->hCreatorProcess)),HANDLE,IN)
                
            pDdSurfaceGlobal32++;
            pDdSurfaceGlobalCopy++;
        }
    }
}    

VOID
Wow64GdiDdThunkSurfaceGlobalPostCall(
    IN PDD_SURFACE_GLOBAL pDdSurfaceGlobal,
    IN OUT struct NT32_DD_SURFACE_GLOBAL * pDdSurfaceGlobal32,
    IN DWORD dwCount
)
{
    if( WOW64_ISPTR(pDdSurfaceGlobal32) && (dwCount>0))
    {
        while( (dwCount--) && (WOW64_ISPTR(pDdSurfaceGlobal32)))
        {
            if( pDdSurfaceGlobal )
            {
                @ForceType(PostCall,pDdSurfaceGlobal->dwBlockSizeY,pDdSurfaceGlobal32->dwBlockSizeY,DWORD,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->dwBlockSizeX,pDdSurfaceGlobal32->dwBlockSizeX,DWORD,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->fpVidMem,pDdSurfaceGlobal32->fpVidMem,FLATPTR,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->dwLinearSize,pDdSurfaceGlobal32->dwLinearSize,DWORD,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->yHint,pDdSurfaceGlobal32->yHint,LONG,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->xHint,pDdSurfaceGlobal32->xHint,LONG,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->wHeight,pDdSurfaceGlobal32->wHeight,DWORD,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->wWidth,pDdSurfaceGlobal32->wWidth,DWORD,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->dwReserved1,pDdSurfaceGlobal32->dwReserved1,ULONG_PTR,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->ddpfSurface,pDdSurfaceGlobal32->ddpfSurface,DDPIXELFORMAT,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->fpHeapOffset,pDdSurfaceGlobal32->fpHeapOffset,FLATPTR,OUT)
                @ForceType(PostCall,pDdSurfaceGlobal->hCreatorProcess,((unsigned)(pDdSurfaceGlobal32->hCreatorProcess)),HANDLE,OUT)            
            }
        
            pDdSurfaceGlobal32++;
            pDdSurfaceGlobal++;
        }
    }
}    

VOID
Wow64GdiDdThunkSurfaceLocalPreCall(
    IN OUT PDD_SURFACE_LOCAL * pDdSurfaceLocal,
    IN struct NT32_DD_SURFACE_LOCAL * pDdSurfaceLocal32,
    IN DWORD dwCount
)
{
    PDD_SURFACE_LOCAL pDdSurfaceLocalCopy = NULL;
    PDD_SURFACE_MORE pDdSurfaceMoreCopy = NULL;
    LPVIDEOMEMORY lpVidMemCopy = NULL;
    
    if( WOW64_ISPTR(pDdSurfaceLocal32) && (dwCount>0) )
    {
        pDdSurfaceLocalCopy = (PDD_SURFACE_LOCAL)Wow64AllocateTemp(sizeof(DD_SURFACE_LOCAL)*dwCount);
        *pDdSurfaceLocal = pDdSurfaceLocalCopy;
    }
    
    if(pDdSurfaceLocalCopy)
    {
        while( (dwCount--) && WOW64_ISPTR(pDdSurfaceLocal32) )
        {
            if( WOW64_ISPTR(pDdSurfaceLocal32->lpGbl) )
            {
                Wow64GdiDdThunkSurfaceGlobalPreCall(&(pDdSurfaceLocalCopy->lpGbl),(struct NT32_DD_SURFACE_GLOBAL *)(pDdSurfaceLocal32->lpGbl),1);
            } else
            {
                pDdSurfaceLocalCopy->lpGbl = NULL;
            }

            @ForceType(PreCall,pDdSurfaceLocalCopy->dwFlags,pDdSurfaceLocal32->dwFlags,DWORD,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->ddsCaps,pDdSurfaceLocal32->ddsCaps,DDSCAPS,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->dwReserved1,pDdSurfaceLocal32->dwReserved1,ULONG_PTR,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->ddckCKSrcBlt,pDdSurfaceLocal32->ddckCKSrcBlt,DDCOLORKEY,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->ddckCKDestOverlay,pDdSurfaceLocal32->ddckCKDestOverlay,DDCOLORKEY,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->ddckCKDestBlt,pDdSurfaceLocal32->ddckCKDestBlt,DDCOLORKEY,IN)
            @ForceType(PreCall,pDdSurfaceLocalCopy->rcOverlaySrc,pDdSurfaceLocal32->rcOverlaySrc,RECT,IN)
            
            @ForceType(PreCall,pDdSurfaceLocalCopy->lpSurfMore,pDdSurfaceLocal32->lpSurfMore,LPVOID,IN)
            
            pDdSurfaceLocalCopy->lpAttachList = NULL;
#if 0            
            if( WOW64_ISPTR(pDdSurfaceLocal32->lpAttachList) )
            {
                // need to walk the attach list chain
                PDD_ATTACHLIST ppCurrentAL;
                PDD_ATTACHLIST *ppCurrentALptr = &(pDdSurfaceLocalCopy->lpAttachList);                
                struct NT32_DD_ATTACHLIST *pCurrentAL32 = (struct NT32_DD_ATTACHLIST *)(pDdSurfaceLocal32->lpAttachList);
                
                while( NULL != pCurrentAL32 )
                {
                    ppCurrentAL = (PDD_ATTACHLIST)Wow64AllocateTemp(sizeof(DD_ATTACHLIST));
                    if( NULL != ppCurrentAL )
                    {
                        ppCurrentAL->lpLink = NULL;
                        Wow64GdiDdThunkSurfaceLocalPreCall((PDD_SURFACE_LOCAL *)&(ppCurrentAL->lpAttached),(struct NT32_DD_SURFACE_LOCAL *)(pCurrentAL32->lpAttached),1);
                        *ppCurrentALptr = ppCurrentAL;
                        ppCurrentALptr = &(ppCurrentAL->lpLink);
                        pCurrentAL32 = (struct NT32_DD_ATTACHLIST *)(pCurrentAL32->lpLink);
                    }
                }                                
            }
#endif

            pDdSurfaceLocalCopy->lpAttachListFrom = NULL;
#if 0            
            if( WOW64_ISPTR(pDdSurfaceLocal32->lpAttachListFrom) )
            {
                // need to walk the attach list from chain
                PDD_ATTACHLIST ppCurrentAL;
                PDD_ATTACHLIST *ppCurrentALptr = &(pDdSurfaceLocalCopy->lpAttachListFrom);                
                struct NT32_DD_ATTACHLIST *pCurrentAL32 = (struct NT32_DD_ATTACHLIST *)(pDdSurfaceLocal32->lpAttachListFrom);
                
                while( NULL != pCurrentAL32 )
                {
                    ppCurrentAL = (PDD_ATTACHLIST)Wow64AllocateTemp(sizeof(DD_ATTACHLIST));
                    if( NULL != ppCurrentAL )
                    {
                        ppCurrentAL->lpLink = NULL;
                        Wow64GdiDdThunkSurfaceLocalPreCall((PDD_SURFACE_LOCAL *)&(ppCurrentAL->lpAttached),(struct NT32_DD_SURFACE_LOCAL *)(pCurrentAL32->lpAttached),1);
                        *ppCurrentALptr = ppCurrentAL;
                        ppCurrentALptr = &(ppCurrentAL->lpLink);
                        pCurrentAL32 = (struct NT32_DD_ATTACHLIST *)(pCurrentAL32->lpLink);
                    }
                }                                
            }
#endif

            pDdSurfaceLocal32++;
            pDdSurfaceLocalCopy++;
        }    
    }
}

VOID
Wow64GdiDdThunkSurfaceLocalPostCall(
    IN OUT PDD_SURFACE_LOCAL pDdSurfaceLocal,
    IN struct NT32_DD_SURFACE_LOCAL * pDdSurfaceLocal32,
    IN DWORD dwCount
)
{
    DWORD dwIndex;
    
    if( WOW64_ISPTR(pDdSurfaceLocal32) )
    {
        for(dwIndex=0; dwIndex<dwCount; dwIndex++)
        {
            if(WOW64_ISPTR(pDdSurfaceLocal32->lpGbl))
            {
                Wow64GdiDdThunkSurfaceGlobalPostCall((PDD_SURFACE_GLOBAL)(&(pDdSurfaceLocal->lpGbl)),(struct NT32_DD_SURFACE_GLOBAL *)(&(pDdSurfaceLocal32->lpGbl)),1);
            }

            @ForceType(PostCall,pDdSurfaceLocal->dwFlags,pDdSurfaceLocal32->dwFlags,DWORD,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->ddsCaps,pDdSurfaceLocal32->ddsCaps,DDSCAPS,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->dwReserved1,pDdSurfaceLocal32->dwReserved1,ULONG_PTR,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->ddckCKSrcBlt,pDdSurfaceLocal32->ddckCKSrcBlt,DDCOLORKEY,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->ddckCKDestOverlay,pDdSurfaceLocal32->ddckCKDestOverlay,DDCOLORKEY,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->ddckCKDestBlt,pDdSurfaceLocal32->ddckCKDestBlt,DDCOLORKEY,OUT)
            @ForceType(PostCall,pDdSurfaceLocal->rcOverlaySrc,pDdSurfaceLocal32->rcOverlaySrc,RECT,OUT)
                
            pDdSurfaceLocal++;
            pDdSurfaceLocal32++;
        }
    }
})
End=
Locals=
BYTE pdedCopy[sizeof(struct _D3D8_DRAWPRIMITIVES2DATA)]; @NL
struct NT32_D3DNTHAL_DRAWPRIMITIVES2DATA *pdedHostCopy; @NL
struct NT32_D3D8_DRAWPRIMITIVES2DATA *pdedXHostCopy; @NL
struct _D3D8_DRAWPRIMITIVES2DATA *pdedX; @NL
pded = (LPD3DNTHAL_DRAWPRIMITIVES2DATA)pdedCopy; @NL
pdedX = (struct _D3D8_DRAWPRIMITIVES2DATA *)pdedCopy; @NL
pdedHostCopy = (struct NT32_D3DNTHAL_DRAWPRIMITIVES2DATA *)pdedHost; @NL
pdedXHostCopy = (struct NT32_D3D8_DRAWPRIMITIVES2DATA *)pdedHost; @NL
End=
PreCall=
hCmdBuf=(HANDLE)((unsigned)hCmdBufHost); @NL
hVBuf=(HANDLE)((unsigned)hVBufHost); @NL
if(ARGUMENT_PRESENT(pdedHost)) { @Indent( @NL
@ForceType(PreCall,pded->dwhContext,pdedHostCopy->dwhContext,ULONG_PTR,IN)
@ForceType(PreCall,pded->dwFlags,pdedHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,pded->dwVertexType,pdedHostCopy->dwVertexType,DWORD,IN)
if( (pded->dwFlags & D3DHALDP2_USERMEMVERTICES) == D3DHALDP2_USERMEMVERTICES ) { @Indent( @NL
@ForceType(PreCall,pded->lpVertices,pdedHostCopy->lpVertices,LPVOID,IN)
)} else { @Indent( @NL
@ForceType(PreCall,pded->lpDDVertex,pdedHostCopy->lpDDVertex,LPVOID,IN)
)} @NL
@ForceType(PreCall,pded->lpDDCommands,pdedHostCopy->lpDDCommands,PVOID,IN)
@ForceType(PreCall,pded->dwCommandOffset,pdedHostCopy->dwCommandOffset,DWORD,IN)
@ForceType(PreCall,pded->dwCommandLength,pdedHostCopy->dwCommandLength,DWORD,IN)
@ForceType(PreCall,pded->dwVertexOffset,pdedHostCopy->dwVertexOffset,DWORD,IN)
@ForceType(PreCall,pded->dwVertexLength,pdedHostCopy->dwVertexLength,DWORD,IN)
@ForceType(PreCall,pded->dwReqVertexBufSize,pdedHostCopy->dwReqVertexBufSize,DWORD,IN)
@ForceType(PreCall,pded->dwReqCommandBufSize,pdedHostCopy->dwReqCommandBufSize,DWORD,IN)
@ForceType(PreCall,pded->lpdwRStates,pdedHostCopy->lpdwRStates,LPDWORD,IN)
@ForceType(PreCall,pded->dwVertexSize,pdedHostCopy->dwVertexSize,DWORD,IN)
@ForceType(PreCall,pded->dwErrorOffset,pdedHostCopy->dwErrorOffset,DWORD,IN)
@ForceType(PreCall,pdedX->fpVidMem_CB,pdedXHostCopy->fpVidMem_CB,ULONG_PTR,IN)
@ForceType(PreCall,pdedX->dwLinearSize_CB,pdedXHostCopy->dwLinearSize_CB,DWORD,IN)
@ForceType(PreCall,pdedX->fpVidMem_VB,pdedXHostCopy->fpVidMem_VB,ULONG_PTR,IN)
@ForceType(PreCall,pdedX->dwLinearSize_VB,pdedXHostCopy->dwLinearSize_VB,DWORD,IN)
@NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(pdedHost)) { @Indent( @NL
@ForceType(PostCall,pded->ddrval,pdedHostCopy->ddrval,HRESULT,OUT)
@ForceType(PostCall,pded->dwErrorOffset,pdedHostCopy->dwErrorOffset,DWORD,OUT)
@ForceType(PostCall,pdedX->fpVidMem_CB,pdedXHostCopy->fpVidMem_CB,ULONG_PTR,OUT)
@ForceType(PostCall,pdedX->dwLinearSize_CB,pdedXHostCopy->dwLinearSize_CB,DWORD,OUT)
@ForceType(PostCall,pdedX->fpVidMem_VB,pdedXHostCopy->fpVidMem_VB,ULONG_PTR,OUT)
@ForceType(PostCall,pdedX->dwLinearSize_VB,pdedXHostCopy->dwLinearSize_VB,DWORD,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetDriverState
NoType=pdata
Locals=
BYTE pdataCopy[sizeof(DD_GETDRIVERSTATEDATA)]; @NL
pdata=(PDD_GETDRIVERSTATEDATA)pdataCopy;
End=
PreCall=
if(ARGUMENT_PRESENT(pdataHost)) { @Indent( @NL
@ForceType(PreCall,pdata->dwFlags,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->dwFlags,DWORD,IN)
@ForceType(PreCall,pdata->dwhContext,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->dwhContext,DWORD_PTR,IN)
@ForceType(PreCall,pdata->lpdwStates,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->lpdwStates,LPDWORD,IN)
@ForceType(PreCall,pdata->dwLength,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->dwLength,DWORD,IN)
@ForceType(PreCall,pdata->ddRVal,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->ddRVal,HRESULT,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(pdataHost)) { @Indent( @NL
@ForceType(PostCall,pdata->lpdwStates,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->lpdwStates,LPDWORD,OUT)
@ForceType(PostCall,pdata->ddRVal,((struct NT32_DD_GETDRIVERSTATEDATA *)pdataHost)->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdAddAttachedSurface
NoType=hSurface
NoType=hSurfaceAttached
NoType=puAddAttachedSurfaceData
Locals=
BYTE puAddAttachedSurfaceDataCopy[sizeof(DD_ADDATTACHEDSURFACEDATA)]; @NL
struct NT32_DD_ADDATTACHEDSURFACEDATA * puAddAttachedSurfaceDataHostCopy; @NL
puAddAttachedSurfaceData=(PDD_ADDATTACHEDSURFACEDATA)puAddAttachedSurfaceDataCopy; @NL
puAddAttachedSurfaceDataHostCopy=(struct NT32_DD_ADDATTACHEDSURFACEDATA *)puAddAttachedSurfaceDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
hSurfaceAttached=(HANDLE)((unsigned)hSurfaceAttachedHost); @NL
if(ARGUMENT_PRESENT(puAddAttachedSurfaceDataHost)) { @Indent( @NL
@ForceType(PreCall,puAddAttachedSurfaceData->lpDD,puAddAttachedSurfaceDataHostCopy->lpDD,PVOID,IN)
Wow64GdiDdThunkSurfaceLocalPreCall(&(puAddAttachedSurfaceData->lpDDSurface),(struct NT32_DD_SURFACE_LOCAL *)(puAddAttachedSurfaceDataHostCopy->lpDDSurface),1); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puAddAttachedSurfaceData->lpSurfAttached),(struct NT32_DD_SURFACE_LOCAL *)(puAddAttachedSurfaceDataHostCopy->lpSurfAttached),1); @NL
@ForceType(PreCall,puAddAttachedSurfaceData->ddRVal,puAddAttachedSurfaceDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puAddAttachedSurfaceData->AddAttachedSurface,puAddAttachedSurfaceDataHostCopy->AddAttachedSurface,PVOID,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puAddAttachedSurfaceDataHost)) { @Indent( @NL
@ForceType(PostCall,puAddAttachedSurfaceData->ddRVal,puAddAttachedSurfaceDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdAlphaBlt
NoType=hSurfaceDest
NoType=hSurfaceSrc
NoType=puBltData
Locals=
BYTE puBltDataCopy[sizeof(DD_BLTDATA)]; @NL
puBltData = (PDD_BLTDATA)puBltDataCopy; @NL
End=
PreCall=
hSurfaceDest=(HANDLE)((unsigned)hSurfaceDestHost); @NL
hSurfaceSrc=(HANDLE)((unsigned)hSurfaceSrcHost); @NL
if(ARGUMENT_PRESENT(puBltDataHost)) { @Indent( @NL
Wow64GdiDdThunkBltDataPreCall(&puBltData,(struct NT32_DD_BLTDATA *)(puBltDataHost)); @NL
)} else { @Indent( @NL
puBltData = NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puBltDataHost)) { @Indent( @NL
@ForceType(PostCall,puBltData->ddRVal,((struct NT32_DD_BLTDATA *)puBltDataHost)->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdAttachSurface
NoType=hSurfaceFrom
NoType=hSurfaceTo
PreCall=
hSurfaceFrom=(HANDLE)((unsigned)hSurfaceFromHost); @NL
hSurfaceTo=(HANDLE)((unsigned)hSurfaceToHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdBeginMoCompFrame
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdBlt
NoType=hSurfaceDest
NoType=hSurfaceSrc
NoType=puBltData
Header=
@NoFormat(
VOID
Wow64GdiDdThunkBltDataPreCall(
    IN OUT PDD_BLTDATA * pDdBltData,
    IN struct NT32_DD_BLTDATA * pDdBltData32
)
{
    PDD_BLTDATA pDdBltDataCopy = NULL;
    
    if( WOW64_ISPTR(pDdBltData32) )
    {
        pDdBltDataCopy = (PDD_BLTDATA)Wow64AllocateTemp(sizeof(DD_BLTDATA));
        if( pDdBltDataCopy )
        {
            pDdBltDataCopy->lpDD=(PDD_DIRECTDRAW_GLOBAL)pDdBltData32->lpDD;
            Wow64GdiDdThunkSurfaceLocalPreCall(&(pDdBltDataCopy->lpDDDestSurface),(struct NT32_DD_SURFACE_LOCAL *)(pDdBltData32->lpDDDestSurface),1);
            @ForceType(PreCall,pDdBltDataCopy->rDest,pDdBltData32->rDest,RECTL,IN)
            Wow64GdiDdThunkSurfaceLocalPreCall(&(pDdBltDataCopy->lpDDSrcSurface),(struct NT32_DD_SURFACE_LOCAL *)(pDdBltData32->lpDDSrcSurface),1);
            @ForceType(PreCall,pDdBltDataCopy->rSrc,pDdBltData32->rSrc,RECTL,IN)
            @ForceType(PreCall,pDdBltDataCopy->dwFlags,pDdBltData32->dwFlags,DWORD,IN)
            @ForceType(PreCall,pDdBltDataCopy->dwROPFlags,pDdBltData32->dwROPFlags,DWORD,IN)
            @ForceType(PreCall,pDdBltDataCopy->bltFX,pDdBltData32->bltFX,DDBLTFX,IN)
            @ForceType(PreCall,pDdBltDataCopy->ddRVal,pDdBltData32->ddRVal,HRESULT,IN)
            @ForceType(PreCall,pDdBltDataCopy->Blt,pDdBltData32->Blt,PVOID,IN)
            @ForceType(PreCall,pDdBltDataCopy->IsClipped,pDdBltData32->IsClipped,BOOL,IN)
            @ForceType(PreCall,pDdBltDataCopy->rOrigDest,pDdBltData32->rOrigDest,RECTL,IN)
            @ForceType(PreCall,pDdBltDataCopy->rOrigSrc,pDdBltData32->rOrigSrc,RECTL,IN)
            @ForceType(PreCall,pDdBltDataCopy->dwRectCnt,pDdBltData32->dwRectCnt,DWORD,IN)
            @ForceType(PreCall,pDdBltDataCopy->prDestRects,pDdBltData32->prDestRects,PVOID,IN)
            @ForceType(PreCall,pDdBltDataCopy->dwAFlags,pDdBltData32->dwAFlags,DWORD,IN)
            @ForceType(PreCall,pDdBltDataCopy->ddargbScaleFactors,pDdBltData32->ddargbScaleFactors,DDARGB,IN)   
        }
    }
    *pDdBltData = pDdBltDataCopy;
})
End=
Locals=
BYTE puBltDataCopy[sizeof(DD_BLTDATA)]; @NL
puBltData = (PDD_BLTDATA)puBltDataCopy; @NL
End=
PreCall=
hSurfaceDest=(HANDLE)((unsigned)hSurfaceDestHost); @NL
hSurfaceSrc=(HANDLE)((unsigned)hSurfaceSrcHost); @NL
if(ARGUMENT_PRESENT(puBltDataHost)) { @Indent( @NL
Wow64GdiDdThunkBltDataPreCall(&puBltData,(struct NT32_DD_BLTDATA *)(puBltDataHost)); @NL
)} else { @Indent( @NL
puBltData = NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puBltDataHost)) { @Indent( @NL
@ForceType(PostCall,puBltData->ddRVal,(((struct NT32_DD_BLTDATA *)puBltDataHost)->ddRVal),HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdCanCreateSurface
NoType=hDirectDraw
NoType=puCanCreateSurfaceData
Locals=
BYTE puCanCreateSurfaceDataCopy[sizeof(DD_CANCREATESURFACEDATA)]; @NL
NT32DD_CANCREATESURFACEDATA *puCanCreateSurfaceDataHostCopy; @NL
LPDDSURFACEDESC2 pDDS2; @NL
struct NT32_DDSURFACEDESC2 *pDDS2Host; @NL
@ForceType(Locals,pDDS2,pDDS2Host,LPDDSURFACEDESC2,IN)
puCanCreateSurfaceData=(DD_CANCREATESURFACEDATA *)puCanCreateSurfaceDataCopy; @NL
puCanCreateSurfaceDataHostCopy=(NT32DD_CANCREATESURFACEDATA *)puCanCreateSurfaceDataHost; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puCanCreateSurfaceDataHost)) { @Indent( @NL
@ForceType(PreCall,puCanCreateSurfaceData->lpDD,puCanCreateSurfaceDataHostCopy->lpDD,PVOID,IN)
pDDS2Host=(struct NT32_DDSURFACEDESC2 *)(puCanCreateSurfaceDataHostCopy->lpDDSurfaceDesc); @NL
@ForceType(PreCall,pDDS2,pDDS2Host,LPDDSURFACEDESC2,IN)
puCanCreateSurfaceData->lpDDSurfaceDesc=(PDD_SURFACEDESC)pDDS2;
@ForceType(PreCall,puCanCreateSurfaceData->bIsDifferentPixelFormat,puCanCreateSurfaceDataHostCopy->bIsDifferentPixelFormat,DWORD,IN)
@ForceType(PreCall,puCanCreateSurfaceData->ddRVal,puCanCreateSurfaceDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puCanCreateSurfaceData->CanCreateSurface,puCanCreateSurfaceDataHostCopy->CanCreateSurface,PVOID,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puCanCreateSurfaceDataHost)) { @Indent( @NL
@ForceType(PostCall,puCanCreateSurfaceData->ddRVal,puCanCreateSurfaceDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,pDDS2,pDDS2Host,LPDDSURFACEDESC2,OUT)
)} @NL
End=

TemplateName=NtGdiDdCanCreateD3DBuffer
NoType=hDirectDraw
NoType=puCanCreateSurfaceData
Locals=
BYTE puCanCreateSurfaceDataCopy[sizeof(DD_CANCREATESURFACEDATA)]; @NL
NT32DD_CANCREATESURFACEDATA *puCanCreateSurfaceDataHostCopy; @NL
LPDDSURFACEDESC2 pDDS2; @NL
struct NT32_DDSURFACEDESC2 *pDDS2Host; @NL
@ForceType(Locals,pDDS2,pDDS2Host,LPDDSURFACEDESC2,IN)
puCanCreateSurfaceData=(DD_CANCREATESURFACEDATA *)puCanCreateSurfaceDataCopy; @NL
puCanCreateSurfaceDataHostCopy=(NT32DD_CANCREATESURFACEDATA *)puCanCreateSurfaceDataHost; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puCanCreateSurfaceDataHost)) { @Indent( @NL
@ForceType(PreCall,puCanCreateSurfaceData->lpDD,puCanCreateSurfaceDataHostCopy->lpDD,PVOID,IN)
pDDS2Host=(struct NT32_DDSURFACEDESC2 *)(puCanCreateSurfaceDataHostCopy->lpDDSurfaceDesc); @NL
@ForceType(PreCall,pDDS2,pDDS2Host,LPDDSURFACEDESC2,IN)
puCanCreateSurfaceData->lpDDSurfaceDesc=(PDD_SURFACEDESC)pDDS2;
@ForceType(PreCall,puCanCreateSurfaceData->bIsDifferentPixelFormat,puCanCreateSurfaceDataHostCopy->bIsDifferentPixelFormat,DWORD,IN)
@ForceType(PreCall,puCanCreateSurfaceData->ddRVal,puCanCreateSurfaceDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puCanCreateSurfaceData->CanCreateSurface,puCanCreateSurfaceDataHostCopy->CanCreateSurface,PVOID,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puCanCreateSurfaceDataHost)) { @Indent( @NL
@ForceType(PostCall,puCanCreateSurfaceData->ddRVal,puCanCreateSurfaceDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdColorControl
NoType=hSurface
NoType=puColorControlData
Locals=
BYTE puColorControlDataCopy[sizeof(DD_COLORCONTROLDATA)]; @NL
struct NT32_DD_COLORCONTROLDATA *puColorControlDataHostCopy; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puColorControlDataHost)) { @Indent( @NL
puColorControlData=(PDD_COLORCONTROLDATA)puColorControlDataCopy; @NL
puColorControlDataHostCopy=(struct NT32_DD_COLORCONTROLDATA *)puColorControlDataHost; @NL
@ForceType(PreCall,puColorControlData->lpDD,puColorControlDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puColorControlData->lpDDSurface,puColorControlDataHostCopy->lpDDSurface,LPVOID,IN)
@ForceType(PreCall,puColorControlData->dwFlags,puColorControlDataHostCopy->dwFlags,DWORD,IN)
if( (puColorControlDataHostCopy->dwFlags & DDRAWI_SETCOLOR) == DDRAWI_SETCOLOR ) { @Indent( @NL
@ForceType(PreCall,puColorControlData->lpColorData,puColorControlDataHostCopy->lpColorData,LPDDCOLORCONTROL,IN)
)} @NL
@ForceType(PreCall,puColorControlData->ddRVal,puColorControlDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puColorControlData->ColorControl,puColorControlDataHostCopy->ColorControl,LPVOID,IN)
)} else { @Indent( @NL
puColorControlData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puColorControlDataHost)) { @Indent( @NL
if( (puColorControlDataHostCopy->dwFlags & DDRAWI_GETCOLOR) == DDRAWI_GETCOLOR ) { @Indent( @NL
@ForceType(PostCall,puColorControlData->lpColorData,puColorControlDataHostCopy->lpColorData,LPDDCOLORCONTROL,OUT)
)} @NL
@ForceType(PostCall,puColorControlData->ddRVal,puColorControlDataHostCopy->ddRVal,HRESULT,OUT)

)} @NL
End=

TemplateName=NtGdiDdCreateDirectDrawObject
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdCreateSurface
NoType=hDirectDraw
NoType=hSurface
NoType=puSurfaceDescription
NoType=puSurfaceGlobalData
NoType=puSurfaceLocalData
NoType=puSurfaceMoreData
NoType=puCreateSurfaceData
NoType=puhSurface
Locals=
BYTE CreateSurfaceDataCopy[sizeof(DD_CREATESURFACEDATA)]; @NL
NT32HANDLE *puhSurfaceHostCopy;
DWORD dwCount;
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puCreateSurfaceDataHost)) { @Indent( @NL
puCreateSurfaceData = (DD_CREATESURFACEDATA *)CreateSurfaceDataCopy; @NL
RtlZeroMemory(puCreateSurfaceData, sizeof(DD_CREATESURFACEDATA)); @NL
puCreateSurfaceData->dwSCnt = ((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->dwSCnt; @NL
puCreateSurfaceData->ddRVal = ((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->ddRVal; @NL
dwCount=puCreateSurfaceData->dwSCnt; @NL
Wow64GdiDdThunkSurfaceHandlesPreCall(&hSurface,(NT32HANDLE *)hSurfaceHost,dwCount); @NL
Wow64GdiDdThunkSurfaceDescriptionPreCall(&puSurfaceDescription,(struct NT32_DDSURFACEDESC *)puSurfaceDescriptionHost,1,dwCount); @NL
Wow64GdiDdThunkSurfaceGlobalPreCall(&(puSurfaceGlobalData),((struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost),dwCount); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puSurfaceLocalData),((struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost),dwCount); @NL
Wow64GdiDdThunkSurfaceMorePreCall(&(puSurfaceMoreData),((struct NT32_DD_SURFACE_MORE *)puSurfaceMoreDataHost),dwCount); @NL
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurface=(HANDLE *)Wow64AllocateTemp(sizeof(HANDLE)*dwCount); @NL
)} else { @Indent( @NL
puhSurface=NULL; @NL
)} @NL
)} else { @Indent( @NL
puCreateSurfaceData=NULL; @NL
Wow64GdiDdThunkSurfaceHandlesPreCall(&hSurface,(NT32HANDLE *)hSurfaceHost,1); @NL
Wow64GdiDdThunkSurfaceDescriptionPreCall(&puSurfaceDescription,(struct NT32_DDSURFACEDESC *)puSurfaceDescriptionHost,1,1); @NL
Wow64GdiDdThunkSurfaceGlobalPreCall(&(puSurfaceGlobalData),((struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost),1); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puSurfaceLocalData),((struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost),1); @NL
Wow64GdiDdThunkSurfaceMorePreCall(&(puSurfaceMoreData),((struct NT32_DD_SURFACE_MORE *)puSurfaceMoreDataHost),1); @NL
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurface=(HANDLE *)Wow64AllocateTemp(sizeof(HANDLE)); @NL
)} else { @Indent( @NL
puhSurface=NULL; @NL
)} @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puCreateSurfaceDataHost)) { @Indent( @NL
((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->ddRVal = puCreateSurfaceData->ddRVal; @NL
Wow64GdiDdThunkSurfaceGlobalPostCall(puSurfaceGlobalData,(struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost,dwCount); @NL
Wow64GdiDdThunkSurfaceLocalPostCall(puSurfaceLocalData,(struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost,dwCount);
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurfaceHostCopy=(NT32HANDLE *)puhSurfaceHost; @NL
while(dwCount--) { @Indent( @NL
*puhSurfaceHostCopy=(NT32HANDLE)(*puhSurface); @NL
puhSurfaceHostCopy++;
puhSurface++;
)} @NL
)} @NL
)} else { @Indent( @NL
Wow64GdiDdThunkSurfaceGlobalPostCall(puSurfaceGlobalData,(struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost,1); @NL
Wow64GdiDdThunkSurfaceLocalPostCall(puSurfaceLocalData,(struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost,1);
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurfaceHostCopy=(NT32HANDLE *)puhSurfaceHost; @NL
*puhSurfaceHostCopy=(NT32HANDLE)(*puhSurface); @NL
)} @NL
)} @NL
End=

TemplateName=NtGdiDdCreateSurfaceEx
NoType=hDirectDraw
NoType=hSurface
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdCreateD3DBuffer
NoType=hDirectDraw
NoType=hSurface
NoType=puSurfaceDescription
NoType=puSurfaceGlobalData
NoType=puSurfaceLocalData
NoType=puSurfaceMoreData
NoType=puCreateSurfaceData
NoType=puhSurface
Locals=
BYTE CreateSurfaceDataCopy[sizeof(DD_CREATESURFACEDATA)]; @NL
NT32HANDLE *puhSurfaceHostCopy;
DWORD dwCount;
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puCreateSurfaceDataHost)) { @Indent( @NL
puCreateSurfaceData = (DD_CREATESURFACEDATA *)CreateSurfaceDataCopy; @NL
RtlZeroMemory(puCreateSurfaceData, sizeof(DD_CREATESURFACEDATA)); @NL
puCreateSurfaceData->dwSCnt = ((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->dwSCnt; @NL
puCreateSurfaceData->ddRVal = ((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->ddRVal; @NL
dwCount=puCreateSurfaceData->dwSCnt; @NL
Wow64GdiDdThunkSurfaceHandlesPreCall(&hSurface,(NT32HANDLE *)hSurfaceHost,dwCount); @NL
Wow64GdiDdThunkSurfaceDescriptionPreCall(&puSurfaceDescription,(struct NT32_DDSURFACEDESC *)puSurfaceDescriptionHost,1,dwCount); @NL
Wow64GdiDdThunkSurfaceGlobalPreCall(&(puSurfaceGlobalData),((struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost),dwCount); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puSurfaceLocalData),((struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost),dwCount); @NL
Wow64GdiDdThunkSurfaceMorePreCall(&(puSurfaceMoreData),((struct NT32_DD_SURFACE_MORE *)puSurfaceMoreDataHost),dwCount); @NL
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurface=(HANDLE *)Wow64AllocateTemp(sizeof(HANDLE)*dwCount); @NL
)} else { @Indent( @NL
puhSurface=NULL; @NL
)} @NL
)} else { @Indent( @NL
puCreateSurfaceData=NULL; @NL
Wow64GdiDdThunkSurfaceHandlesPreCall(&hSurface,(NT32HANDLE *)hSurfaceHost,1); @NL
Wow64GdiDdThunkSurfaceDescriptionPreCall(&puSurfaceDescription,(struct NT32_DDSURFACEDESC *)puSurfaceDescriptionHost,1,1); @NL
Wow64GdiDdThunkSurfaceGlobalPreCall(&(puSurfaceGlobalData),((struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost),1); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puSurfaceLocalData),((struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost),1); @NL
Wow64GdiDdThunkSurfaceMorePreCall(&(puSurfaceMoreData),((struct NT32_DD_SURFACE_MORE *)puSurfaceMoreDataHost),1); @NL
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurface=(HANDLE *)Wow64AllocateTemp(sizeof(HANDLE)); @NL
)} else { @Indent( @NL
puhSurface=NULL; @NL
)} @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puCreateSurfaceDataHost)) { @Indent( @NL
((struct NT32_DD_CREATESURFACEDATA *)puCreateSurfaceDataHost)->ddRVal = puCreateSurfaceData->ddRVal; @NL
Wow64GdiDdThunkSurfaceGlobalPostCall(puSurfaceGlobalData,(struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost,dwCount); @NL
Wow64GdiDdThunkSurfaceLocalPostCall(puSurfaceLocalData,(struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost,dwCount);
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurfaceHostCopy=(NT32HANDLE *)puhSurfaceHost; @NL
while(dwCount--) { @Indent( @NL
*puhSurfaceHostCopy=(NT32HANDLE)(*puhSurface); @NL
puhSurfaceHostCopy++;
puhSurface++;
)} @NL
)} @NL
)} else { @Indent( @NL
Wow64GdiDdThunkSurfaceGlobalPostCall(puSurfaceGlobalData,(struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalDataHost,1); @NL
Wow64GdiDdThunkSurfaceLocalPostCall(puSurfaceLocalData,(struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalDataHost,1);
if(ARGUMENT_PRESENT(puhSurfaceHost)) { @Indent( @NL
puhSurfaceHostCopy=(NT32HANDLE *)puhSurfaceHost; @NL
*puhSurfaceHostCopy=(NT32HANDLE)(*puhSurface); @NL
)} @NL
)} @NL
End=

TemplateName=NtGdiDdCreateMoComp
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdCreateSurfaceObject
NoType=hDirectDrawLocal
NoType=hSurface
NoType=puSurfaceGlobal
NoType=puSurfaceLocal
NoType=puSurfaceMore
PreCall=
hDirectDrawLocal=(HANDLE)((unsigned)hDirectDrawLocalHost); @NL
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
Wow64GdiDdThunkSurfaceGlobalPreCall(&(puSurfaceGlobal),((struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalHost),1); @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puSurfaceLocal),((struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalHost),1); @NL
Wow64GdiDdThunkSurfaceMorePreCall(&(puSurfaceMore),((struct NT32_DD_SURFACE_MORE *)puSurfaceMoreHost),1); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
Wow64GdiDdThunkSurfaceGlobalPostCall(puSurfaceGlobal,(struct NT32_DD_SURFACE_GLOBAL *)puSurfaceGlobalHost,1); @NL
Wow64GdiDdThunkSurfaceLocalPostCall(puSurfaceLocal,(struct NT32_DD_SURFACE_LOCAL *)puSurfaceLocalHost,1);
End=

TemplateName=NtGdiDdDeleteDirectDrawObject
NoType=hDirectDrawLocal
PreCall=
hDirectDrawLocal=(HANDLE)((unsigned)hDirectDrawLocalHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdDeleteSurfaceObject
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdDestroyMoComp
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdDestroySurface
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdDestroyD3DBuffer
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdEndMoCompFrame
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdFlip
NoType=hSurfaceCurrent
NoType=hSurfaceTarget
NoType=hSurfaceCurrentLeft
NoType=hSurfaceTargetLeft
NoType=puFlipData
Locals=
BYTE puFlipDataCopy[sizeof(DD_FLIPDATA)]; @NL
struct NT32_DD_FLIPDATA *puFlipDataHostCopy;
puFlipData=(PDD_FLIPDATA)puFlipDataCopy; @NL
puFlipDataHostCopy=(struct NT32_DD_FLIPDATA *)puFlipDataHost; @NL
End=
PreCall=
hSurfaceCurrent=(HANDLE)((unsigned)hSurfaceCurrentHost); @NL
hSurfaceTarget=(HANDLE)((unsigned)hSurfaceTargetHost); @NL
hSurfaceCurrentLeft=(HANDLE)((unsigned)hSurfaceCurrentLeftHost); @NL
hSurfaceTargetLeft=(HANDLE)((unsigned)hSurfaceTargetLeftHost); @NL
if(ARGUMENT_PRESENT(puFlipDataHost)) { @Indent( @NL
RtlZeroMemory(puFlipDataCopy,sizeof(DD_FLIPDATA)); @NL
@ForceType(PreCall,puFlipData->dwFlags,puFlipDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puFlipData->ddRVal,puFlipDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puFlipData->Flip,puFlipDataHostCopy->Flip,PVOID,IN)
)} else { @Indent( @NL
puFlipData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puFlipData->ddRVal,puFlipDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puFlipData->Flip,puFlipDataHostCopy->Flip,PVOID,OUT)
End=

TemplateName=NtGdiDdFlipToGDISurface
NoType=hDirectDraw
NoType=puFlipToGDISurfaceData
Locals=
BYTE puFlipToGDISurfaceDataCopy[sizeof(DD_FLIPTOGDISURFACEDATA)]; @NL
struct NT32_DD_FLIPTOGDISURFACEDATA *puFlipToGDISurfaceDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puFlipToGDISurfaceDataHost)) { @Indent( @NL
puFlipToGDISurfaceData=(PDD_FLIPTOGDISURFACEDATA)puFlipToGDISurfaceDataCopy; @NL
puFlipToGDISurfaceDataHostCopy=(struct NT32_DD_FLIPTOGDISURFACEDATA *)puFlipToGDISurfaceDataHost; @NL
@ForceType(PreCall,puFlipToGDISurfaceData->lpDD,puFlipToGDISurfaceDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puFlipToGDISurfaceData->dwToGDI,puFlipToGDISurfaceDataHostCopy->dwToGDI,DWORD,IN)
@ForceType(PreCall,puFlipToGDISurfaceData->dwReserved,puFlipToGDISurfaceDataHostCopy->dwReserved,DWORD,IN)
@ForceType(PreCall,puFlipToGDISurfaceData->ddRVal,puFlipToGDISurfaceDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puFlipToGDISurfaceData->FlipToGDISurface,puFlipToGDISurfaceDataHostCopy->FlipToGDISurface,LPVOID,IN)
)} else { @Indent( @NL
puFlipToGDISurfaceData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puFlipToGDISurfaceDataHost)) { @Indent( @NL
@ForceType(PostCall,puFlipToGDISurfaceData->ddRVal,puFlipToGDISurfaceDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puFlipToGDISurfaceData->FlipToGDISurface,puFlipToGDISurfaceDataHostCopy->FlipToGDISurface,LPVOID,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetAvailDriverMemory
NoType=hDirectDraw
NoType=puGetAvailDriverMemoryData
Locals=
BYTE puGetAvailDriverMemoryDataCopy[sizeof(DD_GETAVAILDRIVERMEMORYDATA)]; @NL
struct NT32_DD_GETAVAILDRIVERMEMORYDATA *puGetAvailDriverMemoryDataHostCopy;
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetAvailDriverMemoryDataHost)) { @Indent( @NL
puGetAvailDriverMemoryData=(PDD_GETAVAILDRIVERMEMORYDATA)puGetAvailDriverMemoryDataCopy; @NL
puGetAvailDriverMemoryDataHostCopy=(struct NT32_DD_GETAVAILDRIVERMEMORYDATA *)puGetAvailDriverMemoryDataHost; @NL
@ForceType(PreCall,puGetAvailDriverMemoryData->lpDD,puGetAvailDriverMemoryDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetAvailDriverMemoryData->DDSCaps,puGetAvailDriverMemoryDataHostCopy->DDSCaps,DDSCAPS,IN)
@ForceType(PreCall,puGetAvailDriverMemoryData->dwTotal,puGetAvailDriverMemoryDataHostCopy->dwTotal,DWORD,IN)
@ForceType(PreCall,puGetAvailDriverMemoryData->dwFree,puGetAvailDriverMemoryDataHostCopy->dwFree,DWORD,IN)
@ForceType(PreCall,puGetAvailDriverMemoryData->ddRVal,puGetAvailDriverMemoryDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puGetAvailDriverMemoryData->GetAvailDriverMemory,puGetAvailDriverMemoryDataHostCopy->GetAvailDriverMemory,LPVOID,IN)
)} else { @Indent( @NL
puGetAvailDriverMemoryData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetAvailDriverMemoryDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetAvailDriverMemoryData->DDSCaps,puGetAvailDriverMemoryDataHostCopy->DDSCaps,DDSCAPS,OUT)
@ForceType(PostCall,puGetAvailDriverMemoryData->dwTotal,puGetAvailDriverMemoryDataHostCopy->dwTotal,DWORD,OUT)
@ForceType(PostCall,puGetAvailDriverMemoryData->dwFree,puGetAvailDriverMemoryDataHostCopy->dwFree,DWORD,OUT)
@ForceType(PostCall,puGetAvailDriverMemoryData->ddRVal,puGetAvailDriverMemoryDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puGetAvailDriverMemoryData->GetAvailDriverMemory,puGetAvailDriverMemoryDataHostCopy->GetAvailDriverMemory,LPVOID,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetBltStatus
NoType=hSurface
NoType=puGetBltStatusData
Locals=
BYTE puGetBltStatusDataCopy[sizeof(DD_GETBLTSTATUSDATA)]; @NL
struct NT32_DD_GETBLTSTATUSDATA *puGetBltStatusDataHostCopy; @NL
puGetBltStatusData=(PDD_GETBLTSTATUSDATA)puGetBltStatusDataCopy; @NL
puGetBltStatusDataHostCopy=(struct NT32_DD_GETBLTSTATUSDATA *)puGetBltStatusDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puGetBltStatusDataHost)) { @Indent( @NL
RtlZeroMemory(puGetBltStatusDataCopy,sizeof(DD_GETBLTSTATUSDATA)); @NL
@ForceType(PreCall,puGetBltStatusData->dwFlags,puGetBltStatusDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puGetBltStatusData->ddRVal,puGetBltStatusDataHostCopy->ddRVal,DWORD,IN)
@ForceType(PreCall,puGetBltStatusData->GetBltStatus,puGetBltStatusDataHostCopy->GetBltStatus,PVOID,IN)
)} else { @Indent( @NL
puGetBltStatusData=NULL;
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puGetBltStatusData->ddRVal,puGetBltStatusDataHostCopy->ddRVal,DWORD,OUT)
@ForceType(PostCall,puGetBltStatusData->GetBltStatus,puGetBltStatusDataHostCopy->GetBltStatus,PVOID,OUT)
End=

TemplateName=NtGdiDdGetDC
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdGetDriverInfo
NoType=hDirectDraw
Header=
@NoFormat(
DWORD
whNtGdiDdGetDriverInfoInternal(
    IN HANDLE hDirectDraw,
    IN OUT PDD_GETDRIVERINFODATA pGetDriverInfoData)
{
    DWORD dwRet;
    DD_GETDRIVERINFODATA GetDriverInfoData;
    
    GetDriverInfoData = *pGetDriverInfoData;
    
    if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_VideoPortCallbacks))
    {
        DD_VIDEOPORTCALLBACKS           VideoPortCallBacks;
        LPDDHAL_DDVIDEOPORTCALLBACKS    lpVideoPortCallBacks;
        
        lpVideoPortCallBacks             = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &VideoPortCallBacks;
        GetDriverInfoData.dwExpectedSize = sizeof(VideoPortCallBacks);
        
        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        @ForceType(PostCall,((PDD_VIDEOPORTCALLBACKS)(GetDriverInfoData.lpvData)),((struct NT32_DD_VIDEOPORTCALLBACKS *)(lpVideoPortCallBacks)),PDD_VIDEOPORTCALLBACKS,OUT)
    } 
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_ColorControlCallbacks))
    {
        DD_COLORCONTROLCALLBACKS        ColorControlCallBacks;
        LPDDHAL_DDCOLORCONTROLCALLBACKS lpColorControlCallBacks;

        // Translate ColorControl call-backs to user-mode:

        lpColorControlCallBacks          = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &ColorControlCallBacks;
        GetDriverInfoData.dwExpectedSize = sizeof(ColorControlCallBacks);    
        
        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
                
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        ((struct NT32_DD_COLORCONTROLCALLBACKS *)(lpColorControlCallBacks))->dwSize = ColorControlCallBacks.dwSize;
        ((struct NT32_DD_COLORCONTROLCALLBACKS *)(lpColorControlCallBacks))->dwFlags = ColorControlCallBacks.dwFlags;
        ((struct NT32_DD_COLORCONTROLCALLBACKS *)(lpColorControlCallBacks))->ColorControl = (_int32)ColorControlCallBacks.ColorControl;
        
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_MiscellaneousCallbacks))
    {
        DD_MISCELLANEOUSCALLBACKS           MiscellaneousCallBacks;
        LPDDHAL_DDMISCELLANEOUSCALLBACKS    lpMiscellaneousCallBacks;

        // Translate miscellaneous call-backs to user-mode:

        lpMiscellaneousCallBacks         = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &MiscellaneousCallBacks;
        GetDriverInfoData.dwExpectedSize = sizeof(MiscellaneousCallBacks);
        lpMiscellaneousCallBacks->dwFlags = 0;

        // Don't return what the driver returns because we always want this
        // to suceed

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
               
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        ((struct NT32_DD_MISCELLANEOUSCALLBACKS *)(lpMiscellaneousCallBacks))->dwSize = MiscellaneousCallBacks.dwSize;
        ((struct NT32_DD_MISCELLANEOUSCALLBACKS *)(lpMiscellaneousCallBacks))->dwFlags = MiscellaneousCallBacks.dwFlags;
        ((struct NT32_DD_MISCELLANEOUSCALLBACKS *)(lpMiscellaneousCallBacks))->GetAvailDriverMemory = (_int32)MiscellaneousCallBacks.GetAvailDriverMemory;
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_Miscellaneous2Callbacks))
    {
        DD_MISCELLANEOUS2CALLBACKS          Miscellaneous2CallBacks;
        LPDDHAL_DDMISCELLANEOUS2CALLBACKS   lpMiscellaneous2CallBacks;

        // Translate miscellaneous call-backs to user-mode:

        lpMiscellaneous2CallBacks        = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &Miscellaneous2CallBacks;
        GetDriverInfoData.dwExpectedSize = sizeof(Miscellaneous2CallBacks);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;
        
        ((struct NT32_DD_MISCELLANEOUS2CALLBACKS *)(lpMiscellaneous2CallBacks))->dwSize = Miscellaneous2CallBacks.dwSize;
        ((struct NT32_DD_MISCELLANEOUS2CALLBACKS *)(lpMiscellaneous2CallBacks))->dwFlags = Miscellaneous2CallBacks.dwFlags;
        ((struct NT32_DD_MISCELLANEOUS2CALLBACKS *)(lpMiscellaneous2CallBacks))->AlphaBlt = (__int32)Miscellaneous2CallBacks.AlphaBlt;
        ((struct NT32_DD_MISCELLANEOUS2CALLBACKS *)(lpMiscellaneous2CallBacks))->CreateSurfaceEx = (__int32)Miscellaneous2CallBacks.CreateSurfaceEx;
        ((struct NT32_DD_MISCELLANEOUS2CALLBACKS *)(lpMiscellaneous2CallBacks))->GetDriverState = (__int32)Miscellaneous2CallBacks.GetDriverState;
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_NTCallbacks))
    {
        DD_NTCALLBACKS          NTCallBacks;
        LPDDHAL_DDNTCALLBACKS   lpNTCallBacks;

        // Translate NT call-backs to user-mode:

        lpNTCallBacks                    = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &NTCallBacks;
        GetDriverInfoData.dwExpectedSize = sizeof(NTCallBacks);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        ((struct NT32_DD_NTCALLBACKS *)(lpNTCallBacks))->dwSize = NTCallBacks.dwSize;
        ((struct NT32_DD_NTCALLBACKS *)(lpNTCallBacks))->dwFlags = NTCallBacks.dwFlags;
        ((struct NT32_DD_NTCALLBACKS *)(lpNTCallBacks))->FreeDriverMemory = (__int32)NTCallBacks.FreeDriverMemory;
        ((struct NT32_DD_NTCALLBACKS *)(lpNTCallBacks))->SetExclusiveMode = (__int32)NTCallBacks.SetExclusiveMode;
        ((struct NT32_DD_NTCALLBACKS *)(lpNTCallBacks))->FlipToGDISurface = (__int32)NTCallBacks.FlipToGDISurface;
        
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_D3DCallbacks))
    {
        D3DNTHAL_CALLBACKS D3dCallbacks;
        LPD3DHAL_CALLBACKS lpD3dCallbacks;

        // Translate D3DNTHAL_CALLBACKS to user-mode.

        lpD3dCallbacks = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData = &D3dCallbacks;
        GetDriverInfoData.dwExpectedSize = sizeof(D3dCallbacks);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);        
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        @ForceType(PostCall,((LPD3DNTHAL_CALLBACKS)(GetDriverInfoData.lpvData)),((struct NT32_D3DNTHAL_CALLBACKS *)(lpD3dCallbacks)),LPD3DNTHAL_CALLBACKS,OUT)
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_D3DCallbacks3))
    {
        D3DNTHAL_CALLBACKS3 D3dCallbacks3;
        LPD3DHAL_CALLBACKS3 lpD3dCallbacks3;

        // Translate D3DNTHAL_CALLBACKS3 to user-mode.

        lpD3dCallbacks3 = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData = &D3dCallbacks3;
        GetDriverInfoData.dwExpectedSize = sizeof(D3dCallbacks3);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);        
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        @ForceType(PostCall,((LPD3DNTHAL_CALLBACKS3)(GetDriverInfoData.lpvData)),((struct NT32_D3DNTHAL_CALLBACKS3 *)(lpD3dCallbacks3)),LPD3DNTHAL_CALLBACKS3,OUT)
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_KernelCallbacks))
    {
        DD_KERNELCALLBACKS DdKernelCallbacks;
        LPDDHAL_DDKERNELCALLBACKS lpDdKernelCallbacks;

        // Translate KernelCallbacks to user-mode.

        lpDdKernelCallbacks = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData = &DdKernelCallbacks;
        GetDriverInfoData.dwExpectedSize = sizeof(DdKernelCallbacks);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);        
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        ((struct NT32DD_KERNELCALLBACKS *)(lpDdKernelCallbacks))->dwSize = DdKernelCallbacks.dwSize;
        ((struct NT32DD_KERNELCALLBACKS *)(lpDdKernelCallbacks))->dwFlags = DdKernelCallbacks.dwFlags;
        ((struct NT32DD_KERNELCALLBACKS *)(lpDdKernelCallbacks))->SyncSurfaceData = (__int32)DdKernelCallbacks.SyncSurfaceData;
        ((struct NT32DD_KERNELCALLBACKS *)(lpDdKernelCallbacks))->SyncVideoPortData = (__int32)DdKernelCallbacks.SyncVideoPortData;
    }
    else if (IsEqualIID(&pGetDriverInfoData->guidInfo, &GUID_MotionCompCallbacks))
    {
        DD_MOTIONCOMPCALLBACKS         MotionCompCallbacks;
        LPDDHAL_DDMOTIONCOMPCALLBACKS  lpMotionCompCallbacks;

        // Translate Video call-backs to user-mode:

        lpMotionCompCallbacks            = pGetDriverInfoData->lpvData;
        GetDriverInfoData.lpvData        = &MotionCompCallbacks;
        GetDriverInfoData.dwExpectedSize = sizeof(MotionCompCallbacks);

        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, &GetDriverInfoData);
        
        pGetDriverInfoData->dwActualSize = GetDriverInfoData.dwActualSize;
        pGetDriverInfoData->ddRVal = GetDriverInfoData.ddRVal;        
        
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->dwSize = MotionCompCallbacks.dwSize;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->dwFlags = MotionCompCallbacks.dwFlags;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->GetMoCompGuids = (__int32)MotionCompCallbacks.GetMoCompGuids;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->GetMoCompFormats = (__int32)MotionCompCallbacks.GetMoCompFormats;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->GetMoCompBuffInfo = (__int32)MotionCompCallbacks.GetMoCompBuffInfo;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->GetInternalMoCompInfo = (__int32)MotionCompCallbacks.GetInternalMoCompInfo;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->BeginMoCompFrame = (__int32)MotionCompCallbacks.BeginMoCompFrame;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->EndMoCompFrame = (__int32)MotionCompCallbacks.EndMoCompFrame;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->RenderMoComp = (__int32)MotionCompCallbacks.RenderMoComp;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->QueryMoCompStatus = (__int32)MotionCompCallbacks.QueryMoCompStatus;
        ((struct NT32DD_MOTIONCOMPCALLBACKS *)(lpMotionCompCallbacks))->DestroyMoComp = (__int32)MotionCompCallbacks.DestroyMoComp;
        
    }
    else
    {
        dwRet = NtGdiDdGetDriverInfo(hDirectDraw, pGetDriverInfoData);
    }
    
    return dwRet;
}
)
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
End=
Begin=
@GenApiThunk(whNtGdiDdGetDriverInfoInternal)
End=

TemplateName=NtGdiDdGetDxHandle
NoType=hDirectDraw
NoType=hSurface
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
hDirectDrawHost=(unsigned)hDirectDraw; @NL
hSurfaceHost=(unsigned)hSurface; @NL
End=

TemplateName=NtGdiDdGetFlipStatus
NoType=hSurface
NoType=puGetFlipStatusData
Locals=
BYTE puGetFlipStatusDataCopy[sizeof(DD_GETFLIPSTATUSDATA)]; @NL
struct NT32_DD_GETFLIPSTATUSDATA *puGetFlipStatusDataHostCopy; @NL
puGetFlipStatusData=(PDD_GETFLIPSTATUSDATA)puGetFlipStatusDataCopy; @NL
puGetFlipStatusDataHostCopy=(struct NT32_DD_GETFLIPSTATUSDATA *)puGetFlipStatusDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puGetFlipStatusDataHost)) { @Indent( @NL
RtlZeroMemory(puGetFlipStatusDataCopy,sizeof(DD_GETFLIPSTATUSDATA)); @NL
@ForceType(PreCall,puGetFlipStatusData->dwFlags,puGetFlipStatusDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puGetFlipStatusData->ddRVal,puGetFlipStatusDataHostCopy->ddRVal,DWORD,IN)
@ForceType(PreCall,puGetFlipStatusData->GetFlipStatus,puGetFlipStatusDataHostCopy->GetFlipStatus,PVOID,IN)
)} else { @Indent( @NL
puGetFlipStatusData=NULL;
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puGetFlipStatusData->ddRVal,puGetFlipStatusDataHostCopy->ddRVal,DWORD,OUT)
@ForceType(PostCall,puGetFlipStatusData->GetFlipStatus,puGetFlipStatusDataHostCopy->GetFlipStatus,PVOID,OUT)
End=

TemplateName=NtGdiDdGetInternalMoCompInfo
NoType=hDirectDraw
NoType=puGetInternalData
Locals=
BYTE puGetInternalDataCopy[sizeof(DD_GETINTERNALMOCOMPDATA)]; @NL
struct NT32_DD_GETINTERNALMOCOMPDATA *puGetInternalDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetInternalDataHost)) { @Indent( @NL
puGetInternalData=(PDD_GETINTERNALMOCOMPDATA)puGetInternalDataCopy; @NL
puGetInternalDataHostCopy=(struct NT32_DD_GETINTERNALMOCOMPDATA *)puGetInternalDataHost; @NL
@ForceType(PreCall,puGetInternalData->lpDD,puGetInternalDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetInternalData->lpGuid,puGetInternalDataHostCopy->lpGuid,LPGUID,IN)
@ForceType(PreCall,puGetInternalData->dwWidth,puGetInternalDataHostCopy->dwWidth,DWORD,IN)
@ForceType(PreCall,puGetInternalData->dwHeight,puGetInternalDataHostCopy->dwHeight,DWORD,IN)
@ForceType(PreCall,puGetInternalData->ddPixelFormat,puGetInternalDataHostCopy->ddPixelFormat,DDPIXELFORMAT,IN)
@ForceType(PreCall,puGetInternalData->dwScratchMemAlloc,puGetInternalDataHostCopy->dwScratchMemAlloc,DWORD,IN)
@ForceType(PreCall,puGetInternalData->ddRVal,puGetInternalDataHostCopy->ddRVal,HRESULT,IN)
)} else { @Indent( @NL
puGetInternalData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetInternalDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetInternalData->dwWidth,puGetInternalDataHostCopy->dwWidth,DWORD,OUT)
@ForceType(PostCall,puGetInternalData->dwHeight,puGetInternalDataHostCopy->dwHeight,DWORD,OUT)
@ForceType(PostCall,puGetInternalData->ddPixelFormat,puGetInternalDataHostCopy->ddPixelFormat,DDPIXELFORMAT,OUT)
@ForceType(PostCall,puGetInternalData->dwScratchMemAlloc,puGetInternalDataHostCopy->dwScratchMemAlloc,DWORD,OUT)
@ForceType(PostCall,puGetInternalData->ddRVal,puGetInternalDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetMoCompBuffInfo
NoType=hDirectDraw
NoType=puGetBuffData
Locals=
BYTE puGetBuffDataCopy[sizeof(DD_GETMOCOMPCOMPBUFFDATA)]; @NL
struct NT32_DD_GETMOCOMPCOMPBUFFDATA *puGetBuffDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetBuffDataHost)) { @Indent( @NL
puGetBuffData=(PDD_GETMOCOMPCOMPBUFFDATA)puGetBuffDataCopy; @NL
puGetBuffDataHostCopy=(struct NT32_DD_GETMOCOMPCOMPBUFFDATA *)puGetBuffDataHost; @NL
@ForceType(PreCall,puGetBuffData->lpDD,puGetBuffDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetBuffData->lpGuid,puGetBuffDataHostCopy->lpGuid,LPGUID,IN)
@ForceType(PreCall,puGetBuffData->dwWidth,puGetBuffDataHostCopy->dwWidth,DWORD,IN)
@ForceType(PreCall,puGetBuffData->dwHeight,puGetBuffDataHostCopy->dwHeight,DWORD,IN)
@ForceType(PreCall,puGetBuffData->ddPixelFormat,puGetBuffDataHostCopy->ddPixelFormat,DDPIXELFORMAT,IN)
@ForceType(PreCall,puGetBuffData->dwNumTypesCompBuffs,puGetBuffDataHostCopy->dwNumTypesCompBuffs,DWORD,IN)
@ForceType(PreCall,puGetBuffData->lpCompBuffInfo,puGetBuffDataHostCopy->lpCompBuffInfo,LPDDCOMPBUFFERINFO,IN)
@ForceType(PreCall,puGetBuffData->ddRVal,puGetBuffDataHostCopy->ddRVal,HRESULT,IN)
)} else { @Indent( @NL
puGetBuffData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetBuffDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetBuffData->dwWidth,puGetBuffDataHostCopy->dwWidth,DWORD,OUT)
@ForceType(PostCall,puGetBuffData->dwHeight,puGetBuffDataHostCopy->dwHeight,DWORD,OUT)
@ForceType(PostCall,puGetBuffData->ddPixelFormat,puGetBuffDataHostCopy->ddPixelFormat,DDPIXELFORMAT,OUT)
@ForceType(PostCall,puGetBuffData->dwNumTypesCompBuffs,puGetBuffDataHostCopy->dwNumTypesCompBuffs,DWORD,OUT)
@ForceType(PostCall,puGetBuffData->lpCompBuffInfo,puGetBuffDataHostCopy->lpCompBuffInfo,LPDDCOMPBUFFERINFO,OUT)
@ForceType(PostCall,puGetBuffData->ddRVal,puGetBuffDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetMoCompGuids
NoType=hDirectDraw
NoType=puGetMoCompGuidsData
Locals=
BYTE puGetMoCompGuidsDataCopy[sizeof(DD_GETMOCOMPGUIDSDATA)]; @NL
struct NT32_DD_GETMOCOMPGUIDSDATA *puGetMoCompGuidsDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetMoCompGuidsDataHost)) { @Indent( @NL
puGetMoCompGuidsData=(PDD_GETMOCOMPGUIDSDATA)puGetMoCompGuidsDataCopy; @NL
puGetMoCompGuidsDataHostCopy=(struct NT32_DD_GETMOCOMPGUIDSDATA *)puGetMoCompGuidsDataHost; @NL
@ForceType(PreCall,puGetMoCompGuidsData->lpDD,puGetMoCompGuidsDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetMoCompGuidsData->dwNumGuids,puGetMoCompGuidsDataHostCopy->dwNumGuids,DWORD,IN)
@ForceType(PreCall,puGetMoCompGuidsData->lpGuids,puGetMoCompGuidsDataHostCopy->lpGuids,LPGUID,IN)
@ForceType(PreCall,puGetMoCompGuidsData->ddRVal,puGetMoCompGuidsDataHostCopy->ddRVal,HRESULT,IN)
)} else { @Indent( @NL
puGetMoCompGuidsData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetMoCompGuidsDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetMoCompGuidsData->dwNumGuids,puGetMoCompGuidsDataHostCopy->dwNumGuids,DWORD,OUT)
@ForceType(PostCall,puGetMoCompGuidsData->lpGuids,puGetMoCompGuidsDataHostCopy->lpGuids,LPGUID,OUT)
@ForceType(PostCall,puGetMoCompGuidsData->ddRVal,puGetMoCompGuidsDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetMoCompFormats
NoType=hDirectDraw
NoType=puGetMoCompFormatsData
Locals=
BYTE puGetMoCompFormatsDataCopy[sizeof(DD_GETMOCOMPFORMATSDATA)]; @NL
struct NT32_DD_GETMOCOMPFORMATSDATA *puGetMoCompFormatsDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetMoCompFormatsDataHost)) { @Indent( @NL
puGetMoCompFormatsData=(PDD_GETMOCOMPFORMATSDATA)puGetMoCompFormatsDataCopy; @NL
puGetMoCompFormatsDataHostCopy=(struct NT32_DD_GETMOCOMPFORMATSDATA *)puGetMoCompFormatsDataHost; @NL
@ForceType(PreCall,puGetMoCompFormatsData->lpDD,puGetMoCompFormatsDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetMoCompFormatsData->lpGuid,puGetMoCompFormatsDataHostCopy->lpGuid,LPVOID,IN)
@ForceType(PreCall,puGetMoCompFormatsData->dwNumFormats,puGetMoCompFormatsDataHostCopy->dwNumFormats,DWORD,IN)
@ForceType(PreCall,puGetMoCompFormatsData->lpFormats,puGetMoCompFormatsDataHostCopy->lpFormats,LPDDPIXELFORMAT,IN)
@ForceType(PreCall,puGetMoCompFormatsData->ddRVal,puGetMoCompFormatsDataHostCopy->ddRVal,HRESULT,IN)
)} else { @Indent( @NL
puGetMoCompFormatsData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetMoCompFormatsDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetMoCompFormatsData->dwNumFormats,puGetMoCompFormatsDataHostCopy->dwNumFormats,DWORD,OUT)
@ForceType(PostCall,puGetMoCompFormatsData->lpFormats,puGetMoCompFormatsDataHostCopy->lpFormats,LPDDPIXELFORMAT,OUT)
@ForceType(PostCall,puGetMoCompFormatsData->ddRVal,puGetMoCompFormatsDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdGetScanLine
NoType=hDirectDraw
NoType=puGetScanLineData
Locals=
BYTE puGetScanLineDataCopy[sizeof(DD_GETSCANLINEDATA)]; @NL
struct NT32_DD_GETSCANLINEDATA *puGetScanLineDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puGetScanLineDataHost)) { @Indent( @NL
puGetScanLineData=(PDD_GETSCANLINEDATA)puGetScanLineDataCopy; @NL
puGetScanLineDataHostCopy=(struct NT32_DD_GETSCANLINEDATA *)puGetScanLineDataHost; @NL
@ForceType(PreCall,puGetScanLineData->lpDD,puGetScanLineDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puGetScanLineData->dwScanLine,puGetScanLineDataHostCopy->dwScanLine,DWORD,IN)
@ForceType(PreCall,puGetScanLineData->ddRVal,puGetScanLineDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puGetScanLineData->GetScanLine,puGetScanLineDataHostCopy->GetScanLine,LPVOID,IN)
)} else { @Indent( @NL
puGetScanLineData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puGetScanLineDataHost)) { @Indent( @NL
@ForceType(PostCall,puGetScanLineData->dwScanLine,puGetScanLineDataHostCopy->dwScanLine,DWORD,OUT)
@ForceType(PostCall,puGetScanLineData->ddRVal,puGetScanLineDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puGetScanLineData->GetScanLine,puGetScanLineDataHostCopy->GetScanLine,LPVOID,OUT)
)} @NL
End=

TemplateName=NtGdiDdLock
NoType=hSurface
NoType=puLockData
Locals=
BYTE puLockDataCopy[sizeof(DD_LOCKDATA)]; @NL
struct NT32_DD_LOCKDATA *puLockDataHostCopy; @NL
puLockData=(PDD_LOCKDATA)puLockDataCopy; @NL
puLockDataHostCopy=(struct NT32_DD_LOCKDATA *)puLockDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puLockDataHost)) { @Indent( @NL
RtlZeroMemory(puLockDataCopy,sizeof(DD_LOCKDATA)); @NL
@ForceType(PreCall,puLockData->bHasRect,puLockDataHostCopy->bHasRect,DWORD,IN)
@ForceType(PreCall,puLockData->rArea,puLockDataHostCopy->rArea,RECTL,IN)
@ForceType(PreCall,puLockData->ddRVal,puLockDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puLockData->dwFlags,puLockDataHostCopy->dwFlags,DWORD,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puLockDataHost)) { @Indent( @NL
@ForceType(PostCall,puLockData->lpSurfData,puLockDataHostCopy->lpSurfData,LPVOID,OUT)
@ForceType(PostCall,puLockData->ddRVal,puLockDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdLockD3D
NoType=hSurface
NoType=puLockData
Locals=
BYTE puLockDataCopy[sizeof(DD_LOCKDATA)]; @NL
struct NT32_DD_LOCKDATA *puLockDataHostCopy; @NL
puLockData=(PDD_LOCKDATA)puLockDataCopy; @NL
puLockDataHostCopy=(struct NT32_DD_LOCKDATA *)puLockDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puLockDataHost)) { @Indent( @NL
RtlZeroMemory(puLockDataCopy,sizeof(DD_LOCKDATA)); @NL
@ForceType(PreCall,puLockData->bHasRect,puLockDataHostCopy->bHasRect,DWORD,IN)
@ForceType(PreCall,puLockData->rArea,puLockDataHostCopy->rArea,RECTL,IN)
@ForceType(PreCall,puLockData->ddRVal,puLockDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puLockData->dwFlags,puLockDataHostCopy->dwFlags,DWORD,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puLockDataHost)) { @Indent( @NL
@ForceType(PostCall,puLockData->lpSurfData,puLockDataHostCopy->lpSurfData,LPVOID,OUT)
@ForceType(PostCall,puLockData->ddRVal,puLockDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdQueryDirectDrawObject
NoType=_noname0
NoType=_noname4
NoType=_noname5
NoType=_noname6
NoType=_noname8
Locals=
BYTE _noname4Copy[sizeof(D3DNTHAL_GLOBALDRIVERDATA)]; @NL
BYTE _noname8Copy[sizeof(VIDEOMEMORY)]; @NL
BYTE temp[sizeof (DD_D3DBUFCALLBACKS)];                   @NL
LPDDSURFACEDESC TextureFormats64 = NULL;                  @NL
DWORD TextureFormatsCount = 0;                            @NL
struct NT32_DDSURFACEDESC *TextureFormats32;              @NL
struct NT32_D3DNTHAL_GLOBALDRIVERDATA *_noname4HostCopy; @NL
struct NT32_VIDEOMEMORY *_noname8HostCopy; @NL
DWORD i;                                                  @NL
End=
PreCall=
_noname0=(HANDLE)((unsigned)_noname0Host); @NL
if(ARGUMENT_PRESENT(_noname4Host)) { @Indent( @NL
_noname4=(LPD3DNTHAL_GLOBALDRIVERDATA)_noname4Copy; @NL
_noname4HostCopy=(struct NT32_D3DNTHAL_GLOBALDRIVERDATA *)_noname4Host; @NL
RtlZeroMemory(_noname4,sizeof(D3DNTHAL_GLOBALDRIVERDATA)); @NL
_noname4->dwSize=sizeof(D3DNTHAL_GLOBALDRIVERDATA); @NL
_noname4->dwNumTextureFormats=_noname4HostCopy->dwNumTextureFormats; @NL
)} else { @Indent( @NL
_noname4=NULL; @NL
)} @NL
_noname5 = (PDD_D3DBUFCALLBACKS)temp;                        @NL
_noname5->dwSize = sizeof (*_noname5);                       @NL
TextureFormats32 = (struct NT32_DDSURFACEDESC *)_noname6Host;@NL
                                                             @NL
if(ARGUMENT_PRESENT(TextureFormats32)) { @Indent( @NL
if(ARGUMENT_PRESENT(_noname4Host) && (_noname4HostCopy->dwNumTextureFormats>0)) { @Indent( @NL
TextureFormatsCount=_noname4HostCopy->dwNumTextureFormats; @NL
TextureFormats64=Wow64AllocateTemp(sizeof(DDSURFACEDESC)*TextureFormatsCount); @NL
if(NULL==TextureFormats64) { @Indent( @NL
TextureFormatsCount=0; @NL
)} @NL
)} @NL
)} @NL                   
                                                             @NL
_noname6 = TextureFormats64;                                 @NL
                                                             @NL
_noname8=(VIDEOMEMORY *)_noname8Copy; @NL
_noname8HostCopy=(struct NT32_VIDEOMEMORY *)_noname8Host; @NL
End=
Begin=
#define _WIN32_API_
@GenApiThunk(@ApiName)
#undef _WIN32_API_
End=
PostCall=
if(ARGUMENT_PRESENT(_noname4Host)) { @Indent( @NL
_noname4HostCopy->dwSize=sizeof(struct NT32_D3DNTHAL_GLOBALDRIVERDATA); @NL
@ForceType(PostCall,_noname4->hwCaps,_noname4HostCopy->hwCaps,D3DNTHALDEVICEDESC_V1,OUT)
@ForceType(PostCall,_noname4->dwNumVertices,_noname4HostCopy->dwNumVertices,DWORD,OUT)
@ForceType(PostCall,_noname4->dwNumClipVertices,_noname4HostCopy->dwNumClipVertices,DWORD,OUT)
@ForceType(PostCall,_noname4->dwNumTextureFormats,_noname4HostCopy->dwNumTextureFormats,DWORD,OUT)
)} @NL
//@NL
// It would difficult to thunk where kernel returning some structure containing pointer to function.@NL
// And need to revisit this issue.@NL
//@NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->dwSize             = _noname5->dwSize; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->dwFlags            = _noname5->dwFlags; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->CanCreateD3DBuffer = (DWORD)_noname5->CanCreateD3DBuffer; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->CreateD3DBuffer    = (DWORD)_noname5->CreateD3DBuffer; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->DestroyD3DBuffer   = (DWORD)_noname5->DestroyD3DBuffer; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->LockD3DBuffer      = (DWORD)_noname5->LockD3DBuffer; @NL
((NT32DD_D3DBUFCALLBACKS *)_noname5Host)->UnlockD3DBuffer    = (DWORD)_noname5->UnlockD3DBuffer; @NL

if (ARGUMENT_PRESENT (TextureFormats32) != 0) {              @NL
                                                             @NL
    for (i = 0 ; i < TextureFormatsCount ; i++) {            @NL
                                                             @NL
        @ForceType(PostCall,TextureFormats64,TextureFormats32,LPDDSURFACEDESC,OUT)
        TextureFormats64++;                                  @NL
        TextureFormats32++;                                  @NL
    }                                                        @NL
}                                                            @NL

if(ARGUMENT_PRESENT(_noname8Host)) { @Indent( @NL
@ForceType(PostCall,_noname8->dwFlags,_noname8HostCopy->dwFlags,DWORD,OUT)
@ForceType(PostCall,_noname8->fpStart,_noname8HostCopy->fpStart,FLATPTR,OUT)
@ForceType(PostCall,_noname8->ddsCaps,_noname8HostCopy->ddsCaps,DDSCAPS,OUT)
@ForceType(PostCall,_noname8->ddsCapsAlt,_noname8HostCopy->ddsCapsAlt,DDSCAPS,OUT)
if( (_noname8->dwFlags & VIDMEM_ISRECTANGULAR) == VIDMEM_ISRECTANGULAR ) { @Indent( @NL
@ForceType(PostCall,_noname8->dwWidth,_noname8HostCopy->dwWidth,DWORD,OUT)
@ForceType(PostCall,_noname8->dwHeight,_noname8HostCopy->dwHeight,DWORD,OUT)
)} else { @Indent( @NL
@ForceType(PostCall,_noname8->fpEnd,_noname8HostCopy->fpEnd,FLATPTR,OUT)
@ForceType(PostCall,_noname8->lpHeap,_noname8HostCopy->lpHeap,LPVOID,OUT)
)} @NL
)} @NL
End=


TemplateName=NtGdiDdQueryMoCompStatus
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdReenableDirectDrawObject
NoType=hDirectDrawLocal
PreCall=
hDirectDrawLocal=(HANDLE)((unsigned)hDirectDrawLocalHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdReleaseDC
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdRenderMoComp
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdResetVisrgn
NoType=hSurface
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdResize
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdSetColorKey
NoType=hSurface
NoType=puSetColorKeyData
Locals=
BYTE puSetColorKeyDataCopy[sizeof(DD_SETCOLORKEYDATA)]; @NL
struct NT32_DD_SETCOLORKEYDATA *puSetColorKeyDataHostCopy; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puSetColorKeyDataHost)) { @Indent( @NL
puSetColorKeyData=(PDD_SETCOLORKEYDATA)puSetColorKeyDataCopy; @NL
puSetColorKeyDataHostCopy=(struct NT32_DD_SETCOLORKEYDATA *)puSetColorKeyDataHost; @NL
@ForceType(PreCall,puSetColorKeyData->lpDD,puSetColorKeyDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puSetColorKeyData->lpDDSurface,puSetColorKeyDataHostCopy->lpDDSurface,LPVOID,IN)
@ForceType(PreCall,puSetColorKeyData->dwFlags,puSetColorKeyDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puSetColorKeyData->ckNew,puSetColorKeyDataHostCopy->ckNew,DDCOLORKEY,IN)
@ForceType(PreCall,puSetColorKeyData->ddRVal,puSetColorKeyDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puSetColorKeyData->SetColorKey,puSetColorKeyDataHostCopy->SetColorKey,LPVOID,IN)
)} else { @Indent( @NL
puSetColorKeyData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puSetColorKeyDataHost)) { @Indent( @NL
@ForceType(PostCall,puSetColorKeyData->ddRVal,puSetColorKeyDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdSetExclusiveMode
NoType=hDirectDraw
NoType=puSetExclusiveModeData
Locals=
BYTE puSetExclusiveModeDataCopy[sizeof(DD_SETEXCLUSIVEMODEDATA)]; @NL
struct NT32_DD_SETEXCLUSIVEMODEDATA *puSetExclusiveModeDataHostCopy; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puSetExclusiveModeDataHost)) { @Indent( @NL
puSetExclusiveModeData=(PDD_SETEXCLUSIVEMODEDATA)puSetExclusiveModeDataCopy; @NL
puSetExclusiveModeDataHostCopy=(struct NT32_DD_SETEXCLUSIVEMODEDATA *)puSetExclusiveModeDataHost; @NL
@ForceType(PreCall,puSetExclusiveModeData->lpDD,puSetExclusiveModeDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puSetExclusiveModeData->dwEnterExcl,puSetExclusiveModeDataHostCopy->dwEnterExcl,DWORD,IN)
@ForceType(PreCall,puSetExclusiveModeData->dwReserved,puSetExclusiveModeDataHostCopy->dwReserved,DWORD,IN)
@ForceType(PreCall,puSetExclusiveModeData->ddRVal,puSetExclusiveModeDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puSetExclusiveModeData->SetExclusiveMode,puSetExclusiveModeDataHostCopy->SetExclusiveMode,LPVOID,IN)
)} else { @Indent( @NL
puSetExclusiveModeData=NULL;
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puSetExclusiveModeData->ddRVal,puSetExclusiveModeDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puSetExclusiveModeData->SetExclusiveMode,puSetExclusiveModeDataHostCopy->SetExclusiveMode,LPVOID,OUT)
End=

TemplateName=NtGdiDdSetGammaRamp
NoType=hDirectDraw
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdSetOverlayPosition
NoType=hSurfaceSource
NoType=hSurfaceDestination
NoType=puSetOverlayPositionData
Locals=
BYTE puSetOverlayPositionDataCopy[sizeof(DD_SETOVERLAYPOSITIONDATA)]; @NL
struct NT32_DD_SETOVERLAYPOSITIONDATA *puSetOverlayPositionDataHostCopy; @NL
End=
PreCall=
hSurfaceSource=(HANDLE)((unsigned)hSurfaceSourceHost); @NL
hSurfaceDestination=(HANDLE)((unsigned)hSurfaceDestinationHost); @NL
if(ARGUMENT_PRESENT(puSetOverlayPositionDataHost)) { @Indent( @NL
puSetOverlayPositionData=(PDD_SETOVERLAYPOSITIONDATA)puSetOverlayPositionDataCopy; @NL
puSetOverlayPositionDataHostCopy=(struct NT32_DD_SETOVERLAYPOSITIONDATA *)puSetOverlayPositionDataHost; @NL
@ForceType(PreCall,puSetOverlayPositionData->lpDD,puSetOverlayPositionDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puSetOverlayPositionData->lpDDSrcSurface,puSetOverlayPositionDataHostCopy->lpDDSrcSurface,LPVOID,IN)
@ForceType(PreCall,puSetOverlayPositionData->lpDDDestSurface,puSetOverlayPositionDataHostCopy->lpDDDestSurface,LPVOID,IN)
@ForceType(PreCall,puSetOverlayPositionData->lXPos,puSetOverlayPositionDataHostCopy->lXPos,LONG,IN)
@ForceType(PreCall,puSetOverlayPositionData->lYPos,puSetOverlayPositionDataHostCopy->lYPos,LONG,IN)
@ForceType(PreCall,puSetOverlayPositionData->ddRVal,puSetOverlayPositionDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puSetOverlayPositionData->SetOverlayPosition,puSetOverlayPositionDataHostCopy->SetOverlayPosition,LPVOID,IN)
)} else { @Indent( @NL
puSetOverlayPositionData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puSetOverlayPositionDataHost)) { @Indent( @NL
@ForceType(PostCall,puSetOverlayPositionData->ddRVal,puSetOverlayPositionDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdSetSpriteDisplayList
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDdUnattachSurface
NoType=hSurface
NoType=hSurfaceAttached
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
hSurfaceAttached=(HANDLE)((unsigned)hSurfaceAttachedHost); @NL
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiDdUnlock
NoType=hSurface
NoType=puUnlockData
Locals=
BYTE puUnlockDataCopy[sizeof(DD_UNLOCKDATA)]; @NL
struct NT32_DD_UNLOCKDATA *puUnlockDataHostCopy; @NL
puUnlockData=(PDD_UNLOCKDATA)puUnlockDataCopy; @NL
puUnlockDataHostCopy=(struct NT32_DD_UNLOCKDATA *)puUnlockDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puUnlockDataHost)) { @Indent( @NL
RtlZeroMemory(puUnlockDataCopy,sizeof(DD_UNLOCKDATA)); @NL
@ForceType(PreCall,puUnlockData->ddRVal,puUnlockDataHostCopy->ddRVal,HRESULT,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puUnlockData->ddRVal,puUnlockDataHostCopy->ddRVal,HRESULT,OUT)
End=

TemplateName=NtGdiDdUnlockD3D
NoType=hSurface
NoType=puUnlockData
Locals=
BYTE puUnlockDataCopy[sizeof(DD_UNLOCKDATA)]; @NL
struct NT32_DD_UNLOCKDATA *puUnlockDataHostCopy; @NL
puUnlockData=(PDD_UNLOCKDATA)puUnlockDataCopy; @NL
puUnlockDataHostCopy=(struct NT32_DD_UNLOCKDATA *)puUnlockDataHost; @NL
End=
PreCall=
hSurface=(HANDLE)((unsigned)hSurfaceHost); @NL
if(ARGUMENT_PRESENT(puUnlockDataHost)) { @Indent( @NL
RtlZeroMemory(puUnlockDataCopy,sizeof(DD_UNLOCKDATA)); @NL
@ForceType(PreCall,puUnlockData->ddRVal,puUnlockDataHostCopy->ddRVal,HRESULT,IN)
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puUnlockData->ddRVal,puUnlockDataHostCopy->ddRVal,HRESULT,OUT)
End=

TemplateName=NtGdiDdUpdateOverlay
NoType=hSurfaceDestination
NoType=hSurfaceSource
NoType=puUpdateOverlayData
Locals=
BYTE puUpdateOverlayDataCopy[sizeof(DD_UPDATEOVERLAYDATA)]; @NL
struct NT32_DD_UPDATEOVERLAYDATA *puUpdateOverlayDataHostCopy; @NL
End=
PreCall=
hSurfaceDestination=(HANDLE)((unsigned)hSurfaceDestinationHost); @NL
hSurfaceSource=(HANDLE)((unsigned)hSurfaceSourceHost); @NL
if(ARGUMENT_PRESENT(puUpdateOverlayDataHost)) { @Indent( @NL
puUpdateOverlayData=(PDD_UPDATEOVERLAYDATA)puUpdateOverlayDataCopy; @NL
puUpdateOverlayDataHostCopy=(struct NT32_DD_UPDATEOVERLAYDATA *)puUpdateOverlayDataHost; @NL
@ForceType(PreCall,puUpdateOverlayData->lpDD,puUpdateOverlayDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puUpdateOverlayData->rDest,puUpdateOverlayDataHostCopy->rDest,RECTL,IN)
@ForceType(PreCall,puUpdateOverlayData->rSrc,puUpdateOverlayDataHostCopy->rSrc,RECTL,IN)
@ForceType(PreCall,puUpdateOverlayData->dwFlags,puUpdateOverlayDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puUpdateOverlayData->overlayFX,puUpdateOverlayDataHostCopy->overlayFX,DDOVERLAYFX,IN)
@ForceType(PreCall,puUpdateOverlayData->ddRVal,puUpdateOverlayDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puUpdateOverlayData->UpdateOverlay,puUpdateOverlayDataHostCopy->UpdateOverlay,LPVOID,IN)
if(WOW64_ISPTR(puUpdateOverlayDataHostCopy->lpDDDestSurface)) { @Indent( @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puUpdateOverlayData->lpDDDestSurface),(struct NT32_DD_SURFACE_LOCAL *)(puUpdateOverlayDataHostCopy->lpDDDestSurface),1); @NL
)} else { @Indent( @NL
puUpdateOverlayData->lpDDDestSurface=NULL; @NL
)} @NL
if(WOW64_ISPTR(puUpdateOverlayDataHostCopy->lpDDSrcSurface)) { @Indent( @NL
Wow64GdiDdThunkSurfaceLocalPreCall(&(puUpdateOverlayData->lpDDSrcSurface),(struct NT32_DD_SURFACE_LOCAL *)(puUpdateOverlayDataHostCopy->lpDDSrcSurface),1); @NL
)} else { @Indent( @NL
puUpdateOverlayData->lpDDDestSurface=NULL; @NL
)} @NL
)} else { @Indent( @NL
puUpdateOverlayData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
if(ARGUMENT_PRESENT(puUpdateOverlayDataHost)) { @Indent( @NL
@ForceType(PostCall,puUpdateOverlayData->ddRVal,puUpdateOverlayDataHostCopy->ddRVal,HRESULT,OUT)
)} @NL
End=

TemplateName=NtGdiDdWaitForVerticalBlank
NoType=hDirectDraw
NoType=puWaitForVerticalBlankData
Locals=
BYTE puWaitForVerticalBlankDataCopy[sizeof(DD_WAITFORVERTICALBLANKDATA)]; @NL
struct NT32_DD_WAITFORVERTICALBLANKDATA *puWaitForVerticalBlankDataHostCopy; @NL
puWaitForVerticalBlankData=(PDD_WAITFORVERTICALBLANKDATA)puWaitForVerticalBlankDataCopy; @NL
puWaitForVerticalBlankDataHostCopy=(struct NT32_DD_WAITFORVERTICALBLANKDATA *)puWaitForVerticalBlankDataHost; @NL
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puWaitForVerticalBlankDataHost)) { @Indent( @NL
puWaitForVerticalBlankData->lpDD=NULL; @NL
@ForceType(PreCall,puWaitForVerticalBlankData->dwFlags,puWaitForVerticalBlankDataHostCopy->dwFlags,DWORD,IN)
@ForceType(PreCall,puWaitForVerticalBlankData->bIsInVB,puWaitForVerticalBlankDataHostCopy->bIsInVB,DWORD,IN)
@ForceType(PreCall,puWaitForVerticalBlankData->hEvent,puWaitForVerticalBlankDataHostCopy->hEvent,DWORD,IN)
@ForceType(PreCall,puWaitForVerticalBlankData->ddRVal,puWaitForVerticalBlankDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puWaitForVerticalBlankData->WaitForVerticalBlank,puWaitForVerticalBlankDataHostCopy->WaitForVerticalBlank,LPVOID,IN)
)} else { @Indent( @NL
puWaitForVerticalBlankData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puWaitForVerticalBlankData->dwFlags,puWaitForVerticalBlankDataHostCopy->dwFlags,DWORD,OUT)
@ForceType(PostCall,puWaitForVerticalBlankData->bIsInVB,puWaitForVerticalBlankDataHostCopy->bIsInVB,DWORD,OUT)
@ForceType(PostCall,puWaitForVerticalBlankData->hEvent,puWaitForVerticalBlankDataHostCopy->hEvent,DWORD,OUT)
@ForceType(PostCall,puWaitForVerticalBlankData->ddRVal,puWaitForVerticalBlankDataHostCopy->ddRVal,HRESULT,OUT)
@ForceType(PostCall,puWaitForVerticalBlankData->WaitForVerticalBlank,puWaitForVerticalBlankDataHostCopy->WaitForVerticalBlank,LPVOID,OUT)
End=

TemplateName=NtGdiDvpCanCreateVideoPort
NoType=hDirectDraw
NoType=puCanCreateVPortData
Locals=
BYTE puCanCreateVPortDataCopy[sizeof(DD_CANCREATEVPORTDATA)]; @NL
struct NT32_DD_CANCREATEVPORTDATA *puCanCreateVPortDataHostCopy; @NL
@ForceType(Locals,puCanCreateVPortData->lpDDVideoPortDesc,puCanCreateVPortDataHostCopy->lpDDVideoPortDesc,LPDDVIDEOPORTDESC,IN)
End=
PreCall=
hDirectDraw=(HANDLE)((unsigned)hDirectDrawHost); @NL
if(ARGUMENT_PRESENT(puCanCreateVPortDataHost)) { @Indent( @NL
puCanCreateVPortData=(PDD_CANCREATEVPORTDATA)puCanCreateVPortDataCopy; @NL
puCanCreateVPortDataHostCopy=(struct NT32_DD_CANCREATEVPORTDATA *)puCanCreateVPortDataHost; @NL
@ForceType(PreCall,puCanCreateVPortData->lpDD,puCanCreateVPortDataHostCopy->lpDD,LPVOID,IN)
@ForceType(PreCall,puCanCreateVPortData->lpDDVideoPortDesc,puCanCreateVPortDataHostCopy->lpDDVideoPortDesc,LPDDVIDEOPORTDESC,IN)
@ForceType(PreCall,puCanCreateVPortData->ddRVal,puCanCreateVPortDataHostCopy->ddRVal,HRESULT,IN)
@ForceType(PreCall,puCanCreateVPortData->CanCreateVideoPort,puCanCreateVPortDataHostCopy->CanCreateVideoPort,LPVOID,IN)
)} else { @Indent( @NL
puCanCreateVPortData=NULL; @NL
)} @NL
End=
Begin=
@GenApiThunk(@ApiName)
End=
PostCall=
@ForceType(PostCall,puCanCreateVPortData->lpDDVideoPortDesc,puCanCreateVPortDataHostCopy->lpDDVideoPortDesc,LPDDVIDEOPORTDESC,OUT)
@ForceType(PostCall,puCanCreateVPortData->ddRVal,puCanCreateVPortDataHostCopy->ddRVal,HRESULT,OUT)
End=

TemplateName=NtGdiDvpColorControl
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpCreateVideoPort
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpDestroyVideoPort
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpFlipVideoPort
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortBandwidth
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortField
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortFlipStatus
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortInputFormats
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortLine
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortOutputFormats
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoPortConnectInfo
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpGetVideoSignalStatus
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpUpdateVideoPort
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpWaitForVideoPortSync
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpAcquireNotification
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiDvpReleaseNotification
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiAlphaBlend
Begin=
@GenApiThunk(@ApiName)
End=

TemplateName=NtGdiGradientFill
Begin=
@GenApiThunk(@ApiName)
End=

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  These functions are only called from device drivers
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TemplateName=NtGdiEngCreateBitmap
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCreateDeviceSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCreateDeviceBitmap
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCreatePalette
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngComputeGlyphSet
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCopyBits
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngDeletePalette
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngDeleteSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngEraseSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngUnlockSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngLockSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngBitBlt
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngStretchBlt
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngPlgBlt
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngMarkBandingSurface
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngStrokePath
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngFillPath
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngStrokeAndFillPath
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngPaint
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngLineTo
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngAlphaBlend
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngGradientFill
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngTransparentBlt
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngTextOut
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngStretchBltROP
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngDeletePath
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCreateClip
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngDeleteClip
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiEngCheckAbort
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiXLATEOBJ_cGetPalette
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiXLATEOBJ_iXlate
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiXLATEOBJ_hGetColorTransform
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiCLIPOBJ_bEnum
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiCLIPOBJ_cEnumStart
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiCLIPOBJ_ppoGetPath
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiBRUSHOBJ_ulGetBrushColor
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiBRUSHOBJ_pvAllocRbrush
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiBRUSHOBJ_pvGetRbrush
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiBRUSHOBJ_hGetColorTransform
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiXFORMOBJ_bApplyXform
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiXFORMOBJ_iGetXform
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_vGetInfo
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_pxoGetXform
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_cGetGlyphs
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_pifi
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_pfdg
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_pQueryGlyphAttrs
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_pvTrueTypeFontFile
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiFONTOBJ_cGetAllGlyphHandles
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiSTROBJ_bEnum
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiSTROBJ_bEnumPositionsOnly
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiSTROBJ_bGetAdvanceWidths
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiSTROBJ_vEnumStart
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiSTROBJ_dwGetCodePage
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiPATHOBJ_vGetBounds
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiPATHOBJ_bEnum
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiPATHOBJ_vEnumStart
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiPATHOBJ_vEnumStartClipLines
Begin=
@GenUnsupportedNtApiThunk
End=

TemplateName=NtGdiPATHOBJ_bEnumClipLines
Begin=
@GenUnsupportedNtApiThunk
End=


[Code]
TemplateName=whwin32
CGenBegin=
@NoFormat(
/*
 *  genthunk generated code: Do Not Modify
 *  Thunks for console functions.
 *
 */
#include "whwin32p.h"
#include <wow.h>


ASSERTNAME;

#pragma warning(disable : 4311) //Disable pointer truncation warning
#pragma warning(disable : 4242) //Truncation warning
#pragma warning(disable : 4244) //Truncation warning

#if defined(WOW64DOPROFILE)
#define APIPROFILE(apinum) (ptewhwin32[(apinum)].HitCount++)
#else
#define APIPROFILE(apinum)
#endif

#if defined(WOW64DOPROFILE)
WOW64SERVICE_PROFILE_TABLE_ELEMENT ptewhwin32[];
#endif
)

#if defined(WOW64DOPROFILE) @NL
@ApiList(#define @ApiName_PROFILE_SUBLIST NULL @NL)
#endif @NL

@NoFormat(

#if DBG

// Log api calls for simple user functions.
#define USER_LOG_SIMPLE(apinum) \
   if((apinum) >= ulMaxSimpleCall) { \
       WOWASSERTMSG(FALSE, "Unknown simple api called.\n"); \
       RtlRaiseStatus(STATUS_INVALID_PARAMETER); \
   } \
   LOGPRINT((TRACELOG, "Calling simple user function %s\n", apszSimpleCallNames[(apinum)]));

#else

// Log api calls for simple user functions.
#define USER_LOG_SIMPLE(apinum)

#endif

#if defined(WOW64DOPROFILE)

#define USER_PROFILE_SIMPLE(apinum)              \
if (apinum < ulMaxSimpleCall) {                  \
   SimpleCallProfileElements[apinum].HitCount++; \
}                                                \

#else

#define USER_PROFILE_SIMPLE(apinum)

#endif

// WM_SYSTIMER messages have a kernel mode proc address
// stuffed in the lParam. Forunately the address will
// allways be in win32k.sys so the hi bits will be the same
// for all kprocs. On the first WM_SYSTIMER message
DWORD gdwWM_SYSTIMERProcHiBits;

// These functions must be used with extreme care since the LPARAM
// and WPARAM are not fully thunked.   They are ment for cases where the
// the messsage can't have a pointer to another structure or the kernel
// does not really look at the message.

PMSG Wow64ShallowThunkMSG32TO64(PMSG pMsg64, NT32MSG *pMsg32) {
   if (ARGUMENT_PRESENT(pMsg32)) {
      pMsg64->hwnd = (HWND)pMsg32->hwnd;
      pMsg64->message = pMsg32->message;
      pMsg64->wParam = (WPARAM)pMsg32->wParam;
      pMsg64->lParam = (LPARAM)pMsg32->lParam;
      pMsg64->time = pMsg32->time;
      pMsg64->pt.x = pMsg32->pt.x;
      pMsg64->pt.y = pMsg32->pt.y;
      if (WM_SYSTIMER == pMsg32->message && pMsg32->lParam != 0) {
          WOWASSERT(gdwWM_SYSTIMERProcHiBits != 0); @NL
          pMsg64->lParam = (LPARAM)(((UINT64)gdwWM_SYSTIMERProcHiBits << 32) | (UINT64)(UINT)pMsg32->lParam);
      }
      return pMsg64;
   }
   return NULL;
}

NT32MSG *Wow64ShallowThunkMSG64TO32(NT32MSG *pMsg32, PMSG pMsg64) {
   if (ARGUMENT_PRESENT(pMsg64)) {
      pMsg32->hwnd = (NT32HWND)pMsg64->hwnd;
      pMsg32->message = pMsg64->message;
      pMsg32->wParam = (NT32WPARAM)pMsg64->wParam;
      pMsg32->lParam = (NT32LPARAM)pMsg64->lParam;
      pMsg32->time = pMsg64->time;
      pMsg32->pt.x = pMsg64->pt.x;
      pMsg32->pt.y = pMsg64->pt.y;
      if (pMsg64->message == WM_SYSTIMER && pMsg64->lParam != 0) {
         if (gdwWM_SYSTIMERProcHiBits == 0) {
            gdwWM_SYSTIMERProcHiBits = (DWORD) (pMsg64->lParam >> 32);
         }
         WOWASSERT(gdwWM_SYSTIMERProcHiBits == (DWORD) (pMsg64->lParam >> 32));
         WOWASSERT(pMsg32->lParam != 0);
      }
      return pMsg32;
   }
   return NULL;
}

PEVENTMSG Wow64ShallowThunkEVENTMSG32TO64(PEVENTMSG pMsg64, NT32EVENTMSG *pMsg32) {
   if (ARGUMENT_PRESENT(pMsg32)) {
      pMsg64->message = pMsg32->message;
      pMsg64->paramL = pMsg32->paramL;
      pMsg64->paramH = pMsg32->paramH;
      pMsg64->time = pMsg32->time;
      pMsg64->hwnd = (HWND)pMsg32->hwnd;
      return pMsg64;
   }
   return NULL;
}

NT32EVENTMSG *Wow64ShallowThunkEVENTMSG64TO32(NT32EVENTMSG *pMsg32, PEVENTMSG pMsg64) {
   if (ARGUMENT_PRESENT(pMsg64)) {
      pMsg32->message = pMsg64->message;
      pMsg32->paramL = pMsg64->paramL;
      pMsg32->paramH = pMsg64->paramH;
      pMsg32->time = pMsg64->time;
      pMsg32->hwnd = (NT32HWND)pMsg64->hwnd;
      return pMsg32;
   }
   return NULL;
}

LPHELPINFO Wow64ShallowAllocThunkHELPINFO32TO64(NT32HELPINFO *pHelp32) {

   LPHELPINFO pHelp64;

   if (!ARGUMENT_PRESENT(pHelp32)) {
       return (LPHELPINFO)pHelp32;
   }

   // Do not handle the case where the cbSize is less then the header.
   // The kernel will either throw an exception or grab bad data in this case.
   if (pHelp32->cbSize < sizeof(NT32HELPINFO)) {
       LOGPRINT((ERRORLOG, "Wow64ShallowAllocThunkHELPINFO32TO64 pHelp32->cbSize:%x < sizeof(NT32HELPINFO):%x\n",
                 pHelp32->cbSize, sizeof(NT32HELPINFO)));
       RtlRaiseStatus(STATUS_INVALID_PARAMETER);
   }

   pHelp64 = Wow64AllocateTemp(pHelp32->cbSize + sizeof(HELPINFO) - sizeof(NT32HELPINFO));

   // Thunk the header and then copy the data after the header.  We can only assume it
   // is pointer independent.
   pHelp64->cbSize = pHelp32->cbSize + sizeof(HELPINFO) - sizeof(NT32HELPINFO);
   pHelp64->iContextType = pHelp32->iContextType;
   pHelp64->iCtrlId = pHelp32->iCtrlId;
   pHelp64->hItemHandle = (HANDLE)pHelp32->hItemHandle;
   pHelp64->dwContextId = (DWORD_PTR)pHelp32->dwContextId;
   RtlCopyMemory(&pHelp64->MousePos, &pHelp32->MousePos, sizeof(POINT));

   //Copy the remainder of the structure.
   RtlCopyMemory(((PBYTE)pHelp64) + sizeof(HELPINFO),
                 ((PBYTE)pHelp32) + sizeof(NT32HELPINFO),
                 pHelp32->cbSize - sizeof(NT32HELPINFO));


   return pHelp64;
}

NT32HELPINFO *Wow64ShallowAllocThunkHELPINFO64TO32(LPHELPINFO pHelp64) {

   NT32HELPINFO *pHelp32;

   if (!ARGUMENT_PRESENT(pHelp64)) {
       return (NT32HELPINFO *)pHelp64;
   }

   // Do not handle the case where the cbSize is less then the header.
   if (pHelp64->cbSize < sizeof(HELPINFO)) {
       LOGPRINT((ERRORLOG, "Wow64ShallowAllocThunkHELPINFO64TO32 pHelp64->cbSize:%x < sizeof(HELPINFO):%x\n",
                 pHelp64->cbSize, sizeof(HELPINFO)));
       RtlRaiseStatus(STATUS_INVALID_PARAMETER);
   }

   pHelp32 = Wow64AllocateTemp(pHelp64->cbSize - sizeof(HELPINFO) + sizeof(NT32HELPINFO));

   // Thunk the header and then copy the data after the header.  We can only assume it
   // is pointer independent.
   pHelp32->cbSize = pHelp64->cbSize - sizeof(HELPINFO) + sizeof(NT32HELPINFO);
   pHelp32->iContextType = pHelp64->iContextType;
   pHelp32->iCtrlId = pHelp64->iCtrlId;
   pHelp32->hItemHandle = (NT32HANDLE)pHelp64->hItemHandle;
   pHelp32->dwContextId = (DWORD_PTR)pHelp64->dwContextId;
   RtlCopyMemory(&pHelp32->MousePos, &pHelp64->MousePos, sizeof(POINT));

   //Copy the remainder of the structure.
   RtlCopyMemory(((PBYTE)pHelp32) + sizeof(NT32HELPINFO),
                 ((PBYTE)pHelp64) + sizeof(HELPINFO),
                 pHelp64->cbSize - sizeof(HELPINFO));


   return pHelp32;
}


/* The HLP struct is defined as follows:
    typedef struct {
        WORD cbData;               Size of data
        WORD usCommand;            Command to execute
        ULONG_PTR ulTopic;         Topic/context number (if needed)
        DWORD ulReserved;          Reserved (internal use)
        WORD offszHelpFile;        Offset to help file in block
        WORD offabData;            Offset to other data in block
    } HLP, *LPHLP;

    This structure is followed but a HelpFile string at an offset of offszHelpFile
    and either a second string or a structure at offabData.   The two structure that
    can follow are either a MULTIKEYHELP or a HELPWININFO.  Neither one is pointer dependent.
*/

LPHLP Wow64ShallowAllocThunkHLP32TO64(NT32HLP *pHlp32) {

   LPHLP pHlp64;
   CONST WORD SizeDelta = sizeof(HLP) - sizeof(NT32HLP); // Diff 64 - 32.

   if (!ARGUMENT_PRESENT(pHlp32)) {
       return (LPHLP)pHlp32;
   }

   if (pHlp32->cbData < sizeof(NT32HLP)) {
       LOGPRINT((ERRORLOG, "Wow64ShallowAllocThunkHLP32TO64 pHlp32->cbData:%x < sizeof(NT32HLP):%x\n",
                pHlp32->cbData, sizeof(NT32HLP)));
       RtlRaiseStatus(STATUS_INVALID_PARAMETER);
   }

   pHlp64 = Wow64AllocateTemp(pHlp32->cbData + SizeDelta);


   // Copy the header then adjust the offsets.
   pHlp64->cbData = pHlp32->cbData + SizeDelta;
   pHlp64->usCommand = pHlp32->usCommand;
   pHlp64->ulTopic = (ULONG_PTR)pHlp32->ulTopic;
   pHlp64->ulReserved = pHlp32->ulReserved;
   pHlp64->offszHelpFile = pHlp32->offszHelpFile ? pHlp32->offszHelpFile + SizeDelta : 0;
   pHlp64->offabData = pHlp32->offabData ? pHlp32->offabData + SizeDelta : 0;

   // Copy the remaining structures.
   RtlCopyMemory(((PBYTE)pHlp64) + sizeof(HLP),
                 ((PBYTE)pHlp32) + sizeof(NT32HLP),
                 pHlp32->cbData - sizeof(NT32HLP));

   return pHlp64;
}

NT32HLP *Wow64ShallowAllocThunkHLP64TO32(LPHLP pHlp64) {

   NT32HLP *pHlp32;
   CONST WORD SizeDelta = sizeof(HLP) - sizeof(NT32HLP); // Diff 64 - 32.

   if (!ARGUMENT_PRESENT(pHlp64)) {
       return (NT32HLP *)pHlp64;
   }

   if (pHlp64->cbData < sizeof(HLP)) {
       LOGPRINT((ERRORLOG, "Wow64ShallowAllocThunkHLP64TO32 pHlp64->cbData:%x < sizeof(HLP):%x\n",
                pHlp64->cbData, sizeof(HLP)));
       RtlRaiseStatus(STATUS_INVALID_PARAMETER);
   }

   pHlp32 = Wow64AllocateTemp(pHlp64->cbData - SizeDelta);


   // Copy the header then adjust the offsets.
   pHlp32->cbData = pHlp64->cbData - SizeDelta;
   pHlp32->usCommand = pHlp64->usCommand;
   pHlp32->ulTopic = (ULONG_PTR)pHlp64->ulTopic;
   pHlp32->ulReserved = pHlp64->ulReserved;
   pHlp32->offszHelpFile = pHlp64->offszHelpFile ? pHlp64->offszHelpFile - SizeDelta : 0;
   pHlp32->offabData = pHlp64->offabData ? pHlp64->offabData - SizeDelta : 0;

   // Copy the remaining structures.
   RtlCopyMemory(((PBYTE)pHlp32) + sizeof(NT32HLP),
                 ((PBYTE)pHlp64) + sizeof(HLP),
                 pHlp64->cbData - sizeof(HLP));

   return pHlp32;
}

/*
 * These two sets of function pointer arrays
 * are used to map what the kernel thinks
 * addresses in user32.dll are and what the real
 * addresses are in user32.dll.
 *
 * We grab the Kernel's view of things from
 * CsrClientConnect() called from user32 DLL_PROCESS_ATTACH
 *
 * We grab the Client's view of things from
 * NtUserInitializeClientPfnArrays()
 */
const PFNCLIENT * apfnClientAKernel;
const PFNCLIENT * apfnClientWKernel;
const PFNCLIENTWORKER *apfnClientWorkerKernel;

const PFNCLIENT * apfnClientAClient;
const PFNCLIENT * apfnClientWClient;
const PFNCLIENTWORKER *apfnClientWorkerClient;

PSERVERINFO gpsi;
SHAREDINFO gSharedInfo;

VOID
NtWow64UserConnectHook(
    PVOID ConnectionInformation,
    PULONG ConnectionInformationLength
    )
/*
 * This grabs the ClientPFNArrays that the kernel has
 * stored from the CsrClientConnect() call done by user32.dll's
 * DLL_PROCESS_ATTACH.
 */
{
    WOWASSERT(*ConnectionInformationLength == sizeof(USERCONNECT));

    gSharedInfo = ((USERCONNECT*)ConnectionInformation)->siClient;
    gpsi = gSharedInfo.psi;
    apfnClientAKernel = &gpsi->apfnClientA;
    apfnClientWKernel = &gpsi->apfnClientW;
    apfnClientWorkerKernel = &gpsi->apfnClientWorker;

}

#define Wow64GetClientInfo() ((PCLIENTINFO)((NtCurrentTeb())->Win32ClientInfo))

#define WOW64DESKTOPVALIDATE(pci, pobj)                         \
        if (    pci->pDeskInfo &&                               \
                pobj >= pci->pDeskInfo->pvDesktopBase &&        \
                pobj < pci->pDeskInfo->pvDesktopLimit) {        \
            pobj = (PVOID)((ULONG_PTR)pobj - pci->ulClientDelta);         \
        } else {                                                \
            pobj = (PVOID)NtUserCallOneParam((ULONG_PTR)h,                       \
                    SFI__MAPDESKTOPOBJECT);                     \
        }                                                       \

#define ClientSharedInfo() (&gSharedInfo)
#define ServerInfo() (gpsi)

PWND Wow64ValidateHwnd(HWND h) {

   PCLIENTINFO pci;
   PVOID pobj = NULL;

   pci = Wow64GetClientInfo();

   StartValidateHandleMacro(h)
   BeginTypeValidateHandleMacro(pobj, TYPE_WINDOW)
   WOW64DESKTOPVALIDATE(pci, pobj)
   EndTypeValidateHandleMacro
   EndValidateHandleMacro

   if (!pobj) {
      NtCurrentTeb()->LastErrorValue = ERROR_INVALID_WINDOW_HANDLE;
      LOGPRINT((ERRORLOG, "Wow64ValidateHwnd: %p is an invalid handle\n", h));
   }

   return pobj;

}


PROC
NtWow64MapClientFnToKernelClientFn(
    PROC proc
    )
{
    PROC *pp;

    for (pp = (PROC*)apfnClientAClient; pp < (PROC*) (apfnClientAClient+1); pp ++) {
        if (proc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapClientFnToKernelClientFn: mapping A from %p to %p\n", proc, ((PROC*) apfnClientAKernel) [ (pp - (PROC*)apfnClientAClient) ]));
            return ((PROC*) apfnClientAKernel) [ (pp - (PROC*)apfnClientAClient) ];
        }
    }

    for (pp = (PROC*)apfnClientWClient; pp < (PROC*) (apfnClientWClient+1); pp ++) {
        if (proc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapClientFnToKernelClientFn: mapping W from %p to %p\n", proc, ((PROC*) apfnClientWKernel) [ (pp - (PROC*)apfnClientWClient) ]));
            return ((PROC*) apfnClientWKernel) [ (pp - (PROC*)apfnClientWClient) ];
        }
    }

    for (pp = (PROC*)apfnClientWorkerClient; pp < (PROC*) (apfnClientWorkerClient+1); pp ++) {
        if (proc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapClientFnToKernelClientFn: mapping Worker from %p to %p\n", proc, ((PROC*) apfnClientWorkerKernel) [ (pp - (PROC*)apfnClientWorkerClient) ]));
            return ((PROC*) apfnClientWorkerKernel) [ (pp - (PROC*)apfnClientWorkerClient) ];
        }
    }

    return (PROC)proc;
}

_int32
NtWow64MapKernelClientFnToClientFn(
    PROC kproc
    )
{
    PROC *pp;

    for (pp = (PROC*)apfnClientAKernel; pp < (PROC*) (apfnClientAKernel+1); pp ++) {
        if (kproc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapKernelClientFnToClientFn: mapping A from %p to %x\n", kproc, (_int32)((PROC*) apfnClientAClient) [ (pp - (PROC*)apfnClientAKernel) ]));
            return (_int32)((PROC*) apfnClientAClient) [ (pp - (PROC*)apfnClientAKernel) ];
        }
    }

    for (pp = (PROC*)apfnClientWKernel; pp < (PROC*) (apfnClientWKernel+1); pp ++) {
        if (kproc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapKernelClientFnToClientFn: mapping W from %p to %x\n", kproc, (_int32)((PROC*) apfnClientWClient) [ (pp - (PROC*)apfnClientWKernel) ]));
            return (_int32)((PROC*) apfnClientWClient) [ (pp - (PROC*)apfnClientWKernel) ];
        }
    }

    for (pp = (PROC*)apfnClientWorkerKernel; pp < (PROC*) (apfnClientWorkerKernel+1); pp ++) {
        if (kproc == *pp) {
            LOGPRINT((TRACELOG, "NtWow64MapKernelClientFnToClientFn: mapping Worker from %p to %x\n", kproc, (_int32)((PROC*) apfnClientWorkerClient) [ (pp - (PROC*)apfnClientWorkerKernel) ]));
            return (_int32)((PROC*) apfnClientWorkerClient) [ (pp - (PROC*)apfnClientWorkerKernel) ];
        }
    }

    return (_int32)kproc;
}

)


@Template(Thunks)
                                                           @NL
// Each of the WIN32 NT APIs has different return values for error cases. @NL
// Since no standard exists, a case list is needed.
@NL
// Not used. @NL
#define WOW64_DEFAULT_ERROR_ACTION ApiErrorNTSTATUS @NL
@NL
// This parameter is unused. @NL
#define WOW64_DEFAULT_ERROR_PARAM 0 @NL
@NL
// A case list is needed for these APIs. @NL
extern WOW64_SERVICE_ERROR_CASE sdwhwin32ErrorCase[]; @NL
#define WOW64_API_ERROR_CASES sdwhwin32ErrorCase @NL
@NL
@GenDispatchTable(sdwhwin32)
@NL
#if defined(WOW64DOPROFILE) @NL
@NL
WOW64SERVICE_PROFILE_TABLE_ELEMENT ptewhwin32[] = {  @Indent( @NL
   @ApiList({L"@ApiName", 0, @ApiName_PROFILE_SUBLIST, TRUE}, @NL)
   {NULL, 0, NULL, FALSE} //For debugging                     @NL
)};@NL
@NL

@NL
WOW64SERVICE_PROFILE_TABLE ptwhwin32 = {L"WHWIN32",   L"Win32k Function Thunks", ptewhwin32,
                                       (sizeof(ptewhwin32)/sizeof(WOW64SERVICE_PROFILE_TABLE_ELEMENT))-1}; @NL
@NL
#endif @NL
CGenEnd=
