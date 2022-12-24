#	$OpenBSD: Makefile,v 1.44 2022/09/02 12:40:02 krw Exp $

FS=		install${OSrev}.img
FSSIZE=		1359872
FSTYPE=		install360
CDROM=		install${OSrev}.iso
CDROMEFI=	efiinstall${OSrev}.iso

MOUNT_POINT=	/mnt

RELXDIR?=	rel-${MACHINE}
RELDIR?=	rel-${MACHINE}

BSDRD=		${RELDIR}/bsd.rd
BASE=		${RELDIR}/base${OSrev}.tgz ${RELDIR}/comp${OSrev}.tgz \
		${RELDIR}/game${OSrev}.tgz ${RELDIR}/man${OSrev}.tgz \
		${RELDIR}/bsd ${RELDIR}/bsd.rd ${RELDIR}/bsd.mp \
		${RELDIR}/INSTALL.${MACHINE}
XBASE=		${RELXDIR}/xbase${OSrev}.tgz ${RELXDIR}/xfont${OSrev}.tgz \
		${RELXDIR}/xshare${OSrev}.tgz ${RELXDIR}/xserv${OSrev}.tgz

EFIBOOT?=	${DESTDIR}/usr/mdec/BOOTX64.EFI ${DESTDIR}/usr/mdec/BOOTIA32.EFI
MSDOSSIZE=	960
TOTALSIZE!=	expr ${FSSIZE} + ${MSDOSSIZE}

all: ${FS} ${CDROM}

${FS}: ${BASE} ${XBASE} bsd.rd
	dd if=/dev/zero of=${FS} bs=512 count=${TOTALSIZE}
	vnconfig -v ${FS} > vnd
	fdisk -yi -l ${FSSIZE} -b ${MSDOSSIZE} -f ${DESTDIR}/usr/mdec/mbr `cat vnd`
	disklabel -wAT ${.CURDIR}/template `cat vnd`
	newfs -t msdos /dev/r`cat vnd`i
	mount /dev/`cat vnd`i ${MOUNT_POINT}
	mkdir -p ${MOUNT_POINT}/efi/boot
	cp ${EFIBOOT} ${MOUNT_POINT}/efi/boot
	umount ${MOUNT_POINT}
	newfs -O 1 -m 0 -o space -i 524288 -c ${FSSIZE} /dev/r`cat vnd`a
	mount /dev/`cat vnd`a ${MOUNT_POINT}
	objcopy -S -R .comment ${DESTDIR}/usr/mdec/boot ${MOUNT_POINT}/boot
	installboot -v -r ${MOUNT_POINT} `cat vnd` \
	    ${DESTDIR}/usr/mdec/biosboot ${MOUNT_POINT}/boot
	mkdir -p ${MOUNT_POINT}/${OSREV}/${MACHINE}
	mkdir -p ${MOUNT_POINT}/etc
	echo "set image /${OSREV}/${MACHINE}/bsd.rd" > ${MOUNT_POINT}/etc/boot.conf
	install -c -m 555 -o root -g wheel bsd.rd ${MOUNT_POINT}/bsd
	ln ${MOUNT_POINT}/bsd ${MOUNT_POINT}/bsd.rd

	cp -p ${BASE} ${MOUNT_POINT}/${OSREV}/${MACHINE}
	cp -p ${XBASE} ${MOUNT_POINT}/${OSREV}/${MACHINE}

	cat ${RELDIR}/SHA256 ${RELXDIR}/SHA256 > \
	    ${MOUNT_POINT}/${OSREV}/${MACHINE}/SHA256
	# XXX no SHA256.sig
	df -i ${MOUNT_POINT}
	umount ${MOUNT_POINT}
	vnconfig -u `cat vnd`
	rm -f vnd

${CDROM}: ${BASE} ${XBASE}
	rm -rf ${.OBJDIR}/cd-dir
	mkdir -p ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}
	mkdir -p ${.OBJDIR}/cd-dir/etc
	echo "set image /${OSREV}/${MACHINE}/bsd.rd" > ${.OBJDIR}/cd-dir/etc/boot.conf

	dd if=/dev/zero of=efi.img bs=512 count=2880
	vnconfig vnd1 efi.img
	disklabel -wAT templateefi vnd1
	newfs_msdos vnd1a
	mount_msdos /dev/vnd1a /mnt/
	
	echo "copy efi to image"
	mkdir -p /mnt/efi/boot
	cp ${EFIBOOT} /mnt/efi/boot
	umount /mnt/
	dd if=/dev/vnd1a of=efia.img
	vnconfig -u vnd1
	cp efia.img ${.OBJDIR}/cd-dir/

	cp -p ${BASE} ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}
	cp -p ${XBASE} ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}

	cat ${RELDIR}/SHA256 ${RELXDIR}/SHA256 > \
	    ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}/SHA256
	# XXX no SHA256.sig

	cp -p ${RELDIR}/cdbr ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}
	cp -p ${RELDIR}/cdboot ${.OBJDIR}/cd-dir/${OSREV}/${MACHINE}/cdboot

	# install.iso image with efi support
	mkhybrid -a -R -T -L -l -d -D -N -o ${.OBJDIR}/${CDROMEFI} \
	    -A "OpenBSD ${OSREV} ${MACHINE} Install CD" \
	    -P "Copyright (c) `date +%Y` Theo de Raadt, The OpenBSD project" \
	    -p "Theo de Raadt <deraadt@openbsd.org>" \
	    -V "OpenBSD/${MACHINE}   ${OSREV} Install CD" \
	    -b efia.img \
	    cd-dir/

	# Regular install.iso image
	mkhybrid -a -R -T -L -l -d -D -N -o ${.OBJDIR}/${CDROM} \
	    -A "OpenBSD ${OSREV} ${MACHINE} Install CD" \
	    -P "Copyright (c) `date +%Y` Theo de Raadt, The OpenBSD project" \
	    -p "Theo de Raadt <deraadt@openbsd.org>" \
	    -V "OpenBSD/${MACHINE}   ${OSREV} Install CD" \
	    -b ${OSREV}/${MACHINE}/cdbr -c ${OSREV}/${MACHINE}/boot.catalog \
	    ${.OBJDIR}/cd-dir
install:
	cp ${CDROM} ${FS} ${RELDIR}/

clean cleandir:
	rm -f ${CDROM} ${FS}
	rm -rf cd-dir

bsd.rd: ${BSDRD}
	cp ${BSDRD} bsd.rd

.include <bsd.obj.mk>
