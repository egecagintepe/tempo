# Script to render TEMPO 2.0 brand icons to Android mipmap folders
Add-Type -AssemblyName System.Drawing

$sizes = @{
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" = 48
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" = 72
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" = 96
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" = 144
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" = 192
}

foreach ($entry in $sizes.GetEnumerator()) {
    $path = $entry.Key
    $dim = $entry.Value

    $bmp = New-Object System.Drawing.Bitmap $dim, $dim
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Background: #0A0F1D with rounded squircle
    $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#0A0F1D"))
    $g.FillRectangle($bgBrush, 0, 0, $dim, $dim)

    # Scale factors
    $scale = $dim / 108.0
    $penBlue = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#2563EB")), (5.0 * $scale)
    $penBlue.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penBlue.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $penCyan = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#06B6D4")), (5.0 * $scale)
    $penCyan.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penCyan.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $penWhite = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#FFFFFF")), (4.5 * $scale)
    $penWhite.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $penWhite.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

    $brushCyan = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#06B6D4"))

    # Outer arc
    $rect = New-Object System.Drawing.RectangleF ((54.0 - 26.0) * $scale), ((54.0 - 26.0) * $scale), (52.0 * $scale), (52.0 * $scale)
    $g.DrawArc($penBlue, $rect, 140, 190)
    $g.DrawArc($penCyan, $rect, -10, 120)

    # Central T
    $g.DrawLine($penWhite, (40.0 * $scale), (43.0 * $scale), (68.0 * $scale), (43.0 * $scale))
    $g.DrawLine($penWhite, (54.0 * $scale), (43.0 * $scale), (54.0 * $scale), (67.0 * $scale))

    # Dot
    $g.FillEllipse($brushCyan, ((54.0 - 2.5) * $scale), ((43.0 - 2.5) * $scale), (5.0 * $scale), (5.0 * $scale))

    $g.Dispose()

    $dir = [System.IO.Path]::GetDirectoryName($path)
    if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Generated: $path ($dim x $dim)"
}
