#!/bin/bash

# Check for required tools
for cmd in debootstrap cgexec ip; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd is not installed. Please run: sudo apt install -y debootstrap cgroup-tools iproute2"
        exit 1
    fi
done

# Step 1: Setup filesystem
echo "Setting up filesystem..."
sudo mkdir -p /mycontainer
if ! sudo debootstrap --arch=amd64 noble /mycontainer http://archive.ubuntu.com/ubuntu/; then
    echo "Error: debootstrap failed. Check network or try a different mirror."
    exit 1
fi

# Step 2: Configure cgroups (v2)
echo "Configuring cgroups..."
sudo mkdir -p /sys/fs/cgroup/mycontainer
echo "+cpu +memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control
echo "500000 1000000" | sudo tee /sys/fs/cgroup/mycontainer/cpu.max
echo "256M" | sudo tee /sys/fs/cgroup/mycontainer/memory.max
echo "8:0 wbps=1048576" | sudo tee /sys/fs/cgroup/mycontainer/io.max


# Step 3: Setup networking
echo "Setting up networking..."
HOST_IFACE=$(ip link | grep -o 'ens[0-9]*' | head -n1)  # Detect EC2 interface (e.g., ens5)
if [ -z "$HOST_IFACE" ]; then
    HOST_IFACE="eth0"  # Fallback
fi
sudo ip netns add mycontainer
sudo ip link add veth-host type veth peer name veth-container
sudo ip link set veth-container netns mycontainer
sudo ip addr add 192.168.1.1/24 dev veth-host
sudo ip link set veth-host up
sudo ip netns exec mycontainer ip addr add 192.168.1.2/24 dev veth-container
sudo ip netns exec mycontainer ip link set veth-container up
sudo ip netns exec mycontainer ip route add default via 192.168.1.1
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o "$HOST_IFACE" -j MASQUERADE

# Step 4: Create testuser
echo "Creating testuser..."
sudo chroot /mycontainer adduser --disabled-password --gecos "" testuser
sudo chroot /mycontainer usermod -aG sudo testuser
echo "testuser ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /mycontainer/etc/sudoers

# Step 5: Deploy application
echo "Deploying application..."
cat << 'EOF' | sudo tee /mycontainer/home/testuser/server.py
from http.server import HTTPServer, BaseHTTPRequestHandler
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"Hello from my container!")
HTTPServer(("", 8000), Handler).serve_forever()
EOF
sudo chown 1000:1000 /mycontainer/home/testuser/server.py

# Step 6: Launch container
echo "Launching container..."
sudo cgexec -g cpu,memory:/mycontainer ip netns exec mycontainer unshare --pid --user --mount --fork --map-root-user /bin/bash -c "
    mount -t proc proc /mycontainer/proc
    mount -t sysfs sys /mycontainer/sys
    mount --bind /dev /mycontainer/dev
    chroot /mycontainer su - testuser -c 'python3 /home/testuser/server.py'
" &
echo "Container started. Test it with: curl 192.168.1.2:8000"





