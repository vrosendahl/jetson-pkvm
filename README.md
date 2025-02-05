# Table of contents

- [Install build dependencies](#install-build-dependencies)
  - [OP-TEE and ATF](#op-tee-and-atf)
- [Set up Jetson 36.4.3](#set-up-jetson-3643)
- [Use your own kernel](#use-your-own-kernel)
  - [Check out Android common kernel](#check-out-android-common-kernel)
  - [Create new defconfig](#create-new-defconfig)
  - [Configure NVIDIA build system](#configure-nvidia-build-system)
  - [Fix Ethernet build](#fix-ethernet-build)
  - [Build and install new kernel](#build-and-install-new-kernel)
  - [Update initramfs](#update-initramfs)
  - [Flash it](#flash-it)
- [Building and flashing Secure World software](#building-and-flashing-secure-world-software)
  - [Build OP-TEE](#build-op-tee)
  - [Build ARM Trusted Firmware (ATF)](#build-arm-trusted-firmware-atf)
  - [Generate Trusted OS partition image](#generate-trusted-os-partition-image)
  - [Flash Trusted OS partition](#flash-trusted-os-partition)
- [Steps you might need to know](#steps-you-might-need-to-know)
  - [Recreating NVIDIA's original kernel .config](#recreating-nvidias-original-kernel-config)

# Install build dependencies

These are for Ubuntu 24.04.1 LTS.

## OP-TEE and ATF

```
sudo apt update
sudo apt install python3-pycryptodome python3-pyelftools
```

# Set up Jetson 36.4.3

```
git clone https://github.com/hlyytine/jetson-pkvm.git
cd jetson-pkvm
export WORKSPACE=`pwd`
scripts/jetson-bsp-setup.sh
. env.sh

# optional
echo '. '${WORKSPACE}'/env.sh' >> ${HOME}/.bashrc
```

# Use your own kernel

## Check out Android common kernel

```
cd ${LDK_DIR}/source/kernel
git clone -b android15-6.6.66_r00 https://android.googlesource.com/kernel/common android_common_kernel
```

## Create new defconfig

```
export ARCH=arm64
export KERNEL_SRC_DIR=android_common_kernel
export KERNEL_DEF_CONFIG=pkvm_defconfig

cd ${LDK_DIR}/source/kernel/${KERNEL_SRC_DIR}
cp ${WORKSPACE}/configs/kernel-jammy.config .config

scripts/config --disable SYSTEM_TRUSTED_KEYS
scripts/config --disable SYSTEM_REVOCATION_KEYS
scripts/config --enable ARM64_PMEM
scripts/config --enable VIRTUALIZATION
scripts/config --enable KVM

make savedefconfig
mv defconfig arch/arm64/configs/${KERNEL_DEF_CONFIG}
make mrproper
```

## Configure NVIDIA build system

```
cd ${LDK_DIR}/source
sed -i -e 's/^KERNEL_SRC_DIR=.*$/KERNEL_SRC_DIR="'${KERNEL_SRC_DIR}'"/' kernel_src_build_env.sh
sed -i -e 's/^KERNEL_DEF_CONFIG=.*$/KERNEL_DEF_CONFIG="'${KERNEL_DEF_CONFIG}'"/' kernel_src_build_env.sh
```

## Fix Ethernet build

```
sed -i -e 's/^.*5\.15.*$/ifeq (1,1)/' ${LDK_DIR}/source/nvidia-oot/drivers/net/ethernet/Makefile
```

## Build and install new kernel

```
cd ${LDK_DIR}/source
./nvbuild.sh
./nvbuild.sh -i
# Use new kernel for recovery image as well
cp ${LDK_DIR}/rootfs/boot/Image ${LDK_DIR}/kernel
```

## Update initramfs

```
cd ${LDK_DIR}
sudo ./tools/l4t_update_initrd.sh
```

## Flash it

```
cd ${LDK_DIR}
sudo ./flash.sh jetson-agx-orin-devkit internal
```

# Building and flashing Secure World software

## Build OP-TEE

```
export UEFI_STMM_PATH=${LDK_DIR}/bootloader/standalonemm_optee_t234.bin

cd ${LDK_DIR}/source/tegra/optee-src/nv-optee
./optee_src_build.sh -p t234
dtc -I dts -O dtb -o optee/tegra234-optee.dtb optee/tegra234-optee.dts
```

## Build ARM Trusted Firmware (ATF)

```
cd ${LDK_DIR}/source/tegra/optee-src/atf
export NV_TARGET_BOARD=generic
./nvbuild.sh
```

## Generate Trusted OS partition image

```
cd ${LDK_DIR}/nv_tegra/tos-scripts
./gen_tos_part_img.py \
    --monitor ${LDK_DIR}/source/tegra/optee-src/atf/arm-trusted-firmware/generic-t234/tegra/t234/release/bl31.bin \
    --os ${LDK_DIR}/source/tegra/optee-src/nv-optee/optee/build/t234/core/tee-raw.bin \
    --dtb ${LDK_DIR}/source/tegra/optee-src/nv-optee/optee/tegra234-optee.dtb \
    --tostype optee \
    tos.img

cp tos.img ${LDK_DIR}/bootloader/tos-optee_t234.img
```

## Flash Trusted OS partition

```
cd ${LDK_DIR}
sudo ./flash.sh -k A_secure-os jetson-agx-orin-devkit internal
```

Note that if you are somehow using B slot, the partition name would be `B-secure-os`.

# Steps you might need to know

## Recreating NVIDIA's original kernel .config

`configs/kernel-jammy.config` was created on a fresh Jetson 36.4.3 install
with the following commands:

```
cd ${LDK_DIR}/source
./nvbuild.sh
cp ${LDK_DIR}/source/kernel_out/kernel/kernel-jammy-src/.config ${WORKSPACE}/configs/kernel-jammy.config
```

After all, it's just about running `make defconfig`.
