#! /usr/bin/env sh

. ./define.sh

sanity_check()
{
	if echo "$OS" | grep -q "[Dd]arwin" ; then
		 # Try to find a real way to define if another packages manager is installed.
		# According to their own documentation.
		if [ -f /usr/local/bin/brew ]; then
			printf "Homebrew detected, pkgsrc can conflict with\n"
			exit 1
		fi
		# According to their own documentation.
		if [ -f /opt/local/bin/port ]; then
			printf "MacPorts detected, pkgsrc can conflict with\n"
			exit 1
		fi
	fi
}

install_pkgin()
{
	if [ "$OS" = "Linux" ]; then
		os="linux"
	elif echo "$OS" | grep -q "[Dd]arwin" ; then
		os="osx"
	else
		printf "System not yet supported, sorry.\n"
		exit 1
	fi

	_curl="${curl} --silent --max-time 3 --connect-timeout 2"
	_egrep="${egrep} -o"

	bootstrap_install_url="https://pkgsrc.joyent.com/install-on-$os/"
	bootstrap_doc="/tmp/pkgin_install.txt"
	${_curl} -o ${bootstrap_doc} ${bootstrap_install_url}
	bootstrap_url="$(${cat} ${bootstrap_doc} | ${_egrep} -A1 "Download.*bootstrap" | ${_egrep} "_curl.*$ARCH.*")"

	read bootstrap_hash bootstrap_tar <<EOF
$(${cat} ${bootstrap_doc} | ${_egrep} "[0-9a-z]{32}.+$ARCH.tar.gz")
EOF

	fetch_localbase="$(${_curl} ${bootstrap_url#curl -Os} | ${tar} ztvf - | ${_egrep} '/.+/pkg_install.conf$')"
	pkgin_localbase="${fetch_localbase%/*/*}"
	pkgin_localbase_bin="$pkgin_localbase/bin"
	pkgin_localbase_sbin="$pkgin_localbase/sbin"
	pkgin_localbase_man="$pkgin_localbase/man"
	pkgin_bin="$pkgin_localbase_bin/pkgin"

	export PATH=$pkgin_localbase_sbin:$pkgin_localbase_bin:$path

	[ "$OS" = "Linux" ] && export MANPATH=$pkgin_localbase_man:$manpath

	# Generic variables and commands.
	bootstrap_tmp="/tmp/${bootstrap_tar}"
	# Joyent PGPkey
	repo_gpgkey="0xDE817B8E"

	# download bootstrap kit.
	${_curl} -o "${bootstrap_tmp}" "${bootstrap_url#curl -Os }"
	if [ "$?" != 0 ]; then
		printf "version of bootstrap for $OS not found.\nplease install it by yourself.\n"
		exit 1
	fi

	# Verify SHA1 checksum of the bootstrap kit.
	bootstrap_sha="$(${shasum} -p $bootstrap_tmp)"
	if [ ${bootstrap_hash} != ${bootstrap_sha:0:41} ]; then
		printf "SHA mismatch ! ABOOORT Cap'tain !\n"
		exit 1
	fi

	# install bootstrap kit to the right path regarding your distribution.
	${tar} xfp "$bootstrap_tmp" -c / >/dev/null 2>&1

	# If GPG available, verify GPG signature.
	if [ ! -z ${gpg} ]; then
		# Verifiy PGP signature.
		${gpg} --keyserver hkp://keys.gnupg.net --recv-keys $repo_gpgkey >/dev/null 2>&1
		${_curl} -o "${bootstrap_tmp}.asc" "${bootstrap_url#curl -Os }.asc"
		${gpg} --verify "${bootstrap_tmp}.asc" >/dev/null 2>&1
	fi

	# Fetch packages.
	${rm} -r -- "$PKGIN_VARDB" "$bootstrap_tmp" "$bootstrap_doc"
	"$pkgin_bin" -y update
}

test_if_pkgin_is_installed()
{

	if [ -z ${pkgin} ]; then
		install_pkgin
	fi

	return 0
}

install_3rd_party_pkg()
{
	pkg=${1}
	test_if_pkgin_is_installed

	${pkgin} search ${pkg}
	if [ "$?" != 0 ]; then
		printf "Package not found.\n"
		exit 1
	else
		${pkgin} -y in ${pkg}
	fi
}