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
cp rootfs/boot/Image kernel
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
