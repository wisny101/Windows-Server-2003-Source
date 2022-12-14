#pragma code_page(1252)

#include    <msprivs2.h>

LANGUAGE LANG_PORTUGUESE, SUBLANG_PORTUGUESE
STRINGTABLE MOVEABLE DISCARDABLE
BEGIN
	IDS_SeCreateTokenPrivilege,		"Criar um objecto token"
	IDS_SeAssignPrimaryTokenPrivilege,	"Substituir um token de nível de processo"
	IDS_SeLockMemoryPrivilege,		"Bloquear páginas na memória"
	IDS_SeIncreaseQuotaPrivilege,		"Ajustar quotas de memória para um processo"
	IDS_SeMachineAccountPrivilege,		"Adicionar estações de trabalho ao domínio"
	IDS_SeTcbPrivilege,			"Actuar como parte do sistema operativo"
	IDS_SeSecurityPrivilege,		"Gerir auditoria e registo de segurança"
	IDS_SeTakeOwnershipPrivilege,		"Tomar posse de ficheiros ou outros objectos"
	IDS_SeLoadDriverPrivilege,		"Carregar e remover da memória controladores de dispositivo"
	IDS_SeSystemProfilePrivilege,		"Traçar um perfil do desempenho do sistema"
	IDS_SeSystemtimePrivilege,		"Alterar a hora do sistema"
	IDS_SeProfileSingleProcessPrivilege,	"Traçar um perfil de um processo único"
	IDS_SeIncreaseBasePriorityPrivilege,	"Aumentar a prioridade de agendamento"
	IDS_SeCreatePagefilePrivilege,		"Criar um ficheiro de paginação"
	IDS_SeCreatePermanentPrivilege,		"Criar objectos partilhados permanentemente"
	IDS_SeBackupPrivilege,			"Criar cópias de segurança para ficheiros e directórios"
	IDS_SeRestorePrivilege,			"Restaurar ficheiros e directórios"
	IDS_SeShutdownPrivilege,		"Encerrar o sistema"
	IDS_SeDebugPrivilege,			"Depurar programas"
	IDS_SeAuditPrivilege,			"Gerar auditoria de segurança"
	IDS_SeSystemEnvironmentPrivilege,	"Modificar valores de ambiente para firmware"
	IDS_SeChangeNotifyPrivilege,		"Ignorar verificação transversal"
	IDS_SeRemoteShutdownPrivilege,		"Forçar o encerramento a partir de um sistema remoto"
// new in Windows 2000
	IDS_SeUndockPrivilege,			"Remover computador da estação de ancoragem"
	IDS_SeSyncAgentPrivilege,		"Sincronizar dados do serviço de directório"
	IDS_SeEnableDelegationPrivilege,	"Activar computador e contas de utilizador para serem fidedignos para delegação"
// new in windows 2000 + 1
	IDS_SeManageVolumePrivilege,		"Realizar tarefas de manutenção de volume"
        IDS_SeImpersonatePrivilege,             "Personificar um cliente após autenticação"
        IDS_SeCreateGlobalPrivilege,            "Criar objectos globais"
END
