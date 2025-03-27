# STEP 1:
# Update package lists and install dependencies (iproute2, cgroup-tools, debootstrap). Then, create a minimal Ubuntu 24.04 (Noble) filesystem in /mycontainer.
sudo apt update
sudo apt install -y iproute2 cgroup-tools debootstrap
sudo debootstrap --arch=amd64 noble /mycontainer http://archive.ubuntu.com/ubuntu/   # ubuntu24.04


# STEP 2:
# Bind-mount /proc, /sys, and /dev into the container to provide process, system, and device visibility.
sudo mount --bind /proc /mycontainer/proc
sudo mount --bind /sys /mycontainer/sys
sudo mount --bind /dev /mycontainer/dev


# STEP 3:
# Enter a new PID namespace and remount /proc to isolate processes, then verify with ps aux.
sudo unshare --pid --fork --mount-proc /bin/bash
ps aux


# STEP 4:
# Unshare the mount namespace and chroot into /mycontainer, then check mounts to confirm isolation.
sudo unshare --mount --fork chroot /mycontainer 
mount


# STEP 5:
# Create a network namespace (mycontainer), set up a virtual Ethernet pair (veth-host/veth-container), assign IPs, and bring interfaces upsudo ip netns add mycontainer
sudo ip link add veth-host type veth peer name veth-container
sudo ip link set veth-container netns mycontainer
sudo ip addr add 192.168.1.1/24 dev veth-host
sudo ip link set veth-host up
sudo ip netns exec mycontainer ip addr add 192.168.1.2/24 dev veth-container
sudo ip netns exec mycontainer ip link set veth-container up


# STEP 6:
# Create a cgroup (mycontainer) and set CPU/memory limits (50% CPU, 256MB RAM max).
sudo mkdir /sys/fs/cgroup/mycontainer
echo "+cpu +memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
echo "500000 1000000" | sudo tee /sys/fs/cgroup/mycontainer/cpu.max
echo "256M" | sudo tee /sys/fs/cgroup/mycontainer/memory.max


# STEP 7:
# Use chroot to add a restricted user (testuser) inside the container.
sudo chroot /mycontainer adduser --disabled-password testuser

# STEP 8:
# Alternative method: Enter the container via chroot and manually add testuser.
chroot /mycontainer /bin/bash
adduser --disabled-password testuser
exit



# STEP 9:
# Inside the container, update packages and install Python 3.
sudo chroot /mycontainer
apt update
apt install -y python3


# STEP 10:
# Create a simple HTTP server script (server.py) to respond with "Hello from my woman king!"
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



# STEP 11:
# Set ownership of server.py to testuser (UID 1000) and start the server on port 8000.
chown 1000:1000 /home/testuser/server.py

# Launch the server:
python3 /home/testuser/server.py


