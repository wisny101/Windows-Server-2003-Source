;	Command.com initialization messages.
;
;	See resmsg.equ for macro definition.

        msg     BadVerMsg,   <"Niepoprawna wersja systemu DOS",CR,LF>
        msg     OutEnvMsg,   <"Brak miejsca na ?rodowisko",CR,LF>
        msg     CopyrightMsg,<"Microsoft(R) Windows DOS",CR,LF,"(C)Copyright Microsoft Corp 1990-2001.",CR,LF>
        msg     BadComLkMsg, <"Podany katalog wyszukiwania pliku COMMAND jest niew?a?ciwy",CR,LF>
        msg     BadComAccMsg,<"Podany katalog wyszukania pliku COMMAND jest niew?a?ciwy; odmowa dost?pu",CR,LF>

        msg     Help1Msg  <"Uruchamia nowe wyst?pienie interpretera polece? MS-DOS.",CR,LF,CR,LF>
        msg     Help2Msg  <"COMMAND [[dysk:]?cie?ka] [urz?dzenie] [/E:nnnnn] [/P] [/C polecenie] [/MSG]",CR,LF,CR,LF>
        msg     Help3Msg  <"  [dysk:]?cie?ka  Okre?la katalog zawieraj?cy plik COMMAND.COM",CR,LF>
        msg     Help4Msg  <"  urz?dzenie      Okre?la urz?dzenie u?yte jako wej?cie i wyj?cie polecenia.",CR,LF>
        msg     Help5Msg  <"  /E:nnnnn        Ustawia pocz?tkowy rozmiar ?rodowiska na nnnnn bajt?w.",CR,LF>
        msg     Help6Msg  <"  /P              Ustala nowy interpreter polece? jako sta?y (wyj?cie niemo?liwe).",CR,LF>
        msg     Help7Msg  <"  /C polecenie    Wykonuje okre?lone polecenie i powraca.",CR,LF>
        msg     Help8Msg  <"  /MSG            Przechowuje wszystkie komunikaty o b??dach. Wymagany jest",CR,LF>
        msg     Help9Msg  <"                  r?wnie? parametr /P.",CR,LF>

HelpMsgs	dw	RESGROUP:Help1Msg,RESGROUP:Help2Msg
		dw	RESGROUP:Help3Msg,RESGROUP:Help4Msg
		dw	RESGROUP:Help5Msg,RESGROUP:Help6Msg
		dw	RESGROUP:Help7Msg,RESGROUP:Help8Msg
		dw	RESGROUP:Help9Msg,0

	public	HelpMsgs
