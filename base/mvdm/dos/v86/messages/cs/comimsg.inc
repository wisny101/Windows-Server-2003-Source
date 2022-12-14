;       Command.com initialization messages.
;
;       See resmsg.equ for macro definition.

        msg     BadVerMsg,   <"Nespr?vn? verze syst?mu DOS",CR,LF>
        msg     OutEnvMsg,   <"Nedostatek pam?ti pro syst?mov? prom?nn?",CR,LF>
        msg     CopyrightMsg,<"Microsoft(R) Windows DOS",CR,LF,"(C)Copyright Microsoft Corp 1990-2001.",CR,LF>
        msg     BadComLkMsg, <"Zadan? adres?? pro vyhled?n? p??kazu COMMAND je chybn?",CR,LF>
        msg     BadComAccMsg,<"K zadan?mu adres??i pro vyhled?n? p??kazu COMMAND byl odm?tnut p??stup",CR,LF>

        msg     Help1Msg  <"Spou?t? nov? prost?ed? p??kazov?ho ??dku MS-DOS.",CR,LF,CR,LF>
        msg     Help2Msg  <"COMMAND [[jednotka:]cesta] [za??zen?] [/E:nnnnn] [/P] [/C ?et?zec] [/MSG]",CR,LF,CR,LF>
        msg     Help3Msg  <" [jednotka:]cesta Ur?? jednotku a adres?? obsahuj?c? soubor COMMAND.COM.",CR,LF>
        msg     Help4Msg  <" za??zen?         Ur?? za??zen? pro vstup a v?stup p??kaz?.",CR,LF>
        msg     Help5Msg  <" /E:nnnnn         Nastav? velikost pam?ti pro prom?nn? syst?mu na nnnnn bajt?.",CR,LF>
        msg     Help6Msg  <" /P               Ur??, ?e prost?ed? MS-DOS nelze ukon?it.",CR,LF>
        msg     Help7Msg  <" /C ?et?zec       Vykon? p??kaz ur?en? ?et?zcem, pak se zastav?.",CR,LF>
        msg     Help8Msg  <" /MSG             Ur??, ?e v?echny chybov? zpr?vy se ulo?? do pam?ti.",CR,LF>
        msg     Help9Msg  <"                  S p?ep?na?em /MSG je nutno nastavit i p?ep?na? /P.",CR,LF>

HelpMsgs        dw      RESGROUP:Help1Msg,RESGROUP:Help2Msg
                dw      RESGROUP:Help3Msg,RESGROUP:Help4Msg
                dw      RESGROUP:Help5Msg,RESGROUP:Help6Msg
                dw      RESGROUP:Help7Msg,RESGROUP:Help8Msg
                dw      RESGROUP:Help9Msg,0

        public  HelpMsgs
