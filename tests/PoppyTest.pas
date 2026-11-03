{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}
program PoppyTest;

{ Console test for the Poppy Layout engine (clsPoppyPhonetic.pas).

  Usage:  PoppyTest <path to typing_cases.tsv>
  Every line of the file is  <typed latin text> TAB <expected bangla text>.
  Exit code 0 = all cases pass.

  Built and run by .github/workflows/build.yml with Free Pascal. }

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  clsPoppyPhonetic;

function Dump(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 4) + ' ';
end;

var
  Lines: TStringList;
  Stream: TFileStream;
  Raw: RawByteString;
  I, P, Total, Fail: Integer;
  Line, Typed, Expected, Got: string;
begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: PoppyTest typing_cases.tsv');
    Halt(2);
  end;

  Total := 0;
  Fail := 0;
  Lines := TStringList.Create;
  try
    // read raw bytes and decode UTF-8 ourselves (independent of TStringList encoding rules)
    Stream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Raw, Stream.Size);
      if Stream.Size > 0 then
        Stream.ReadBuffer(Raw[1], Stream.Size);
    finally
      Stream.Free;
    end;
    Lines.Text := UTF8Decode(Raw);
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      Line := StringReplace(Line, #13, '', [rfReplaceAll]);
      if Trim(Line) = '' then
        Continue;
      P := Pos(#9, Line);
      if P = 0 then
        Continue;
      Typed := Copy(Line, 1, P - 1);
      Expected := Copy(Line, P + 1, Length(Line));
      Inc(Total);
      Got := PoppyConvert(Typed);
      if Got <> Expected then
      begin
        Inc(Fail);
        WriteLn('FAIL  typed=', Typed);
        WriteLn('      got      : ', Dump(Got));
        WriteLn('      expected : ', Dump(Expected));
      end;
    end;
  finally
    Lines.Free;
  end;

  WriteLn(Total, ' cases, ', Fail, ' failed');
  if (Fail > 0) or (Total = 0) then
    Halt(1);
end.
