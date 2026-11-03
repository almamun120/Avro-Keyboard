{
  =============================================================================
  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.
  =============================================================================

  Poppy Layout - phonetic typing engine (Latin letters -> Bangla).

  This unit is intentionally free of any VCL / Windows dependency so that it can
  be compiled and unit-tested on its own (see tests/PoppyTest.pas, which is run
  by the GitHub workflow with Free Pascal).

  The whole source file is plain ASCII: every Bangla character is written as a
  code point (#$09XX), so file encoding can never corrupt it.

  Rules (all letters are treated as lower case; Shift never changes the output):
    vowels      o a i ii u uu rrr e oi oo ou
    consonants  k kh g gh qng c ch j jh qn tt tth dd ddh nn t th d dh n p f ph
                b bh v m y z r l s ss sss h x rr rrh
    signs       ng = ANUSVARA, qw = VISARGA, qq = CHANDRABINDU, qt = KHANDA TA,
                qk = TAKA, '.' = DARI, 0-9 = Bangla digits, ',,' = HASANTA+ZWNJ
    w           ba-phala after a consonant, otherwise the vowel O
    b           always an independent BA (never joins)
    q           break marker (see docs/PoppyLayout.md)
}

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}
{$ENDIF}
unit clsPoppyPhonetic;

interface

const
  POPPY_LAYOUT_NAME = 'poppy*';

  { Latin buffer -> Bangla text (final text, no markers). }
function PoppyConvert(const Input: string): string;

{ True when the layout identifier means the built-in Poppy layout. }
function IsPoppyLayoutName(const LayoutName: string): Boolean;

implementation

uses
  SysUtils;

const
  HASANTA = #$09CD;
  ZWNJ    = #$200C;
  ZWJ     = #$200D;
  NUKTA   = #$09BC;

  BN_RA = #$09B0;
  BN_BA = #$09AC;
  BN_YA = #$09AF; // YA (the one used for ya-phala)
  BN_NA = #$09A8;
  BN_NNA = #$09A3;
  BN_VISARGA = #$0983;
  BN_ANUSVARA = #$0982;
  BN_CANDRABINDU = #$0981;
  BN_KHANDA_TA = #$09CE;
  BN_TAKA = #$09F3;
  BN_DARI = #$0964;
  BN_VOWEL_O = #$0993;

type
  TConsEntry = record
    Tok: string;
    Bn:  string;
  end;

  TVowelEntry = record
    Tok:   string;
    Indep: string;
    Kar:   string;
  end;

const
  ConsCount = 38;
  Consonants: array [0 .. ConsCount - 1] of TConsEntry = (
    (Tok: 'k'; Bn: #$0995),
    (Tok: 'kh'; Bn: #$0996),
    (Tok: 'g'; Bn: #$0997),
    (Tok: 'gh'; Bn: #$0998),
    (Tok: 'qng'; Bn: #$0999),
    (Tok: 'c'; Bn: #$099A),
    (Tok: 'ch'; Bn: #$099B),
    (Tok: 'j'; Bn: #$099C),
    (Tok: 'jh'; Bn: #$099D),
    (Tok: 'qn'; Bn: #$099E),
    (Tok: 'tt'; Bn: #$099F),
    (Tok: 'tth'; Bn: #$09A0),
    (Tok: 'dd'; Bn: #$09A1),
    (Tok: 'ddh'; Bn: #$09A2),
    (Tok: 'nn'; Bn: #$09A3),
    (Tok: 't'; Bn: #$09A4),
    (Tok: 'th'; Bn: #$09A5),
    (Tok: 'd'; Bn: #$09A6),
    (Tok: 'dh'; Bn: #$09A7),
    (Tok: 'n'; Bn: #$09A8),
    (Tok: 'p'; Bn: #$09AA),
    (Tok: 'f'; Bn: #$09AB),
    (Tok: 'ph'; Bn: #$09AB),
    (Tok: 'b'; Bn: #$09AC),
    (Tok: 'bh'; Bn: #$09AD),
    (Tok: 'v'; Bn: #$09AD),
    (Tok: 'm'; Bn: #$09AE),
    (Tok: 'y'; Bn: #$09AF#$09BC),
    (Tok: 'z'; Bn: #$09AF),
    (Tok: 'r'; Bn: #$09B0),
    (Tok: 'l'; Bn: #$09B2),
    (Tok: 's'; Bn: #$09B8),
    (Tok: 'ss'; Bn: #$09B6),
    (Tok: 'sss'; Bn: #$09B7),
    (Tok: 'h'; Bn: #$09B9),
    (Tok: 'x'; Bn: #$0995#$09CD#$09B7),
    (Tok: 'rr'; Bn: #$09A1#$09BC),
    (Tok: 'rrh'; Bn: #$09A2#$09BC)
    );

  VowelCount = 11;
  Vowels: array [0 .. VowelCount - 1] of TVowelEntry = (
    (Tok: 'o'; Indep: #$0985; Kar: ''),
    (Tok: 'a'; Indep: #$0986; Kar: #$09BE),
    (Tok: 'i'; Indep: #$0987; Kar: #$09BF),
    (Tok: 'ii'; Indep: #$0988; Kar: #$09C0),
    (Tok: 'u'; Indep: #$0989; Kar: #$09C1),
    (Tok: 'uu'; Indep: #$098A; Kar: #$09C2),
    (Tok: 'rrr'; Indep: #$098B; Kar: #$09C3),
    (Tok: 'e'; Indep: #$098F; Kar: #$09C7),
    (Tok: 'oi'; Indep: #$0990; Kar: #$09C8),
    (Tok: 'oo'; Indep: #$0993; Kar: #$09CB),
    (Tok: 'ou'; Indep: #$0994; Kar: #$09CC)
    );

  BanglaDigits: array [0 .. 9] of Char = (#$09E6, #$09E7, #$09E8, #$09E9, #$09EA, #$09EB, #$09EC, #$09ED, #$09EE, #$09EF);

  { =============================================================================== }

function IsPoppyLayoutName(const LayoutName: string): Boolean;
begin
  Result := LowerCase(LayoutName) = POPPY_LAYOUT_NAME;
end;

{ =============================================================================== }

function FindConsonant(const Tok: string; out BnText: string): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 0 to ConsCount - 1 do
    if Consonants[K].Tok = Tok then
    begin
      BnText := Consonants[K].Bn;
      Result := True;
      Exit;
    end;
end;

{ =============================================================================== }

function FindVowel(const Tok: string; out Indep, Kar: string): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 0 to VowelCount - 1 do
    if Vowels[K].Tok = Tok then
    begin
      Indep := Vowels[K].Indep;
      Kar := Vowels[K].Kar;
      Result := True;
      Exit;
    end;
end;

{ =============================================================================== }

function StartsAt(const S, Sub: string; const At: Integer): Boolean;
begin
  Result := Copy(S, At, Length(Sub)) = Sub;
end;

{ =============================================================================== }

function IsLowerLatin(const C: Char): Boolean;
begin
  Result := (C >= 'a') and (C <= 'z');
end;

{ =============================================================================== }

// last output char is a plain RA (not already the second half of a conjunct)
function EndsWithPlainRa(const S: string): Boolean;
var
  L: Integer;
begin
  L := Length(S);
  Result := (L >= 1) and (S[L] = BN_RA) and ((L < 2) or (S[L - 1] <> HASANTA));
end;

{ =============================================================================== }

function PoppyConvert(const Input: string): string;
var
  Src, Res, Tok, CV, VIndep, VKar: string;
  I, N, Len, J, L:                 Integer;
  C, Last:                         Char;
  ConsAfter, WordStart:            Boolean;
  RaInitial, WasRaInitial:         Boolean;
  QBreak, WasQBreak:               Boolean;
  NasalQ, Matched, StartsWord:     Boolean;
begin
  // only A-Z are lower-cased (length is unchanged)
  Src := Input;
  for J := 1 to Length(Src) do
    if (Src[J] >= 'A') and (Src[J] <= 'Z') then
      Src[J] := Char(Ord(Src[J]) + 32);

  Res := '';
  ConsAfter := False;
  WordStart := True;
  RaInitial := False;
  QBreak := False;
  N := Length(Src);
  I := 1;

  while I <= N do
  begin
    C := Src[I];
    WasRaInitial := RaInitial;
    RaInitial := False;
    WasQBreak := QBreak;
    QBreak := False;

    // HASANTA + ZWNJ  ( ,, )
    if (C = ',') and StartsAt(Src, ',,', I) then
    begin
      Res := Res + HASANTA + ZWNJ;
      ConsAfter := False;
      WordStart := False;
      Inc(I, 2);
      Continue;
    end;

    // qn = NYA, but after NA / NNA the q is only a break marker
    NasalQ := False;
    if StartsAt(Src, 'qn', I) then
    begin
      NasalQ := True;
      if ConsAfter and (Res <> '') then
      begin
        Last := Res[Length(Res)];
        if (Last = BN_NA) or (Last = BN_NNA) then
          NasalQ := False;
      end;
    end;

    if (C = 'q') and (not NasalQ) then
    begin
      // qw = VISARGA
      if StartsAt(Src, 'qw', I) then
      begin
        Res := Res + BN_VISARGA;
        ConsAfter := False;
        WordStart := False;
        Inc(I, 2);
        Continue;
      end;

      // qr = RA without joining
      if StartsAt(Src, 'qr', I) then
      begin
        Res := Res + BN_RA;
        ConsAfter := True;
        WordStart := False;
        Inc(I, 2);
        Continue;
      end;

      if ConsAfter then
      begin
        // rqz = RA + ZWJ + HASANTA + YA
        if StartsAt(Src, 'qz', I) and EndsWithPlainRa(Res) then
        begin
          Res := Res + ZWJ + HASANTA + BN_YA;
          ConsAfter := True;
          WordStart := False;
          Inc(I, 2);
          Continue;
        end;
        // q after a consonant: break marker only
        Inc(I);
        Continue;
      end;

      // after a vowel / at the start: special signs
      if StartsAt(Src, 'qt', I) then
      begin
        Res := Res + BN_KHANDA_TA;
        WordStart := False;
        Inc(I, 2);
        Continue;
      end;
      if StartsAt(Src, 'qq', I) then
      begin
        Res := Res + BN_CANDRABINDU;
        WordStart := False;
        Inc(I, 2);
        Continue;
      end;
      if StartsAt(Src, 'qk', I) then
      begin
        Res := Res + BN_TAKA;
        WordStart := False;
        Inc(I, 2);
        Continue;
      end;

      // q to separate two vowels (boqi = BOI, not BOI-kar)
      if (not WordStart) and (I < N) and IsLowerLatin(Src[I + 1]) then
      begin
        QBreak := True;
        Inc(I);
        Continue;
      end;

      // a lone q stays q
      Res := Res + 'q';
      ConsAfter := False;
      WordStart := False;
      Inc(I);
      Continue;
    end;

    // longest token first (3 -> 2 -> 1)
    Matched := False;
    Len := N - I + 1;
    if Len > 3 then
      Len := 3;
    while Len >= 1 do
    begin
      Tok := Copy(Src, I, Len);

      // w: ba-phala after a consonant, otherwise the vowel O
      if Tok = 'w' then
      begin
        if ConsAfter then
        begin
          Res := Res + HASANTA + BN_BA;
          ConsAfter := True;
        end
        else
        begin
          Res := Res + BN_VOWEL_O;
          ConsAfter := False;
        end;
        WordStart := False;
        Inc(I);
        Matched := True;
        Break;
      end;

      // ng = ANUSVARA
      if Tok = 'ng' then
      begin
        Res := Res + BN_ANUSVARA;
        ConsAfter := False;
        WordStart := False;
        Inc(I, 2);
        Matched := True;
        Break;
      end;

      if FindConsonant(Tok, CV) then
      begin
        StartsWord := WordStart and (not ConsAfter);
        L := Length(Res);
        if (Tok = 'z') and (not ConsAfter) and (not WasQBreak) and (L >= 1) and (Res[L] >= #$0985) and (Res[L] <= #$0994) then
        begin
          // ya-phala on an independent vowel: oza = a-with-ya-phala
          Res := Res + HASANTA + CV;
        end
        else if (Tok = 'z') and ConsAfter and WasRaInitial then
        begin
          // word-initial RA + ya-phala
          Res := Res + ZWJ + HASANTA + CV;
        end
        else
        begin
          // b is always an independent BA (ba-phala is w)
          if ConsAfter and (Tok <> 'b') then
            Res := Res + HASANTA;
          Res := Res + CV;
        end;
        RaInitial := (Tok = 'r') and StartsWord;
        ConsAfter := True;
        WordStart := False;
        Inc(I, Len);
        Matched := True;
        Break;
      end;

      if FindVowel(Tok, VIndep, VKar) then
      begin
        if ConsAfter then
          Res := Res + VKar
        else
          Res := Res + VIndep;
        ConsAfter := False;
        WordStart := False;
        Inc(I, Len);
        Matched := True;
        Break;
      end;

      Dec(Len);
    end;
    if Matched then
      Continue;

    // digits, dari and every other character
    if (C >= '0') and (C <= '9') then
      Res := Res + BanglaDigits[Ord(C) - Ord('0')]
    else if C = '.' then
      Res := Res + BN_DARI
    else
      Res := Res + Input[I];
    ConsAfter := False;
    WordStart := True;
    Inc(I);
  end;

  Result := Res;
end;

end.
