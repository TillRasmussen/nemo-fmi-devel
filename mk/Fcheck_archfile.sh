#!/bin/bash
#set -x
set -o posix
#set -u
#set -e
#+
#
# ==================
# Fcheck_archfile.sh
# ==================
#
# --------------------------
# Check the compilation file
# --------------------------
#
# SYNOPSIS
# ========
#
# ::
#
#  $ Fcheck_archfile.sh
#
#
# DESCRIPTION
# ===========
#
#
# Check the choice of the compiler.
# Three cases :  
#
# - There was a previous choice
# - A new one has be specified, we use this one
# - No information, exit
#
# We use TOOLS/COMPILE/arch.fcm to see if something was chosen. 
#
# EXAMPLES
# ========
#
# ::
#
#  $ ./Fcheck_archfile.sh ARCHFILE CPPFILE COMPILER
#
#
# TODO
# ====
#
# option debug
#
#
# EVOLUTIONS
# ==========
#
# $Id: Fcheck_archfile.sh 10449 2019-01-02 09:38:04Z andmirek $
#
#
#
#   * creation
#
#-
cpeval () 
{
    cat > $2 << EOF

#==========================================================
#    Automatically generated by Fcheck_archfile.sh from
#    $1
#==========================================================

EOF
    while read line  
    do  
	eval "echo \"$line\" >> $2"
    done < $1
}
# cleaning related to the old version
rm -f $( find ${COMPIL_DIR} -type l -name $1 -print )
#
if [ ${#3} -eq 0 ]; then # arch not specified
    if [ ! -f ${COMPIL_DIR}/arch.history ]; then
	echo "Warning !!!"
	echo "NO compiler chosen"
	echo "Try makenemo -h for help"
	echo "EXITING..."
	exit 1 
    else # use the arch file defined in arch.history
	myarch=$( cat ${COMPIL_DIR}/arch.history )	
	if [ ! -f $myarch ]; then
	    echo "Warning !!!"
	    echo "previously used arch file no more found:"
	    echo $myarch
	    echo "EXITING..."
	    exit 1 
	else
	    if [ -f ${COMPIL_DIR}/$1 ]; then
		if [ "$2" != "nocpp" ] 
		then
		    # has the cpp keys file been changed since we copied the arch file in ${COMPIL_DIR}?
		    mycpp=$( ls -l ${COMPIL_DIR}/$2 | sed -e "s/.* -> //" )
		    if [ "$mycpp" != "$( cat ${COMPIL_DIR}/cpp.history )" ]; then
			echo $mycpp > ${COMPIL_DIR}/cpp.history
			cpeval ${myarch} ${COMPIL_DIR}/$1
		    fi
		    # has the cpp keys file been updated since we copied the arch file in ${COMPIL_DIR}?
		    mycpp=$( find -L ${COMPIL_DIR} -cnewer ${COMPIL_DIR}/$1 -name $2 -print )
		    [ ${#mycpp} -ne 0 ] && cpeval ${myarch} ${COMPIL_DIR}/$1
		fi
		# has myarch file been updated since we copied it in ${COMPIL_DIR}?
		myarchdir=$( dirname ${myarch} )
		myarchname=$( basename ${myarch} )
		myarch=$( find -L $myarchdir -cnewer ${COMPIL_DIR}/$1 -name $myarchname -print )
		[ ${#myarch} -ne 0 ] && cpeval ${myarch} ${COMPIL_DIR}/$1
	    else
		cpeval ${myarch} ${COMPIL_DIR}/$1
	    fi
	fi
    fi
else 
    nb=$( find ${MAIN_DIR}/arch -name arch-${3}.fcm -print | wc -l )
    if [ $nb -eq 0 ]; then # no arch file found
	echo "Warning !!!"
	echo "Compiler not existing"
	echo "Try makenemo -h for help"
	echo "EXITING..."
	exit 1       
    fi
    if [ $nb -gt 1 ]; then # more than 1 arch file found
	echo "Warning !!!"
	echo "more than 1 arch file for the same compiler have been found"
	find ${MAIN_DIR}/arch -name arch-${3}.fcm -print
	echo "keep only 1"
	echo "EXITING..."
	exit 1       
    fi
    myarch=$( find ${MAIN_DIR}/arch -name arch-${3}.fcm -print )
    # we were already using this arch file ?
    if [ "$myarch" == "$( cat ${COMPIL_DIR}/arch.history )" ]; then 
	if [ -f ${COMPIL_DIR}/$1 ]; then
	    if [ "$2" != "nocpp" ] 
	    then
		# has the cpp keys file been changed since we copied the arch file in ${COMPIL_DIR}?
		mycpp=$( ls -l ${COMPIL_DIR}/$2 | sed -e "s/.* -> //" )
		if [ "$mycpp" != "$( cat ${COMPIL_DIR}/cpp.history )" ]; then
		    echo $mycpp > ${COMPIL_DIR}/cpp.history
		    cpeval ${myarch} ${COMPIL_DIR}/$1
		fi
		# has the cpp keys file been updated since we copied the arch file in ${COMPIL_DIR}?
		mycpp=$( find -L ${COMPIL_DIR} -cnewer ${COMPIL_DIR}/$1 -name $2 -print )
		[ ${#mycpp} -ne 0 ] && cpeval ${myarch} ${COMPIL_DIR}/$1
	    fi
	    # has myarch file been updated since we copied it in ${COMPIL_DIR}?
	    myarch=$( find -L ${MAIN_DIR}/arch -cnewer ${COMPIL_DIR}/$1 -name arch-${3}.fcm -print )
	    [ ${#myarch} -ne 0 ] && cpeval ${myarch} ${COMPIL_DIR}/$1
	else
	    cpeval ${myarch} ${COMPIL_DIR}/$1
	fi
    else
	if [ "$2" != "nocpp" ] 
	then
	    ls -l ${COMPIL_DIR}/$2 | sed -e "s/.* -> //" > ${COMPIL_DIR}/cpp.history
	fi
	echo ${myarch} > ${COMPIL_DIR}/arch.history
	cpeval ${myarch} ${COMPIL_DIR}/$1
    fi
fi

#- do we need xios library?
#- 2 cases: 
#- in CONFIG directory looking for key_iomput
if [ "$1" == "arch_nemo.fcm" ]
then
    if [ "$2" != "nocpp" ] 
    then
        use_iom=$( sed -e "s/#.*$//" ${COMPIL_DIR}/$2 | grep -c key_iomput )
    else
        use_iom=0
    fi
    have_lxios=$( sed -e "s/#.*$//" ${COMPIL_DIR}/$1 | grep -c "\-lxios" )
    if [[ ( $use_iom -eq 0 ) && ( $have_lxios -ge 1 ) ]]
    then 
        sed -e "s/-lxios//g" ${COMPIL_DIR}/$1 > ${COMPIL_DIR}/tmp$$
        mv -f ${COMPIL_DIR}/tmp$$ ${COMPIL_DIR}/$1
    fi
#- in TOOLS directory looking for USE xios
else
    use_iom=$( egrep --exclude-dir=.svn -r USE ${NEW_CONF}/src/* | grep -c xios )
    have_lxios=$( sed -e "s/#.*$//" ${COMPIL_DIR}/$1 | grep -c "\-lxios" )
    if [[ ( $use_iom -eq 0 ) || ( $have_lxios != 1 ) ]]
    then 
        sed -e "s/-lxios//g" ${COMPIL_DIR}/$1 > ${COMPIL_DIR}/tmp$$
        mv -f ${COMPIL_DIR}/tmp$$ ${COMPIL_DIR}/$1
    fi
fi

#- do we need oasis libraries?
if [ "$2" != "nocpp" ] 
then
    use_oasis=$( sed -e "s/#.*$//" ${COMPIL_DIR}/$2 | grep -c key_oasis3 )
else
    use_oasis=0
fi
#ignore use_oasis if XIOS_OASIS is set  (doesn't matter to what value) 
if [[ ! -z "$XIOS_OASIS" ]]; then 
    use_oasis=1 
fi 
for liboa in psmile.MPI1 mct mpeu scrip mpp_io
do
    have_liboa=$( sed -e "s/#.*$//" ${COMPIL_DIR}/$1 | grep -c "\-l${liboa}" )
    if [[ ( $use_oasis -eq 0 ) && ( $have_liboa -ge 1 ) ]]
    then 
	sed -e "s/-l${liboa}//g" ${COMPIL_DIR}/$1 > ${COMPIL_DIR}/tmp$$
	mv -f ${COMPIL_DIR}/tmp$$ ${COMPIL_DIR}/$1
    fi
done
