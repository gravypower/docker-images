[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [hashtable]$WatchDirectoryParameters
)

# setup
$ErrorActionPreference = "STOP"

$timeFormat = "HH:mm:ss:fff"

# print start message
Write-Host ("$(Get-Date -Format $timeFormat): Sitecore Development ENTRYPOINT, starting...")

# check to see if we should start the Watch-Directory.ps1 script
$watchDirectoryJobName = "Watch-Directory.ps1"
$useWatchDirectory = (Test-Path -Path "C:\src" -PathType "Container") -eq $true

if ($useWatchDirectory)
{
    # setup default parameters if none is supplied
    if ($null -eq $WatchDirectoryParameters)
    {
        $WatchDirectoryParameters = @{ Path = "C:\src"; Destination = "C:\IndexWorker"; }
    }

    # start Watch-Directory.ps1 in background, kill foreground process if it fails
    Start-Job -Name $watchDirectoryJobName -ArgumentList $WatchDirectoryParameters -ScriptBlock {
        param([hashtable]$params)

        & "C:\tools\scripts\Watch-Directory.ps1" @params

    } | Out-Null

    # wait to see if job have failed (it will if for example parsing in invalid parameters)...
    Start-Sleep -Milliseconds 1000

    Get-Job -Name $watchDirectoryJobName | ForEach-Object {
        $job = $_

        if ($job.State -ne "Running")
        {
            # writes output stream
            Receive-Job $job

            # exit
            exit 1
        }

        Write-Host "$(Get-Date -Format $timeFormat): Job '$($job.Name)' started..."
    }
}
else
{
    Write-Host ("$(Get-Date -Format $timeFormat): Skipping start of '$watchDirectoryJobName', to enable you should mount a directory into 'C:\src'.")
}

#copy the license file

$licenseFilePath = "C:\license\license.xml"

# Create licence file environment variable
$licenseString = $env:SITECORE_LICENSE;
if ($licenseString) {
    $data = [System.Convert]::FromBase64String($licenseString)
    $ms = New-Object System.IO.MemoryStream
    $ms.Write($data, 0, $data.Length)
    $ms.Seek(0,0) | Out-Null

    $cs = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object System.IO.StreamReader($cs)
    $t = $sr.readtoend()
    New-Item -Path "c:\" -Name "license" -ItemType "directory"
    $t | Out-File C:\license\license.xml
}


if (!(Test-Path $licenseFilePath -PathType "Leaf"))
{
    throw ("License not found at '{0}'." -f $licenseFilePath)
}

$LicenseFileTargetPath = "C:\IndexWorker\App_Data\license.xml"

Copy-Item $licenseFilePath -Destination $LicenseFileTargetPath -Force

# print ready message
Write-Host ("$(Get-Date -Format $timeFormat): Indexworker ready!")

# start filebeat.exe in foreground
#& "C:\tools\bin\filebeat\filebeat.exe" -c (Join-Path $PSScriptRoot "\filebeat.yml")
& "C:\IndexWorker\XConnectSearchIndexer.exe"