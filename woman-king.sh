# 1

sudo apt update
sudo apt install -y iproute2 cgroup-tools debootstrap
sudo debootstrap --arch=amd64 noble /mycontainer http://archive.ubuntu.com/ubuntu/   # ubuntu24.04


# 2
sudo mount --bind /proc /mycontainer/proc
sudo mount --bind /sys /mycontainer/sys
sudo mount --bind /dev /mycontainer/dev


# 3
sudo unshare --pid --fork --mount-proc /bin/bash
ps aux


# 4
sudo unshare --mount --fork chroot /mycontainer 
mount


# 5
sudo ip netns add mycontainer
sudo ip link add veth-host type veth peer name veth-container
sudo ip link set veth-container netns mycontainer
sudo ip addr add 192.168.1.1/24 dev veth-host
sudo ip link set veth-host up
sudo ip netns exec mycontainer ip addr add 192.168.1.2/24 dev veth-container
sudo ip netns exec mycontainer ip link set veth-container up


# 6
sudo mkdir /sys/fs/cgroup/mycontainer
echo "+cpu +memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
echo "500000 1000000" | sudo tee /sys/fs/cgroup/mycontainer/cpu.max
echo "256M" | sudo tee /sys/fs/cgroup/mycontainer/memory.max


# 7
sudo chroot /mycontainer adduser --disabled-password testuser

# 8
chroot /mycontainer /bin/bash
adduser --disabled-password testuser
exit



# 9

sudo chroot /mycontainer
apt update
apt install -y python3

# 10
cd /home/testuser/
vi /home/testuser/server.py

# paste
from http.server import HTTPServer, BaseHTTPRequestHandler
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Hello from my woman king!")
HTTPServer(("", 8000), Handler).serve_forever()



# then
chown 1000:1000 /home/testuser/server.py



# Launch the server:


python3 /home/testuser/server.py


