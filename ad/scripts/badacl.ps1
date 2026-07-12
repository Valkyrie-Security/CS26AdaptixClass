function AddACL {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Rights
    )

    # Rights that require a specific extended-right or property-set GUID
    $extRightsMap = @{
        'ForceChangePassword'      = @('ExtendedRight', '00299570-246d-11d0-a768-00aa006e0529')
        'AllExtendedRights'        = @('ExtendedRight', $null)
        'AddMembers'               = @('WriteProperty', 'bf9679c0-0de6-11d0-a285-00aa003049e2')
        'WriteGPLink'              = @('WriteProperty', 'f30e3bbe-9ff0-11d1-b603-0000f80367c1')
        'WriteSPN'                 = @('WriteProperty', 'f3a64788-5306-11d1-a9c5-0000f80367c1')
        'WriteAccountRestrictions' = @('WriteProperty', '4c164200-20c0-11d0-a768-00aa006e0529')
        'ReadLAPSPassword'         = @('ReadProperty', $null)
        'WriteKeyCredentialLink'   = @('WriteProperty', '5b47d60f-6090-40b2-9f37-2a4de88f3063')
        'Owns'                     = @('WriteOwner',   $null)
    }

    # Strip call-site suffixes (.sid, .DistinguishedName)
    $sourceName = $Source -replace '\.sid$', ''

    # Resolve destination: use as-is if already a DN, otherwise look up by SamAccountName
    if ($Destination -match '^(CN|OU|DC)=') {
        $destDN = $Destination
    } else {
        $destName = $Destination -replace '\.DistinguishedName$', ''
        $destObj  = Get-ADObject -Filter "SamAccountName -eq '$destName'" -ErrorAction SilentlyContinue
        if (-not $destObj) {
            Write-Warning "AddACL: destination '$destName' not found in AD, skipping."
            return
        }
        $destDN = $destObj.DistinguishedName
    }

    # Resolve source SamAccountName to SID
    $sourceObj = Get-ADObject -Filter "SamAccountName -eq '$sourceName'" -Properties objectSID -ErrorAction SilentlyContinue
    if (-not $sourceObj) {
        Write-Warning "AddACL: source '$sourceName' not found in AD, skipping."
        return
    }
    $identity = New-Object System.Security.Principal.SecurityIdentifier $sourceObj.objectSID

    $ADObject        = [ADSI]("LDAP://" + $destDN)
    $type            = [System.Security.AccessControl.AccessControlType]"Allow"
    $inheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance]"All"

    if ($extRightsMap.ContainsKey($Rights)) {
        $mapping  = $extRightsMap[$Rights]
        $adRights = [System.DirectoryServices.ActiveDirectoryRights]$mapping[0]
        if ($mapping[1]) {
            $guid = [Guid]$mapping[1]
            $ACE  = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$guid,$inheritanceType
        } else {
            $ACE  = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType
        }
    } else {
        $adRights = [System.DirectoryServices.ActiveDirectoryRights]$Rights
        $ACE      = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $identity,$adRights,$type,$inheritanceType
    }

    $ADObject.psbase.ObjectSecurity.AddAccessRule($ACE)
    $ADObject.psbase.commitchanges()
}


AddACl -Source Recreation.sid -Destination Fleet.DistinguishedName -Rights AllExtendedRights
AddACl -Source Court.sid -Destination Grounds.DistinguishedName -Rights GenericAll
AddACl -Source PublicServiceCommission.sid -Destination Paramedics.DistinguishedName -Rights GenericAll
AddACl -Source Parks.sid -Destination Utilities.DistinguishedName -Rights GenericAll
# Replaced: Recreation GenericAll now targets sofia.cross instead of Fire_Inspector
#AddACl -Source Recreation.sid -Destination Fire_Inspector.DistinguishedName -Rights GenericAll
AddACl -Source Administration.sid -Destination Grounds.DistinguishedName -Rights GenericAll
AddACl -Source Fire.sid -Destination Patrol.DistinguishedName -Rights AddMembers
AddACl -Source Recreation.sid -Destination Clerk.DistinguishedName -Rights GenericWrite
AddACl -Source Zoning.sid -Destination Assessor.DistinguishedName -Rights Self
AddACl -Source PublicServices.sid -Destination Chamberofcommerce.DistinguishedName -Rights WriteOwner
AddACl -Source PublicServices.sid -Destination Patrol.DistinguishedName -Rights WriteDacl
AddACl -Source Administration.sid -Destination Teachers.DistinguishedName -Rights AllExtendedRights
AddACl -Source Fire.sid -Destination Schooladmin.DistinguishedName -Rights AllExtendedRights
AddACl -Source Recreation.sid -Destination Fleet.DistinguishedName -Rights WriteProperty
AddACl -Source EconomicDevelopment.sid -Destination Fleet.DistinguishedName -Rights WriteGPLink
AddACl -Source VillageBoard.sid -Destination HelpDesk.DistinguishedName -Rights AddMembers
AddACl -Source Court.sid -Destination Budget.DistinguishedName -Rights WriteDacl
AddACl -Source PublicServices.sid -Destination Patrol.DistinguishedName -Rights AllExtendedRights
AddACl -Source IT.sid -Destination Finance.DistinguishedName -Rights GenericWrite
# AddACl -Source Fire.sid -Destination HumanResources.DistinguishedName -Rights WriteDacl
AddACl -Source Schools.sid -Destination Teachers.DistinguishedName -Rights AllExtendedRights
AddACl -Source Fire.sid -Destination Schooladmin.DistinguishedName -Rights AddMembers
AddACl -Source Fire.sid -Destination Parking.DistinguishedName -Rights WriteProperty
AddACl -Source VillageBoard.sid -Destination BuildingInspection.DistinguishedName -Rights GenericWrite
AddACl -Source EmergencyManagement.sid -Destination Engineering.DistinguishedName -Rights Self
AddACl -Source Court.sid -Destination Sanitation.DistinguishedName -Rights WriteDacl
AddACl -Source Police.sid -Destination Budget.DistinguishedName -Rights GenericAll
AddACl -Source Zoning.sid -Destination CommunityCenter.DistinguishedName -Rights WriteOwner
AddACl -Source Administration.sid -Destination Fire_Inspector.DistinguishedName -Rights WriteProperty
AddACl -Source Zoning.sid -Destination CommunityCenter.DistinguishedName -Rights GenericAll
AddACl -Source Administration.sid -Destination francine.higgins.DistinguishedName -Rights WriteDacl
AddACl -Source VillageBoard.sid -Destination willa.sanchez.DistinguishedName -Rights GenericAll
AddACl -Source Treasurer.sid -Destination lana.rosario.DistinguishedName -Rights ForceChangePassword
AddACl -Source Paramedics.sid -Destination araceli.weiss.DistinguishedName -Rights GenericWrite
AddACl -Source Utilities.sid -Destination angel.dotson.DistinguishedName -Rights WriteOwner
AddACl -Source President.sid -Destination freeman.mcneil.DistinguishedName -Rights WriteProperty
AddACl -Source Recreation.sid -Destination kaitlin.fitzgerald.DistinguishedName -Rights GenericWrite
AddACl -Source Marketing.sid -Destination alva.morton.DistinguishedName -Rights WriteDacl
AddACl -Source Administration.sid -Destination quentin.cannon.DistinguishedName -Rights AllExtendedRights
AddACl -Source Grounds.sid -Destination jess.drake.DistinguishedName -Rights ReadLAPSPassword
AddACl -Source PublicServiceCommission.sid -Destination rae.warren.DistinguishedName -Rights WriteDacl
# Duplicate: empty source — superseded by winifred.sampson.sid on line 152
#AddACl -Source .sid -Destination sonny.trevino.DistinguishedName -Rights ForceChangePassword
AddACl -Source Parks.sid -Destination rory.cannon.DistinguishedName -Rights WriteDacl
# Duplicate: empty source — superseded by emery.kirkland.sid on line 153
#AddACl -Source .sid -Destination justin.valentine.DistinguishedName -Rights AllExtendedRights
AddACl -Source Assessor.sid -Destination alberto.battle.DistinguishedName -Rights GenericWrite
AddACl -Source PTA.sid -Destination jean.barnett.DistinguishedName -Rights GenericWrite
AddACl -Source YouthPrograms.sid -Destination quentin.cannon.DistinguishedName -Rights WriteAccountRestrictions
AddACl -Source PublicServiceCommission.sid -Destination kelly.keith.DistinguishedName -Rights ForceChangePassword
AddACl -Source Fire.sid -Destination marquis.stafford.DistinguishedName -Rights WriteOwner
AddACl -Source Administration.sid -Destination gavin.gould.DistinguishedName -Rights ReadLAPSPassword
AddACl -Source kellie.ellison.sid -Destination Clerk.DistinguishedName -Rights AllExtendedRights
AddACl -Source natalia.morton.sid -Destination Licenses.DistinguishedName -Rights WriteOwner
AddACl -Source sarah.mcdowell.sid -Destination Assessor.DistinguishedName -Rights Owns
# Group is RoadwayMaintenance — corrected entry at bottom of file
#AddACl -Source pansy.allen.sid -Destination RoadMaintenance.DistinguishedName -Rights WriteOwner
AddACl -Source tessa.montgomery.sid -Destination Fire.DistinguishedName -Rights WriteProperty
AddACl -Source morris.vasquez.sid -Destination BuildingInspection.DistinguishedName -Rights WriteOwner
AddACl -Source florine.donovan.sid -Destination PTA.DistinguishedName -Rights WriteOwner
AddACl -Source jeffrey.bryan.sid -Destination Grounds.DistinguishedName -Rights WriteGPLink
AddACl -Source woodrow.perkins.sid -Destination PTA.DistinguishedName -Rights GenericAll
AddACl -Source carson.gaines.sid -Destination Fire_Inspector.DistinguishedName -Rights GenericAll
AddACl -Source maritza.rivers.sid -Destination IT.DistinguishedName -Rights WriteDacl
AddACl -Source angelique.mathis.sid -Destination Chief.DistinguishedName -Rights WriteDacl
AddACl -Source tommy.houston.sid -Destination Fire_Inspector.DistinguishedName -Rights WriteGPLink
AddACl -Source jerry.hood.sid -Destination President.DistinguishedName -Rights AllExtendedRights
# Group is RoadwayMaintenance — corrected entry at bottom of file
#AddACl -Source cathleen.wilson.sid -Destination RoadMaintenance.DistinguishedName -Rights AddMembers
AddACl -Source jocelyn.hopkins.sid -Destination HelpDesk.DistinguishedName -Rights WriteProperty
AddACl -Source les.moon.sid -Destination VillageBoard.DistinguishedName -Rights WriteProperty
# Group is RoadwayMaintenance — corrected entry at bottom of file
#AddACl -Source gloria.solis.sid -Destination RoadMaintenance.DistinguishedName -Rights AddMembers
AddACl -Source aaron.roy.sid -Destination Grounds.DistinguishedName -Rights Owns
AddACl -Source wilma.benson.sid -Destination Parks.DistinguishedName -Rights AllExtendedRights
AddACl -Source alton.noel.sid -Destination Finance.DistinguishedName -Rights GenericAll
AddACl -Source osvaldo.hopper.sid -Destination Parks.DistinguishedName -Rights Self
AddACl -Source lenora.jacobs.sid -Destination Grounds.DistinguishedName -Rights GenericAll
AddACl -Source carey.melendez.sid -Destination Fire_Inspector.DistinguishedName -Rights WriteOwner
AddACl -Source sal.farley.sid -Destination Clerk.DistinguishedName -Rights AddMembers
AddACl -Source marcel.cooley.sid -Destination IT.DistinguishedName -Rights WriteOwner
AddACl -Source craig.thomas.sid -Destination Schools.DistinguishedName -Rights AllExtendedRights
# Group is RoadwayMaintenance — corrected entry at bottom of file
#AddACl -Source esperanza.ballard.sid -Destination RoadMaintenance.DistinguishedName -Rights WriteDacl
AddACl -Source bettye.blair.sid -Destination Zoning.DistinguishedName -Rights GenericWrite
AddACl -Source candice.french.sid -Destination Chamberofcommerce.DistinguishedName -Rights GenericAll
AddACl -Source mickey.owen.sid -Destination jeffery.murray.DistinguishedName -Rights WriteSPN
AddACl -Source lina.gordon.sid -Destination emery.kirkland.DistinguishedName -Rights Owns
AddACl -Source christy.matthews.sid -Destination amparo.doyle.DistinguishedName -Rights WriteAccountRestrictions
AddACl -Source glenna.watson.sid -Destination margaret.mccarty.DistinguishedName -Rights GenericWrite
AddACl -Source esperanza.ballard.sid -Destination shelly.thomas.DistinguishedName -Rights GenericWrite
AddACl -Source angel.dotson.sid -Destination tameka.roth.DistinguishedName -Rights WriteOwner
AddACl -Source janet.mcbride.sid -Destination holly.mcgowan.DistinguishedName -Rights WriteOwner
AddACl -Source mary.medina.sid -Destination sarah.mcdowell.DistinguishedName -Rights Owns
AddACl -Source denny.craig.sid -Destination melissa.adkins.DistinguishedName -Rights WriteProperty
AddACl -Source freida.parker.sid -Destination chelsea.owens.DistinguishedName -Rights ReadLAPSPassword
AddACl -Source kristen.moreno.sid -Destination katelyn.carey.DistinguishedName -Rights WriteOwner
AddACl -Source jenny.wong.sid -Destination nathan.chavez.DistinguishedName -Rights Owns
AddACl -Source rochelle.mcgowan.sid -Destination ethel.graves.DistinguishedName -Rights WriteDacl
AddACl -Source adolph.davenport.sid -Destination june.mejia.DistinguishedName -Rights WriteSPN
AddACl -Source emilio.whitehead.sid -Destination cherie.romero.DistinguishedName -Rights WriteProperty
AddACl -Source brenton.mercado.sid -Destination edward.hudson.DistinguishedName -Rights ForceChangePassword
AddACl -Source sandra.medina.sid -Destination meredith.orr.DistinguishedName -Rights WriteSPN
AddACl -Source sharon.hatfield.sid -Destination bethany.benjamin.DistinguishedName -Rights GenericWrite
AddACl -Source luann.riggs.sid -Destination concetta.mclean.DistinguishedName -Rights WriteProperty
AddACl -Source kathie.evans.sid -Destination elvira.ellis.DistinguishedName -Rights GenericWrite
AddACl -Source beatriz.durham.sid -Destination nannie.rush.DistinguishedName -Rights WriteProperty
AddACl -Source marion.wade.sid -Destination sharon.nixon.DistinguishedName -Rights Owns
AddACl -Source brandy.drake.sid -Destination rebecca.myers.DistinguishedName -Rights ReadLAPSPassword
AddACl -Source walter.odom.sid -Destination jacob.barnes.DistinguishedName -Rights ReadLAPSPassword
AddACl -Source mary.medina.sid -Destination mariano.giles.DistinguishedName -Rights WriteDacl
AddACl -Source agustin.reeves.sid -Destination wilma.warren.DistinguishedName -Rights Owns
AddACl -Source loraine.mcpherson.sid -Destination lawanda.wright.DistinguishedName -Rights WriteProperty
AddACl -Source dewayne.brennan.sid -Destination franklin.schultz.DistinguishedName -Rights AllExtendedRights
AddACl -Source collin.robinson.sid -Destination lenny.bennett.DistinguishedName -Rights WriteProperty
AddACl -Source karina.bryan.sid -Destination arturo.howe.DistinguishedName -Rights Owns
AddACl -Source mercedes.mccoy.sid -Destination brandie.cherry.DistinguishedName -Rights ForceChangePassword
AddACl -Source brandie.cherry.sid -Destination ellis.gallagher.DistinguishedName -Rights GenericWrite
AddACl -Source ellis.gallagher.sid -Destination rico.thomas.DistinguishedName -Rights WriteDacl
AddACl -Source rico.thomas.sid -Destination PublicServiceCommission.DistinguishedName -Rights Self
AddACl -Source PublicServiceCommission.sid -Destination Fire_Inspector.DistinguishedName -Rights AddMembers
# Replaced: WriteOwner on alec.jarvis now granted to sofia.cross instead of Fire_Inspector
#AddACl -Source Fire_Inspector.sid -Destination alec.jarvis.DistinguishedName -Rights WriteOwner
# Removed: HumanResources GenericAll on effie.carr
#AddACl -Source HumanResources.sid -Destination effie.carr.DistinguishedName -Rights GenericAll
AddACl -Source effie.carr.sid -Destination DC01$.DistinguishedName -Rights GenericAll
AddACl -Source EmergencyManagement.sid -Destination DC01$.DistinguishedName -Rights GenericAll
AddACl -Source emilio.whitehead.sid -Destination "Domain Admins" -Rights GenericAll
AddACl -Source emilio.whitehead.sid -Destination "CN=AdminSDHolder,CN=System,DC=cheddarsale,DC=local" -Rights GenericAll
AddACl -Source araceli.weiss.sid -Destination "OU=Administration,DC=cheddarsale,DC=local" -Rights WriteDacl
AddACl -Source PublicServices.sid -Destination roderick.alston.DistinguishedName -Rights WriteDacl
AddACl -Source Patrol.sid -Destination wilma.warren.DistinguishedName -Rights ForceChangePassword
AddACl -Source winifred.sampson.sid -Destination sonny.trevino.DistinguishedName -Rights ForceChangePassword
AddACl -Source emery.kirkland.sid -Destination justin.valentine.DistinguishedName -Rights AllExtendedRights
AddACl -Source pansy.allen.sid -Destination RoadwayMaintenance.DistinguishedName -Rights WriteOwner
AddACl -Source cathleen.wilson.sid -Destination RoadwayMaintenance.DistinguishedName -Rights AddMembers
AddACl -Source gloria.solis.sid -Destination RoadwayMaintenance.DistinguishedName -Rights AddMembers
AddACl -Source esperanza.ballard.sid -Destination RoadwayMaintenance.DistinguishedName -Rights WriteDacl
AddACl -Source devin.aguirre.sid -Destination Recreation.DistinguishedName -Rights AddMembers
AddACl -Source Recreation.sid -Destination sofia.cross.DistinguishedName -Rights GenericAll
AddACl -Source sofia.cross.sid -Destination alec.jarvis.DistinguishedName -Rights WriteOwner
AddACl -Source alec.jarvis.sid -Destination clinton.stewart.DistinguishedName -Rights WriteKeyCredentialLink
AddACl -Source clinton.stewart.sid -Destination effie.carr.DistinguishedName -Rights Owns
AddACl -Source effie.carr.sid -Destination SRV03$.DistinguishedName -Rights WriteOwner
