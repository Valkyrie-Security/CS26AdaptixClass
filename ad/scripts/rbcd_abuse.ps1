# RBCD (Resource-Based Constrained Delegation) Attack Setup
# https://www.thehacker.recipes/ad/movement/kerberos/delegations/rbcd

# --- Previous configuration (percy.baldwin / GenericWrite) ---
# $attacker = "percy.baldwin"
# $target = "SRV03"
#
# # Grant attacker GenericWrite on target computer
# $computerDN = (Get-ADComputer $target).DistinguishedName
# $acl = Get-Acl "AD:\$computerDN"
# $attacker_sid = (Get-ADUser $attacker).SID
# $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
#     $attacker_sid,
#     "GenericWrite",
#     "Allow"
# )
# $acl.AddAccessRule($ace)
# Set-Acl -Path "AD:\$computerDN" -AclObject $acl
#
# Write-Host "RBCD: $attacker can now configure delegation on $target"
# # Attacker can now run:
# # Set-ADComputer $target -PrincipalsAllowedToDelegateToAccount (Get-ADComputer attacker_machine)
# # Then use Rubeus s4u to get service ticket

$attacker = "effie.carr"
$target = "SRV03"

# Grant attacker GenericAll on target computer (required to reset password and obtain TGT)
$computerDN = (Get-ADComputer $target).DistinguishedName
$acl = Get-Acl "AD:\$computerDN"
$attacker_sid = (Get-ADUser $attacker).SID
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $attacker_sid,
    "GenericAll",
    "Allow"
)
$acl.AddAccessRule($ace)
Set-Acl -Path "AD:\$computerDN" -AclObject $acl

Write-Host "RBCD: $attacker has GenericAll on $target"

# Enable protocol transition — required for S4U2self to return a forwardable ticket
Set-ADAccountControl -Identity "$target`$" -TrustedToAuthForDelegation $true
Write-Host "T2A4D enabled on $target`$ — protocol transition active"
