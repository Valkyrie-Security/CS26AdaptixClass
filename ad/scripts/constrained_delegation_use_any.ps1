Set-ADUser -Identity "carmen.bolton" -ServicePrincipalNames @{Add='CIFS/maintenance.cheddarsale.local'}
Get-ADUser -Identity "carmen.bolton" | Set-ADAccountControl -TrustedToAuthForDelegation $true
#Set-ADUser -Identity "carmen.bolton" -Add @{'msDS-AllowedToDelegateTo'=@('CIFS/DC01.cheddarsale.local','CIFS/DC01')}