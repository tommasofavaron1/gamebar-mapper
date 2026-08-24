param(
    [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Rectangle,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rectangle.X, $Rectangle.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($Rectangle.Right - $diameter, $Rectangle.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Rectangle.X, $Rectangle.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-StoreLogo {
    param(
        [int]$Size,
        [string]$Path
    )

    $renderSize = $Size * 4
    $scale = $renderSize / 50.0
    $bitmap = New-Object System.Drawing.Bitmap $renderSize, $renderSize,
        ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $background = New-RoundedRectanglePath `
        -Rectangle (New-Object System.Drawing.RectangleF (2 * $scale), (2 * $scale), (46 * $scale), (46 * $scale)) `
        -Radius (11 * $scale)
    $backgroundBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 31, 36, 43))
    $graphics.FillPath($backgroundBrush, $background)

    $controller = New-Object System.Drawing.Drawing2D.GraphicsPath
    $controller.StartFigure()
    $controller.AddBezier(9 * $scale, 34 * $scale, 7 * $scale, 32 * $scale, 8 * $scale, 28 * $scale, 10 * $scale, 22 * $scale)
    $controller.AddBezier(12 * $scale, 16 * $scale, 17 * $scale, 13 * $scale, 22 * $scale, 16 * $scale, 25 * $scale, 16 * $scale)
    $controller.AddBezier(28 * $scale, 16 * $scale, 33 * $scale, 13 * $scale, 38 * $scale, 16 * $scale, 40 * $scale, 22 * $scale)
    $controller.AddBezier(40 * $scale, 22 * $scale, 42 * $scale, 28 * $scale, 43 * $scale, 32 * $scale, 41 * $scale, 34 * $scale)
    $controller.AddBezier(41 * $scale, 34 * $scale, 39 * $scale, 36 * $scale, 36 * $scale, 31 * $scale, 33 * $scale, 29 * $scale)
    $controller.AddBezier(33 * $scale, 29 * $scale, 29 * $scale, 31 * $scale, 21 * $scale, 31 * $scale, 17 * $scale, 29 * $scale)
    $controller.AddBezier(17 * $scale, 29 * $scale, 14 * $scale, 31 * $scale, 11 * $scale, 36 * $scale, 9 * $scale, 34 * $scale)
    $controller.CloseFigure()

    $controllerBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 242, 245, 247))
    $graphics.FillPath($controllerBrush, $controller)

    $inkBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 31, 36, 43))
    $mintBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 75, 215, 164))
    $coralBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 107, 107))
    $goldBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 195, 77))

    $graphics.FillRectangle($mintBrush, 14 * $scale, 20 * $scale, 3 * $scale, 10 * $scale)
    $graphics.FillRectangle($mintBrush, 10.5 * $scale, 23.5 * $scale, 10 * $scale, 3 * $scale)
    $graphics.FillEllipse($coralBrush, 34 * $scale, 20 * $scale, 4 * $scale, 4 * $scale)
    $graphics.FillEllipse($goldBrush, 30 * $scale, 24 * $scale, 4 * $scale, 4 * $scale)

    $arrowPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 57, 155, 220)), (1.8 * $scale)
    $arrowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $arrowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($arrowPen, 21 * $scale, 21.5 * $scale, 29 * $scale, 21.5 * $scale)
    $graphics.DrawLine($arrowPen, 26.5 * $scale, 19 * $scale, 29 * $scale, 21.5 * $scale)
    $graphics.DrawLine($arrowPen, 21 * $scale, 26.5 * $scale, 29 * $scale, 26.5 * $scale)
    $graphics.DrawLine($arrowPen, 21 * $scale, 26.5 * $scale, 23.5 * $scale, 29 * $scale)

    $output = New-Object System.Drawing.Bitmap $Size, $Size,
        ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $outputGraphics = [System.Drawing.Graphics]::FromImage($output)
    $outputGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $outputGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $outputGraphics.DrawImage($bitmap, 0, 0, $Size, $Size)
    $output.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

    $outputGraphics.Dispose()
    $output.Dispose()
    $arrowPen.Dispose()
    $goldBrush.Dispose()
    $coralBrush.Dispose()
    $mintBrush.Dispose()
    $inkBrush.Dispose()
    $controllerBrush.Dispose()
    $controller.Dispose()
    $backgroundBrush.Dispose()
    $background.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

function New-HorizontalAsset {
    param(
        [int]$Width,
        [int]$Height,
        [string]$Path,
        [switch]$Splash
    )

    $bitmap = New-Object System.Drawing.Bitmap $Width, $Height,
        ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::FromArgb(255, 23, 25, 29))

    $accentBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 75, 215, 164))
    $graphics.FillRectangle($accentBrush, 0, 0, [Math]::Max(2, [int]($Width * 0.012)), $Height)

    $logoSize = if ($Splash) { [int]($Height * 0.56) } else { [int]($Height * 0.68) }
    $logoPath = Join-Path ([System.IO.Path]::GetTempPath()) ("ControllerMapperLogo-{0}.png" -f [Guid]::NewGuid())
    New-StoreLogo -Size $logoSize -Path $logoPath
    $logo = [System.Drawing.Image]::FromFile($logoPath)

    $contentWidth = if ($Splash) { [int]($Width * 0.66) } else { [int]($Width * 0.86) }
    $logoX = [int](($Width - $contentWidth) / 2)
    $logoY = [int](($Height - $logoSize) / 2)
    $graphics.DrawImage($logo, $logoX, $logoY, $logoSize, $logoSize)

    $textX = $logoX + $logoSize + [int]($Height * 0.10)
    $titleSize = if ($Splash) { $Height * 0.105 } else { $Height * 0.105 }
    $subtitleSize = $titleSize * 0.55
    $titleFont = New-Object System.Drawing.Font "Segoe UI Semibold", $titleSize,
        ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $subtitleFont = New-Object System.Drawing.Font "Segoe UI", $subtitleSize,
        ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
    $titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 242, 245, 247))
    $subtitleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 169, 175, 184))
    $titleY = [int]($Height * 0.34)
    $graphics.DrawString("CONTROLLER", $titleFont, $titleBrush, $textX, $titleY)
    $graphics.DrawString("MAPPER", $titleFont, $titleBrush, $textX, $titleY + ($titleSize * 1.05))
    if ($Splash) {
        $graphics.DrawString("Rimappatura in Game Bar", $subtitleFont, $subtitleBrush, $textX, $titleY + ($titleSize * 2.35))
    }

    $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)

    $subtitleBrush.Dispose()
    $titleBrush.Dispose()
    $subtitleFont.Dispose()
    $titleFont.Dispose()
    $logo.Dispose()
    Remove-Item $logoPath -Force
    $accentBrush.Dispose()
    $graphics.Dispose()
    $bitmap.Dispose()
}

$scales = [ordered]@{
    100 = 1.00
    125 = 1.25
    150 = 1.50
    200 = 2.00
    400 = 4.00
}

foreach ($scaleEntry in $scales.GetEnumerator()) {
    $scaleName = $scaleEntry.Key
    $factor = $scaleEntry.Value
    $squareAssets = [ordered]@{
        StoreLogo = [int][Math]::Round(50 * $factor, [System.MidpointRounding]::AwayFromZero)
        Square44x44Logo = [int][Math]::Round(44 * $factor, [System.MidpointRounding]::AwayFromZero)
        Square150x150Logo = [int][Math]::Round(150 * $factor, [System.MidpointRounding]::AwayFromZero)
        SmallTile = [int][Math]::Round(71 * $factor, [System.MidpointRounding]::AwayFromZero)
        LargeTile = [int][Math]::Round(310 * $factor, [System.MidpointRounding]::AwayFromZero)
    }

    foreach ($asset in $squareAssets.GetEnumerator()) {
        $outputPath = Join-Path $OutputDirectory "$($asset.Key).scale-$scaleName.png"
        New-StoreLogo -Size $asset.Value -Path $outputPath
        Write-Output "GENERATED=$outputPath"
    }

    $wideWidth = [int][Math]::Round(310 * $factor, [System.MidpointRounding]::AwayFromZero)
    $wideHeight = [int][Math]::Round(150 * $factor, [System.MidpointRounding]::AwayFromZero)
    $widePath = Join-Path $OutputDirectory "Wide310x150Logo.scale-$scaleName.png"
    New-HorizontalAsset -Width $wideWidth -Height $wideHeight -Path $widePath
    Write-Output "GENERATED=$widePath"

    $splashWidth = [int][Math]::Round(620 * $factor, [System.MidpointRounding]::AwayFromZero)
    $splashHeight = [int][Math]::Round(300 * $factor, [System.MidpointRounding]::AwayFromZero)
    $splashPath = Join-Path $OutputDirectory "SplashScreen.scale-$scaleName.png"
    New-HorizontalAsset -Width $splashWidth -Height $splashHeight -Path $splashPath -Splash
    Write-Output "GENERATED=$splashPath"
}

$targetSizes = 16, 24, 32, 48, 256
foreach ($targetSize in $targetSizes) {
    $outputPath = Join-Path $OutputDirectory "Square44x44Logo.targetsize-$targetSize.png"
    New-StoreLogo -Size $targetSize -Path $outputPath
    Write-Output "GENERATED=$outputPath"
}

$unplatedTargetSizes = 16, 24, 32, 48, 256
foreach ($targetSize in $unplatedTargetSizes) {
    $fileName = if ($targetSize -eq 24) {
        "Square44x44Logo.targetsize-24_altform-unplated.png"
    }
    else {
        "Square44x44Logo.altform-unplated_targetsize-$targetSize.png"
    }
    $outputPath = Join-Path $OutputDirectory $fileName
    New-StoreLogo -Size $targetSize -Path $outputPath
    Write-Output "GENERATED=$outputPath"
}

$lockScreenPath = Join-Path $OutputDirectory "LockScreenLogo.scale-200.png"
New-StoreLogo -Size 48 -Path $lockScreenPath
Write-Output "GENERATED=$lockScreenPath"