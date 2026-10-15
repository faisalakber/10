param([string]$Printer,[string]$Data)
# Prints a receipt (text lines from a JSON file) through the normal Windows printer driver
try {
  Add-Type -AssemblyName System.Drawing
  $script:lines = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $Data | ConvertFrom-Json)
  $doc = New-Object System.Drawing.Printing.PrintDocument
  $doc.PrinterSettings.PrinterName = $Printer
  if (-not $doc.PrinterSettings.IsValid) { [Console]::Error.WriteLine("Printer not found: $Printer"); exit 1 }
  $doc.DocumentName = "One10 Receipt"
  $doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0,0,0,0)
  $doc.add_PrintPage({
    param($sender,$e)
    $g = $e.Graphics
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::Black,1)
    $brush = [System.Drawing.Brushes]::Black
    $x0 = 6.0; $y = 6.0
    $w = [double]$e.PageBounds.Width - 12
    if ($w -lt 120) { $w = 265 }
    foreach ($ln in $script:lines) {
      if ($ln.t -eq "--") { $g.DrawLine($pen,[single]$x0,[single]($y+3),[single]($x0+$w),[single]($y+3)); $y += 9; continue }
      $size = 9; if ($ln.z -eq 1) { $size = 13 }; if ($ln.z -eq 2) { $size = 20 }
      $style = [System.Drawing.FontStyle]::Regular; if ($ln.b -eq 1) { $style = [System.Drawing.FontStyle]::Bold }
      $f = New-Object System.Drawing.Font("Arial",[single]$size,$style)
      $fmt = New-Object System.Drawing.StringFormat
      if ($ln.a -eq "c") { $fmt.Alignment = [System.Drawing.StringAlignment]::Center } else { $fmt.Alignment = [System.Drawing.StringAlignment]::Near }
      $t = [string]$ln.t; $r = [string]$ln.r
      $rw = 0.0
      if ($r.Length -gt 0) { $rw = $g.MeasureString($r,$f).Width + 4 }
      $lw = $w - $rw
      $hl = $g.MeasureString($t,$f,[int]$lw,$fmt).Height
      $h = $hl
      if ($t.Length -gt 0) { $g.DrawString($t,$f,$brush,(New-Object System.Drawing.RectangleF([single]$x0,[single]$y,[single]$lw,[single]($hl+2))),$fmt) }
      if ($r.Length -gt 0) {
        $ff = New-Object System.Drawing.StringFormat; $ff.Alignment = [System.Drawing.StringAlignment]::Far
        $g.DrawString($r,$f,$brush,(New-Object System.Drawing.RectangleF([single]$x0,[single]$y,[single]$w,[single]($hl+2))),$ff)
        $h = [Math]::Max($hl,$g.MeasureString($r,$f).Height)
      }
      $y += $h + 1
    }
    $e.HasMorePages = $false
  })
  $doc.Print()
} catch { [Console]::Error.WriteLine($_.Exception.Message); exit 1 }
