#!/bin/bash
#
# Auteur: kanzuke (kanzuke@wired.dynalias.org)
# Nom du script: !!FICHIER!!
# Date: !!DATE!!
#
# Template bash script, for when you need something overengineerd :)



#------------------------  VARIABLES  ------------------------#
LDAP_HOST=psyche.wired.dynalias.org
LDAP_BASEDN=dc=wired,dc=dynalias,dc=org
LDAP_BINDDN=cn=ldap_admin,dc=wired,dc=dynalias,dc=org
LDAP_BINDPW=ldap@wired

 
 
#------------------------  FONCTIONS  ------------------------#
# Function to echo in color. Don't supply color for normal color.
echo_color()
{
  message="$1"
  color="$2"
 
  red_begin="\033[01;31m"
  green_begin="\033[01;32m"
  yellow_begin="\033[01;33m"
  color_end="\033[00m"
 
  # Set color to normal when there is no color
  [ ! "$color" ] && color_begin="$color_end"
 
  if [ "$color" == "red" ]; then
    color_begin="$red_begin"
  fi
 
  if [ "$color" == "green" ]; then
    color_begin="$green_begin"
  fi
 
  if [ "$color" == "yellow" ]; then
    color_begin="$yellow_begin"
  fi
 
  echo -e "${color_begin}${message}${color_end}"
}



#----- FONCTIONS LDAP

# Fonction de recherche d'un utilisateur dans l'annuaire LDAP
search_ldap_user() {
	user=$1
	
	uid=$(ldapsearch -x -h $LDAP_HOST -b $LDAP_BASEDN -L "(&(objectClass=inetOrgPerson)(uid=$user))" uidNumber | grep "uidNumber:" | awk '{print $2}')
	echo $uid
}

# Récupérer l'uid local actuel d'un utilisateur
get_old_uid() {
	echo $(id -u $1)
}

# Change l'uid local d'un utilisateur
change_uid() {
	user=$1
	uid=$2

	usermod -u $2 $user
}


# Remplace les appartenances des fichiers, suite au changement d'uid dun utilisateur
replace_owner() {
	old_uid=$1
	new_uid=$2

	find /c -uid $old_uid -exec chown $new_uid {} \;
}






 
#------------------------  DEBUT DU SCRIPT  ------------------------#
clear


# 1) Récupération de la liste des utilisateurs samba du NAS. La lecture se fait depuis le fichier /etc/samba/smbpasswd
SMB_USERS_TMP=/tmp/smbusers.tmp
cat /etc/samba/smbpasswd | awk -F : '{print $1}' | grep -v '#' > $SMB_USERS_TMP

echo_color "Liste des utilisateurs SAMBA:" "yellow"
echo_color "-----------------------------" "yellow"
cat $SMB_USERS_TMP


# 2) A partir de la liste des utilisateurs, on lance une boucle pour tester chacun d'entre eux
echo
echo_color "Vérification des utilisateurs SAMBA:" "yellow"
echo_color "------------------------------------" "yellow"
while read user
do
	echo -n "Vérification de "; echo_color "$user" "green"

	# recherche dans le ldap
	uid=$(search_ldap_user $user)

	# récupération de l'id et modification. Si l'uid est vide, c'est qu'il n'y pas de correspondance dans le LDAP, auquel cas, on passe
	# directement à l'utilisateur suivant
	if [ ! $uid == "" ]; then
		# Remplacement de l'uid local de l'utilisateur avec celui de l'annuaire LDAP
		old_uid=$(get_old_uid $user)

		if [ $uid -ne $old_uid ]; then
			change_uid $user $uid
			# Remplacement du propriétaire des fichiers		
			replace_owner $old_uid $uid
	
			# Résumé
			echo -en "\t\tAncien uid: "; echo_color $old_uid "green"
			echo -en "\t\tNouvel uid: "; echo_color $uid "green"
		fi		
	fi
done < $SMB_USERS_TMP

