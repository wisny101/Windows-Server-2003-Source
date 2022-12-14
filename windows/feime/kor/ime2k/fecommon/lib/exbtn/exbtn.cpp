#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <windowsx.h>
#include "dbg.h"
#include "cexbtn.h"

// Safe String
#define STRSAFE_NO_DEPRECATE
#include "strsafe.h"

//////////////////////////////////////////////////////////////////
// Function : EXButton_CreateWindow
// Type     : HWND
// Purpose  : Opened API.
//			: Create Extended Button.
// Args     : 
//          : HINSTANCE		hInst 
//          : HWND			hwndParent 
//          : DWORD			dwStyle		EXBS_XXXXX combination.
//          : INT			wID			Window ID
//          : INT			xPos 
//          : INT			yPos 
//          : INT			width 
//          : INT			height 
// Return   : 
// DATE     : 970905
//////////////////////////////////////////////////////////////////
#ifndef UNDER_CE
#define SZCLASSNAME "MSIME_EXB"
#else // UNDER_CE
#define SZCLASSNAME TEXT("MSIME_EXB")
#endif // UNDER_CE
#ifdef UNDER_CE // In Windows CE, all window classes are process global.
static LPCTSTR MakeClassName(HINSTANCE hInst, LPTSTR lpszBuf)
{
	// make module unique name
	TCHAR szFileName[MAX_PATH];
	GetModuleFileName(hInst, szFileName, MAX_PATH);
	LPTSTR lpszFName = _tcsrchr(szFileName, TEXT('\\'));
	if(lpszFName) *lpszFName = TEXT('_');
	StringCchCopy(lpszBuf, MAX_PATH, SZCLASSNAME);
	StringCchCat(lpszBuf, MAX_PATH, lpszFName);
	return lpszBuf;
}

BOOL EXButton_UnregisterClass(HINSTANCE hInst)
{
	TCHAR szClassName[MAX_PATH];
	return UnregisterClass(MakeClassName(hInst, szClassName), hInst);
}

#endif // UNDER_CE
HWND EXButton_CreateWindow(HINSTANCE	hInst, 
						   HWND			hwndParent, 
						   DWORD		dwStyle,
						   INT			wID, 
						   INT			xPos,
						   INT			yPos,
						   INT			width,
						   INT			height)
{
	DBG_INIT();
	LPCEXButton lpEXB = new CEXButton(hInst, hwndParent, dwStyle, wID);
	HWND hwnd;
	if(!lpEXB) {
		return NULL;
	}
#ifndef UNDER_CE // In Windows CE, all window classes are process global.
	lpEXB->RegisterWinClass(SZCLASSNAME);
	hwnd = CreateWindowEx(0,
						  SZCLASSNAME, 
#else // UNDER_CE
	TCHAR szClassName[MAX_PATH];
	MakeClassName(hInst, szClassName);

	lpEXB->RegisterWinClass(szClassName);
	hwnd = CreateWindowEx(0,
						  szClassName, 
#endif // UNDER_CE
#ifndef UNDER_CE
						  "", 
#else // UNDER_CE
						  TEXT(""),
#endif // UNDER_CE
						  WS_CHILD | WS_VISIBLE | WS_CLIPSIBLINGS, 
						  xPos, yPos,
						  width,
						  height,
						  hwndParent,
#ifdef _WIN64
						  (HMENU)(INT_PTR)wID,
#else
						  (HMENU)wID,
#endif
						  hInst,
						  (LPVOID)lpEXB);
	return hwnd;
}

