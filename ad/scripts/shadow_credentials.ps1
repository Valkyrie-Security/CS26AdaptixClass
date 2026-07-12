# Shadow Credentials Setup
# Attacker can use Whisker or Certipy to exploit
# https://www.thehacker.recipes/ad/movement/kerberos/shadow-credentials
$victim = "nathan.chavez"
$attacker = "angelique.mathis"

# Grant attacker write access to victim's msDS-KeyCredentialLink
$victimDN = (Get-ADUser $victim).DistinguishedName
$acl = Get-Acl "AD:\$victimDN"
$attacker_sid = (Get-ADUser $attacker).SID
$schemaIDGUID = [GUID]"5b47d60f-6090-40b2-9f37-2a4de88f3063"  # msDS-KeyCredentialLink GUID
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $attacker_sid,
    "WriteProperty",
    "Allow",
    $schemaIDGUID
)
$acl.AddAccessRule($ace)
Set-Acl -Path "AD:\$victimDN" -AclObject $acl
Write-Host "Shadow Credentials: $attacker can now abuse msDS-KeyCredentialLink on $victim"
