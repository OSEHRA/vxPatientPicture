unit rMisc;

{
Copyright 2013 Document Storage Systems, Inc.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
}

interface

uses SysUtils, Windows, Classes, Forms, Controls, ComCtrls, Grids, ORFn, ORNet;

const
  MAX_TOOLITEMS = 30;

type
  TToolItem = record
    Caption: string;
    Action: string;
  end;

  TToolItemList = array[0..MAX_TOOLITEMS] of TToolItem;

  {An Object of this Class is Created to Hold the Sizes of Controls(Forms)
   while the app is running, thus reducing calls to RPCs SAVESIZ and LOADSIZ}

{//kw - commented for vxPatientPicture
  TSizeHolder = class(TObject)
  private
    FSizeList,FNameList: TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    function GetSize(AName: String): String;
    procedure SetSize(AName,ASize: String);
    procedure AddSizesToStrList(theList: TStringList);
  end;
}
function DetailPrimaryCare(const DFN: string): TStrings;  //*DFN*
procedure GetToolMenu(var ToolItems: TToolItemList; var OverLimit: boolean);
procedure ListSymbolTable(Dest: TStrings);
function MScalar(const x: string): string;
procedure SetShareNode(const DFN: string; AHandle: HWND);  //*DFN*
function ServerHasPatch(const x: string): Boolean;
function ServerVersion(const Option, VerClient: string): string;

{ //kw - commented for vxPatientPicture
procedure SaveUserBounds(AControl: TControl);
procedure SaveUserSizes(SizingList: TStringList);
procedure SetFormPosition(AForm: TForm);
procedure SetUserBounds(var AControl: TControl);
procedure SetUserBounds2(AName: string; var v1, v2, v3, v4: integer);
procedure SetUserWidths(var AControl: TControl);
procedure SetUserColumns(var AControl: TControl);
function StrUserBounds(AControl: TControl): string;
function StrUserBounds2(AName: string; v1, v2, v3, v4: integer): string;
function StrUserWidth(AControl: TControl): string;
function StrUserColumns(AControl: TControl): string;
function UserFontSize: integer;
procedure SaveUserFontSize( FontSize: integer);
}

//var
  //SizeHolder : TSizeHolder; //kw

implementation

uses TRPCB, {fOrders,} math;

var
  uBounds, uWidths, uColumns: TStringList;

function DetailPrimaryCare(const DFN: string): TStrings;  //*DFN*
begin
  CallV('ORWPT1 PCDETAIL', [DFN]);
  Result := RPCBrokerV.Results;
end;

procedure GetToolMenu(var ToolItems: TToolItemList; var OverLimit: boolean);
var
  i: Integer;
  x: string;
  LoopIndex: integer;
begin
  for i := 0 to MAX_TOOLITEMS do with ToolItems[i] do
  begin
    Caption := '';
    Action := '';
  end;
  CallV('ORWU TOOLMENU', [nil]);
  OverLimit := (MAX_TOOLITEMS < RPCBrokerV.Results.Count - 1);
  LoopIndex := Min(MAX_TOOLITEMS, RPCBrokerV.Results.Count - 1);
  with RPCBrokerV do for i := 0 to LoopIndex do with ToolItems[i] do
  begin
    x := Piece(Results[i], U, 1);
    Caption := Piece(x, '=', 1);
    Action := Copy(x, Pos('=', x) + 1, Length(x));
  end;
end;

procedure ListSymbolTable(Dest: TStrings);
var
  i: Integer;
  x: string;
begin
  Dest.Clear;
  CallV('ORWUX SYMTAB', [nil]);
  i := 0;
  with RPCBrokerV.Results do while i < Count do
  begin
    x := Strings[i] + '=';
    Inc(i);
    if i < Count then x := x + Strings[i];
    Dest.Add(x);
    Inc(i);
  end;
end;

function MScalar(const x: string): string;
begin
  with RPCBrokerV do
  begin
    RemoteProcedure := 'XWB GET VARIABLE VALUE';
    Param[0].Value := x;
    Param[0].PType := reference;
    CallBroker;
    Result := Results[0];
  end;
end;

function ServerHasPatch(const x: string): Boolean;
begin
  Result := sCallV('ORWU PATCH', [x]) = '1';
end;

function ServerVersion(const Option, VerClient: string): string;
begin
  Result := sCallV('ORWU VERSRV', [Option, VerClient]);
end;
{
function UserFontSize: integer;
begin
  Result := StrToIntDef(sCallV('ORWCH LDFONT', [nil]),8);
end;

procedure LoadSizes;
var
  i, p: Integer;
begin
  uBounds  := TStringList.Create;
  uWidths  := TStringList.Create;
  uColumns := TStringList.Create;
  CallV('ORWCH LOADALL', [nil]);
  with RPCBrokerV do
  begin
    for i := 0 to Results.Count - 1 do    // change '^' to '='
    begin
      p := Pos(U, Results[i]);
      if p > 0 then Results[i] := Copy(Results[i], 1, p - 1) + '=' +
                                  Copy(Results[i], p + 1, Length(Results[i]));
    end;
    ExtractItems(uBounds,  RPCBrokerV.Results, 'Bounds');
    ExtractItems(uWidths,  RPCBrokerV.Results, 'Widths');
    ExtractItems(uColumns, RPCBrokerV.Results, 'Columns');
  end;
end;
}
procedure SetShareNode(const DFN: string; AHandle: HWND);  //*DFN*
begin
  // sets node that allows other apps to see which patient is currently selected
  sCallV('ORWPT SHARE', [DottedIPStr, IntToHex(AHandle, 8), DFN]);
end;
{
procedure SetUserBounds(var AControl: TControl);
var
  x: string;
begin
  if uBounds = nil then LoadSizes;
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  x := uBounds.Values[x];
  if (x = '0,0,0,0') and (AControl is TForm)
    then TForm(AControl).WindowState := wsMaximized
    else
    begin
      AControl.Left   := HigherOf(StrToIntDef(Piece(x, ',', 1), AControl.Left), 0);
      AControl.Top    := HigherOf(StrToIntDef(Piece(x, ',', 2), AControl.Top), 0);
      if Assigned( AControl.Parent ) then
      begin
        AControl.Width  := LowerOf(StrToIntDef(Piece(x, ',', 3), AControl.Width), AControl.Parent.Width - AControl.Left);
        AControl.Height := LowerOf(StrToIntDef(Piece(x, ',', 4), AControl.Height), AControl.Parent.Height - AControl.Top);
      end
      else
      begin
        AControl.Width  := StrToIntDef(Piece(x, ',', 3), AControl.Width);
        AControl.Height := StrToIntDef(Piece(x, ',', 4), AControl.Height);
      end;
    end;
  //if (x = '0,0,' + IntToStr(Screen.Width) + ',' + IntToStr(Screen.Height)) and
  //  (AControl is TForm) then TForm(AControl).WindowState := wsMaximized;
end;

procedure SetUserBounds2(AName: string; var v1, v2, v3, v4: integer);
var
  x: string;
begin
  if uBounds = nil then LoadSizes;
  x := uBounds.Values[AName];
  v1 := StrToIntDef(Piece(x, ',', 1), 0);
  v2 := StrToIntDef(Piece(x, ',', 2), 0);
  v3 := StrToIntDef(Piece(x, ',', 3), 0);
  v4 := StrToIntDef(Piece(x, ',', 4), 0);
end;


procedure SetUserWidths(var AControl: TControl);
var
  x: string;
begin
  if uWidths = nil then LoadSizes;
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  x := uWidths.Values[x];
  if Assigned (AControl.Parent) then
    AControl.Width := LowerOf(StrToIntDef(x, AControl.Width), AControl.Parent.Width - AControl.Left)
  else
    AControl.Width := StrToIntDef(x, AControl.Width);
end;

procedure SetUserColumns(var AControl: TControl);
var
  x: string;
  i, AWidth: Integer;
  couldSet: boolean;
begin
  couldSet := False;
  if uColumns = nil then LoadSizes;
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  if AnsiCompareText(x,'frmOrders.hdrOrders')=0 then
    couldSet := True;
  x := uColumns.Values[x];
  if AControl is THeaderControl then with THeaderControl(AControl) do
    for i := 0 to Sections.Count - 1 do
    begin
      //Make sure all of the colmumns fit, even if it means scrunching the last ones.
      AWidth := LowerOf(StrToIntDef(Piece(x, ',', i + 1), 0), HigherOf(ClientWidth - (Sections.Count - i)*5 - Sections.Items[i].Left, 5));
      if AWidth > 0 then Sections.Items[i].Width := AWidth;
      if couldSet and (i=0) and (AWidth>0) then
//lwm20061118        frmOrders.EvtColWidth := AWidth;
    end;
  if AControl is TCustomGrid then //nothing for now;
end;

procedure SaveUserBounds(AControl: TControl);
var
  x: string;
begin
  if (AControl is TForm) and (TForm(AControl).WindowState = wsMaximized) then
    x := '0,0,0,0'
  else
    with AControl do
      x := IntToStr(Left) + ',' + IntToStr(Top) + ',' +
           IntToStr(Width) + ',' + IntToStr(Height);
//  CallV('ORWCH SAVESIZ', [AControl.Name, x]);
  //SizeHolder.SetSize(AControl.Name, x); //kw commented
end;

procedure SaveUserSizes(SizingList: TStringList);
begin
  CallV('ORWCH SAVEALL', [SizingList]);
end;

procedure SaveUserFontSize( FontSize: integer);
begin
  CallV('ORWCH SAVFONT', [IntToStr(FontSize)]);
end;


procedure SetFormPosition(AForm: TForm);
var
  x: string;
  Rect: TRect;
begin
//  x := sCallV('ORWCH LOADSIZ', [AForm.Name]);
  x := SizeHolder.GetSize(AForm.Name);
  if x = '' then Exit; // allow default bounds to be passed in, else screen center?
  if (x = '0,0,0,0') then
    AForm.WindowState := wsMaximized
  else
  begin
    AForm.SetBounds(StrToIntDef(Piece(x, ',', 1), AForm.Left),
                    StrToIntDef(Piece(x, ',', 2), AForm.Top),
                    StrToIntDef(Piece(x, ',', 3), AForm.Width),
                    StrToIntDef(Piece(x, ',', 4), AForm.Height));
    Rect := AForm.BoundsRect;
    ForceInsideWorkArea(Rect);
    AForm.BoundsRect := Rect;
  end;

end;


function StrUserBounds(AControl: TControl): string;
var
  x: string;
begin
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  with AControl do Result := 'B' + U + x + U + IntToStr(Left) + ',' + IntToStr(Top) + ',' +
                                               IntToStr(Width) + ',' + IntToStr(Height);
  if (AControl is TForm) and (TForm(AControl).WindowState = wsMaximized)
    then Result := 'B' + U + x + U + '0,0,0,0';
end;

function StrUserBounds2(AName: string; v1, v2, v3, v4: integer): string;
begin
  Result := 'B' + U + AName + U + IntToStr(v1) + ',' + IntToStr(v2) + ',' +
                                  IntToStr(v3) + ',' + IntToStr(v4);
end;

function StrUserWidth(AControl: TControl): string;
var
  x: string;
begin
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  with AControl do Result := 'W' + U + x + U + IntToStr(Width);
end;

function StrUserColumns(AControl: TControl): string;
var
  x: string;
  i: Integer;
  shouldSave: boolean;
begin
  shouldSave := False;
  x := AControl.Name;
  if not (AControl is TForm) and (Assigned(AControl.Owner)) then x := AControl.Owner.Name + '.' + x;
  if AnsiCompareText(x,'frmOrders.hdrOrders') = 0 then
    shouldSave := True;
  Result := 'C' + U + x + U;
  if AControl is THeaderControl then with THeaderControl(AControl) do
    for i := 0 to Sections.Count - 1 do
    begin
      if shouldSave and (i = 0) then
//lwm20061118        Result := Result + IntToStr(frmOrders.EvtColWidth) + ','
      else
        Result := Result + IntToStr(Sections.Items[i].Width) + ',';
    end;
  if AControl is TCustomGrid then //nothing for now;
  if CharAt(Result, Length(Result)) = ',' then Result := Copy(Result, 1, Length(Result) - 1);
end;

 // end TSizeHolder

procedure TSizeHolder.AddSizesToStrList(theList: TStringList);
//Adds all the Sizes in the TSizeHolder Object to theList String list parameter
var
  i: integer;
begin
  for i := 0 to FNameList.Count-1 do
    theList.Add('B' + U + FNameList[i] + U + FSizeList[i]);
end;

constructor TSizeHolder.Create;
begin
  inherited;
  FNameList := TStringList.Create;
  FSizeList := TStringList.Create;
end;


destructor TSizeHolder.Destroy;
begin
  FNameList.Free;
  FSizeList.Free;
  inherited;
end;

function TSizeHolder.GetSize(AName: String): String;
//Fuctions returns a String of the Size(s) Of the Name parameter passed,
 //if the Size(s) are already loaded into the object it will return those,
 //otherwise it will make the apropriate RPC call to LOADSIZ
var
  rSizeVal: String; //return Size value
  nameIndex: integer;
begin
  rSizeVal := '';
  nameIndex := FNameList.IndexOf(AName);
  if nameIndex = -1 then //Currently Not in the NameList
  begin
    rSizeVal := sCallV('ORWCH LOADSIZ', [AName]);
    if rSizeVal <> '' then
    begin
      FNameList.Add(AName);
      FSizeList.Add(rSizeVal);
    end;
  end
  else //Currently is in the NameList
    rSizeVal := FSizeList[nameIndex];
  result := rSizeVal;
end;

procedure TSizeHolder.SetSize(AName, ASize: String);
//Store the Size(s) Of the ASize parameter passed, Associate it with the AName
 //Parameter. This only stores the sizes in the objects member variables.
 //to Store on the MUMPS Database call SendSizesToDB()
var
  nameIndex: integer;
begin
  nameIndex := FNameList.IndexOf(AName);
  if nameIndex = -1 then //Currently Not in the NameList
  begin
    FNameList.Add(AName);
    FSizeList.Add(ASize);
  end
  else //Currently is in the NameList
    FSizeList[nameIndex] := ASize;

end;
}
initialization
  // nothing for now

finalization
  if uBounds  <> nil then uBounds.Free;
  if uWidths  <> nil then uWidths.Free;
  if uColumns <> nil then uColumns.Free;

end.
