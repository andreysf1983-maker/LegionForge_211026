param([string]$Root = "", [string]$CnfPath = "", [string]$MysqlExe = "")
$ErrorActionPreference = "Continue"
if (-not $Root) { $Root = Split-Path -Parent $PSScriptRoot }
if (-not $CnfPath) { $CnfPath = Join-Path $Root "setup_tmp\mysql.cnf" }
$sqlDir = Join-Path $Root "sql\custom"
# Кастомные патчи LegionForge (БЕЗ ботов: 31/32/46 сюда не входят).
$patches = @(
    @{ Db = "auth";       File = "10_legionforge_realm.sql" },
    @{ Db = "world";      File = "48_legion_allied_races.sql" },
    @{ Db = "world";      File = "49_legion_allied_races_hotbar.sql" },
    @{ Db = "world";      File = "105_legionforge_client_races_real_ids.sql" },
    @{ Db = "world";      File = "41_legionforge_minibosses.sql" },
    @{ Db = "world";      File = "42_legionforge_miniboss_loot.sql" },
    @{ Db = "world";      File = "43_legionforge_upgrade_tokens.sql" },
    @{ Db = "world";      File = "44_legionforge_upgrade_limits.sql" },
    @{ Db = "world";      File = "45_legionforge_ancient_knowledge.sql" },
    @{ Db = "world";      File = "40_legionforge_items.sql" },
    @{ Db = "hotfixes";   File = "40_legionforge_items.sql"; Soft = $true },
    @{ Db = "hotfixes";   File = "43_legionforge_upgrade_tokens.sql"; Soft = $true },
    @{ Db = "world";      File = "106_legionforge_form_scrolls.sql" },
    @{ Db = "hotfixes";   File = "106_legionforge_form_scrolls.sql"; Soft = $true },
    @{ Db = "characters"; File = "106_legionforge_form_scrolls.sql"; Soft = $true },
    @{ Db = "world";      File = "107_legionforge_demon_scrolls_and_form_defaults.sql" },
    @{ Db = "hotfixes";   File = "107_legionforge_demon_scrolls_and_form_defaults.sql"; Soft = $true },
    @{ Db = "characters"; File = "107_legionforge_demon_scrolls_and_form_defaults.sql"; Soft = $true },
    @{ Db = "world";      File = "110_legionforge_log_cleanup_26124.sql"; Soft = $true },
    @{ Db = "world";      File = "111_remove_wrong_race_slots.sql" }
)
$fail = 0
foreach ($p in $patches) {
    $path = Join-Path $sqlDir $p.File
    if (-not (Test-Path -LiteralPath $path)) { Write-Host "  [!] Нет файла $path"; $fail++; continue }
    Write-Host "  [*] $($p.File) -> $($p.Db)"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $MysqlExe
    $psi.Arguments = ('--defaults-extra-file="{0}" --default-character-set=utf8mb4 --max_allowed_packet=512M {1}' -f $CnfPath, $p.Db)
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $proc = [System.Diagnostics.Process]::Start($psi)
    $bytes = [IO.File]::ReadAllBytes($path)
    try { $proc.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length) } catch { }
    $proc.StandardInput.Close(); $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) {
        $err = $proc.StandardError.ReadToEnd()
        if ($p.ContainsKey("Soft") -and $p.Soft) { Write-Host "  [!] SOFT-FAIL $($p.File): $err" ; continue }
        Write-Host "  [ОШИБКА] $($p.File): $err"; $fail++
    }
}
if ($fail -gt 0) { Write-Host "  [ОШИБКА] Патчей с ошибками: $fail"; exit 1 }
Write-Host "  [OK] Все кастомные патчи применены."
exit 0
