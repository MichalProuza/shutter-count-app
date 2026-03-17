param(
  [string]$Path = (Join-Path $PSScriptRoot 'Raws_small_truncated'),
  [switch]$Recurse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-U16 {
  param([byte[]]$Bytes, [int]$Offset, [bool]$LittleEndian)
  if ($Offset + 1 -ge $Bytes.Length) { return 0 }
  $b0 = [int]$Bytes[$Offset]
  $b1 = [int]$Bytes[$Offset + 1]
  if ($LittleEndian) {
    return [int]($b0 -bor ($b1 -shl 8))
  }
  return [int](($b0 -shl 8) -bor $b1)
}

function Read-U32 {
  param([byte[]]$Bytes, [int]$Offset, [bool]$LittleEndian)
  if ($Offset + 3 -ge $Bytes.Length) { return 0 }
  $b0 = [uint32]$Bytes[$Offset]
  $b1 = [uint32]$Bytes[$Offset + 1]
  $b2 = [uint32]$Bytes[$Offset + 2]
  $b3 = [uint32]$Bytes[$Offset + 3]
  if ($LittleEndian) {
    return [uint32]($b0 -bor ($b1 -shl 8) -bor ($b2 -shl 16) -bor ($b3 -shl 24))
  }
  return [uint32](($b0 -shl 24) -bor ($b1 -shl 16) -bor ($b2 -shl 8) -bor $b3)
}

function Read-U64BE {
  param([byte[]]$Bytes, [int]$Offset)
  if ($Offset + 7 -ge $Bytes.Length) { return [uint64]0 }
  $hi = [uint64](Read-U32 $Bytes $Offset $false)
  $lo = [uint64](Read-U32 $Bytes ($Offset + 4) $false)
  return ($hi -shl 32) -bor $lo
}

function Read-S4 {
  param([byte[]]$Bytes, [int]$Offset)
  if ($Offset + 3 -ge $Bytes.Length) { return '' }
  return [string]([char]$Bytes[$Offset]) + [char]$Bytes[$Offset + 1] + [char]$Bytes[$Offset + 2] + [char]$Bytes[$Offset + 3]
}

function Read-Ascii {
  param([byte[]]$Bytes, [int]$Offset, [int]$Count)
  if ($Offset -lt 0 -or $Count -le 0 -or $Offset -ge $Bytes.Length) { return '' }
  $end = [Math]::Min($Bytes.Length, $Offset + $Count)
  $sb = [System.Text.StringBuilder]::new()
  for ($i = $Offset; $i -lt $end; $i++) {
    if ($Bytes[$i] -eq 0) { break }
    [void]$sb.Append([char]$Bytes[$i])
  }
  return $sb.ToString().Trim()
}

function Parse-IFD {
  param([byte[]]$Bytes, [int]$Offset, [int]$Base, [bool]$LittleEndian)
  $table = @{}
  if ($Offset + 1 -ge $Bytes.Length) { return $table }
  $count = Read-U16 $Bytes $Offset $LittleEndian
  $limit = [Math]::Min($count, 300)
  for ($i = 0; $i -lt $limit; $i++) {
    $p = $Offset + 2 + ($i * 12)
    if ($p + 11 -ge $Bytes.Length) { break }
    $tag = Read-U16 $Bytes $p $LittleEndian
    $type = Read-U16 $Bytes ($p + 2) $LittleEndian
    $cnt = [uint32](Read-U32 $Bytes ($p + 4) $LittleEndian)
    $raw = [uint32](Read-U32 $Bytes ($p + 8) $LittleEndian)
    $val = $raw
    if ($type -eq 3 -and $cnt -eq 1) {
      $val = Read-U16 $Bytes ($p + 8) $LittleEndian
    }
    $table[$tag] = [pscustomobject]@{
      Tag = $tag
      Type = $type
      Count = $cnt
      Raw = [uint32]$raw
      Value = [uint64]$val
    }
  }
  return $table
}

function Get-IFDString {
  param([byte[]]$Bytes, [int]$Base, $Tag)
  if (-not $Tag) { return '' }
  if ($Tag.Count -gt 4096) { return '' }
  if ($Tag.Count -gt 4) {
    return Read-Ascii $Bytes ($Base + $Tag.Raw) $Tag.Count
  }
  $raw = [uint32]$Tag.Raw
  $chars = [System.Text.StringBuilder]::new()
  for ($j = 0; $j -lt $Tag.Count; $j++) {
    $b = ($raw -shr ($j * 8)) -band 0xFF
    if ($b -eq 0) { break }
    [void]$chars.Append([char]$b)
  }
  return $chars.ToString().Trim()
}

function New-Result {
  return @{
    make = ''
    model = ''
    shutterCount = $null
    method = ''
    firmware = ''
    dateTime = ''
    iso = $null
    focalLength = $null
    aperture = $null
    shutterSpeed = $null
    lensModel = ''
    fileNumber = ''
    dirIndex = $null
    fileIndex = $null
    _probeValues = ''
    _cr3BlockSize = $null
  }
}

function Parse-CanonMakerNote {
  param([byte[]]$Bytes, [int]$MakerOff, [bool]$LittleEndian, [hashtable]$Result)
  $mn = Parse-IFD $Bytes $MakerOff $MakerOff $LittleEndian

  $fi = $mn[0x93]
  if (-not $LittleEndian -and $fi -and $fi.Type -eq 3 -and $fi.Count -ge 2) {
    $off = if ($fi.Count -gt 2) { $fi.Raw } else { 0 }
    if ($off -gt 0 -and $off + 3 -lt $Bytes.Length) {
      $sc = [uint32](Read-U32 $Bytes $off $false)
      if ($sc -gt 0 -and $sc -lt 600000) {
        $Result.shutterCount = [int]$sc
        $Result.method = 'Canon FileInfo[0] BE (1D/1Ds)'
        return
      }
    }
  }

  $ci = $mn[0x0d]
  if ($ci -and $ci.Type -eq 7 -and $ci.Count -gt 0x17a -and $Result.model -match 'EOS-?1D\s*(MARK\s*III|MK\s*3)\b') {
    $off = $ci.Raw
    if ($off + 0x179 -lt $Bytes.Length) {
      $sc = [uint32](Read-U32 $Bytes ($off + 0x176) $true)
      if ($sc -gt 0 -and $sc -lt 9999999) {
        $Result.shutterCount = [int]($sc + 1)
        $Result.method = 'Canon CameraInfo1DmkIII[0x176]'
        return
      }
    }
  }

  if ($ci -and $ci.Type -eq 7) {
    $off = $ci.Raw
    $fileIdxOffsets = @(0x1bb, 0x1c3, 0x1cb, 0x1d3, 0x1e3)
    $dirIdxOffsets = @(0x1c7, 0x1cf, 0x1d7, 0x1df, 0x1ef)
    for ($i = 0; $i -lt $fileIdxOffsets.Count; $i++) {
      $fo = $fileIdxOffsets[$i]
      $dfo = $dirIdxOffsets[$i]
      if ($fo + 3 -ge $ci.Count -or $dfo + 3 -ge $ci.Count) { continue }
      $fileIdx = [uint32](Read-U32 $Bytes ($off + $fo) $true)
      $dirIdx = [uint32](Read-U32 $Bytes ($off + $dfo) $true)
      if ($fileIdx -gt 0 -and $fileIdx -lt 10000 -and $dirIdx -ge 100 -and $dirIdx -lt 1000) {
        $Result.fileNumber = '{0}-{1}' -f $dirIdx, (($fileIdx + 1).ToString('0000'))
        $Result.fileIndex = [int]$fileIdx
        $Result.dirIndex = [int]$dirIdx
        break
      }
    }
  }
}

$script:SonyDecipher = [byte[]]@(
0,1,50,177,10,14,135,40,2,204,202,173,27,220,8,237,100,134,240,79,140,108,184,203,105,196,44,3,151,182,147,124,
20,243,226,62,48,142,215,96,28,161,171,55,236,117,190,35,21,106,89,63,208,185,150,181,80,39,136,227,129,148,224,192,
4,92,198,232,95,75,112,56,159,130,128,81,43,197,69,73,155,33,82,83,84,133,11,93,97,218,123,85,38,36,7,110,
54,91,71,183,217,74,162,223,191,18,37,188,30,127,86,234,16,230,207,103,77,60,145,131,225,49,179,111,244,5,138,70,
200,24,118,104,189,172,146,42,19,233,15,163,122,219,61,212,231,58,26,87,175,32,66,178,158,195,139,242,213,211,164,126,
31,152,156,238,116,165,166,167,216,94,176,180,52,206,168,121,119,90,193,137,174,154,17,51,157,245,57,25,101,120,22,113,
210,169,68,99,64,41,186,160,143,228,214,59,132,13,194,78,88,221,153,34,107,201,187,23,6,229,125,102,67,98,246,205,
53,144,46,65,141,109,170,9,115,149,12,241,29,222,76,47,45,247,209,114,235,239,72,199,248,249,250,251,252,253,254,255
)

function Unmask-Sony {
  param([byte[]]$Data)
  $out = [byte[]]::new($Data.Length)
  for ($i = 0; $i -lt $Data.Length; $i++) {
    $out[$i] = $script:SonyDecipher[$Data[$i]]
  }
  return $out
}

function Parse-SonyMakerNote {
  param([byte[]]$Bytes, [int]$MakerOff, [bool]$LittleEndian, [hashtable]$Result, [int]$Correction = 0)
  $mn = Parse-IFD $Bytes $MakerOff $MakerOff $LittleEndian
  $t9050 = $mn[0x9050]
  if ($t9050 -and $t9050.Type -eq 7 -and $t9050.Count -gt 60) {
    $dataOff = $t9050.Raw + $Correction
    if ($dataOff -ge 0 -and $dataOff + $t9050.Count -le $Bytes.Length) {
      $slice = [byte[]]::new($t9050.Count)
      [Array]::Copy($Bytes, $dataOff, $slice, 0, $t9050.Count)
      $plain = Unmask-Sony $slice
      $model = ([string]$Result.model).ToUpperInvariant()
      $offsets = @()
      if ($model -match 'ILCE-(6700|7CM2|7CR)') {
        $offsets = @(0x000a)
      } elseif ($model -match 'ILCE-(7M4|7RM5|7SM3|1\b)|ILME-(FX3|FX30)|ZV-E1\b') {
        $offsets = @(0x003a)
      } elseif ($model -match 'ILCE-(7M3|7RM3|7RM4A?|9M?2?|6[1-6]\d\d|7C\b)|ZV-E10|ILCA-99M2') {
        $offsets = @(0x003a, 0x0050)
      } else {
        $offsets = @(0x0032, 0x004c)
      }

      foreach ($off in $offsets) {
        if ($off + 3 -ge $plain.Length) { continue }
        $sc = [uint32](Read-U32 $plain $off $true)
        if ($sc -gt 0 -and $sc -lt 600000) {
          $Result.shutterCount = [int]$sc
          $Result.method = ('Sony 9050[0x{0}]' -f $off.ToString('x4'))
          return
        }
      }
    }
  }
}

function Parse-FujiMakerNote {
  param([byte[]]$Bytes, [int]$MakerOff, [hashtable]$Result)
  if ($MakerOff + 11 -ge $Bytes.Length) { return }
  if ((Read-S4 $Bytes $MakerOff) -ne 'FUJI' -or (Read-S4 $Bytes ($MakerOff + 4)) -ne 'FILM') { return }
  $ifdRelOff = $Bytes[$MakerOff + 8] -bor ($Bytes[$MakerOff + 9] -shl 8)
  if ($ifdRelOff -lt 8 -or $ifdRelOff -gt 256) { return }
  $ifdOff = $MakerOff + $ifdRelOff
  $mn = Parse-IFD $Bytes $ifdOff $MakerOff $true
  $shot = $mn[0x1438]
  if ($shot -and $shot.Value -gt 0 -and $shot.Value -lt 2000000) {
    $Result.shutterCount = [int]$shot.Value
    $Result.method = 'Fujifilm MakerNote 0x1438'
  }
}

function Parse-OlympusMakerNote {
  param([byte[]]$Bytes, [int]$MakerOff, [int]$TiffBase, [bool]$LittleEndian, [hashtable]$Result)
  if ($MakerOff + 7 -ge $Bytes.Length) { return }
  $ifdOff = $MakerOff
  $ifdBase = $MakerOff
  $ifdLE = $LittleEndian
  if ((Read-S4 $Bytes $MakerOff) -eq 'OLYM' -and (Read-S4 $Bytes ($MakerOff + 4)) -eq "PUS$([char]0)") {
    $ifdLE = $Bytes[$MakerOff + 8] -eq 0x49
    $ifdBase = $MakerOff
    $ifdOff = $MakerOff + 12
  } elseif ((Read-S4 $Bytes $MakerOff) -eq 'OM S' -and (Read-S4 $Bytes ($MakerOff + 4)) -eq 'YSTE') {
    $ifdLE = $Bytes[$MakerOff + 12] -eq 0x49
    $ifdBase = $MakerOff
    $ifdOff = $MakerOff + 16
  } elseif ((Read-S4 $Bytes $MakerOff) -eq 'OLYM' -and $Bytes[$MakerOff + 4] -eq 0x50) {
    $ifdBase = $TiffBase
    $ifdOff = $MakerOff + 8
  }
  $mn = Parse-IFD $Bytes $ifdOff $ifdBase $ifdLE
  # Full-release validation has not confirmed a reliable in-file shutter count for ORF.
}

function Parse-Exif {
  param([byte[]]$Bytes)
  $r = New-Result
  $tb = 0

  if ((Read-U16 $Bytes 0 $false) -eq 0xFFD8) {
    $p = 2
    while ($p -lt $Bytes.Length - 4) {
      $marker = Read-U16 $Bytes $p $false
      $len = Read-U16 $Bytes ($p + 2) $false
      if ($marker -eq 0xFFE1 -and (Read-S4 $Bytes ($p + 4)) -eq 'Exif') {
        $tb = $p + 10
        break
      }
      if ($marker -eq 0xFFDA) { break }
      if ($len -lt 2) { break }
      $p += 2 + $len
    }
    if ($tb -eq 0) { return $r }
  }

  $order = Read-U16 $Bytes $tb $false
  $le = $order -eq 0x4949
  if (-not $le -and $order -ne 0x4D4D) { return $r }
  $tiffMagic = Read-U16 $Bytes ($tb + 2) $le
  if ($tiffMagic -ne 0x002A -and $tiffMagic -ne 0x4F52 -and $tiffMagic -ne 0x0055) { return $r }

  $ifd0 = Parse-IFD $Bytes ($tb + (Read-U32 $Bytes ($tb + 4) $le)) $tb $le
  $r.make = Get-IFDString $Bytes $tb $ifd0[0x010F]
  $r.model = Get-IFDString $Bytes $tb $ifd0[0x0110]
  $r.dateTime = Get-IFDString $Bytes $tb $ifd0[0x0132]

  $ex = @{}
  if ($ifd0.ContainsKey(0x8769)) {
    $ex = Parse-IFD $Bytes ($tb + $ifd0[0x8769].Value) $tb $le
  }
  if ($ex.ContainsKey(0x8827)) { $r.iso = [int]$ex[0x8827].Value }
  if ($ex.ContainsKey(0xA434)) { $r.lensModel = Get-IFDString $Bytes $tb $ex[0xA434] }

  $mk = ([string]$r.make).ToUpperInvariant()
  if ($ex.ContainsKey(0x927C)) {
    $mo = $tb + $ex[0x927C].Value
    if ($mk.Contains('CANON')) {
      Parse-CanonMakerNote $Bytes $mo $le $r
    } elseif ($mk.Contains('NIKON')) {
      if ((Read-S4 $Bytes $mo) -eq 'Niko') {
        $nb = $mo + 10
        $le2 = (Read-U16 $Bytes $nb $false) -eq 0x4949
        $io2 = Read-U32 $Bytes ($nb + 4) $le2
        $mn = Parse-IFD $Bytes ($nb + $io2) $nb $le2
        if ($mn.ContainsKey(0x00A7) -and $mn[0x00A7].Value -gt 0) {
          $r.shutterCount = [int]$mn[0x00A7].Value
          $r.method = 'Nikon MakerNote 0x00A7'
        }
      }
    } elseif ($mk.Contains('SONY')) {
      Parse-SonyMakerNote $Bytes $mo $le $r 0
    } elseif ($mk.Contains('FUJIFILM')) {
      Parse-FujiMakerNote $Bytes $mo $r
    } elseif ($mk.Contains('OLYMPUS') -or $mk.Contains('OM ') -or $mk.Contains('OM-DIGITAL')) {
      Parse-OlympusMakerNote $Bytes $mo $tb $le $r
    }
  }

  if (-not $r.shutterCount -and $ifd0.ContainsKey(0xC634)) {
    $dp = $ifd0[0xC634].Raw
    if ((Read-S4 $Bytes $dp) -eq 'Adob' -and $Bytes[$dp + 4] -eq 0x65 -and $Bytes[$dp + 5] -eq 0x00 -and (Read-S4 $Bytes ($dp + 6)) -eq 'MakN') {
      $origBase = [uint32](Read-U32 $Bytes ($dp + 16) $false)
      $ifdAbs = $dp + 20
      $corr = $ifdAbs - $origBase
      $mn = Parse-IFD $Bytes $ifdAbs 0 $true
      if ($mk.Contains('SONY')) {
        Parse-SonyMakerNote $Bytes $ifdAbs $true $r $corr
      } elseif ($mk.Contains('NIKON') -and $mn.ContainsKey(0x927C)) {
        $mo2 = $mn[0x927C].Raw + $corr
        if ((Read-S4 $Bytes $mo2) -eq 'Niko') {
          $nb = $mo2 + 10
          $le2 = (Read-U16 $Bytes $nb $false) -eq 0x4949
          $io2 = Read-U32 $Bytes ($nb + 4) $le2
          $mn2 = Parse-IFD $Bytes ($nb + $io2) $nb $le2
          if ($mn2.ContainsKey(0x00A7) -and $mn2[0x00A7].Value -gt 0) {
            $r.shutterCount = [int]$mn2[0x00A7].Value
            $r.method = 'Nikon DNG MakerNote 0x00A7'
          }
        }
      }
    }
  }

  return $r
}

function Parse-RAF {
  param([byte[]]$Bytes)
  if ((Read-S4 $Bytes 0) -ne 'FUJI' -or (Read-S4 $Bytes 4) -ne 'FILM') { return $null }
  if ($Bytes.Length -lt 0x60) { return $null }
  $jpegOff = [int](Read-U32 $Bytes 0x54 $false)
  $jpegLen = [int](Read-U32 $Bytes 0x58 $false)
  if ($jpegOff -lt 64 -or $jpegOff -ge $Bytes.Length -or $jpegLen -lt 100) { return $null }
  $end = [Math]::Min($jpegOff + $jpegLen, $Bytes.Length)
  if ($Bytes[$jpegOff] -ne 0xFF -or $Bytes[$jpegOff + 1] -ne 0xD8) { return $null }
  $slice = [byte[]]::new($end - $jpegOff)
  [Array]::Copy($Bytes, $jpegOff, $slice, 0, $slice.Length)
  return Parse-Exif $slice
}

function Parse-CMTs {
  param([byte[]]$Bytes, [int]$Start, [int]$End, [hashtable]$Result)
  $p = $Start
  while ($p + 7 -lt $End) {
    $sz = [int](Read-U32 $Bytes $p $false)
    if ($sz -lt 8) { break }
    $t = Read-S4 $Bytes ($p + 4)
    if ($t -in @('CMT1', 'CMT2', 'CMT3')) {
      Parse-CMT $Bytes ($p + 8) ($sz - 8) $t $Result
    }
    $p += $sz
  }
}

function Parse-CMT {
  param([byte[]]$Bytes, [int]$Base, [int]$Size, [string]$Cmt, [hashtable]$Result)
  if ($Base + 7 -ge $Bytes.Length) { return }
  $le = (Read-U16 $Bytes $Base $false) -eq 0x4949
  if ((Read-U16 $Bytes ($Base + 2) $le) -ne 0x002A) { return }
  $io = [int](Read-U32 $Bytes ($Base + 4) $le)
  $p = $Base + $io
  if ($p + 1 -ge $Bytes.Length) { return }
  $n = Read-U16 $Bytes $p $le
  $p += 2
  for ($i = 0; $i -lt [Math]::Min($n, 300); $i++) {
    if ($p + 11 -ge $Bytes.Length) { break }
    $tag = Read-U16 $Bytes $p $le
    $type = Read-U16 $Bytes ($p + 2) $le
    $cnt = [int](Read-U32 $Bytes ($p + 4) $le)
    $raw = [uint32](Read-U32 $Bytes ($p + 8) $le)
    if ($Cmt -eq 'CMT1') {
      if ($tag -eq 0x0110 -and $type -eq 2) { $Result.model = Read-Ascii $Bytes ($Base + $raw) $cnt }
      if ($tag -eq 0x0132 -and $type -eq 2) { $Result.dateTime = Read-Ascii $Bytes ($Base + $raw) $cnt }
    } elseif ($Cmt -eq 'CMT2') {
      if ($tag -eq 0x8827 -and $type -eq 3 -and $cnt -eq 1) { $Result.iso = Read-U16 $Bytes ($p + 8) $le }
      if ($tag -eq 0xA434 -and $type -eq 2) { $Result.lensModel = Read-Ascii $Bytes ($Base + $raw) $cnt }
    } elseif ($Cmt -eq 'CMT3') {
      if ($tag -eq 0x0007 -and $type -eq 2) { $Result.firmware = Read-Ascii $Bytes ($Base + $raw) $cnt }
    }
    $p += 12
  }
}

function Parse-CR3 {
  param([byte[]]$Bytes)
  $res = New-Result
  $res.make = 'Canon'
  $moovOff = -1
  $moovEnd = -1
  $p = 0
  while ($p + 7 -lt $Bytes.Length) {
    $sz = [int](Read-U32 $Bytes $p $false)
    if ($sz -lt 8) { break }
    if ((Read-S4 $Bytes ($p + 4)) -eq 'moov') {
      $moovOff = $p
      $moovEnd = $p + $sz
      break
    }
    $p += $sz
  }
  if ($moovOff -lt 0) { return $null }

  $canonUuid = [byte[]](0x85,0xc0,0xb6,0x87,0x82,0x0f,0x11,0xe0,0x81,0x11,0xf4,0xce,0x46,0x2b,0x6a,0x48)
  $p = $moovOff + 8
  while ($p + 23 -lt $moovEnd) {
    $sz = [int](Read-U32 $Bytes $p $false)
    if ($sz -lt 8) { break }
    if ((Read-S4 $Bytes ($p + 4)) -eq 'uuid') {
      $ok = $true
      for ($i = 0; $i -lt 16; $i++) {
        if ($Bytes[$p + 8 + $i] -ne $canonUuid[$i]) { $ok = $false; break }
      }
      if ($ok) {
        Parse-CMTs $Bytes ($p + 24) ($p + $sz) $res
        break
      }
    }
    $p += $sz
  }

  $co64s = [System.Collections.Generic.List[int]]::new()
  function Scan-Boxes([byte[]]$LocalBytes, [int]$Start, [int]$End, [int]$Depth, [System.Collections.Generic.List[int]]$Boxes) {
    $pp = $Start
    while ($pp + 7 -lt $End) {
      $sz = [int](Read-U32 $LocalBytes $pp $false)
      if ($sz -lt 8) { break }
      $t = Read-S4 $LocalBytes ($pp + 4)
      if ($t -eq 'co64') { [void]$Boxes.Add($pp) }
      if ($Depth -lt 6 -and $t -in @('moov','trak','mdia','minf','stbl','udta','meta')) {
        Scan-Boxes $LocalBytes ($pp + 8) ([Math]::Min($pp + $sz, $End)) ($Depth + 1) $Boxes
      }
      $pp += $sz
    }
  }
  Scan-Boxes $Bytes ($moovOff + 8) $moovEnd 0 $co64s

  foreach ($co64Off in $co64s) {
    $entries = [int](Read-U32 $Bytes ($co64Off + 12) $false)
    if ($entries -lt 1) { continue }
    $ck = [int64](Read-U64BE $Bytes ($co64Off + 16))
    if ($ck + 8 -gt $Bytes.Length) { continue }
    $frt = Read-U16 $Bytes ($ck + 4) $true
    $frs = [uint32](Read-U32 $Bytes $ck $true)
    if ($frt -ne 1 -or $frs -lt 8 -or $frs -gt 256) { continue }

    $cp = 0
    while ($ck + $cp + 7 -lt $Bytes.Length) {
      $rs = [uint32](Read-U32 $Bytes ($ck + $cp) $true)
      $rt = Read-U16 $Bytes ($ck + $cp + 4) $true
      if ($rs -lt 8 -or $rs -gt 0x40000) { break }
      if ($rt -eq 8) {
        $pd = $ck + $cp + 8
        $psz = $rs - 8
        for ($ti = 0; $ti -lt [Math]::Min(64, $psz - 8); $ti++) {
          $isLE = $Bytes[$pd + $ti] -eq 0x49 -and $Bytes[$pd + $ti + 1] -eq 0x49 -and $Bytes[$pd + $ti + 2] -eq 0x2A -and $Bytes[$pd + $ti + 3] -eq 0x00
          $isBE = $Bytes[$pd + $ti] -eq 0x4D -and $Bytes[$pd + $ti + 1] -eq 0x4D -and $Bytes[$pd + $ti + 2] -eq 0x00 -and $Bytes[$pd + $ti + 3] -eq 0x2A
          if ($isLE -or $isBE) {
            $tb = $pd + $ti
            $le = $Bytes[$tb] -eq 0x49
            $io = [int](Read-U32 $Bytes ($tb + 4) $le)
            if ($tb + $io + 1 -gt $Bytes.Length) { break }
            $nc = Read-U16 $Bytes ($tb + $io) $le
            if ($nc -gt 100) { break }
            $ep = $tb + $io + 2
            for ($ei = 0; $ei -lt $nc; $ei++) {
              if ($ep + 11 -ge $Bytes.Length) { break }
              $tag = Read-U16 $Bytes $ep $le
              $typ = Read-U16 $Bytes ($ep + 2) $le
              $cnt = [int](Read-U32 $Bytes ($ep + 4) $le)
              $raw = [uint32](Read-U32 $Bytes ($ep + 8) $le)
              if ($tag -eq 0x000d -and $typ -eq 7 -and $cnt -ge 100) {
                $bo = $tb + $raw
                $res._cr3BlockSize = $cnt
                $offsets = @(
                  @{ minCnt = 0x0d2d; off = 0x0d29; label = 'R6II/R8/R50'; model = '\bEOS\s+R6\s+MARK\s+II\b|\bEOS\s+R8\b|\bEOS\s+R50\b' }
                  @{ minCnt = 0x0af5; off = 0x0af1; label = 'R5/R6/R3/R5 C'; model = '\bEOS\s+R5\b|\bEOS\s+R6\b|\bEOS\s+R3\b|\bEOS\s+R5\s+C\b' }
                )
                foreach ($o in $offsets) {
                  if ($o.model -and $res.model -notmatch $o.model) { continue }
                  if ($cnt -ge $o.minCnt -and $bo + $o.off + 3 -lt $Bytes.Length) {
                    $sc = [uint32](Read-U32 $Bytes ($bo + $o.off) $true)
                    if ($sc -gt 0 -and $sc -lt 999999) {
                      $res.shutterCount = [int]$sc
                      $res.method = ('CTMD rec.8 -> tag 0x000D -> offset 0x{0} ({1})' -f $o.off.ToString('X'), $o.label)
                      return $res
                    }
                  }
                }
                $offsets16 = @(
                  @{ minCnt = 0x086f; off = 0x086d; label = 'R6III/R50V/R1'; model = '(\bEOS\s+)?R6\s+MARK\s+III\b|\bR50\s+V\b|\bEOS\s+R1\b|\bR1\b' }
                )
                foreach ($o in $offsets16) {
                  if ($o.model -and $res.model -notmatch $o.model) { continue }
                  if ($cnt -ge $o.minCnt -and $bo + $o.off + 1 -lt $Bytes.Length) {
                    $sc = Read-U16 $Bytes ($bo + $o.off) $true
                    if ($sc -gt 0 -and $sc -lt 65535) {
                      $res.shutterCount = [int]$sc
                      $res.method = ('CTMD rec.8 -> tag 0x000D -> offset 0x{0} ({1})' -f $o.off.ToString('X'), $o.label)
                      return $res
                    }
                  }
                }
              }
              $ep += 12
            }
            break
          }
        }
      }
      $cp += $rs
    }
  }
  return $res
}

function Parse-File {
  param([byte[]]$Bytes)
  if ($Bytes.Length -ge 8 -and (Read-S4 $Bytes 4) -eq 'ftyp') {
    $cr3 = Parse-CR3 $Bytes
    if ($cr3) { return $cr3 }
    return Parse-Exif $Bytes
  }
  if ($Bytes.Length -ge 8 -and (Read-S4 $Bytes 0) -eq 'FUJI' -and (Read-S4 $Bytes 4) -eq 'FILM') {
    $raf = Parse-RAF $Bytes
    if ($raf) { return $raf }
    return Parse-Exif $Bytes
  }
  return Parse-Exif $Bytes
}

$accepted = @('.cr2','.cr3','.nef','.arw','.raf','.orf','.rw2','.dng','.jpg','.jpeg','.mrw','.nrw')
$items = Get-ChildItem -File -Path $Path -Recurse:$Recurse | Where-Object { $accepted -contains $_.Extension.ToLowerInvariant() } | Sort-Object FullName
$rows = foreach ($file in $items) {
  $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
  $parsed = Parse-File $bytes
  [pscustomobject]@{
    RelativePath = $file.FullName.Substring((Resolve-Path $Path).Path.Length).TrimStart('\')
    File = $file.Name
    Make = $parsed.make
    Model = $parsed.model
    ShutterCount = $parsed.shutterCount
    Method = $parsed.method
    FileNumber = $parsed.fileNumber
    CR3Block = $parsed._cr3BlockSize
  }
}

$rows | Format-Table -AutoSize | Out-String -Width 260 | Write-Output

$summary = $rows | Group-Object Make | Sort-Object Name | ForEach-Object {
  $withShutter = @($_.Group | Where-Object { $_.ShutterCount -ne $null }).Count
  [pscustomobject]@{
    Make = if ($_.Name) { $_.Name } else { '(empty)' }
    Files = @($_.Group).Count
    WithShutter = $withShutter
  }
}

"SUMMARY"
$summary | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
