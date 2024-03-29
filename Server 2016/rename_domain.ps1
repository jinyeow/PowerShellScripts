# HOWTO: rename domain name

# In Administrator cmd prompt:
# 1. rendom /list - creates Domainlist.xml in PWD
# 2. notepad Domainlist.xml - edit all instances of the domain name
# 3. rendom /upload
# 4. rendom /prepare
# 5. rendom /execute

# NOTE: The computer name for the DC will still be DC.old.domain.name
# To change it/update it:
# 1. netdom computername DC.old.domain.name /add:DC.new.domain.name
# 2. netdom computername DC.old.domain.name /makeprimary:DC.new.domain.name
# 3. Reboot the DC

# NEXT: fix group policies
# 1. gpfixup /olddns:<old.domain.name> /newdns:<new.domain.name>
# 2. gpfixup /oldnb:<old.netbios> /newnb:<new.netbios>
# 3. rendom /end

# NEXT: update DNS
# 1. create new zone for the new.domain.name
#       - Make the zone AD integrated
#       - Replication scope: in the domain
# 2. create new zone for the _msdcs.new.domain.name
#       - Make the zone AD integrated
#       - Replication scope: in the forest
# 3. ipconfig /registerdns
# 4. net stop netlogon
# 5. net start netlogon