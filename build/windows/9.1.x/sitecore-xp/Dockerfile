# escape=`
ARG BASE_IMAGE
ARG ASSETS_IMAGE

FROM $ASSETS_IMAGE as assets
FROM $BASE_IMAGE as build

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG ASSETS_USE_WDP
ARG SC_ROLE_CONFIG_DIRECTORY

COPY --from=assets ["${ASSETS_USE_WDP}", "C:\\temp\\packages\\"]

# expand selected wdp into installation directory
RUN Expand-Archive -Path 'C:\\temp\\packages\\*.zip' -DestinationPath 'C:\\temp'; `
    Copy-Item -Path 'C:\\temp\\Content\\Website\\*' -Destination 'C:\\inetpub\\wwwroot' -Recurse -Force;

# configure wwwroot
RUN Copy-Item -Path 'C:\\inetpub\\wwwroot\\App_Config\\Include\\Examples\\Sitecore.Owin.Authentication.IdentityServer.Disabler.config.example' -Destination 'C:\\inetpub\\wwwroot\\App_Config\\Include\\Sitecore.Owin.Authentication.IdentityServer.Disabler.config'; `
    New-Item -Path 'C:\\inetpub\\wwwroot\\upload' -ItemType Directory | Out-Null; `
    New-Item -Path 'C:\\inetpub\\wwwroot\\sitecore\\shell\\override' -ItemType Directory | Out-Null; `
    Remove-Item -Path 'C:\\inetpub\\wwwroot\\App_Data\\logs' -Force -Recurse;

# copy tools and transforms
COPY --from=assets ["C:\\install\\tools\\", "C:\\inetpub\\wwwroot\\temp\\install\\tools\\"]
COPY ${SC_ROLE_CONFIG_DIRECTORY} C:\\inetpub\\wwwroot\\

# copy microsoft environment varable configuration builder
RUN Copy-Item -Path 'C:\\inetpub\\wwwroot\\temp\\install\\tools\\bin\\Microsoft.Configuration.ConfigurationBuilders*.dll' -Destination 'C:\\inetpub\\wwwroot\\bin\\';

# find transform files and do transformation
RUN $xdts = (Get-ChildItem -Path 'C:\\inetpub\\wwwroot\\*.config.xdt'), (Get-ChildItem -Path 'C:\\inetpub\\wwwroot\\App_Config\\*.config.xdt' -Recurse); `
    $xdts | ForEach-Object { & 'C:\\inetpub\\wwwroot\\temp\\install\\tools\\scripts\\Invoke-XdtTransform.ps1' -Path $_.FullName.Replace('.xdt', '') -XdtPath $_.FullName -XdtDllPath 'C:\\inetpub\\wwwroot\\temp\\install\\tools\\bin\\Microsoft.Web.XmlTransform.dll'; }; `
    $xdts | ForEach-Object { Remove-Item -Path $_.FullName; };

# add config patches
COPY .\config\*.config C:\\inetpub\\wwwroot\\App_Config\\Include\\

# add installers
COPY --from=assets ["C:\\install\\setup\\", "C:\\inetpub\\wwwroot\\temp\\install\\setup\\"]

FROM $BASE_IMAGE

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG SC_ROLE_DEFINE

COPY --from=build ["C:\\inetpub\\wwwroot\\", "C:\\inetpub\\wwwroot\\"]

#patch in the configBuilders attibute for web.config validation
COPY --from=assets ["C:\\install\\patches\\FX_schema.patch.xml", "C:\\Windows\\System32\\inetsrv\\config\\schema"]


RUN $env:INSTALL_TEMP = 'C:\\inetpub\\wwwroot\\temp\\install'; `
    $env:IIS_SITE_PATH = 'IIS:\Sites\Default Web Site'; `
    $env:IIS_SITE_HOMEDIR_PATH = 'C:\\inetpub\\wwwroot'; `
    $env:IIS_APPPOOL_IDENTITY = 'IIS AppPool\DefaultAppPool'; `
    # install dependencies
    Start-Process msiexec.exe -ArgumentList '/i', (Join-Path $env:INSTALL_TEMP '\\setup\\urlrewrite.msi'), '/quiet', '/norestart' -NoNewWindow -Wait; `
    Start-Process (Join-Path $env:INSTALL_TEMP '\\setup\\vc_redist.exe') -ArgumentList '/install', '/passive', '/norestart' -NoNewWindow -Wait; `
    # install tools
    Copy-Item -Path (Join-Path $env:INSTALL_TEMP '\\tools') -Destination 'C:\\tools' -Recurse -Force; `
    setx /M PATH $($env:PATH + ';C:\tools\scripts;C:\tools\bin') | Out-Null; `
    # configure Windows to disable DNS caching
    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' -Name 'ServerPriorityTimeLimit' -Value 0 -Type DWord; `
    # configure app pool permissions
    Add-LocalGroupMember -Group 'Performance Monitor Users' -Member $env:IIS_APPPOOL_IDENTITY; `
    $acl = Get-Acl -Path $env:IIS_SITE_HOMEDIR_PATH; `
    $acl.SetAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($env:IIS_APPPOOL_IDENTITY, 'FullControl', @('ContainerInherit', 'ObjectInherit'), 'None', 'Allow'))); `
    Set-Acl -Path $env:IIS_SITE_HOMEDIR_PATH -AclObject $acl; `
    # configure role
    Import-Module WebAdministration; `
    Set-WebConfigurationProperty -PSPath $env:IIS_SITE_PATH -Filter '/appSettings/add[@key=\"role:define\"]' -Name 'value' -Value $env:SC_ROLE_DEFINE; `
    # delete temporary files
    Remove-Item -Path $env:INSTALL_TEMP -Force -Recurse;
