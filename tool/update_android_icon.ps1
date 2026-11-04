param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '..\assets\branding\app_icon.png')
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$source = [System.Drawing.Image]::FromFile((Resolve-Path -LiteralPath $SourcePath).Path)
function Write-AndroidIcon([string]$OutputPath, [int]$Size, [bool]$Round = $false) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutputPath) | Out-Null
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $clip = [System.Drawing.Drawing2D.GraphicsPath]::new()
    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        if ($Round) {
            $clip.AddEllipse(0, 0, $Size, $Size)
            $graphics.SetClip($clip)
        }
        $graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $clip.Dispose()
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
try {
    if ($source.Width -ne $source.Height) { throw 'The launcher icon source must be square.' }
    $densities = [ordered]@{ mdpi = 48; hdpi = 72; xhdpi = 96; xxhdpi = 144; xxxhdpi = 192 }
    foreach ($entry in $densities.GetEnumerator()) {
        $size = [int]$entry.Value
        $outputDirectory = Join-Path $projectRoot "android\app\src\main\res\mipmap-$($entry.Key)"
        foreach ($round in @($false, $true)) {
            $fileName = if ($round) { 'ic_launcher_round.png' } else { 'ic_launcher.png' }
            Write-AndroidIcon (Join-Path $outputDirectory $fileName) $size $round
        }
        Write-Output "$($entry.Key): launcher and round launcher ready"
    }
} finally {
    $source.Dispose()
}
