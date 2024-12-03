Program Advent;

Uses
  D32, Dos;

Const
  YEAR = 2024;
  SCREEN_SIZE = 4000;
  MAX_DAYS = 25;
  WELCOME_SCREEN = 'WELCOME.ANS';
  COMEBACK_SCREEN = 'COMEBACK.ANS';
  ART_FILE = 'ADVENT.DAT';

Var
  CurrentDay: Integer;

Procedure ClearScreenBuffer;
Var
  i: Integer;
Begin
  For i := 0 to 3999 do
    Mem[$B800: i] := 0;  { Clear both character and attribute bytes }
End;

Function IntToStr(Value: Integer): String;
Var
  Temp: String;
Begin
  Str(Value, Temp);  { Convert the integer to a string }
  IntToStr := Temp;
End;


Procedure DisplayCenteredDate(Y: Byte);
Var
  Year, Month, Day, Dow: Word;
  DateStr: String;
  CenterX:Byte; { Example: CenterX is a constant and holds the value 40 }
Const
  MonthNames: Array[1..12] of String[9] = (
    'January', 
    'February', 
    'March', 
    'April', 
    'May', 
    'June', 
    'July', 
    'August', 
    'September', 
    'October', 
    'November', 
    'December'
  );
  
Begin
  { Get the current date }
  GetDate(Year, Month, Day, Dow);

  { Format the date string }
  DateStr := MonthNames[Month] + ' ' + IntToStr(Day) + ', ' + IntToStr(Year);

  { Calculate the X position to center the string }
  CenterX := (80 - Length(DateStr)) Div 2;

  { Position the cursor and write the date }
  ansi_GotoXY(CenterX, Y);
  SendLn('|10' + DateStr); { |10 sets light green color, modify as needed }
End;

Procedure DisplayComebackScreen(Y: Byte);
Var
  Year, Month, Day, Dow: Word;
  DateStr, Message: String;
  CenterX: Byte;
Const
  MonthNames: Array[1..12] of String[9] = (
    'January', 
    'February', 
    'March', 
    'April', 
    'May', 
    'June', 
    'July', 
    'August', 
    'September', 
    'October', 
    'November', 
    'December'
  );
Begin
  { Get the current date }
  GetDate(Year, Month, Day, Dow);

  If (Month = 12) And (Day < 25) Then
  Begin
    { Tomorrow's Art }
    DateStr := MonthNames[Month] + ' ' + IntToStr(Day + 1) + ', ' + IntToStr(Year);
    Message := 'Tomorrow: ' + DateStr;
  End
  Else If (Month = 12) And (Day >= 25) Then
  Begin
    { See you next year! }
    Message := 'See you next year!';
  End
  Else
  Begin
    { Out of Advent season }
    Message := 'Advent Calendar is only active in December.';
  End;

  { Calculate the X position to center the string }
  CenterX := (80 - Length(Message)) Div 2;

  { Position the cursor and write the message }
  ansi_GotoXY(CenterX, Y);
  SendLn('|10' + Message); { |10 sets light green color, modify as needed }
End;



Procedure DisplayWelcomeScreen;
Begin
  SendCLS;
  If Not FExist(WELCOME_SCREEN) Then
  Begin
    SendLn('|04Error: WELCOME.ANS file not found.|CR');
    Exit;
  End;
  SendFile(WELCOME_SCREEN, False); { Display the welcome screen }
  DisplayCenteredDate(21); { Show the date centered on row 21 }
End;


Procedure DisplayDay(Day: Integer);
Const
  ROWS_TO_DISPLAY = 24;          { Limit display to the first 24 rows }
  COLUMNS_PER_ROW = 80;          { Each row has 80 characters }
  BYTES_PER_ROW = COLUMNS_PER_ROW * 2; { Each character requires 2 bytes (char + attribute) }
  MAX_DISPLAY_BYTES = ROWS_TO_DISPLAY * BYTES_PER_ROW; { 24 rows * 80 columns * 2 bytes = 3840 bytes }
Var
  Offset: LongInt;
  Buffer: Array[1..SCREEN_SIZE] of Byte;
  ArtFile: File;
  BytesRead: Word;
Begin
  Assign(ArtFile, ART_FILE);
  {$I-}
  Reset(ArtFile, 1);
  If IOResult <> 0 Then
  Begin
    SendLn('|04Error: Unable to open ADVENT.DAT.|CR');
    Exit;
  End;
  {$I+}

  Offset := (Day - 1) * SCREEN_SIZE;
  Seek(ArtFile, Offset);
  BlockRead(ArtFile, Buffer, SCREEN_SIZE, BytesRead);

  If BytesRead < MAX_DISPLAY_BYTES Then
  Begin
    SendLn('|04Error: Art for day ' + IntToStr(Day) + ' is incomplete.|CR');
    Close(ArtFile);
    Exit;
  End;

  Close(ArtFile);

  { Clear only the first 24 rows (3840 bytes) of screen memory, avoiding row 25 }
  FillChar(Mem[$B800:0000], MAX_DISPLAY_BYTES, 0);

  { Display only the first 24 rows (3840 bytes) }
  Move(Buffer, Mem[$B800:0000], MAX_DISPLAY_BYTES);

End;

procedure CursorOff;
var
  regs: registers;
begin
  regs.ah := $01;
  regs.cx := $2000;
  Intr($10, regs);
end;

procedure CursorOn;
var
  regs: registers;
begin
  regs.ah := $01;
  regs.cx := $0607;
  Intr($10, regs);
end;

Function AdventDay: Integer;
Var
  Year, Month, Day, Dow: Word;
Begin
  GetDate(Year, Month, Day, Dow);
  If (Year = YEAR) And (Month = 12) Then AdventDay := Day
  Else AdventDay := 0; { Return 0 if not December }
End;

Procedure NavigateDays;
Var
  Ch: Char;
  LastDay: Integer;
Begin
  LastDay := -1; { Track the last displayed day to prevent unnecessary reloads }
  Repeat
    { Display the appropriate screen only if CurrentDay changes }
    If CurrentDay <> LastDay Then
    Begin
      SendCLS;
      If CurrentDay = 0 Then
        DisplayWelcomeScreen
      Else If (CurrentDay >= 1) And (CurrentDay <= AdventDay) Then
        DisplayDay(CurrentDay)
      Else If CurrentDay = AdventDay + 1 Then
      Begin
        If FExist(COMEBACK_SCREEN) Then
        Begin
          SendFile(COMEBACK_SCREEN, False);
          DisplayComebackScreen(21); { Ensure this line is included in the block }
        End
        Else
        Begin
          SendLn('|04Error: COMEBACK.ANS file not found.|CR');
        End;
      End;
      LastDay := CurrentDay; { Update the last displayed day }
    End;

    { Wait for user input }
    Ch := GetKey;

    { Handle navigation keys }
    If IsArrowKey Then
    Begin
      If (Ch = #75) And (CurrentDay > 0) Then  { Left Arrow }
        Dec(CurrentDay)
      Else If (Ch = #77) And (CurrentDay < AdventDay + 1) Then { Right Arrow }
        Inc(CurrentDay);
    End
    Else If (Ch = #27) Or (Ch = 'Q') Or (Ch = 'q') Then
    Begin
      CloseDOOR;
      Halt; { Exit the program }
    End;
  Until False;
End;

Procedure StartAdventCalendar;
Var
  Today: Integer;
Begin
  Today := AdventDay;
  If Today = 0 Then
  Begin
    SendLn('|04Come back on December 1st, ' + Int2Str(YEAR) + '!|CR');
    Exit;
  End;

  CurrentDay := Today;
  NavigateDays; 
End;

Procedure RunWelcomeScreen;
Var
  Ch: Char;
Begin
  While True Do
  Begin
    CursorOff;
    DisplayWelcomeScreen;

    While True Do
    Begin
      If KeyWaiting Then
      Begin
        Ch := GetKey;
    
        If (Ch = #77) Then Break; { Right Arrow starts the calendar }
        If (Ch = #27) Or (Ch = 'Q') Or (Ch = 'q') Then Halt; { Quit on ESC/Q }
      End;
    End;

    StartAdventCalendar;
    { If user exits the calendar with Left Arrow, return to Welcome Screen }
  End;
End;

Var
  Res: Byte;
Begin

  If ParamCount <> 1 Then
  Begin
    WriteLn;
    WriteLn('Advent: Mistigris Advent Calendar Door');
    WriteLn('Syntax: Advent <Path to drop file>');
    Halt;
  End;

  Res := OpenDOOR(ParamStr(1));

  Case Res of
    1: WriteLn('|04ERROR: Drop file not found.');
    2: WriteLn('|04ERROR: Error reading drop file');
    3: WriteLn('|04ERROR: Unknown drop file type');
    4: WriteLn('|04ERROR: Unable to open communications port');
  End;

  If Res <> 0 Then Halt;

  CursorOff;
  RunWelcomeScreen;
  CursorOn;

  CloseDOOR;
End.
