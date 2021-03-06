unit FMX.TKRBarCodeScanner;

//  TTKRBarCodeScanner is an iOS and Android Bar Code Delphi XE5 Component
//  TTKRBarCodeScanner is released under the Mozilla Public License 1.1
//  http://www.mozilla.org/MPL/MPL-1.1.html
//
// The code is heavly based on Jim McKeeth work (TAndroidBarcodeScanner).
// http://cc.embarcadero.com/Download.aspx?id=29699
// For the iOS part it uses the free TMS TTMSFMXZBarReader component
// http://www.tmssoftware.com/site/blog.asp?post=280


interface

uses
  System.Classes
  {$IFDEF IOS}
  ,FMX.TMSZBarReader
  {$ENDIF}
  {$IFDEF ANDROID}
  ,FMX.Platform, FMX.Helpers.Android, System.Rtti, FMX.Types, System.SysUtils,
  Androidapi.JNI.GraphicsContentViewText, Androidapi.JNI.JavaTypes,
  FMX.StdCtrls, FMX.Edit
    {$IF CompilerVersion >= 20}
    ,Androidapi.Helpers
    {$ENDIF}
  {$ENDIF}
  ;
type
  TTKRBarCodeScannerResult = procedure(Sender: TObject; AResult: String) of object;

type
  [ComponentPlatformsAttribute(pidAndroid or pidiOSDevice)]
  TTKRBarCodeScanner = class(TComponent)
  public
    type TBarcodeMode = (bmOneD, bmQRCode, bmProduct, bmDataMatrix);
    type TBarcodeModes = set of TBarcodeMode;
  protected
    FOnScanResult: TTKRBarCodeScannerResult;
    FBarcodeModes: TBarcodeModes;
  {$IFDEF IOS}
    FTMSFMXZBarReader: TTMSFMXZBarReader;
  {$ENDIF}
  {$IFDEF ANDROID}
    FClipService: IFMXClipboardService;
    FPreservedClipboardValue: TValue;
    FMonitorClipboard: Boolean;
    FXxx: Byte;
    const ClipboardCanary = 'waiting';
    const BarcodeModesStrArry: array [bmOneD .. bmDataMatrix] of string =
      ('ONE_D_MODE', 'QR_CODE_MODE', 'PRODUCT_MODE', 'DATA_MATRIX_MODE');
    function HandleAppEvent(AAppEvent: TApplicationEvent; AContext: TObject): Boolean;
    function GetBarcodeValue(): Boolean;
    procedure CallScan();
    function GetModeString(): string;
  {$ENDIF}
    procedure SetOnScanResult(const Value: TTKRBarCodeScannerResult);
  public
    {$IFDEF ANDROID}
    property ClipService: IFMXClipboardService read FClipService;
    {$ENDIF}
    procedure Scan;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property BarcodeModes: TBarcodeModes read FBarcodeModes write FBarcodeModes;
    property OnScanResult: TTKRBarCodeScannerResult read FOnScanResult write SetOnScanResult;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('TKR Bar Code Scanner', [TTKRBarCodeScanner]);
end;

{ TKRBarCodeScanner }

constructor TTKRBarCodeScanner.Create(AOwner: TComponent);
{$IFDEF ANDROID}
var
  aFMXApplicationEventService: IFMXApplicationEventService;
{$ENDIF}
begin
  inherited Create(AOwner);
  {$IFDEF IOS}
  FTMSFMXZBarReader := TTMSFMXZBarReader.Create(AOwner);
  {$ENDIF}
  {$IFDEF ANDROID}
  FMonitorClipboard := False;

  if not TPlatformServices.Current.SupportsPlatformService(IFMXClipboardService, IInterface(FClipService)) then
  begin
    FClipService := nil;
  end;

  if TPlatformServices.Current.SupportsPlatformService(IFMXApplicationEventService, IInterface(aFMXApplicationEventService)) then
  begin
    aFMXApplicationEventService.SetApplicationEventHandler(HandleAppEvent);
  end
  else
  begin
    Log.d('Application Event Service is not supported.');
  end;
  {$ENDIF}
  FBarcodeModes := [bmOneD, bmQRCode, bmProduct, bmDataMatrix];
end;

destructor TTKRBarCodeScanner.Destroy;
begin
  {$IFDEF IOS}
  FTMSFMXZBarReader.Free;
  {$ENDIF}
  {$IFDEF ANDROID}
  {$ENDIF}
  inherited Destroy;
end;

procedure TTKRBarCodeScanner.SetOnScanResult(const Value: TTKRBarCodeScannerResult);
begin
  FOnScanResult := Value;
  {$IFDEF IOS}
  FTMSFMXZBarReader.OnGetResult := FOnScanResult;
  {$ENDIF}
  {$IFDEF ANDROID}
  {$ENDIF}
end;

procedure TTKRBarCodeScanner.Scan;
begin
  {$IFDEF IOS}
  FTMSFMXZBarReader.Show;
  {$ENDIF}
  {$IFDEF ANDROID}
  CallScan;
  {$ENDIF}
end;

{$IFDEF ANDROID}
function TTKRBarCodeScanner.HandleAppEvent(AAppEvent: TApplicationEvent;
  AContext: TObject): Boolean;
begin
  Result := False;
  if FMonitorClipboard and
  (AAppEvent = {$IF CompilerVersion >= 20}
  TApplicationEvent.{$ENDIF}{$IF CompilerVersion >= 21}
  BecameActive{$ELSE}
  aeBecameActive{$ENDIF}) then
  begin
    Result := GetBarcodeValue;
  end;
end;
{$ENDIF}

{$IFDEF ANDROID}
function TTKRBarCodeScanner.GetBarcodeValue():Boolean;
var
  value: String;
begin
  Result := False;
  FMonitorClipboard := False;
  if (FClipService.GetClipboard.ToString <> ClipboardCanary) then
  begin
    value := FClipService.GetClipboard.ToString;
    if assigned(FOnScanResult) then
      FOnScanResult(Self, FClipService.GetClipboard.ToString);
    FClipService.SetClipboard(FPreservedClipboardValue);
    Result := True;
  end;
end;
{$ENDIF}

{$IFDEF ANDROID}
procedure TTKRBarCodeScanner.CallScan();
var
  intent: JIntent;
  aScanCmd: string;
begin
  if Assigned(FClipService) then
  begin
    FPreservedClipboardValue := FClipService.GetClipboard;
    FMonitorClipboard := True;
    FClipService.SetClipboard(ClipboardCanary);
    intent := tjintent.Create;
    intent.setAction(stringtojstring('com.google.zxing.client.android.SCAN'));
    aScanCmd := GetModeString;
    intent.putExtra(tjintent.JavaClass.EXTRA_TEXT, stringtojstring(aScanCmd));

    {$IF RTLVersion > 31}
    TAndroidHelper.Activity.startActivity(Intent);
    {$ELSE}
    sharedactivity.startActivityForResult(intent, 0);
    {$ENDIF}

  end;

//  Intent := TJIntent.Create;
//  try
//    Intent.setAction(TJIntent.JavaClass.ACTION_SEND); //Defines the Action.
//    {$IF RTLVersion > 31}
//    if TJBuild_VERSION.JavaClass.SDK_INT >= versionCode then
//    begin
//      LAuthority := StringToJString(JStringToString(TAndroidHelper.Context.getApplicationContext.getPackageName) + '.fileprovider');
//      Data  := TJFileProvider.JavaClass.getUriForFile(TAndroidHelper.Context, LAuthority, TJFile.JavaClass.init(StringToJString(FileName)));
//      Intent.putExtra(TJIntent.JavaClass.EXTRA_STREAM,  TJParcelable.Wrap((Data as ILocalObject).GetObjectID));
//      Intent.setDataAndType(Data, StringToJString('application/pdf'));
//      Intent.setFlags(TJIntent.JavaClass.FLAG_GRANT_READ_URI_PERMISSION);
//      TAndroidHelper.Activity.startActivity(Intent);
//    end
//    {$ELSE}
//    Intent.setType(StringToJString('application/pdf'));
//    Intent.putExtra(TJIntent.JavaClass.EXTRA_STREAM, TJParcelable.Wrap((FileNameToUri(FileName) as ILocalObject).GetObjectID));
//    SharedActivity.startActivity(TJIntent.JavaClass.createChooser(Intent, StrToJCharSequence('Selecione um App. de E-mail. *pdf')));
//    {$ENDIF}
//  finally
//    Intent:= Nil ;
//  end;

end;
{$ENDIF}

{$IFDEF ANDROID}
function TTKRBarCodeScanner.GetModeString(): string;
var
  mode: TBarcodeMode;
  aBarcodeModes: TBarcodeModes;
begin
  Result := '';
  if FBarcodeModes = [] then
  begin
    aBarcodeModes := [bmOneD,bmQRCode,bmProduct,bmDataMatrix];
  end
  else
  begin
    aBarcodeModes := FBarcodeModes;
  end;

  for mode in FBarcodeModes do
  begin
    Result := Result + ',' + BarcodeModesStrArry[mode];
  end;
  Result := StringReplace(Result, ',', '"SCAN_MODE","', []) + '"';
end;
{$ENDIF}

end.
