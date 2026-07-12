Try {
  Write-Output "Set power plan to high performance"

  $HighPerf = powercfg -l | ForEach-Object {if($_.contains("Ultimate Performance")) {$_.split()[3]}}

  if ($HighPerf -eq $null)
  {

    $HighPerf = powercfg -l | ForEach-Object {if($_.contains("High performance")) {$_.split()[3]}}
  }

  $CurrPlan = $(powercfg -getactivescheme).split()[3]

  if ($CurrPlan -ne $HighPerf) {powercfg -setactive $HighPerf}

  powercfg -change -monitor-timeout-ac 0
  powercfg -change -monitor-timeout-dc 0
  powercfg -change -standby-timeout-ac 0
  powercfg -change -standby-timeout-dc 0
  powercfg -change hibernate-timeout-ac 0
  powercfg -change hibernate-timeout-dc 0

} Catch {
  Write-Warning -Message "Unable to set power plan to high performance"
  Write-Warning $Error[0]
}
