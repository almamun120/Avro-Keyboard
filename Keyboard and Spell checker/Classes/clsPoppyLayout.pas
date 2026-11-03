{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================

  Poppy Layout - keyboard handler.

  Keeps the Latin letters typed since the last word break, runs them through
  PoppyConvert (clsPoppyPhonetic.pas) after every key and replaces the text that
  was already sent with the new result (backspace + resend of the changed tail).
}

{$INCLUDE ../ProjectDefines.inc}
unit clsPoppyLayout;

interface

uses
  Classes,
  SysUtils,
  StrUtils,
  clsPoppyPhonetic,
  clsUnicodeToBijoy2000;

const
  Poppy_MaxBufferLength = 60;

type
  TPoppyLayout = class
    private
      Bijoy:       TUnicodeToBijoy2000;
      EnglishT:    string;
      PrevBanglaT: string;
      BlockLast:   Boolean;

      procedure AddStr(const Str: string);
      procedure SendDifference(const NewBanglaText: string);
      procedure DoBackspace(var Block: Boolean);
      function KeyToText(const KeyCode: Integer; const ShiftDown: Boolean): string;
    public
      constructor Create;
      destructor Destroy; override;

      function ProcessVKeyDown(const KeyCode: Integer; var Block: Boolean): string;
      procedure ProcessVKeyUP(const KeyCode: Integer; var Block: Boolean);
      procedure ResetDeadKey;
  end;

implementation

uses
  KeyboardFunctions,
  VirtualKeyCode,
  uForm1,
  clsLayout,
  uRegistrySettings;

{ TPoppyLayout }

{ =============================================================================== }

constructor TPoppyLayout.Create;
begin
  inherited;
  Bijoy := TUnicodeToBijoy2000.Create;
  EnglishT := '';
  PrevBanglaT := '';
  BlockLast := False;
end;

{ =============================================================================== }

destructor TPoppyLayout.Destroy;
begin
  FreeAndNil(Bijoy);
  inherited;
end;

{ =============================================================================== }

procedure TPoppyLayout.ResetDeadKey;
begin
  EnglishT := '';
  PrevBanglaT := '';
  BlockLast := False;
end;

{ =============================================================================== }

// Replace what is already on screen (PrevBanglaT) by NewBanglaText with the
// smallest number of backspaces.
procedure TPoppyLayout.SendDifference(const NewBanglaText: string);
var
  OldT, NewT: string;
  I, Matched: Integer;
begin
  if OutputIsBijoy = 'YES' then
  begin
    OldT := Bijoy.Convert(PrevBanglaT);
    NewT := Bijoy.Convert(NewBanglaText);
  end
  else
  begin
    OldT := PrevBanglaT;
    NewT := NewBanglaText;
  end;

  Matched := 0;
  for I := 1 to Length(OldT) do
  begin
    if (I <= Length(NewT)) and (OldT[I] = NewT[I]) then
      Inc(Matched)
    else
      Break;
  end;

  if Length(OldT) - Matched >= 1 then
    Backspace(Length(OldT) - Matched);

  if Length(NewT) > Matched then
    SendKey_Char(Copy(NewT, Matched + 1, Length(NewT) - Matched));

  PrevBanglaT := NewBanglaText;
end;

{ =============================================================================== }

procedure TPoppyLayout.AddStr(const Str: string);
begin
  if Length(EnglishT) >= Poppy_MaxBufferLength then
    ResetDeadKey;

  EnglishT := EnglishT + Str;
  SendDifference(PoppyConvert(EnglishT));
end;

{ =============================================================================== }

procedure TPoppyLayout.DoBackspace(var Block: Boolean);
begin
  if Length(EnglishT) <= 1 then
  begin
    // only one typed key is left: let the real Backspace remove the last character
    if OutputIsBijoy = 'YES' then
    begin
      if Length(Bijoy.Convert(PrevBanglaT)) - 1 >= 1 then
        Backspace(Length(Bijoy.Convert(PrevBanglaT)) - 1);
    end
    else
    begin
      if Length(PrevBanglaT) - 1 >= 1 then
        Backspace(Length(PrevBanglaT) - 1);
    end;
    ResetDeadKey;
    Block := False;
  end
  else
  begin
    Block := True;
    EnglishT := LeftStr(EnglishT, Length(EnglishT) - 1);
    SendDifference(PoppyConvert(EnglishT));
  end;
end;

{ =============================================================================== }

// Text produced by a key (Latin buffer text). '' = key is not handled here.
function TPoppyLayout.KeyToText(const KeyCode: Integer; const ShiftDown: Boolean): string;
begin
  Result := '';

  // letters: always lower case, Shift has no effect on Bangla output
  if (KeyCode >= A_Key) and (KeyCode <= Z_Key) then
  begin
    Result := Char(Ord('a') + (KeyCode - A_Key));
    Exit;
  end;

  // number pad
  if (KeyCode >= VK_NUMPAD0) and (KeyCode <= VK_NUMPAD9) then
  begin
    Result := Char(Ord('0') + (KeyCode - VK_NUMPAD0));
    Exit;
  end;

  case KeyCode of
    VK_DECIMAL:
      Result := '.';
    VK_DIVIDE:
      Result := '/';
    VK_MULTIPLY:
      Result := '*';
    VK_SUBTRACT:
      Result := '-';
    VK_ADD:
      Result := '+';

    VK_0:
      if ShiftDown then Result := ')' else Result := '0';
    VK_1:
      if ShiftDown then Result := '!' else Result := '1';
    VK_2:
      if ShiftDown then Result := '@' else Result := '2';
    VK_3:
      if ShiftDown then Result := '#' else Result := '3';
    VK_4:
      if ShiftDown then Result := '$' else Result := '4';
    VK_5:
      if ShiftDown then Result := '%' else Result := '5';
    VK_6:
      if ShiftDown then Result := '^' else Result := '6';
    VK_7:
      if ShiftDown then Result := '&' else Result := '7';
    VK_8:
      if ShiftDown then Result := '*' else Result := '8';
    VK_9:
      if ShiftDown then Result := '(' else Result := '9';

    VK_OEM_1:
      if ShiftDown then Result := ':' else Result := ';';
    VK_OEM_2:
      if ShiftDown then Result := '?' else Result := '/';
    VK_OEM_3:
      if ShiftDown then Result := '~' else Result := '`';
    VK_OEM_4:
      if ShiftDown then Result := '{' else Result := '[';
    VK_OEM_5:
      if ShiftDown then Result := '|' else Result := '\';
    VK_OEM_6:
      if ShiftDown then Result := '}' else Result := ']';
    VK_OEM_7:
      if ShiftDown then Result := '"' else Result := #39;
    VK_OEM_COMMA:
      if ShiftDown then Result := '<' else Result := ',';
    VK_OEM_MINUS:
      if ShiftDown then Result := '_' else Result := '-';
    VK_OEM_PERIOD:
      if ShiftDown then Result := '>' else Result := '.';
    VK_OEM_PLUS:
      if ShiftDown then Result := '+' else Result := '=';
  end;
end;

{ =============================================================================== }

function TPoppyLayout.ProcessVKeyDown(const KeyCode: Integer; var Block: Boolean): string;
var
  Txt: string;
begin
  Result := '';
  Block := False;

  if (IsControl = True) or (IsAlter = True) or (IsWinKey = True) then
  begin
    // shortcuts (Ctrl+V etc.) change the text behind our back
    ResetDeadKey;
    BlockLast := False;
    Exit;
  end;

  if IsIgnorableModifierKey(KeyCode) then
  begin
    BlockLast := False;
    Exit;
  end;

  if AvroMainForm1.GetMyCurrentKeyboardMode = SysDefault then
  begin
    BlockLast := False;
    Exit;
  end;

  // ---- Bangla mode ----
  case KeyCode of
    VK_SPACE, VK_RETURN, VK_TAB, VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_DELETE:
      begin
        ResetDeadKey;
        Exit;
      end;
    VK_BACK:
      begin
        DoBackspace(Block);
        BlockLast := Block;
        Exit;
      end;
  end;

  Txt := KeyToText(KeyCode, IsTrueShift);
  if Txt <> '' then
  begin
    AddStr(Txt);
    Block := True;
    BlockLast := True;
  end
  else
    BlockLast := False;
end;

{ =============================================================================== }

procedure TPoppyLayout.ProcessVKeyUP(const KeyCode: Integer; var Block: Boolean);
begin
  if IsIgnorableModifierKey(KeyCode) then
  begin
    Block := False;
    BlockLast := False;
    Exit;
  end;

  if AvroMainForm1.GetMyCurrentKeyboardMode = SysDefault then
  begin
    Block := False;
    BlockLast := False;
  end
  else if BlockLast = True then
    Block := True;
end;

{ =============================================================================== }

end.
