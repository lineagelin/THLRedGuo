param(
    [string]$Apk,
    [string]$Device1Address,
    [string]$Device2Address,
    [switch]$SkipDevice2
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $projectRoot 'build/toolchain/android-sdk/platform-tools/adb.exe'
if (-not $Apk) { $Apk = Join-Path $projectRoot 'dist/android/糖葫芦-com.line.redlook-1.0.0.apk' }
$apkPath = (Resolve-Path -LiteralPath $Apk).Path
$configPath = Join-Path $PSScriptRoot 'android-devices.json'
$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($config.devices.Count -ne 2) { throw '安装目标必须包含两台设备。' }
if ($Device1Address) { $config.devices[0].address = $Device1Address }
if ($Device2Address) { $config.devices[1].address = $Device2Address }
$failures = @()
$targets = if ($SkipDevice2) { @($config.devices[0]) } else { $config.devices }
foreach ($device in $targets) {
    try {
        $address = [string]$device.address
        if ($address -notmatch '^([0-9]{1,3}[.]){3}[0-9]{1,3}:[0-9]{1,5}$') { throw "无效的设备地址：$address" }
        Write-Output "连接 $($device.name) ($address)"
        & $adb connect $address
        $state = & $adb -s $address get-state 2>&1
        if ($LASTEXITCODE -ne 0 -or ($state -join '').Trim() -ne 'device') { throw '设备未连接，请更新无线调试地址。' }
        $actualSerial = (& $adb -s $address shell getprop ro.serialno).Trim()
        if ($LASTEXITCODE -ne 0 -or $actualSerial -ne $device.serial) { throw "设备序列号不符，停止安装到 $address。" }
        & $adb -s $address install -r $apkPath
        if ($LASTEXITCODE -ne 0) { throw 'APK 安装失败。' }
        Write-Output "已安装：$($device.name)"
    } catch {
        $failures += "$($device.name): $($_.Exception.Message)"
        Write-Warning $failures[-1]
    }
}
if ($failures.Count -gt 0) { throw ($failures -join [Environment]::NewLine) }
$config | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $configPath -Encoding UTF8
