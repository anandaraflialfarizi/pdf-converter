Unicode true
Name "pdf Converter"
OutFile "../build/pdf-Converter-Windows-x64-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\pdf Converter"
RequestExecutionLevel user
Icon "../windows/AppIcon.ico"
SetCompressor /SOLID lzma
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section
  SetOutPath "$INSTDIR"
  File /r "../build/windows-payload/pdf Converter/*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$SMPROGRAMS\pdf Converter.lnk" "$INSTDIR\runtime\pythonw.exe" '$\"$INSTDIR\app.pyw$\"' "$INSTDIR\AppIcon.ico"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfConverter" "DisplayName" "pdf Converter"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfConverter" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\pdf Converter.lnk"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\pdfConverter"
  !include "../build/remove-payload.nsh"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
