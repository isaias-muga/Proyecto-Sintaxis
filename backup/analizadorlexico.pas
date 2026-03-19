UNIT AnalizadorLexico;

{$mode objfpc}{$H+}

INTERFACE

USES
  Classes, SysUtils;

  { --- TIPOS PÚBLICOS --- }
  { Aquí definiremos los tipos de tokens que el resto del programa puede ver }
TYPE
  TTipoToken = (
    TOKEN_ERROR,
    TOKEN_EOF,

    { Tipos de Datos }
    TOKEN_ID,
    TOKEN_ENTERO,
    TOKEN_REAL,
    TOKEN_STRING,     { Para cadenas entre comillas "..." }

    TOKEN_PROGRAM,
    TOKEN_VAR,        { Para declarar variables }
    TOKEN_BEGIN,
    TOKEN_END,
    TOKEN_IF,
    TOKEN_THEN,
    TOKEN_ELSE,
    TOKEN_WHILE,
    TOKEN_DO,
    TOKEN_READ,
    TOKEN_WRITE,
    TOKEN_TYPE_REAL,  { La palabra 'real' en declaraciones }
    TOKEN_TYPE_MATRIX, { La palabra 'matrix' en declaraciones }
    TOKEN_MAS,          { + }
    TOKEN_MENOS,        { - }
    TOKEN_POR,          { * }
    TOKEN_DIV,          { / }
    TOKEN_ASIG,         { := }
    TOKEN_IGUAL,        { = o == }
    TOKEN_DISTINTO,     { <> o != }
    TOKEN_MENOR,        { < }
    TOKEN_MAYOR,        { > }
    TOKEN_MENOR_IGUAL,  { <= }
    TOKEN_MAYOR_IGUAL,  { >= }
    TOKEN_PAREN_IZQ,    { ( }
    TOKEN_PAREN_DER,    { ) }
    TOKEN_COR_IZQ,      { [ }
    TOKEN_COR_DER,      { ] }
    TOKEN_COMA,         { , }
    TOKEN_PUNTO_COMA,   { ; }
    TOKEN_DOS_PUNTOS,   { : }
    TOKEN_PUNTO,        { . }
    TOKEN_LLAVE_IZQ,
    TOKEN_LLAVE_DER
    );

  { --- VARIABLES PÚBLICAS --- }
VAR
  ArchivoFuente: TextFile;
  LineaActual: INTEGER = 1; { Para reportar errores }

  { --- FUNCIONES PÚBLICAS --- }
  { Estas son las que el programa principal podrá llamar }

{ Abre el archivo fuente para empezar a leer }
PROCEDURE InicializarLexico(RutaArchivo: STRING);

{ Cierra el archivo al terminar }
PROCEDURE FinalizarLexico;

FUNCTION EscanearNumero(VAR Lexema: STRING): TTipoToken;

{ La función estrella: devuelve el siguiente token encontrado }
FUNCTION ObtenerSiguienteToken(VAR Lexema: STRING): TTipoToken;



IMPLEMENTATION

{ --- VARIABLES PRIVADAS --- }
VAR
  LineaActualStr: STRING = '';   { El contenido completo de la línea actual }
  PosicionActual: INTEGER = 1;   { Nuestra posición en LineaActualStr (empezando en 1) }
  FinDeArchivo: BOOLEAN = False; { Indica si ya no hay más líneas }
  CaracterActual: CHAR = ' ';

  { --- FUNCIONES PRIVADAS (Helpers) --- }

{ Lee el siguiente carácter del archivo y lo guarda en CaracterActual }
{ Lee el siguiente carácter usando el buffer de línea }
{ Lee el siguiente carácter usando el buffer de línea }
PROCEDURE LeerSiguienteCaracter;
BEGIN
  IF FinDeArchivo THEN
  BEGIN
    CaracterActual := #0;
    Exit;
  END;

  { Si nos pasamos del final de la línea actual, intentamos leer la siguiente }
  IF PosicionActual > Length(LineaActualStr) THEN
  BEGIN
    IF EOF(ArchivoFuente) THEN
    BEGIN
      FinDeArchivo := True;
      CaracterActual := #0;
      { Truco: agregamos un salto de línea virtual al final del archivo
        para que el último token se procese correctamente si no hay un enter al final }
      IF (Length(LineaActualStr) > 0) and
        (LineaActualStr[Length(LineaActualStr)] <> #10) THEN
        CaracterActual := #10
      ELSE
        Exit;
    END
    ELSE
    BEGIN
      ReadLn(ArchivoFuente, LineaActualStr);
      LineaActualStr := LineaActualStr + #10; { Agregamos el \n que ReadLn quita }
      Inc(LineaActual);
      PosicionActual := 1;
    END;
  END;

  { Si después de intentar leer nueva línea seguimos en fin de archivo, salimos }
  IF FinDeArchivo and (CaracterActual = #0) THEN Exit;

  { Leemos el carácter de la posición actual en el buffer }
  CaracterActual := LineaActualStr[PosicionActual];
  Inc(PosicionActual);
END;
{ Salta espacios en blanco, tabs y saltos de línea }
PROCEDURE SaltarBlancos;
BEGIN
  WHILE (not FinDeArchivo) and (CaracterActual in [#9, #10, #13, ' ']) DO
    LeerSiguienteCaracter;
END;

{ --- IMPLEMENTACIÓN DE FUNCIONES PÚBLICAS --- }

PROCEDURE InicializarLexico(RutaArchivo: STRING);
BEGIN
  AssignFile(ArchivoFuente, RutaArchivo);
  Reset(ArchivoFuente);
  LineaActual := 0; { Empezamos en 0 porque LeerSiguienteCaracter incrementará a 1 }
  PosicionActual := 1;
  LineaActualStr := '';     { Buffer vacío al inicio }
  FinDeArchivo := False;

  { Leemos el primer carácter para arrancar el proceso }
  LeerSiguienteCaracter;
END;

PROCEDURE FinalizarLexico;
BEGIN
  CloseFile(ArchivoFuente);
END;
{ Intenta leer una Constante Real desde la posición actual }
FUNCTION EsConstanteReal(VAR Lexema: STRING): BOOLEAN;
VAR
  PuntoEncontrado: BOOLEAN;
  TieneDecimales: BOOLEAN;
  TempLexema: STRING;
BEGIN
  { Guardamos el estado inicial por si tenemos que "rebobinar" (conceptual) }
  TempLexema := '';
  PuntoEncontrado := False;
  TieneDecimales := False;

  { 1. Debe empezar con dígito }
  IF not (CaracterActual in ['0'..'9']) THEN Exit(False);

  { 2. Leer parte entera }
  WHILE CaracterActual in ['0'..'9'] DO
  BEGIN
    TempLexema := TempLexema + CaracterActual;
    LeerSiguienteCaracter;
  END;

  { 3. ¿Sigue un punto? }
  IF CaracterActual = '.' THEN
  BEGIN
    PuntoEncontrado := True;
    TempLexema := TempLexema + CaracterActual;
    LeerSiguienteCaracter;

    { 4. Debe seguir al menos un dígito decimal }
    IF not (CaracterActual in ['0'..'9']) THEN
    BEGIN
       { ERROR: Tenemos "123." pero no sigue un dígito.
         Esto NO es un real válido según nuestra definición.
         PERO cuidado: ya "consumimos" el punto. Esto es complejo.
         Por ahora, simplifiquemos: si falla aquí, NO es real. }
      Exit(False);
       { NOTA PRO: En un lexer real, aquí deberíamos "devolver" el punto
         al input y aceptar "123" como entero. Por ahora, asumamos
         que el usuario no escribe cosas raras como "123.abc" }
    END;

    { 5. Leer resto de decimales }
    WHILE CaracterActual in ['0'..'9'] DO
    BEGIN
      TieneDecimales := True;
      TempLexema := TempLexema + CaracterActual;
      LeerSiguienteCaracter;
    END;
  END;

  { Si llegamos aquí, ¿es un real válido? }
  IF PuntoEncontrado and TieneDecimales THEN
  BEGIN
    Lexema := TempLexema;
    Result := True;
  END
  ELSE
  BEGIN
    { Si leímos solo dígitos y no hubo punto, NO es un REAL, es un ENTERO.
      Así que devolvemos False para que otra función lo intente.
      ¡PROBLEMA! Ya consumimos los caracteres. }
    Result := False;
  END;
END;

FUNCTION EscanearNumero(VAR Lexema: STRING): TTipoToken;
VAR
  EsReal: BOOLEAN;
BEGIN
  Lexema := '';
  EsReal := False;

  { 1. Leer parte entera (sabemos que empieza con dígito por el Despachador) }
  WHILE CaracterActual in ['0'..'9'] DO
  BEGIN
    Lexema := Lexema + CaracterActual;
    LeerSiguienteCaracter;
  END;

  { 2. ¿Sigue un punto decimal? }
  IF CaracterActual = '.' THEN
  BEGIN
    { Cuidado: podría ser un punto final de sentencia (si tu lenguaje lo usara).
      Pero asumiremos que '.' siempre intenta ser un real. }

    { Es un candidato a REAL. Consumimos el punto. }
    Lexema := Lexema + CaracterActual;
    LeerSiguienteCaracter;

    { 3. DEBE seguir al menos un dígito para ser un real válido }
    IF CaracterActual in ['0'..'9'] THEN
    BEGIN
      EsReal := True;
      WHILE CaracterActual in ['0'..'9'] DO
      BEGIN
        Lexema := Lexema + CaracterActual;
        LeerSiguienteCaracter;
      END;
    END
    ELSE
    BEGIN
      { ERROR: Tenemos "123." y no sigue un dígito.
        Según nuestra ER, esto es inválido. }
      Result := TOKEN_ERROR;
      Exit;
    END;
  END;

  { 4. Devolver el token correcto }
  IF EsReal THEN
    Result := TOKEN_REAL
  ELSE
    Result := TOKEN_ENTERO;
END;

FUNCTION EscanearIdentificador(VAR Lexema: STRING): TTipoToken;
VAR
  LexemaLower: STRING;
BEGIN
  Lexema := '';

  { 1. Leer el identificador completo }
  { Sabemos que empieza con letra o '_' por el despachador }
  WHILE CaracterActual in ['a'..'z', 'A'..'Z', '0'..'9', '_'] DO
  BEGIN
    Lexema := Lexema + CaracterActual;
    LeerSiguienteCaracter;
  END;

  { 2. Verificar si es Palabra Reservada }
  { Convertimos a minúsculas para que sea case-insensitive (opcional, pero recomendado) }
  LexemaLower := LowerCase(Lexema);

  IF LexemaLower = 'program' THEN Exit(TOKEN_PROGRAM)
  ELSE IF LexemaLower = 'var' THEN Exit(TOKEN_VAR)
  ELSE IF LexemaLower = 'begin' THEN Exit(TOKEN_BEGIN)
  ELSE IF LexemaLower = 'end' THEN Exit(TOKEN_END)
  ELSE IF LexemaLower = 'if' THEN Exit(TOKEN_IF)
  ELSE IF LexemaLower = 'then' THEN Exit(TOKEN_THEN)
  ELSE IF LexemaLower = 'else' THEN Exit(TOKEN_ELSE)
  ELSE IF LexemaLower = 'while' THEN Exit(TOKEN_WHILE)
  ELSE IF LexemaLower = 'do' THEN Exit(TOKEN_DO)
  ELSE IF LexemaLower = 'read' THEN Exit(TOKEN_READ)
  ELSE IF LexemaLower = 'write' THEN Exit(TOKEN_WRITE)
  ELSE IF LexemaLower = 'real' THEN Exit(TOKEN_TYPE_REAL)
  ELSE IF LexemaLower = 'matrix' THEN Exit(TOKEN_TYPE_MATRIX)

  { Si no es ninguna de las anteriores, es un Identificador normal }
  ELSE
    Result := TOKEN_ID;
END;

FUNCTION ObtenerSiguienteToken(VAR Lexema: STRING): TTipoToken;
BEGIN
  SaltarBlancos; { Ignoramos espacios, tabs y saltos de línea }

  Lexema := '';

  IF FinDeArchivo and (CaracterActual = #0) THEN
    Exit(TOKEN_EOF);

  { --- DESPACHADOR CENTRAL --- }
  CASE CaracterActual OF
    'A'..'Z', 'a'..'z', '_':
      Result := EscanearIdentificador(Lexema);

    '0'..'9':
      Result := EscanearNumero(Lexema);

    { --- SÍMBOLOS SIMPLES --- }
    '+': BEGIN
      Lexema := '+';
      Result := TOKEN_MAS;
      LeerSiguienteCaracter;
    END;
    '-': BEGIN
      Lexema := '-';
      Result := TOKEN_MENOS;
      LeerSiguienteCaracter;
    END;
    '*': BEGIN
      Lexema := '*';
      Result := TOKEN_POR;
      LeerSiguienteCaracter;
    END;
    '/': BEGIN
      Lexema := '/';
      Result := TOKEN_DIV;
      LeerSiguienteCaracter;
    END;
    '(': BEGIN
      Lexema := '(';
      Result := TOKEN_PAREN_IZQ;
      LeerSiguienteCaracter;
    END;
    ')': BEGIN
      Lexema := ')';
      Result := TOKEN_PAREN_DER;
      LeerSiguienteCaracter;
    END;
    '[': BEGIN
      Lexema := '[';
      Result := TOKEN_COR_IZQ;
      LeerSiguienteCaracter;
    END;
    ']': BEGIN
      Lexema := ']';
      Result := TOKEN_COR_DER;
      LeerSiguienteCaracter;
    END;
    '{': BEGIN
      Lexema := '{';
      Result := TOKEN_LLAVE_IZQ;
      LeerSiguienteCaracter;
    END;
    '}': BEGIN
      Lexema := '}';
      Result := TOKEN_LLAVE_DER;
      LeerSiguienteCaracter;
    END;
    ',': BEGIN
      Lexema := ',';
      Result := TOKEN_COMA;
      LeerSiguienteCaracter;
    END;
    ';': BEGIN
      Lexema := ';';
      Result := TOKEN_PUNTO_COMA;
      LeerSiguienteCaracter;
    END;
    '.': BEGIN
      Lexema := '.';
      Result := TOKEN_PUNTO;
      LeerSiguienteCaracter;
    END;

    { --- SÍMBOLOS COMPLEJOS --- }
    ':':
    BEGIN
      LeerSiguienteCaracter;
      IF CaracterActual = '=' THEN
      BEGIN
        Lexema := ':=';
        Result := TOKEN_ASIG;
        LeerSiguienteCaracter;
      END
      ELSE
      BEGIN
        Lexema := ':';
        Result := TOKEN_DOS_PUNTOS;
      END;
    END;

    '<':
    BEGIN
      LeerSiguienteCaracter;
      IF CaracterActual = '=' THEN
      BEGIN
        Lexema := '<=';
        Result := TOKEN_MENOR_IGUAL;
        LeerSiguienteCaracter;
      END
      ELSE IF CaracterActual = '>' THEN
      BEGIN
        Lexema := '<>';
        Result := TOKEN_DISTINTO;
        LeerSiguienteCaracter;
      END
      ELSE
      BEGIN
        Lexema := '<';
        Result := TOKEN_MENOR;
      END;
    END;

    '>':
    BEGIN
      LeerSiguienteCaracter;
      IF CaracterActual = '=' THEN
      BEGIN
        Lexema := '>=';
        Result := TOKEN_MAYOR_IGUAL;
        LeerSiguienteCaracter;
      END
      ELSE
      BEGIN
        Lexema := '>';
        Result := TOKEN_MAYOR;
      END;
    END;

    '=': { Agregado para comparaciones de igualdad (== o =) }
    BEGIN
      Lexema := '=';
      Result := TOKEN_IGUAL;
      LeerSiguienteCaracter;
      { Si tu lenguaje usa '==' para igualdad, aquí añadirías un chequeo extra }
    END;

    ELSE
    BEGIN
      { --- CASO DE ERROR / CARÁCTER DESCONOCIDO --- }
      { Muy importante: consumirlo para no quedarnos trabados }
      Lexema := CaracterActual;
      Result := TOKEN_ERROR;
      LeerSiguienteCaracter;
    END;
  END; { case }
END;

END.
