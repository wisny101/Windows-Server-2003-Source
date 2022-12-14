;/*--
;Copyright (c) 1993  Microsoft Corporation
;
;Module Name:
;
;    atmonmsg.h
;
;Abstract:
;
;    Definitions for AppleTalk Print Monitor events.
;
;Author:
;
;    Frank Byrum (frankb@microsoft.com)
;
;Revision History:
;
;Notes:
;
;    This file is generated by the MC tool from the atmonmsg.mc file.
;
;--*/
;
;#ifndef _ATMONMSG_
;#define _ATMONMSG_
;
;#define ATALKMON_EVENT_SOURCE  L"AppleTalk Print Monitor"
;

SeverityNames=(Success=0x0:STATUS_SEVERITY_SUCCESS
               Informational=0x1:STATUS_SEVERITY_INFORMATIONAL
               Warning=0x2:STATUS_SEVERITY_WARNING
               Error=0x3:STATUS_SEVERITY_ERROR
              )

;
;/////////////////////////////////////////////////////////////////////////
;// AppleTalk Print Monitor Event Categories
;/////////////////////////////////////////////////////////////////////////
;
MessageId=1 SymbolicName=EVENT_CATEGORY_INTERNAL
Language=English
System Events
.

MessageId=+1 SymbolicName=EVENT_CATEGORY_ADMIN
Language=English
Administrative Events
.

MessageId=+1 SymbolicName=EVENT_CATEGORY_USAGE
Language=English
Usage Events
.

MessageId=+1 SymbolicName=EVENT_CATEGORY_CONFIG
Language=English
Not used
Configuration Events
.
;
;/////////////////////////////////////////////////////////////////////////
;// AppleTalk Print Monitor Events
;/////////////////////////////////////////////////////////////////////////
;

MessageId=2000 Severity=Informational SymbolicName=EVENT_ATALKMON_STARTED
Language=English
Not used
The AppleTalk Print Monitor has started.
.

MessageId=+1 Severity=Warning SymbolicName=EVENT_ATALKMON_STACK_NOT_STARTED
Language=English
An attempt was made to send a print job to an AppleTalk printer while
the AppleTalk Protocol device was stopped.  
.

MessageId=+1 Severity=Warning SymbolicName=EVENT_ATALKMON_STATUS
Language=English
Not used
The printer returned the following status message when an attempt was made
to print a job: %1
.

MessageId=+1 Severity=Warning SymbolicName=EVENT_ATALKMON_PRINTER_NOT_FOUND
Language=English
Not used
The printer %1 cannot be found on the AppleTalk network.  The print job has
been deleted.
.

MessageId=+1 Severity=Warning SymbolicName=EVENT_ATALKMON_JOB_CANCELED
Language=English
Not used
There was a communication problem with the printer %1. The print job has
been deleted.
.

MessageId=+1 Severity=Error SymbolicName=EVENT_ATALKMON_WINSOCK_ERROR
Language=English
Unable to intialize Windows Sockets for AppleTalk protocol. Ensure that AppleTalk is correctly configured.
.

MessageId=+1 Severity=Error SymbolicName=EVENT_ATALKMON_REGISTRY_ERROR
Language=English
An error was reported while attempting to initialize the monitor with the 
list of port information from the registry. 
The information is located in the key 
SYSTEM\CurrentControlSet\Control\Print\Monitors\AppleTalk Printing Devices
The error code is in the data.
.


;
;#endif // _ATMONMSG_
;

