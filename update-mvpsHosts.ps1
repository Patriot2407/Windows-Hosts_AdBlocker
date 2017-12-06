param([switch]$Elevated)
function checkAdmin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((checkAdmin) -eq $false)  {
    if ($elevated)
    {
        # could not elevate, quit
    }
    else {
        Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
    }
    exit
}
$folder = 'B:\Scripts\hosts'
[int]$success = 1
function Unzip {
    param([string]$zipfile, [string]$outpath)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
}
function BackupLocalHost {
    param([string]$hostFilePath)
    Copy-Item $hostFilePath "$hostFilePath.bak_$(Get-Date -format FileDate)"
}

function UpdateHost {
    param([string]$hostFilePath, [string[]]$mvpsFileContents)
    $hostFileContents = Get-Content -Path $hostFilePath

    $count = 0;
    foreach($hostLine in $hostFileContents)
    {
        if ($hostLine -eq "# BREAKLINE") {
            break
        }
        $count++
    }
    try{
#    $finalHostFileContents = $hostFileContents[0..$($count-1)] + $mvpsFileContents
$finalHostFileContents = $hostFileContents + $mvpsFileContents
    }catch
{
write-host "ERROR DETECTED!" -ForegroundColor Red
<#write-host "$($_.Exception.GetType().FullName)" -ForegroundColor Red #>
write-host "$($_.Exception.Message)" -ForegroundColor Red
$ErrorExit = Read-host -Prompt "Press ENTER to acknowledge and exit"
exit
exit
exit
}
while ($success -ge 1) {
    try{
<#    # openfiles /local on <----- have to run this once to be able to show what is locking hosts file and reboot is required
    $LockingProcess = CMD /C "openfiles /query /fo table | find /I ""$hostFilePath"""
    Write-Host "HOSTS Locks displayed immediately after this..."
    Write-Host $LockingProcess
    #>
    Set-Content -Path $hostFilePath -value $finalHostFileContents
    }
    catch
{
}
    Write-Host "Done: Local Host file updated"
    $success = $success - 1
    }
}

function main() {
    $basePath = "$env:windir\system32\drivers\etc"
    $mvpsHostZipFilePath = "$basePath\mvps.zip"
    if (Test-Path("$mvpsHostZipFilePath")) { Remove-Item $mvpsHostZipFilePath -Force }
    $mvpsHostUnzipFolderPath = "$basePath\mvps"
    if (Test-Path("$mvpsHostUnzipFolderPath")) { Remove-Item $mvpsHostUnzipFolderPath -Recurse -Force }
    $mvpsHostUrl = "http://winhelp2002.mvps.org/hosts.zip"
    Write-Host "Downloading latest mvps host file from $mvpsHostUrl" 
    Invoke-WebRequest $mvpsHostUrl -OutFile $mvpsHostZipFilePath
    Unzip -zipfile $mvpsHostZipFilePath -outpath $mvpsHostUnzipFolderPath
    Remove-Item $mvpsHostZipFilePath -Force   
    cat $mvpsHostUnzipFolderPath\hosts, $folder\youtube.TXT, $folder\win_telemetry_block.TXT, $folder\all_others_manually_added.TXT | sc $folder\temp.txt
    $mvpsFileContents = Get-Content -Path  "$folder\temp.txt"
    Remove-Item $mvpsHostUnzipFolderPath -Recurse -Force
    BackupLocalHost -hostfilePath "$basePath\hosts"
    UpdateHost -hostFilePath "$basePath\hosts" -mvpsFileContents $mvpsFileContents
    Write-Host "Wiping out all previously cached DNS so that the new HOSTS file immediatley takes effect."
    nbtstat -R
    ipconfig /flushdns
    Write-Host "Done. You may now exit."
    pause
            }
main

