/*****************************************************************************
******************************************************************************
**
**
**	ICShelp.h
**		Contains the useful public entry points to an ICS-assistance library
**		created for the Salem/PCHealth Remote Assistance feature in Whistler
**
**	Dates:
**		11-1-2000	created by TomFr
**		11-17-2000	re-written as a DLL, had been an object.
**
******************************************************************************
*****************************************************************************/
#ifndef __ICSHELP_HH__
#define __ICSHELP_HH__

#ifdef __cplusplus
extern "C" {
#endif


/****************************************************************************
**
**	OpenPort(int port)
**		if there is no ICS available, then we should just return...
**
**		Of course, we save away the Port, as it goes back in the
**		FetchAllAddresses call, asthe formatted "port" whenever a
**		different one is not specified.
**
****************************************************************************/

DWORD APIENTRY OpenPort(int Port);

/****************************************************************************
**
**	Called to close a port, whenever a ticket is expired or closed.
**
****************************************************************************/

DWORD APIENTRY ClosePort(DWORD dwHandle);

/****************************************************************************
**
**	FetchAllAddresses
**		Returns a string listing all the valid IP addresses for the machine,
**		followed by the DNS name of the machine.
**		Formatting details:
**		1. Each address is seperated with a ";" (semicolon)
**		2. Each address consists of the "1.2.3.4", and is followed by ":p"
**		   where the colon is followed by the port number
**
****************************************************************************/

DWORD APIENTRY FetchAllAddresses(WCHAR *lpszAddr, int iBufSize);


/****************************************************************************
**
**
**
**
**
**
****************************************************************************/

DWORD APIENTRY CloseAllOpenPorts(void);

/****************************************************************************
**
**
**
**
**
**
****************************************************************************/

DWORD APIENTRY StartICSLib(void);

/****************************************************************************
**
**
**
**
**
**
****************************************************************************/

DWORD APIENTRY StopICSLib(void);

/****************************************************************************
**
**	FetchAllAddressesEx
**
****************************************************************************/
// these are the flag bits to use.
#define IPF_ADD_DNS		1
#define IPF_NO_SORT		4

DWORD APIENTRY FetchAllAddressesEx(WCHAR *lpszAddr, int iBufSize, int IPflags);

/****************************************************************************
**
**	GetIcsStatus(PICSSTAT pStat)
**		Returns a structure detailing much of what is going on inside this
**		library. The dwSize entry must be filled in before calling this
**		function. Use "sizeof(ICSSTAT))" to populate this before calling.
**
****************************************************************************/

typedef struct _ICSSTAT {
	DWORD	dwSize;
	BOOL	bIcsFound;	// TRUE if we found a NAT to negotiate
	BOOL	bFwFound;	// TRUE if we found a FIREWALL to negotiate
	BOOL	bIcsServer;	// TRUE if this machine is the ICS server (NAT)
	BOOL	bUsingDP;	// TRUE if using the DPNHxxxx.DLL support
	BOOL	bUsingUpnp;	// TRUE for uPnP, FALSE for PAST
	BOOL	bModemPresent;
	BOOL	bVpnPresent;
	WCHAR	wszPubAddr[25];	// filled in with the public side addr of ICS
	WCHAR	wszLocAddr[25];	// IP of local NIC used for PAST bindings
	WCHAR	wszDllName[32]; // name of DLL used for ICS support
	DWORD	dwFlags;
} ICSSTAT, *PICSSTAT;


DWORD APIENTRY GetIcsStatus(PICSSTAT pStat);

#ifdef __cplusplus
}
#endif

#endif // __ICSHELP_HH__
