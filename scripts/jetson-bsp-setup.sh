#! /bin/sh

set -e

if test "x${DLDIR}" = "x"; then
  DLDIR=${HOME}/jetson_downloads
fi

if test "x${WORKSPACE}" = "x"; then
  echo "WORKSPACE not set, exiting." 1>&2
  exit 1
fi

FILES="
  aarch64--glibc--stable-2022.08-1.tar.bz2
  Jetson_Linux_R36.4.3_aarch64.tbz2
  Tegra_Linux_Sample-Root-Filesystem_R36.4.3_aarch64.tbz2
"

for f in ${FILES}; do
  if test ! -e "${DLDIR}/${f}"; then
    echo "${f} does not exist in ${DLDIR}." 1>&2
    exit 1
  fi
done

mkdir -p ${WORKSPACE}

# Unpack Jetson BSP
tar -C ${WORKSPACE} -xjvf ${DLDIR}/Jetson_Linux_R36.4.3_aarch64.tbz2
export LDK_DIR=${WORKSPACE}/Linux_for_Tegra

# Unpack sample rootfs
sudo tar -C ${LDK_DIR}/rootfs --numeric-owner -xjvf ${DLDIR}/Tegra_Linux_Sample-Root-Filesystem_R36.4.3_aarch64.tbz2

# Install NVIDIA binary Debian packages onto rootfs
cd ${LDK_DIR}
sudo ./tools/l4t_flash_prerequisites.sh
sudo ./apply_binaries.sh

# Skip runtime post installation step
sudo ./tools/l4t_create_default_user.sh -u nvidia -p nvidia -a --accept-license

# Install our convenience scripts
sudo install -d ${LDK_DIR}/rootfs/usr/bin
sudo install ${WORKSPACE}/scripts/install-cargo-deps.sh ${LDK_DIR}/rootfs/usr/bin

# Install cross-compiler
mkdir -p ${WORKSPACE}/toolchain
tar -C ${WORKSPACE}/toolchain -xjvf ${DLDIR}/aarch64--glibc--stable-2022.08-1.tar.bz2
cd ${WORKSPACE}/toolchain/aarch64--glibc--stable-2022.08-1
./relocate-sdk.sh

# Checkout NVIDIA sources
cd ${LDK_DIR}/source
./source_sync.sh -t jetson_36.4.3

cat > ${WORKSPACE}/env.sh <<EOF
WORKSPACE=${WORKSPACE}
# for generic use
export CROSS_COMPILE=\${WORKSPACE}/toolchain/aarch64--glibc--stable-2022.08-1/bin/aarch64-buildroot-linux-gnu-
# these two are for OP-TEE and ATF
export CROSS_COMPILE_AARCH64_PATH=${WORKSPACE}/toolchain/aarch64--glibc--stable-2022.08-1
export CROSS_COMPILE_AARCH64=${CROSS_COMPILE_AARCH64_PATH}/bin/aarch64-buildroot-linux-gnu-
export LDK_DIR=\${WORKSPACE}/Linux_for_Tegra
export INSTALL_MOD_PATH=\${LDK_DIR}/rootfs
EOF
