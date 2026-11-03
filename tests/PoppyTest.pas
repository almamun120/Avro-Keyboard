{$MODE OBJFPC}{$H+}
program PoppyTest;

{ Console test for the Poppy Layout engine (clsPoppyPhonetic.pas).

  Usage:  PoppyTest <path to typing_cases.tsv>
  Every line of the file is  <typed latin text> TAB <expected bangla text, UTF-8>.
  Exit code 0 = all cases pass.

  Built and run by .github/workflows/build.yml with Free Pascal.
  File reading and UTF-8 decoding are done by hand with explicit string types,
  so the result does not depend on compiler string-mode defaults. }

uses
  SysUtils,
  Classes,
  clsPoppyPhonetic;

function Dump(const S: UnicodeString): AnsiString;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 4) + ' ';
end;

var
  Stream: TFileStream;
  Raw, RawLine, RawTyped, RawExpected: RawByteString;
  Pos1, PosTab, Total, Fail: Integer;
  Typed, Expected, Got: UnicodeString;
begin
  if ParamCount < 1 then
  begin
    WriteLn('usage: PoppyTest typing_cases.tsv');
    Halt(2);
  end;

  Stream := TFileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Raw, Stream.Size);
    if Stream.Size > 0 then
      Stream.ReadBuffer(Raw[1], Stream.Size);
  finally
    Stream.Free;
  end;

  Total := 0;
  Fail := 0;
  while Length(Raw) > 0 do
  begin
    Pos1 := System.Pos(#10, Raw);
    if Pos1 = 0 then
    begin
      RawLine := Raw;
      Raw := '';
    end
    else
    begin
      RawLine := Copy(Raw, 1, Pos1 - 1);
      Raw := Copy(Raw, Pos1 + 1, Length(Raw));
    end;
    if (Length(RawLine) > 0) and (RawLine[Length(RawLine)] = #13) then
      SetLength(RawLine, Length(RawLine) - 1);

    PosTab := System.Pos(#9, RawLine);
    if PosTab = 0 then
      Continue;
    RawTyped := Copy(RawLine, 1, PosTab - 1);
    RawExpected := Copy(RawLine, PosTab + 1, Length(RawLine));
    Typed := UnicodeString(AnsiString(RawTyped));   // typed text is plain ASCII
    Expected := UTF8Decode(RawExpected);
    Inc(Total);

    Got := PoppyConvert(Typed);
    if Got <> Expected then
    begin
      Inc(Fail);
      WriteLn('FAIL  typed=', RawTyped);
      WriteLn('      got      : ', Dump(Got));
      WriteLn('      expected : ', Dump(Expected));
    end;
  end;

  WriteLn(Total, ' cases, ', Fail, ' failed');
  if (Fail > 0) or (Total = 0) then
    Halt(1);
end.
