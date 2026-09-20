#requires -version 5.1
<#
.SYNOPSIS
    DiscordStorage - Otomatik Build, İmza ve Dağıtım (Windows Desktop)
.DESCRIPTION
    Flutter Windows projesini release modda derler, Inno Setup ile installer oluşturur,
    signtool ile imzalar, agy ile sürüm notlarını üretir ve GitHub Release yapar.
.NOTES
    Proje kökünde çalıştırılmalıdır.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# -- Renk & Log Yardımcıları -------------------------------------------------------
function Write-Step   ([string]$msg) { Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-Info   ([string]$msg) { Write-Host "   [i] $msg" -ForegroundColor DarkGray }
function Write-Ok     ([string]$msg) { Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Warn   ([string]$msg) { Write-Host "   [!] $msg" -ForegroundColor Yellow }
function Write-Err    ([string]$msg) { Write-Host "   [X] $msg" -ForegroundColor Red }

# -- İşlem Süresi Ölçümü -----------------------------------------------------------
function Format-Elapsed ([TimeSpan]$ts) {
    if ($ts.TotalMinutes -ge 1) {
        return "{0:N0}dk {1:N0}sn" -f [Math]::Floor($ts.TotalMinutes), $ts.Seconds
    }
    return "{0:N1}sn" -f $ts.TotalSeconds
}

try {
    $scriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # -- 0) Yapılandırma -----------------------------------------------------------
    $projectRoot = if (Test-Path (Join-Path $PSScriptRoot "pubspec.yaml")) {
        $PSScriptRoot
    } else {
        Split-Path -Parent $PSScriptRoot
    }
    Set-Location $projectRoot

    $projectsParent = Split-Path -Parent $projectRoot
    $outputsRoot    = if (Test-Path (Join-Path $projectsParent "Outputs")) {
        Join-Path $projectsParent "Outputs"
    } else {
        "C:\Users\Kerem\Projects\Outputs"
    }

    $appName       = "DiscordStorage"
    $innoSetupPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    
    # ISS dosyasını kontrol et (InnoSetup.iss veya İnnoSetup.iss)
    $issFilePath = Join-Path $projectRoot "InnoSetup.iss"
    if (-not (Test-Path $issFilePath)) {
        $issAlt = Join-Path $projectRoot "İnnoSetup.iss"
        if (Test-Path $issAlt) { $issFilePath = $issAlt }
    }

    # SignTool & PFX
    $signtool = "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x86\signtool.exe"
    if (-not (Test-Path $signtool)) {
        # Alternatif SDK yolları
        $sdkMatches = @(Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\bin" -Recurse -Filter "signtool.exe" -ErrorAction SilentlyContinue)
        if ($sdkMatches.Count -gt 0) {
            $signtool = $sdkMatches[0].FullName
        }
    }

    $imzaDir           = if (Test-Path (Join-Path $projectsParent "imza-bilgileri")) {
        Join-Path $projectsParent "imza-bilgileri"
    } else {
        "C:\Users\Kerem\Projects\imza-bilgileri"
    }
    $pfxPath           = Join-Path $imzaDir "KeremKuyucu.pfx"
    $pfxPropertiesPath = Join-Path $imzaDir "pfx.properties"
    $pfxPassPlain      = $null

    # Inno installer dosya adı ipucu
    $installerNameHint = "DiscordStorage"
    $timestampServers  = @(
        "http://timestamp.digicert.com",
        "http://timestamp.sectigo.com",
        "http://tsa.starfieldtech.com",
        "http://timestamp.globalsign.com/tsa/r6advanced1"
    )

    # -- Yardımcı Fonksiyonlar -----------------------------------------------------
    function Ensure-Dir ([string]$path) {
        if (-not (Test-Path $path)) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }

    function Escape-ProcessArg ([string]$arg) {
        if ($arg -match '\s') {
            return "`"$arg`""
        }
        return $arg
    }

    function Run-Exe {
        <#
        .SYNOPSIS
            Harici prosesi çalıştırır; stdout/stderr async okunur (deadlock önlenir).
        #>
        param(
            [Parameter(Mandatory = $true)][string]$FilePath,
            [Parameter(Mandatory = $false)][string[]]$ArgumentList = @(),
            [Parameter(Mandatory = $false)][string]$WorkingDirectory = $projectRoot,
            [Parameter(Mandatory = $false)][switch]$AllowNonZero
        )

        $resolvedPath = $FilePath
        $prependArgs  = @()
        $cmd = Get-Command $FilePath -ErrorAction SilentlyContinue
        if ($cmd) {
            $resolvedPath = $cmd.Source
            if ($resolvedPath -match '\.(bat|cmd)$') {
                $prependArgs  = @("/c", $resolvedPath)
                $resolvedPath = "$env:SystemRoot\System32\cmd.exe"
            }
        }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $resolvedPath
        $psi.WorkingDirectory       = $WorkingDirectory
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $allArgs = $prependArgs + $ArgumentList
        if ($allArgs.Count -gt 0) {
            $psi.Arguments = ($allArgs | ForEach-Object { Escape-ProcessArg $_ }) -join ' '
        }

        $proc           = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi

        $stdoutBuilder = New-Object System.Text.StringBuilder
        $stderrBuilder = New-Object System.Text.StringBuilder

        $onStdout = { if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) } }
        $onStderr = { if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) } }

        $stdoutEvent = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -Action $onStdout -MessageData $stdoutBuilder
        $stderrEvent = Register-ObjectEvent -InputObject $proc -EventName ErrorDataReceived  -Action $onStderr -MessageData $stderrBuilder

        Write-Host "   >> $FilePath $($psi.Arguments)" -ForegroundColor DarkGray

        try {
            [void]$proc.Start()
            $proc.BeginOutputReadLine()
            $proc.BeginErrorReadLine()
            $proc.WaitForExit()

            Start-Sleep -Milliseconds 200

            $stdout = $stdoutBuilder.ToString().TrimEnd()
            $stderr = $stderrBuilder.ToString().TrimEnd()

            if ($stdout) { Write-Host $stdout }
            if ($stderr -and $proc.ExitCode -ne 0) {
                Write-Host $stderr -ForegroundColor Red
            }
            elseif ($stderr) {
                Write-Host $stderr -ForegroundColor DarkYellow
            }

            if ($proc.ExitCode -ne 0 -and -not $AllowNonZero) {
                throw "Komut basarisiz (ExitCode=$($proc.ExitCode)): $FilePath $($psi.Arguments)"
            }
            return $proc.ExitCode
        }
        finally {
            Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
            Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
            Remove-Job -Id $stdoutEvent.Id -Force -ErrorAction SilentlyContinue
            Remove-Job -Id $stderrEvent.Id -Force -ErrorAction SilentlyContinue
            $proc.Dispose()
        }
    }

    function Invoke-AgyReleaseNotes ([string]$ver) {
        <#
        .SYNOPSIS
            Antigravity CLI (agy) kullanarak git değişikliklerinden sürüm notlarını otomatik oluşturur.
        #>
        $agyCmd = Get-Command "agy" -ErrorAction SilentlyContinue
        if (-not $agyCmd) {
            Write-Warn "Antigravity CLI ('agy') sistemde bulunamadı. Sürüm notları otomatik oluşturulamadı."
            return $false
        }

        Write-Step "Antigravity CLI (agy) ile Sürüm Notları Oluşturuluyor (v$ver)..."
        Write-Info "Son commit logları ve değişiklikler inceleniyor..."

        $agyPrompt = "DiscordStorage projesinin v$ver sürümü için sürüm notlarını oluştur. " +
            "1. Git commit loglarını ve son değişiklikleri incele. " +
            "2. RELEASE_TEMPLATE.md şablonuna birebir uyarak 'RELEASE_$ver.md' dosyasını oluştur. " +
            "Dosyayı doğrudan proje kök dizininde oluştur."

        try {
            $exitCode = Run-Exe -FilePath "agy" -ArgumentList @(
                "-p", $agyPrompt,
                "--add-dir", $projectRoot,
                "--dangerously-skip-permissions"
            ) -WorkingDirectory $projectRoot -AllowNonZero

            $ghNotes = Join-Path $projectRoot "RELEASE_$ver.md"
            if (Test-Path $ghNotes) {
                Write-Ok "GitHub sürüm notu hazır: RELEASE_$ver.md"
                return $true
            }
            return ($exitCode -eq 0)
        }
        catch {
            Write-Warn "Antigravity CLI çalıştırılırken hata oluştu: $($_.Exception.Message)"
            return $false
        }
    }

    # -- 1) Versiyon Bilgisi & Doğrulama (pubspec.yaml vs InnoSetup.iss) ------------
    Write-Step "Versiyon Bilgileri Doğrulanıyor..."
    $pubspecPath    = Join-Path $projectRoot "pubspec.yaml"
    $currentVersion = $null

    if (Test-Path $pubspecPath) {
        $versionLine = Get-Content $pubspecPath | Select-String "^\s*version:\s*"
        if ($versionLine) {
            $currentVersion = ($versionLine.ToString().Split(":")[1].Trim().Split("+")[0]).Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($currentVersion)) {
        Write-Warn "Versiyon bilgisi pubspec.yaml'dan alınamadı."
        $userInput = Read-Host "Lütfen versiyon numarasını girin (Örn: 0.2.1-alpha)"
        if ([string]::IsNullOrWhiteSpace($userInput)) {
            throw "HATA: Versiyon girmeden devam edilemez!"
        }
        $currentVersion = $userInput.Trim()
    }

    Write-Info "pubspec.yaml sürümü : $currentVersion"

    # Inno Setup (.iss) dosyasındaki AppVersion kontrolü ve doğrulaması
    if (Test-Path $issFilePath) {
        $issContent = Get-Content $issFilePath -Raw -Encoding UTF8
        $issMatch = [regex]::Match($issContent, '(?m)^\s*#define\s+AppVersion\s+["'']?([^"''\r\n]+)["'']?')
        if (-not $issMatch.Success) {
            $issMatch = [regex]::Match($issContent, 'AppVersion\s+["'']?([^"''\r\n]+)["'']?')
        }

        if ($issMatch.Success) {
            $issVersionRaw = $issMatch.Groups[1].Value.Trim()
            Write-Info "InnoSetup.iss sürümü: $issVersionRaw"

            # Kıyaslama için normalizasyon (başındaki 'v' önekini kaldır)
            $normYaml = $currentVersion -replace '^v',''
            $normIss  = $issVersionRaw -replace '^v',''

            if ($normYaml -ne $normIss) {
                Write-Host ""
                Write-Err "=================================================================="
                Write-Err " SÜRÜM UYUŞMAZLIĞI TESPİT EDİLDİ!"
                Write-Err "  pubspec.yaml sürümü : $currentVersion"
                Write-Err "  InnoSetup.iss sürümü: $issVersionRaw"
                Write-Err "=================================================================="
                Write-Host ""

                $syncPrompt = Read-Host "InnoSetup.iss dosyasındaki sürüm pubspec.yaml ($currentVersion) ile güncellensin mi? (E/H)"
                if ($syncPrompt -eq 'E' -or $syncPrompt -eq 'e' -or $syncPrompt -eq 'Y' -or $syncPrompt -eq 'y') {
                    $newIssContent = [regex]::Replace(
                        $issContent,
                        '(?m)(^\s*#define\s+AppVersion\s+["''])[^"'']+(["''])',
                        "`${1}v$normYaml`${2}"
                    )
                    Set-Content -Path $issFilePath -Value $newIssContent -Encoding UTF8
                    Write-Ok "InnoSetup.iss dosyasındaki sürüm 'v$normYaml' olarak güncellendi."
                } else {
                    throw "HATA: pubspec.yaml ($currentVersion) ile InnoSetup.iss ($issVersionRaw) sürümleri eşleşmiyor! Lütfen sürümleri eşitleyip tekrar deneyin."
                }
            } else {
                Write-Ok "Sürüm doğrulaması başarılı: pubspec.yaml ($currentVersion) == InnoSetup.iss ($issVersionRaw)"
            }
        } else {
            Write-Warn "InnoSetup.iss dosyasında AppVersion tanımı bulunamadı, doğrulama atlandı."
        }
    } else {
        Write-Warn "InnoSetup.iss dosyası bulunamadı, doğrulama atlandı."
    }

    $verFolder = if ($currentVersion -match '^v') { $currentVersion } else { "v$currentVersion" }
    $distPath  = Join-Path (Join-Path $outputsRoot $appName) $verFolder
    Ensure-Dir $distPath

    $verPadded = $currentVersion.PadRight(18)
    Write-Host ""
    Write-Host "+===========================================================+" -ForegroundColor Cyan
    Write-Host "|   DiscordStorage Build & Release  -  v$verPadded  |" -ForegroundColor Cyan
    Write-Host "+===========================================================+" -ForegroundColor Cyan
    Write-Info "Proje Dizini : $projectRoot"
    Write-Info "Çıktı Dizini : $distPath"

    # -- 2) Sistem & Ön Kontroller -------------------------------------------------
    Write-Host ""
    Write-Host "+===========================================================+" -ForegroundColor Cyan
    Write-Host "|             Sistem ve Araç Ön Kontrolleri                 |" -ForegroundColor Cyan
    Write-Host "+===========================================================+" -ForegroundColor Cyan

    # A) Flutter SDK
    $flutterCheck = Get-Command "flutter" -ErrorAction SilentlyContinue
    if (-not $flutterCheck) {
        throw "Flutter SDK sistemde bulunamadı! PATH ortam değişkeninizi kontrol edin."
    }
    Write-Ok "Flutter SDK hazır: $($flutterCheck.Source)"

    # B) Inno Setup Compiler
    if (-not (Test-Path $innoSetupPath)) {
        throw "Inno Setup Compiler (ISCC.exe) bulunamadı: $innoSetupPath"
    }
    Write-Ok "Inno Setup Compiler hazır: $innoSetupPath"

    if (-not (Test-Path $issFilePath)) {
        throw "Inno Setup script dosyası bulunamadı: $issFilePath"
    }
    Write-Ok "Inno Setup Scripti hazır: $(Split-Path $issFilePath -Leaf)"

    # C) SignTool & PFX Sertifikası
    if (-not (Test-Path $signtool)) {
        throw "SignTool (signtool.exe) bulunamadı: $signtool"
    }
    Write-Ok "SignTool hazır: $signtool"

    if (-not (Test-Path $pfxPath)) {
        throw "PFX sertifikası bulunamadı: $pfxPath"
    }
    Write-Ok "PFX Sertifikası hazır: $pfxPath"

    # PFX Şifresi
    if (Test-Path $pfxPropertiesPath) {
        $propLine = Get-Content $pfxPropertiesPath | Select-String "^\s*password\s*="
        if ($propLine) {
            $pfxPassPlain = ($propLine.ToString().Split("=", 2)[1]).Trim()
            Write-Ok "PFX şifresi pfx.properties dosyasından okundu."
        }
    }
    if ([string]::IsNullOrWhiteSpace($pfxPassPlain)) {
        Write-Warn "pfx.properties bulunamadı veya password satırı yok."
        $pfxPassSecure = Read-Host "Lütfen PFX sertifika şifresini girin (güvenli)" -AsSecureString
        $bstr          = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($pfxPassSecure)
        $pfxPassPlain  = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        if ([string]::IsNullOrWhiteSpace($pfxPassPlain)) {
            throw "PFX şifresi olmadan installer imzalanamaz!"
        }
        Write-Ok "PFX şifresi alındı."
    }

    # D) GitHub CLI
    $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    if ($ghCmd) {
        $ghStatus = (& cmd.exe /c "gh auth status" 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            $ghUserLine = ($ghStatus -split "[\r\n]+" | Where-Object { $_ -match "account" } | Select-Object -First 1)
            $ghUser = if ($ghUserLine) { $ghUserLine.Trim() } else { "Giriş yapılmış" }
            Write-Ok "GitHub CLI hazır ($ghUser)."
        } else {
            Write-Warn "GitHub CLI oturumu kapalı (GitHub Release atlanabilir)."
        }
    } else {
        Write-Info "GitHub CLI ('gh') kurulu değil (GitHub Release atlanabilir)."
    }

    # E) Antigravity CLI (agy)
    $agyCmd = Get-Command "agy" -ErrorAction SilentlyContinue
    if ($agyCmd) {
        Write-Ok "Antigravity CLI (agy) hazır: $($agyCmd.Source)"
    } else {
        Write-Warn "Antigravity CLI ('agy') bulunamadı (Sürüm notları manuel oluşturulacak)."
    }

    Write-Host "+===========================================================+" -ForegroundColor Cyan
    Write-Ok "Tüm ön kontroller başarıyla tamamlandı!"

    # -- 3) Flutter Clean (Opsiyonel) ----------------------------------------------
    $doClean = Read-Host "`nÖnce 'flutter clean' çalıştırılsın mı? (e/H)"
    if ($doClean -match '^[Ee]$') {
        Write-Step "Flutter Clean & Pub Get"
        Run-Exe -FilePath "flutter" -ArgumentList @("clean") -WorkingDirectory $projectRoot
        Run-Exe -FilePath "flutter" -ArgumentList @("pub", "get") -WorkingDirectory $projectRoot
    }

    $buildResults = @{}

    # -- 4) Windows Derleme (Flutter Build Windows) ---------------------------------
    Write-Step "Windows Uygulaması Derleniyor (flutter build windows --release)..."
    $swWin = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        Run-Exe -FilePath "flutter" -ArgumentList @("build", "windows", "--release") -WorkingDirectory $projectRoot
        $swWin.Stop()
        $buildResults["WindowsBuild"] = [pscustomobject]@{
            Elapsed = $swWin.Elapsed
            Success = $true
            Error   = $null
        }
        Write-Ok "Windows derlemesi tamamlandı - $(Format-Elapsed $swWin.Elapsed)"
    }
    catch {
        $swWin.Stop()
        $buildResults["WindowsBuild"] = [pscustomobject]@{
            Elapsed = $swWin.Elapsed
            Success = $false
            Error   = $_.Exception.Message
        }
        Write-Err "Windows derlemesi başarısız: $($_.Exception.Message)"
        throw
    }

    # Derlenen ana exe kontrolü
    $builtExePath = Join-Path $projectRoot "build\windows\x64\runner\Release\discordstorage.exe"
    if (-not (Test-Path $builtExePath)) {
        throw "Derlenen discordstorage.exe bulunamadı: $builtExePath"
    }

    # -- 5) Inno Setup İle Installer Oluşturma -------------------------------------
    Write-Step "Inno Setup Compiler Çalıştırılıyor..."
    $swInno = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        # AppVersion parametresini dinamik geç
        $appVerArg = "/DAppVersion=$verFolder"
        $outDirArg = "/O$distPath"

        Run-Exe -FilePath $innoSetupPath -ArgumentList @($appVerArg, $outDirArg, $issFilePath) -WorkingDirectory $projectRoot
        $swInno.Stop()

        # Oluşan installer dosyasını bul
        $installerExe = Get-ChildItem -Path $distPath -Filter "*.exe" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -like "*$installerNameHint*" -or $_.BaseName -like "*Installer*" } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $installerExe) {
            throw "Installer .exe çıktısı bulunamadı: $distPath"
        }

        $sizeMB = "{0:N2} MB" -f ($installerExe.Length / 1MB)
        Write-Ok "Installer oluşturuldu: $($installerExe.Name) ($sizeMB) - $(Format-Elapsed $swInno.Elapsed)"

        $buildResults["InnoInstaller"] = [pscustomobject]@{
            Elapsed = $swInno.Elapsed
            Success = $true
            Error   = $null
        }

        # -- 6) Installer İmzalama (SignTool + Timestamp) --------------------------
        Write-Step "Installer İmzalanıyor (SignTool)..."
        $signedSuccessfully = $false

        foreach ($tsUrl in $timestampServers) {
            Write-Info "Zaman damgası sunucusu deneniyor: $tsUrl"
            $signExit = Run-Exe -FilePath $signtool -ArgumentList @(
                "sign", "/fd", "SHA256",
                "/tr", $tsUrl, "/td", "SHA256",
                "/f", $pfxPath, "/p", $pfxPassPlain,
                $installerExe.FullName
            ) -AllowNonZero

            if ($signExit -eq 0) {
                $signedSuccessfully = $true
                Write-Ok "İmza ve zaman damgası başarılı ($tsUrl)"
                break
            }
            Write-Warn "$tsUrl sunucusundan yanıt alınamadı, diğer sunucu deneniyor..."
        }

        if (-not $signedSuccessfully) {
            Write-Warn "Zaman damgası sunucularına erişilemedi. Zaman damgasız imzalanıyor..."
            Run-Exe -FilePath $signtool -ArgumentList @(
                "sign", "/fd", "SHA256",
                "/f", $pfxPath, "/p", $pfxPassPlain,
                $installerExe.FullName
            )
        }

        # Doğrulama
        $verifyExit = Run-Exe -FilePath $signtool -ArgumentList @("verify", "/pa", "/v", $installerExe.FullName) -AllowNonZero
        if ($verifyExit -eq 0) {
            Write-Ok "Installer imzası başarıyla doğrulandı."
        } else {
            Write-Warn "Installer imzalandı, ancak kök sertifika (self-signed) güvenilmeyen listesinde olabilir."
        }
    }
    finally {
        Remove-Variable -Name pfxPassPlain -Force -ErrorAction SilentlyContinue
    }

    # -- 7) Sürüm Notları (Antigravity CLI / agy) -----------------------------------
    $ghNotesFile = Join-Path $projectRoot "RELEASE_$currentVersion.md"
    $notesExist  = Test-Path $ghNotesFile

    Write-Host ""
    Write-Host "-- Sürüm Notları (Antigravity CLI) --" -ForegroundColor Cyan
    if (-not $notesExist) {
        $genNotes = Read-Host "   Sürüm notları eksik. Antigravity CLI (agy) ile otomatik oluşturulsun mu? (E/h)"
        if ($genNotes -notmatch '^[Hh]$') {
            [void](Invoke-AgyReleaseNotes -ver $currentVersion)
        }
    }
    else {
        $regenNotes = Read-Host "   Sürüm notları mevcut. Antigravity CLI (agy) ile yeniden oluşturulsun mu? (e/H)"
        if ($regenNotes -match '^[Ee]$') {
            [void](Invoke-AgyReleaseNotes -ver $currentVersion)
        }
    }

    # -- 8) GitHub Release (Opsiyonel) ---------------------------------------------
    Write-Host ""
    Write-Host "-- GitHub Release --" -ForegroundColor Cyan
    $createRelease = Read-Host "   GitHub Release oluşturulsun / güncellensin mi? (E/h)"

    if ($createRelease -notmatch '^[Hh]$') {
        $installer = Get-ChildItem -Path $distPath -Filter "*.exe" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if (-not $installer) {
            Write-Warn "Release için yüklenecek installer dosyası bulunamadı."
        }
        else {
            $tagName      = if ($currentVersion -match '^v') { $currentVersion } else { "v$currentVersion" }
            $releaseTitle = "DiscordStorage $tagName"

            Push-Location $projectRoot
            try {
                $releaseExists = $false
                try {
                    $null = & gh release view $tagName 2>&1
                    if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
                }
                catch { $releaseExists = $false }

                if ($releaseExists) {
                    Write-Step "Mevcut release'e installer yükleniyor: $tagName"
                    Write-Info "Yükleniyor: $($installer.Name)"
                    Run-Exe -FilePath "gh" -ArgumentList @("release", "upload", $tagName, $installer.FullName, "--clobber") -WorkingDirectory $projectRoot
                    Write-Ok "Installer mevcut release'e yüklendi: $tagName"
                }
                else {
                    Write-Step "Yeni GitHub Release Oluşturuluyor: $tagName"

                    $ghArgs = @("release", "create", $tagName, "--title", $releaseTitle)

                    if (Test-Path $ghNotesFile) {
                        Write-Info "Release notu dosyası bulundu: $(Split-Path $ghNotesFile -Leaf)"
                        $ghArgs += @("--notes-file", $ghNotesFile)
                    }
                    else {
                        $releaseNotes = Read-Host "   Release notları (boş bırakılabilir)"
                        if ([string]::IsNullOrWhiteSpace($releaseNotes)) {
                            $releaseNotes = "DiscordStorage $tagName - $(Get-Date -Format 'yyyy-MM-dd')"
                        }
                        $ghArgs += @("--notes", $releaseNotes)
                    }

                    # Dosyayı ekle
                    $ghArgs += $installer.FullName

                    Run-Exe -FilePath "gh" -ArgumentList $ghArgs -WorkingDirectory $projectRoot
                    Write-Ok "GitHub Release başarıyla oluşturuldu: $tagName"
                }
            }
            catch {
                Write-Err "GitHub Release işlemi başarısız: $($_.Exception.Message)"
            }
            finally {
                Pop-Location
            }
        }
    }

    # -- 9) Özet Tablosu -----------------------------------------------------------
    $scriptStopwatch.Stop()

    Write-Host ""
    Write-Host "+===========================================================+" -ForegroundColor Green
    Write-Host "|                      BUILD ÖZETİ                          |" -ForegroundColor Green
    Write-Host "+===========================================================+" -ForegroundColor Green

    foreach ($name in $buildResults.Keys) {
        $r       = $buildResults[$name]
        $status  = if ($r.Success) { "Başarılı" } else { "HATALI" }
        $sColor  = if ($r.Success) { "Green" }    else { "Red" }
        $elapsed = Format-Elapsed $r.Elapsed
        $line    = "|  {0,-16}  {1,-12}  {2,-20}  |" -f $name, $status, $elapsed
        Write-Host $line -ForegroundColor $sColor
    }

    if (Test-Path $distPath) {
        $distFiles = Get-ChildItem -Path $distPath -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 5
        if ($distFiles) {
            Write-Host "+-----------------------------------------------------------+" -ForegroundColor Green
            Write-Host "|  Çıktı Dosyaları: $distPath" -ForegroundColor Green
            foreach ($f in $distFiles) {
                $sizeMB = "{0:N2} MB" -f ($f.Length / 1MB)
                $fLine  = "|    {0,-38} {1,10}" -f $f.Name, $sizeMB
                Write-Host $fLine -ForegroundColor White
            }
        }
    }

    Write-Host "+-----------------------------------------------------------+" -ForegroundColor Green
    $totalLine = "|  Toplam Süre: {0,-43}|" -f (Format-Elapsed $scriptStopwatch.Elapsed)
    Write-Host $totalLine -ForegroundColor Cyan
    Write-Host "+===========================================================+" -ForegroundColor Green

    Write-Host ""
    Write-Ok "DiscordStorage $currentVersion yayına hazır!"
}
catch {
    Write-Host ""
    Write-Host "+===========================================================+" -ForegroundColor Red
    Write-Host "|                      KRİTİK HATA                          |" -ForegroundColor Red
    Write-Host "+===========================================================+" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Satır: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor DarkGray
    Write-Host "   Dosya: $($_.InvocationInfo.ScriptName)" -ForegroundColor DarkGray

    if ($null -ne $projectRoot -and (Test-Path $projectRoot)) { Set-Location $projectRoot }
}
finally {
    Write-Host "`nÇıkmak için bir tuşa basın..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
