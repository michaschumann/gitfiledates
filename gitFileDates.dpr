program gitFileDates;

{$APPTYPE CONSOLE}
{$R *.res}

  (*****************************************************************************************
   gitFileDates

   (c) Michael Schumann
   I share this code with anyone who can use it without any warranty for any purpose.
   Of course no attibution is required if its used.

   Save and restore last file write attribite for those who use git under Windows.
   Created because I use to check in all required files for building the application
   including DLLs. As some update mechanisms rely on file dates it is important to restore
   them before building the package.

   How to use
   If using TortoiseGit just create a Tortoise hook (in Tortoise settings) calling this program
   "on start commit" like this:

   gitFileDates /dir <root path to source> /save

   creates the file .gitfileattr with all file last modified informations, must be checked in.

   When building the project with a runner (gitlab-ci) include one stage after checkout like
   this:

   gitFileDates /dir <root path to source> /apply

   applies the timestamps saved in .gitfileattr to the source tree.

   Timestamps of folders will not be modified.

   *****************************************************************************************)

uses
  Classes,
  Windows,
  jclFileUtils,
  SysUtils;

var
  sl, sl1: TStringList;
  i: integer;
  s, CurDir: string;
  fage: integer;

function PathRelativePathTo(pszPath: PChar; pszFrom: PChar; dwAttrFrom: DWORD; pszTo: PChar; dwAtrTo: DWORD): LongBool;
  stdcall; external 'shlwapi.dll' name 'PathRelativePathToW';

function AbsToRel(const AbsPath, BasePath: string): string;
var
  Path: array [0 .. MAX_PATH - 1] of char;
begin
  PathRelativePathTo(@Path[0], PChar(BasePath), FILE_ATTRIBUTE_DIRECTORY, PChar(AbsPath), 0);
  Result := Path;
end;

function PathCanonicalize(lpszDst: PChar; lpszSrc: PChar): LongBool; stdcall;
  external 'shlwapi.dll' name 'PathCanonicalizeW';

function RelToAbs(const RelPath, BasePath: string): string;
var
  Dst: array [0 .. MAX_PATH - 1] of char;
begin
  PathCanonicalize(@Dst[0], PChar(IncludeTrailingBackslash(BasePath) + RelPath));
  Result := Dst;
end;

begin
  try
    if not FindCmdLineSwitch('save') and not FindCmdLineSwitch('apply') then
    begin
      writeln('Usage: gitFileDates /save or /apply');
      exit;
    end;
    CurDir := getCurrentDir;
    if FindCmdLineSwitch('dir') then
      FindCmdLineSwitch('dir', CurDir, true, [clstValueNextParam]);
    CurDir := IncludeTrailingPathDelimiter(CurDir);
    if FindCmdLineSwitch('save') then
    begin
      sl := TStringList.create;
      sl1 := TStringList.create;
      advBuildFileList(CurDir + '*.*', faAnyFile, sl, amSuperSetOf, [flRecursive, flFullNames]);
      for i := 0 to sl.count - 1 do
      begin
        if (extractFileName(sl[i]) <> '.') and (extractFileName(sl[i]) <> '..') and (FileAge(sl[i]) > -1) then
          sl1.add(AbsToRel(sl[i], CurDir) + ':' + intToStr(FileAge(sl[i])));
      end;
      sl1.saveToFile(CurDir + '.gitfileattr');
      sl.free;
      sl1.free;
    end;
    if FindCmdLineSwitch('apply') then
    begin
      if not fileExists(CurDir + '.gitfileattr') then
      begin
        writeln('Datei .gitfileattr nicht gefunden');
        exit;
      end;
      sl := TStringList.create;
      sl1 := TStringList.create;
      sl1.delimiter := ':';
      sl1.strictDelimiter := true;
      sl.loadFromFile(CurDir + '.gitfileattr');
      for i := 0 to sl.count - 1 do
      begin
        sl1.delimitedText := sl[i];
        s := RelToAbs(sl1[0], CurDir);
        fage := StrToInt(sl1[1]);
        FileSetDate(s, fage);
      end;
      sl1.free;
      sl.free;
    end;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;

end.
