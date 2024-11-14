#!/bin/bash
# raspios.sh
# Usage:
# REPOSITORY=YOUR_DOCKER_HUB_REPOSITORY_type raspios image_file_url debian_release type date ARCH
# or if img already exists this works too: 
# raspios.sh dummy debian_release type date ARCH
# (Default is not to delete the image after download.)
# e.g. 
# Example for arm64:
# ./raspios.sh  https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2023-12-06/2023-12-05-raspios-bookworm-arm64-lite.img.xz bookworm lite 2023-12-06 arm64

# Note also you should have an account setup on docker's hub. Make sure to set that account as REPOSITORY 
# in your environment and also make sure that you have local login from your command line enabled.
# 
# Alternately you can setup a local registry thus:
# Instructions here: https://docs.docker.com/registry/deploying/
# If you setup your registry with an ssl cert, you may have fewer problems.
# You can set the registry URL with the REPOSITORY env variable.
# e.g. export REPOSITORY="dockerserver:5000"
# sudo apt install -y uidmap golang
imageurl="${1}"
debian_release="${2}"
type="${3}"
date="${4}"
ARCH="${5}"
: "${outdir:=$(pwd)}"
: "${REPOSITORY:=meshtastic}"
echo "       image url:${imageurl}"
echo "  debian release:${debian_release}"
echo "            type: ${type}"
echo "            date: ${date}"
echo "            ARCH: ${ARCH}"
echo "      REPOSITORY: ${REPOSITORY}"
echo "     output root: ${outdir}"

tmpdir=$(mktemp -d docker_XXXX -p "$(pwd)")

function abspath {
  echo $(cd "$1" && pwd)
}
countdown()
(
  IFS=:
  set -- $*
  secs=$(( ${1#0} * 3600 + ${2#0} * 60 + ${3#0} ))
  while [ $secs -gt 0 ]
  do
    sleep 1 &
    printf "\r%02d:%02d:%02d" $((secs/3600)) $(( (secs/60)%60)) $((secs%60))
    secs=$(( $secs - 1 ))
    wait
  done
  echo
)

get_arch () {
  if [[ ! -f "$ARCH/${date}-raspios-${debian_release}-${ARCH}-${type}.img.xz" ]] ; then
    echo "$ARCH/${date}-raspios-${debian_release}-${ARCH}-${type}.img.xz not found"
    mkdir -p "$ARCH"
    curl --retry 3 -Lf "$imageurl" -o "$ARCH"/"${date}-raspios-${debian_release}-${ARCH}-${type}.img.xz" || ( echo "Download failed" && kill $$ )
  fi
  mkdir -p "${tmpdir}"_unxz
  date_image="${tmpdir}_unxz/${date}-raspios-${debian_release}-${ARCH}-${type}.img"
  unxz -kc "$ARCH"/"${date}-raspios-${debian_release}-${ARCH}-${type}.img.xz" > "$date_image"
    
  sudo kpartx -d "$date_image"
  rootpart=$(sudo kpartx -v -a "$date_image" | grep 'p2\b' | awk '{print $3}')
  bootpart=$(sudo kpartx -v -a "$date_image" | grep 'p1\b' | awk '{print $3}')
  if [[ -n $rootpart ]]; then 
    sudo umount /dev/mapper/"$bootpart" || true
    sudo umount /dev/mapper/"$rootpart" || true
    echo "sudo mount -o ro -t ext4 /dev/mapper/$rootpart $tmpdir"
    sudo mount -o ro -t ext4 /dev/mapper/"$rootpart" "$tmpdir"
    echo "sudo mount -o ro -t vfat /dev/mapper/$bootpart $tmpdir/boot"
    sudo mount -o ro -t vfat /dev/mapper/"$bootpart" "$tmpdir/boot"
  else
    rootpart=$(losetup | grep "$date_image" | awk '{print $1}')
    [[ -n $rootpart ]] && sudo mount -o ro -t ext4 "$rootpart" "$tmpdir"
  fi
  [[ -z "$rootpart" ]] && (echo "The downloaded image in ${type}.img.${date}.zip doesn't look right." && kill $$)
  raspios_arch=$(file "$tmpdir"/bin/bash | awk '{print $8}' | sed 's/,//g')
  echo "raspios_arch is $raspios_arch"
  if [[ "$raspios_arch" == "aarch64" ]]; then
    ARCH=arm64
    DOCKER_PLATFORM=arm64v8
    PLATFORM="linux/arm64"
  elif [[ "$raspios_arch" == "file" ]]; then
    echo "Error in determining image architecture."
    exit 1
  fi
}
import_to_Docker () {
  if ! docker image ls | grep "${REPOSITORY}"/raspios:"${date}-${debian_release}-${ARCH}-${type}" ; then
    (cd "$tmpdir" && sudo tar -c . | docker import --platform "${PLATFORM}" - "${REPOSITORY}"/raspios:"${date}-${debian_release}-${ARCH}-${type}")
  fi
  sudo umount "$tmpdir/boot"
  sudo umount "$tmpdir"
  rm -rf "$tmpdir"
  rm -rf "${tmpdir}_xz"
}
build_docker_image_with_docker_hub () {
  docker ps
  echo "Tag & Push starting in ..." && countdown "00:00:01"
  if ! docker pull "${REPOSITORY}"/raspios:"${date}"-"${debian_release}"-"${ARCH}"-"${type}" ; then 
    set -x
    tags="${DOCKER_PLATFORM} ${debian_release} ${ARCH} ${type} ${date} ${raspios_arch} latest"
    for tag in $tags
    do
      docker tag "${REPOSITORY}"/raspios:"${date}"-"${debian_release}"-"${ARCH}"-"${type}" "${REPOSITORY}"/raspios:"$tag"
    done
    docker push -a "${REPOSITORY}"/raspios
    set +x
  fi
}
make_docker_image_script () {
  dockercmd="docker run --platform ${PLATFORM} --rm --net=host \${PAGER_PASSTHROUGH} \${X11} -e LOCALRC=\"\${LOCALRC}\" --mount type=bind,source=/etc/localtime,target=/etc/localtime,readonly -v \$(pwd):/output -h \$(hostname)-${ARCH} -it ${REPOSITORY}/raspios:${date}-${debian_release}-${ARCH}-${type} /bin/bash"
  [[ -f $(abspath "${outdir}")/raspios-${date}-${debian_release}-${ARCH}-${type}.sh ]] && rm $(abspath "${outdir}")/raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}".sh
  cat <<IMAGESCRIPTEOF > $(abspath "${outdir}")/raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}".sh
#!/bin/bash
if [ -n "\$SSH_CLIENT" ] || [ -n "\$SSH_TTY" ]; then
  SESSION_TYPE=remote/ssh
elif pstree -p | egrep --quiet --extended-regexp ".*sshd.*\(\$\$\)"; then
  SESSION_TYPE=remote/ssh
else
  case \$(ps -o comm= -p \$PPID) in
    sshd|*/sshd) SESSION_TYPE=remote/ssh;;
  esac
fi
if [ -z \${PAGER+x} ]; then 
  echo "PAGER is not set."
else 
  PAGER_PASSTHROUGH=-e
  PAGER_PASSTHROUGH+=" "
  PAGER_PASSTHROUGH+=CONTAINER_PAGER=\${PAGER}
fi
X11+=" "
X11=-e
X11+=" "
X11+=DISPLAY=\${DISPLAY:-:0.0}
X11+=" "
if ! [[ \$SESSION_TYPE == remote/ssh ]] && [ -d /tmp/.X11-unix ]; then
  X11+=" -v /tmp/.X11-unix:/tmp/.X11-unix "
fi
if [ -f "\$HOME"/.Xauthority ]; then
  X11+=--volume=\$HOME/.Xauthority:/home/pi/.Xauthority:rw
fi
docker pull --platform ${PLATFORM} ${REPOSITORY}/raspios:${date}-${debian_release}-${ARCH}-${type}
docker pull tonistiigi/binfmt
docker run --privileged --rm tonistiigi/binfmt --install all
$dockercmd
IMAGESCRIPTEOF
  chmod +x $(abspath "${outdir}")/raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}".sh
    }
enter_docker_image () {
  echo "Running \"$dockercmd\" from \"$(abspath "${outdir}")/raspios-${date}-${debian_release}-${ARCH}-${type}.sh\""
  echo "Entering in..." && countdown "00:00:30"
  exec "$(abspath "${outdir}")/raspios-${date}-${debian_release}-${ARCH}-${type}.sh"
}
main () {
  get_arch
  import_to_Docker
  rm raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}"-build.log
  echo "build being logged to raspios-${date}-${debian_release}-${ARCH}-${type}-build.log"
  build_docker_image_with_docker_hub 2>&1 | tee -a raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}"-build.log
  make_docker_image_script 2>&1 | tee -a raspios-"${date}"-"${debian_release}"-"${ARCH}"-"${type}"-build.log
  [[ -z "$JUST_BUILD" ]] && enter_docker_image
}
main
