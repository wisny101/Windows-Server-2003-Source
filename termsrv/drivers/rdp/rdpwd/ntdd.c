/****************************************************************************/
// ntdd.c
//
// Standard NT driver initialization, for inclusion in each of the TS
// stack drivers.
//
// Copyright (C) 1997-1999 Microsoft Corp.
/****************************************************************************/

#include "precomp.h"
#pragma hdrstop

#define DEVICE_NAME_PREFIX L"\\Device\\"


//
// Global data
//
PDEVICE_OBJECT DrvDeviceObject;


//
// External references
//

// This is the name of the WD/TD/PD module we are initializing as.
extern const PWCHAR ModuleName;

// Global code page caching data to be initialized and freed in asmint.c.
extern FAST_MUTEX fmCodePage;
extern ULONG LastCodePageTranslated;
extern PVOID LastNlsTableBuffer;
extern UINT NlsTableUseCount;


// This is the stack driver module entry point defined in ntos\citrix\inc\sdapi.h
NTSTATUS
_stdcall
ModuleEntry(
    IN OUT PSDCONTEXT pSdContext,
    IN BOOLEAN bLoad
    );


//
// Forward refrences
//
VOID DrvUnload( PDRIVER_OBJECT );

NTSTATUS
DrvDispatch(
    IN PDEVICE_OBJECT DeviceObject,
    IN PIRP Irp
    );


NTSTATUS
DriverEntry(
    IN PDRIVER_OBJECT DriverObject,
    IN PUNICODE_STRING RegistryPath
    )


/*++

Routine Description:

    Standard NT driver entry routine.

Arguments:

    DriverObject - NT passed driver object
    RegistryPath - Path to driver specific registry entry

Return Value:

    NTSTATUS code.

Environment:

    Kernel mode, DDK
--*/
{
    ULONG i;
    NTSTATUS Status;
    UNICODE_STRING DeviceName;
    PWCHAR NameBuffer;
    ULONG  NameSize;

    PAGED_CODE( );

    NameSize = sizeof(DEVICE_NAME_PREFIX) + sizeof(WCHAR);
    NameSize += (wcslen(ModuleName) * sizeof(WCHAR));

    NameBuffer = ExAllocatePool( NonPagedPool, NameSize );
    if( NameBuffer == NULL ) {
        return( STATUS_INSUFFICIENT_RESOURCES );
    }

    wcscpy( NameBuffer, DEVICE_NAME_PREFIX );
    wcscat( NameBuffer, ModuleName );

    RtlInitUnicodeString( &DeviceName, NameBuffer );

    Status = IoCreateDevice(
                 DriverObject,
                 0,       // No DeviceExtension
                 &DeviceName,
                 FILE_DEVICE_TERMSRV,
                 0,
                 FALSE,
                 &DrvDeviceObject
                 );

    if( !NT_SUCCESS(Status) ) {
        ExFreePool( NameBuffer );
        return( Status );
    }

    DriverObject->DriverUnload = DrvUnload;
    DriverObject->FastIoDispatch = NULL;

    for (i = 0; i <= IRP_MJ_MAXIMUM_FUNCTION; i++) {
        DriverObject->MajorFunction[i] = DrvDispatch;
    }

    // Init code page handling info from asmint.c.
    ExInitializeFastMutex(&fmCodePage);
    LastCodePageTranslated = 0;
    LastNlsTableBuffer = NULL;
    NlsTableUseCount = 0;
    
    DrvDeviceObject->Flags &= ~DO_DEVICE_INITIALIZING;

    ExFreePool( NameBuffer );

    return( Status );
}


VOID
DrvUnload(
    IN PDRIVER_OBJECT DriverObject
    )

/*++

Routine Description:

    Driver unload routine.

Arguments:

    DriverObject - Driver object being unloaded.

Return Value:

    None.

Environment:

    Kernel mode, DDK
--*/
{
    PAGED_CODE( );

    // Free remaining code page data on exit, if it exists.
    if (LastNlsTableBuffer != NULL) {
        ExFreePool(LastNlsTableBuffer);
        LastNlsTableBuffer = NULL;
    }

    IoDeleteDevice( DrvDeviceObject );

    return;
}


NTSTATUS
DrvDispatch(
    IN PDEVICE_OBJECT DeviceObject,
    IN PIRP Irp
    )

/*++

Routine Description:

    This is the dispatch routine for the driver.

Arguments:

    DeviceObject - Pointer to device object for target device

    Irp - Pointer to I/O request packet

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

Environment:

    Kernel mode, DDK
--*/
{
    PIO_STACK_LOCATION irpSp;
    KIRQL saveIrql;
    NTSTATUS Status;
    PSD_MODULE_INIT pmi;

    DeviceObject;   // prevent compiler warnings

    irpSp = IoGetCurrentIrpStackLocation( Irp );

    switch ( irpSp->MajorFunction ) {

        case IRP_MJ_CREATE:
    
            if( Irp->RequestorMode != KernelMode ) {
                Status = STATUS_ACCESS_DENIED;
                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, 0 );
                return( Status );
            }

            Status = STATUS_SUCCESS;

            Irp->IoStatus.Status = Status;
            IoCompleteRequest( Irp, 0 );
    
            return Status;

        case IRP_MJ_INTERNAL_DEVICE_CONTROL:

            if( Irp->RequestorMode != KernelMode ) {
                Status = STATUS_NOT_IMPLEMENTED;
                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, 0 );
                return( Status );
            }

            if( irpSp->Parameters.DeviceIoControl.IoControlCode !=
                    IOCTL_SD_MODULE_INIT ) {
                Status = STATUS_NOT_IMPLEMENTED;
                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, 0 );
                return( Status );
            }

            if( irpSp->Parameters.DeviceIoControl.OutputBufferLength <
                    sizeof(SD_MODULE_INIT) ) {
                Status = STATUS_BUFFER_TOO_SMALL;
                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, 0 );
                return( Status );
            }

            // Return the SD module entry point.
            pmi = (PSD_MODULE_INIT)Irp->UserBuffer;
            pmi->SdLoadProc = ModuleEntry;

            Status = STATUS_SUCCESS;
            Irp->IoStatus.Information = sizeof(SD_MODULE_INIT);
            Irp->IoStatus.Status = Status;
            IoCompleteRequest( Irp, 0 );
    
            return Status;

        case IRP_MJ_CLEANUP:
    
            Status = STATUS_SUCCESS;

            Irp->IoStatus.Status = Status;
            IoCompleteRequest( Irp, 0 );
    
            return Status;

        case IRP_MJ_CLOSE:
    
            Status = STATUS_SUCCESS;

            Irp->IoStatus.Status = Status;
            IoCompleteRequest( Irp, 0 );
    
            return Status;

        default:
            Irp->IoStatus.Status = STATUS_NOT_IMPLEMENTED;
            IoCompleteRequest( Irp, 0 );
    
            return STATUS_NOT_IMPLEMENTED;
    }
}

