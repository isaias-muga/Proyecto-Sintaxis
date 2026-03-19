PROGRAM Interprete;

{$mode objfpc}{$H+}

USES
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes,
  SysUtils,
  TypInfo,
  AnalizadorLexico;

VAR
  Token: TTipoToken;
  Lexema: STRING;

BEGIN


  WriteLn('--- Iniciando Analizador Lexico ---');

  Lexema := '';

  TRY
    InicializarLexico('programa.txt');

    REPEAT
      Token := ObtenerSiguienteToken(Lexema);
      WriteLn('Token encontrado: ', GetEnumName(TypeInfo(TTipoToken), Ord(Token)));
    UNTIL Token = TOKEN_EOF;

    FinalizarLexico;

  EXCEPT
    on E: Exception DO
      WriteLn('Error: ' + E.Message);
  END;

  WriteLn('--- Fin del Analisis ---');
  ReadLn;
END.
