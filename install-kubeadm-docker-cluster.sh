VERSION="1.24.7-00"

mkdir $HOME/kubernetes-installation
cd $HOME/kubernetes-installation

# Update apt package repositories
apt update -y

#
# DOCKER INSTALLATION
#

# Install certificate tools
apt-get install apt-transport-https ca-certificates curl gnupg lsb-release golang-go -y
# Create keyrings
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg -yes
# Add docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
# Update repositories again
apt update -y
# Install Docker Runtime
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

#
# KUBERNETES INSTALLATION
#

# Register kubernetes repository
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# Update packages
sudo apt update -y
# Install kubernetes tools
sudo apt install -y kubelet=$VERSION kubeadm=$VERSION kubectl=$VERSION
sudo apt-mark hold kubelet kubeadm kubectl

#
# PREPARE INSTALLATION
#

# Disable Swapfile temporary for kubernetes installation
swapoff -a
sed -e '/swap/ s/^#*/#/' -i /etc/fstab # This command disables the swapfile permanently in fstab
# Installing cri-dockerd
git clone https://github.com/Mirantis/cri-dockerd.git
cd cri-dockerd
mkdir bin
VERSION=$((git describe --abbrev=0 --tags | sed -e 's/v//') || echo $(cat VERSION)-$(git log -1 --pretty='%h')) PRERELEASE=$(grep -q dev <<< "${VERSION}" && echo "pre" || echo "") REVISION=$(git log -1 --pretty='%h')
go build -ldflags="-X github.com/Mirantis/cri-dockerd/version.Version='$VERSION}' -X github.com/Mirantis/cri-dockerd/version.PreRelease='$PRERELEASE' -X github.com/Mirantis/cri-dockerd/version.BuildTime='$BUILD_DATE' -X github.com/Mirantis/cri-dockerd/version.GitCommit='$REVISION'" -o cri-dockerd
go build -o bin/cri-dockerd
mkdir -p /usr/local/bin
install -o root -g root -m 0755 bin/cri-dockerd /usr/local/bin/cri-dockerd
cp -a packaging/systemd/* /etc/systemd/system
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

# Install Kubernetes
kubeadm init --cri-socket=/var/run/cri-dockerd.sock

# Copy kubernetes admin credentials to current user profile
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
