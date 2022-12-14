
/*************************************************************************
*
* dispatch.c
*
* This module contains the dispatch routines for the TERMDD driver.
*
* Copyright 1998, Microsoft.
*
*************************************************************************/

/*
 *  Includes
 */
#include <precomp.h>
#pragma hdrstop

#include "ptdrvcom.h"

NTSTATUS
IcaDeviceControl (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaCreate (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaRead (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaWrite (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaWriteSync (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaCleanup (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );

NTSTATUS
IcaClose (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    );


NTSTATUS
IcaDispatch (
    IN PDEVICE_OBJECT DeviceObject,
    IN PIRP Irp
    )

/*++

Routine Description:

    This is the dispatch routine for ICA.

Arguments:

    DeviceObject - Pointer to device object for target device

    Irp - Pointer to I/O request packet

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PIO_STACK_LOCATION irpSp;
    KIRQL saveIrql;
    NTSTATUS Status;

    irpSp = IoGetCurrentIrpStackLocation( Irp );

    /*
     * Fan out the IRPs based on device type
     */
    if (*((ULONG *)(DeviceObject->DeviceExtension)) != DEV_TYPE_TERMDD)
    {
        /*
         * This is for the port driver part of TermDD
         */
        switch ( irpSp->MajorFunction ) {

            case IRP_MJ_CREATE:
                return PtCreate(DeviceObject, Irp);

            case IRP_MJ_CLOSE:
                return PtClose(DeviceObject, Irp);

            case IRP_MJ_INTERNAL_DEVICE_CONTROL:
                return PtInternalDeviceControl(DeviceObject, Irp);

            case IRP_MJ_DEVICE_CONTROL:
                return PtDeviceControl(DeviceObject, Irp);

            case IRP_MJ_FLUSH_BUFFERS:
                return STATUS_NOT_IMPLEMENTED;

            case IRP_MJ_PNP:
                return PtPnP(DeviceObject, Irp);

            case IRP_MJ_POWER:
                return PtPower(DeviceObject, Irp);

            case IRP_MJ_SYSTEM_CONTROL:
                return PtSystemControl(DeviceObject, Irp);

            default:
                KdPrint(( "IcaDispatch: Invalid major function FOR PORT DRIVER %lx\n",
                          irpSp->MajorFunction ));
                Irp->IoStatus.Status = STATUS_NOT_IMPLEMENTED;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return STATUS_NOT_IMPLEMENTED;
        }
    }
    else
    {
        switch ( irpSp->MajorFunction ) {

            case IRP_MJ_WRITE:

                ASSERT( FIELD_OFFSET( IO_STACK_LOCATION, Parameters.Write.Length ) ==
                        FIELD_OFFSET( IO_STACK_LOCATION, Parameters.DeviceIoControl.OutputBufferLength ) );
                ASSERT( FIELD_OFFSET( IO_STACK_LOCATION, Parameters.Write.Key ) ==
                        FIELD_OFFSET( IO_STACK_LOCATION, Parameters.DeviceIoControl.InputBufferLength ) );

                saveIrql = KeGetCurrentIrql();

                irpSp->Parameters.Write.Key = 0;

                Status = IcaWrite( Irp, irpSp );

                ASSERT( KeGetCurrentIrql( ) == saveIrql );

                return Status;

            case IRP_MJ_READ:

                ASSERT( FIELD_OFFSET( IO_STACK_LOCATION, Parameters.Read.Length ) ==
                        FIELD_OFFSET( IO_STACK_LOCATION, Parameters.DeviceIoControl.OutputBufferLength ) );
                ASSERT( FIELD_OFFSET( IO_STACK_LOCATION, Parameters.Read.Key ) ==
                        FIELD_OFFSET( IO_STACK_LOCATION, Parameters.DeviceIoControl.InputBufferLength ) );

                saveIrql = KeGetCurrentIrql();

                irpSp->Parameters.Read.Key = 0;

                Status = IcaRead( Irp, irpSp );

                ASSERT( KeGetCurrentIrql( ) == saveIrql );

                return Status;

            case IRP_MJ_DEVICE_CONTROL:

                saveIrql = KeGetCurrentIrql();

                Status = IcaDeviceControl( Irp, irpSp );

                ASSERT( KeGetCurrentIrql( ) == saveIrql );

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return( Status );

            case IRP_MJ_CREATE:

                Status = IcaCreate( Irp, irpSp );

                ASSERT( KeGetCurrentIrql( ) == LOW_LEVEL );

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return Status;

            case IRP_MJ_FLUSH_BUFFERS :

                Status = IcaWriteSync( Irp, irpSp );

                ASSERT( KeGetCurrentIrql( ) == LOW_LEVEL );

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return Status;

            case IRP_MJ_CLEANUP:

                Status = IcaCleanup( Irp, irpSp );

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                ASSERT( KeGetCurrentIrql( ) == LOW_LEVEL );

                return Status;

            case IRP_MJ_CLOSE:

                Status = IcaClose( Irp, irpSp );

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                ASSERT( KeGetCurrentIrql( ) == LOW_LEVEL );

                return Status;

            case IRP_MJ_QUERY_SECURITY:

                Status = STATUS_INVALID_DEVICE_REQUEST;

                Irp->IoStatus.Status = Status;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return Status;

            default:
                Irp->IoStatus.Status = STATUS_NOT_IMPLEMENTED;
                IoCompleteRequest( Irp, IcaPriorityBoost );

                return STATUS_NOT_IMPLEMENTED;
        }
    }
}

BOOLEAN
IcaIsSystemProcessRequest (
    PIRP Irp,
    PIO_STACK_LOCATION IrpSp,
    BOOLEAN *pbSystemClient)
{
    PACCESS_STATE accessState;
    PIO_SECURITY_CONTEXT  securityContext;
    PACCESS_TOKEN CallerAccessToken;
    PACCESS_TOKEN ClientAccessToken;
    PTOKEN_USER userId = NULL;
    BOOLEAN result = FALSE;
    NTSTATUS status = STATUS_SUCCESS;
    PSID systemSid;


    ASSERT(Irp != NULL);
    
    ASSERT(IrpSp != NULL);

    ASSERT(pbSystemClient != NULL);

    *pbSystemClient = FALSE;

    securityContext = IrpSp->Parameters.Create.SecurityContext;

    ASSERT(securityContext != NULL);

    //
    //  Get the well-known system SID.
    //
    systemSid = ExAllocatePoolWithTag(
                            PagedPool,
                            RtlLengthRequiredSid(1),
                            ICA_POOL_TAG
                            );
    if (systemSid) {
        SID_IDENTIFIER_AUTHORITY identifierAuthority = SECURITY_NT_AUTHORITY;
        *(RtlSubAuthoritySid(systemSid, 0)) = SECURITY_LOCAL_SYSTEM_RID;
        status = RtlInitializeSid(systemSid, &identifierAuthority, (UCHAR)1);
    }
    else {
        status = STATUS_INSUFFICIENT_RESOURCES;
    }

    accessState = securityContext->AccessState;

     //
    //  Get the non-impersonated, primary token for the IRP request.
    //
    CallerAccessToken = accessState->SubjectSecurityContext.PrimaryToken;

    //
    // get the impersonated token.
    //
    ClientAccessToken = accessState->SubjectSecurityContext.ClientToken;


    //
    // We got the system SID. Now compare the caller and client's SIDs.
    //
    if (NT_SUCCESS(status) && CallerAccessToken){
        //
        //  Get the user ID associated with the primary token for the process
        //  that generated the IRP.
        //
        status = SeQueryInformationToken(
            CallerAccessToken,
            TokenUser,
            &userId
        );

        //
        //  Do the comparison.
        //  
        if (NT_SUCCESS(status)) {
            result = RtlEqualSid(systemSid, userId->User.Sid);
            ExFreePool(userId);
        }

        if (ClientAccessToken)
        {
        	
	        //
	        //  Get the user ID associated with the client  token (impersonation token) 
	        //
	        status = SeQueryInformationToken(
	            ClientAccessToken,
	            TokenUser,
	            &userId
	        );

	        //
	        //  Do the comparison.
	        //  
	        if (NT_SUCCESS(status)) {
	            *pbSystemClient = RtlEqualSid(systemSid, userId->User.Sid);
	            ExFreePool(userId);
	        }

        }
        else
        {
        	// 
        	// we dont have  ClientAccessToken, impling there is no impersonation going on.
        	// in this case lets set *pbSystemClient = caller
        	//
        	*pbSystemClient = result;
        }
        
    }


  
    if (systemSid) {
        ExFreePool(systemSid);
    }

    return result;
}



NTSTATUS
IcaCreate (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the routine that handles Create IRPs in ICA.

Arguments:

    Irp - Pointer to I/O request packet.

    IrpSp - pointer to the IO stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_OPEN_PACKET openPacket;
    PFILE_FULL_EA_INFORMATION eaBuffer;
    PFILE_OBJECT pConnectFileObject;
    PICA_CONNECTION pConnect;
    NTSTATUS Status;
    BOOLEAN bSystemCaller; // was the caller of this IRP system?
    BOOLEAN bSystemClient; // was the client of this IRP system?




    PAGED_CODE( );

    // Save result in FsContext2: if the requestor is system process or not
    bSystemCaller = IcaIsSystemProcessRequest(Irp, IrpSp, &bSystemClient);
    IrpSp->FileObject->FsContext2 = (VOID *)bSystemCaller;

    


    /*
     * Find the open packet from the EA buffer in the system buffer of
     * the associated IRP.  If no EA buffer was specified, then this
     * is a request to open a new ICA connection.
     */
    eaBuffer = Irp->AssociatedIrp.SystemBuffer;
    if ( eaBuffer == NULL ) {
        if ( (Irp->RequestorMode != KernelMode) &&  !bSystemCaller) {

            return STATUS_ACCESS_DENIED;
        }
        return( IcaCreateConnection( Irp, IrpSp ) );
    }

    if (eaBuffer->EaValueLength < sizeof(ICA_OPEN_PACKET)) {
       ASSERT(FALSE);
       return STATUS_INVALID_PARAMETER;
    }



    openPacket = (PICA_OPEN_PACKET)(eaBuffer->EaName + eaBuffer->EaNameLength + 1);

    /*
     * Validate parameters in the open packet.
     */
    if ( openPacket->OpenType != IcaOpen_Stack &&
         openPacket->OpenType != IcaOpen_Channel ) {
        ASSERT(FALSE);
        return STATUS_INVALID_PARAMETER;
    }
    /*
     * If this open is not for a virtual channel then the caller has to be system or kernel mode.
     */


    if ((openPacket->OpenType == IcaOpen_Stack) || openPacket->TypeInfo.ChannelClass != Channel_Virtual) {
        if ( (Irp->RequestorMode != KernelMode) &&  !bSystemCaller) {
            return STATUS_ACCESS_DENIED;
        }
    }

     /*
      *   if we are creating a Virtual Channel, then add some more restriction on security. as an RPC caller 
      *   can cause us to open the v channel, mark the object so if the either caller or client is non system.
      */
     if (openPacket->OpenType == IcaOpen_Channel && openPacket->TypeInfo.ChannelClass == Channel_Virtual) 
     {
         if (!_stricmp(VIRTUAL_THINWIRE, openPacket->TypeInfo.VirtualName))
         {
             // THIS IS A UGLY SPECIAL CASE. IN SHADOWWORKER, THIS CHANNEL IS CREATED WHILE IMPERSONATED.
             // BUT WE DONT LET THIS CHANNLE TO BE OPENED BY RPCOPENVIRTUAL CHANNEL. SO LETS MARK MAKE AN EXCEPTION FOR THIS.
         }
         else
         {
            IrpSp->FileObject->FsContext2 = (VOID *)(BOOLEAN)(bSystemClient && bSystemCaller);
         }
     }



    /*
     * Use the specified ICA connection handle to get a pointer to
     * the connection object.
     */
    Status = ObReferenceObjectByHandle(
                 openPacket->IcaHandle,
                 STANDARD_RIGHTS_READ,                         // DesiredAccess
                 *IoFileObjectType,
                 Irp->RequestorMode,
                 (PVOID *)&pConnectFileObject,
                 NULL
                 );
    if ( !NT_SUCCESS(Status) )
        return( Status );

    /*
     * Ensure what we have is a connection object
     */

    if (pConnectFileObject->DeviceObject != IcaDeviceObject) {
        ASSERT(FALSE);
        ObDereferenceObject( pConnectFileObject );
        return STATUS_INVALID_PARAMETER;
    }
    pConnect = pConnectFileObject->FsContext;
    ASSERT( pConnect->Header.Type == IcaType_Connection );
    if ( pConnect->Header.Type != IcaType_Connection ) {
        ObDereferenceObject( pConnectFileObject );
        return( STATUS_INVALID_CONNECTION );
    }

    /*
     * Create a new stack or new channel
     */
    IcaReferenceConnection( pConnect );

    switch ( openPacket->OpenType ) {
        case IcaOpen_Stack :
            Status = IcaCreateStack( pConnect, openPacket, Irp, IrpSp );
            break;

        case IcaOpen_Channel :
            Status = IcaCreateChannel( pConnect, openPacket, Irp, IrpSp );
            break;
    }

    IcaDereferenceConnection( pConnect );
    ObDereferenceObject( pConnectFileObject );

    return( Status );
}


NTSTATUS
IcaRead (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the read routine for ICA.

Arguments:

    Irp - Pointer to I/O request packet

    IrpSp - pointer to the stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    /*
     * Get pointer to ICA object header.
     * If a read routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_READ] == NULL ) {
        Status = STATUS_INVALID_DEVICE_REQUEST;
        Irp->IoStatus.Status = Status;
        IoCompleteRequest( Irp, IcaPriorityBoost );
        return( Status );
    }

    /*
     * Call the read routine for this ICA object.
     */
    Status = (pIcaHeader->pDispatchTable[IRP_MJ_READ])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
IcaWrite (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the write routine for ICA.

Arguments:

    Irp - Pointer to I/O request packet

    IrpSp - pointer to the stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    /*
     * Get pointer to ICA object header.
     * If a write routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_WRITE] == NULL ) {
        Status = STATUS_INVALID_DEVICE_REQUEST;
        Irp->IoStatus.Status = Status;
        IoCompleteRequest( Irp, IcaPriorityBoost );
        return( Status );
    }

    /*
     * Call the write routine for this ICA object.
     */
    Status = (pIcaHeader->pDispatchTable[IRP_MJ_WRITE])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
IcaWriteSync (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the flush routine for ICA.

Arguments:

    Irp - Pointer to I/O request packet

    IrpSp - pointer to the stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    /*
     * Get pointer to ICA object header.
     * If a flush routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_FLUSH_BUFFERS] == NULL )
        return( STATUS_INVALID_DEVICE_REQUEST );

    /*
     * Call the flush routine for this ICA object.
     */
    Status = (pIcaHeader->pDispatchTable[IRP_MJ_FLUSH_BUFFERS])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
IcaDeviceControl (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the dispatch routine for ICA IOCTLs.

Arguments:

    Irp - Pointer to I/O request packet.

    IrpSp - pointer to the stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    /*
     * Get pointer to ICA object header.
     * If a device control routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_DEVICE_CONTROL] == NULL )
        return( STATUS_INVALID_DEVICE_REQUEST );

    /*
     * Call the device control routine for this ICA object.
     */
    Status = (pIcaHeader->pDispatchTable[IRP_MJ_DEVICE_CONTROL])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
IcaCleanup (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the routine that handles Cleanup IRPs in ICA.

Arguments:

    Irp - Pointer to I/O request packet.

    IrpSp - pointer to the IO stack location to use for this request.

Return Value:

    NTSTATUS --

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    /*
     * Get pointer to ICA object header.
     * If a cleanup routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_CLEANUP] == NULL )
        return( STATUS_INVALID_DEVICE_REQUEST );

    Status = (pIcaHeader->pDispatchTable[IRP_MJ_CLEANUP])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
IcaClose (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp
    )

/*++

Routine Description:

    This is the routine that handles Close IRPs in ICA.  It
    dereferences the endpoint specified in the IRP, which will result in
    the endpoint being freed when all other references go away.

Arguments:

    Irp - Pointer to I/O request packet.

    IrpSp - pointer to the IO stack location to use for this request.

Return Value:

    NTSTATUS -- Indicates whether the request was successfully queued.

--*/

{
    PICA_HEADER pIcaHeader;
    NTSTATUS Status;

    PAGED_CODE( );

    /*
     * Get pointer to ICA object header.
     * If a close routine is not defined, return an error.
     */
    pIcaHeader = IrpSp->FileObject->FsContext;
    if ( pIcaHeader->pDispatchTable[IRP_MJ_CLOSE] == NULL )
        return( STATUS_INVALID_DEVICE_REQUEST );

    Status = (pIcaHeader->pDispatchTable[IRP_MJ_CLOSE])(
                pIcaHeader, Irp, IrpSp );

    return( Status );
}


NTSTATUS
CaptureUsermodeBuffer (
    IN PIRP Irp,
    IN PIO_STACK_LOCATION IrpSp,
    OUT PVOID *pInBuffer,
    IN ULONG InBufferSize,
    OUT PVOID *pOutBuffer,
    IN ULONG OutBufferSize,
    IN BOOLEAN MethodBuffered,
    OUT PVOID *pAllocatedTemporaryBuffer
    )
{
    NTSTATUS Status = STATUS_SUCCESS;

    PVOID pBuffer = NULL;

    try {

        if (MethodBuffered) {
            if (pInBuffer != NULL) {
                *pInBuffer = Irp->AssociatedIrp.SystemBuffer;
            }
            if (pOutBuffer != NULL) {
                *pOutBuffer = Irp->AssociatedIrp.SystemBuffer;
            }
            if (pAllocatedTemporaryBuffer != NULL) {
                *pAllocatedTemporaryBuffer = NULL;
            }

        } else{
            ULONG AlignedInputSize = (InBufferSize + sizeof(BYTE*) - 1) & ~(sizeof(BYTE*) - 1);
            ULONG AllocationSize = AlignedInputSize +OutBufferSize;
            if (AllocationSize != 0 ) {
                if (gCapture && (Irp->RequestorMode == UserMode) ) {
                    pBuffer = ExAllocatePoolWithTag(PagedPool, AllocationSize, ICA_POOL_TAG);
                    if (pBuffer == NULL) {
                        ExRaiseStatus(STATUS_NO_MEMORY);
                    } else{
                        if (pInBuffer != NULL) {
                            *pInBuffer = pBuffer;
                        }
                        if (pOutBuffer != NULL) {
                            *pOutBuffer = (PVOID)((BYTE*)pBuffer+AlignedInputSize);
                        }
                        if (pAllocatedTemporaryBuffer != NULL) {
                            *pAllocatedTemporaryBuffer = pBuffer;
                        }
                        if (IrpSp->Parameters.DeviceIoControl.InputBufferLength != 0) {
                            RtlCopyMemory( pBuffer, 
                                           IrpSp->Parameters.DeviceIoControl.Type3InputBuffer, 
                                           IrpSp->Parameters.DeviceIoControl.InputBufferLength);
                        }
                        if (IrpSp->Parameters.DeviceIoControl.OutputBufferLength != 0 ) {
                            RtlCopyMemory((PVOID) ((BYTE*)pBuffer+AlignedInputSize), 
                                           Irp->UserBuffer, 
                                           IrpSp->Parameters.DeviceIoControl.OutputBufferLength);
                        }
                    }
                }   else{
                    if (pInBuffer != NULL) {
                        *pInBuffer = IrpSp->Parameters.DeviceIoControl.Type3InputBuffer;
                    }
                    if (pOutBuffer != NULL) {
                        *pOutBuffer = Irp->UserBuffer;
                    }
                    if (pAllocatedTemporaryBuffer != NULL) {
                        *pAllocatedTemporaryBuffer = NULL;
                    }
                }

            }else {
                if (pInBuffer != NULL) {
                    *pInBuffer = NULL;
                }
                if (pOutBuffer != NULL) {
                    *pOutBuffer = NULL;
                }
                if (pAllocatedTemporaryBuffer != NULL) {
                    *pAllocatedTemporaryBuffer = NULL;
                }

            }
        }
    }   except(EXCEPTION_EXECUTE_HANDLER){
            if (pBuffer != NULL) {
                ExFreePool(pBuffer);
            }
            if (pAllocatedTemporaryBuffer != NULL) {
                *pAllocatedTemporaryBuffer = NULL;
            }
            Status = GetExceptionCode();

    }
    return Status;

}
