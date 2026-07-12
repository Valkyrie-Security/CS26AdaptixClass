
# https://www.thehacker.recipes/ad/movement/kerberos/delegations/constrained#without-protocol-transition
Set-ADComputer -Identity "srv03$" -ServicePrincipalNames @{Add='HTTP/DC01.cheddarsale.local'}
Set-ADComputer -Identity "srv03$" -Add @{'msDS-AllowedToDelegateTo'=@('HTTP/DC01.cheddarsale.local','HTTP/DC01')}
Set-ADComputer -Identity "srv03$" -Add @{'msDS-AllowedToDelegateTo'=@('CIFS/DC01.cheddarsale.local','CIFS/DC01')}
