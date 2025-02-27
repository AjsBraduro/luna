#!/bin/bash
echo ""
echo ""
echo "Current user:"
whoami
echo ""
echo ""
# Stop any existing cloudflared process
pkill cloudflared
# Uncomment the following line if you want to Update and install dependencies
# sudo apt update && sudo apt --fix-broken install -y && sudo apt install -f -y && sudo apt install -y docker.io wget && sudo apt autoremove -y && sudo apt upgrade -y
# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 
IMAGE_NAME="xfce-vnc-image"
CONTAINER_NAME="xfce-vnc-container"
IMAGE_FILE="$SCRIPT_DIR/$IMAGE_NAME"
PERSISTENT_VOLUME="$SCRIPT_DIR/persistent_data" # Directory for persistent storage
# Create the persistent volume directory if it doesn't exist
mkdir -p "$PERSISTENT_VOLUME"
# Function to check if Docker is installed and running
check_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker before running this script."
        exit 1
    fi
    if ! docker info &> /dev/null; then
        echo "Docker is not running. Please start the Docker service."
        exit 1
    fi
}
# Function to stop and remove the existing container
stop_and_remove_container() {
    if docker ps -a --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo "Stopping and removing container $CONTAINER_NAME..."
        docker stop "$CONTAINER_NAME" || true
        docker rm "$CONTAINER_NAME" || true
    fi
}
# Function to save the container state as an image
save_container_state() {
    if docker ps -a --format "{{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        echo "Saving the state of container $CONTAINER_NAME to an image..."
        docker commit "$CONTAINER_NAME" "$IMAGE_NAME" || { echo "Error creating the image."; exit 1; }
        docker save "$IMAGE_NAME" -o "$IMAGE_FILE" || { echo "Error saving the image."; exit 1; }
        echo "Image saved to $IMAGE_FILE"
    else
        echo "Container $CONTAINER_NAME does not exist. Its state cannot be saved."
    fi
}
# Function to load the image and run the container with Docker-in-Docker support
load_image_and_run_container() {
    if [ -f "$IMAGE_FILE" ]; then
        echo "Loading image from $IMAGE_FILE..."
        docker load < "$IMAGE_FILE" || { echo "Error loading the image."; exit 1; }
        echo "Running container from the loaded image with Docker-in-Docker support..."
        docker run -d \
            -p 8080:8080 \
            -p 5901:5901 \
            --name "$CONTAINER_NAME" \
            --privileged \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$PERSISTENT_VOLUME:/home/HoneyPot/persistent_data" \
            --security-opt seccomp=unconfined \
            "$IMAGE_NAME" || { echo "Error starting the container."; exit 1; }
    else
        echo "Image not found at $IMAGE_FILE. Creating a new container..."
        DOCKERFILE_DIR="$HOME/everyone"
        mkdir -p "$DOCKERFILE_DIR"
        if [ ! -f "$DOCKERFILE_DIR/Dockerfile" ]; then
            cat << 'EOF' > "$DOCKERFILE_DIR/Dockerfile"
FROM debian:latest
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
   xfce4 \
   xfce4-goodies \
   sudo \
   tightvncserver \
   xauth \
   x11-utils \
   wget \
   neofetch \
   vim \
   nano \
   htop \
   curl \
   git \
   novnc \
   websockify \
   dbus-x11 \
   firefox-esr \
   docker.io \
   && apt-get clean \
   && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash HoneyPot && echo "HoneyPot:P0p00909" | chpasswd && usermod -aG sudo HoneyPot
RUN mkdir /home/HoneyPot/.vnc && \
   echo "P0p00909" | vncpasswd -f > /home/HoneyPot/.vnc/passwd && \
   chown -R HoneyPot:HoneyPot /home/HoneyPot/.vnc && chmod 600 /home/HoneyPot/.vnc/passwd
RUN mkdir -p /home/HoneyPot/Desktop
RUN echo '#!/bin/sh\nxrdb $HOME/.Xresources\nstartxfce4 &\nsetxkbmap en\n' > /home/HoneyPot/.vnc/xstartup && \
   chmod +x /home/HoneyPot/.vnc/xstartup && chown HoneyPot:HoneyPot /home/HoneyPot/.vnc/xstartup
RUN echo '[Desktop Entry]\nVersion=1.0\nName=Firefox\nComment=Web browser\nExec=firefox\nIcon=firefox\nTerminal=false\nType=Application\nCategories=Network;WebBrowser;\n' > /home/HoneyPot/Desktop/firefox.desktop && \
   chmod +x /home/HoneyPot/Desktop/firefox.desktop && chown HoneyPot:HoneyPot /home/HoneyPot/Desktop/firefox.desktop
RUN apt-get update && apt-get install -y extrepo && \
   extrepo enable librewolf && \
   apt-get update && apt-get install -y librewolf
RUN echo '[Desktop Entry]\nVersion=1.0\nName=LibreWolf\nComment=Privacy-focused web browser\nExec=librewolf\nIcon=librewolf\nTerminal=false\nType=Application\nCategories=Network;WebBrowser;\n' > /home/HoneyPot/Desktop/librewolf.desktop && \
   chmod +x /home/HoneyPot/Desktop/librewolf.desktop && chown HoneyPot:HoneyPot /home/HoneyPot/Desktop/librewolf.desktop
EXPOSE 5901 8080
CMD ["sh", "-c", "service dbus start && su - HoneyPot -c 'vncserver :1 -geometry 1920x1080 -depth 24 && websockify --web /usr/share/novnc/ 8080 localhost:5901'"]
EOF
        fi
        docker build -t "$IMAGE_NAME" "$DOCKERFILE_DIR" || { echo "Error building the image."; exit 1; }
        docker run -d \
            -p 8080:8080 \
            -p 5901:5901 \
            --name "$CONTAINER_NAME" \
            --privileged \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$PERSISTENT_VOLUME:/home/HoneyPot/persistent_data" \
            --security-opt seccomp=unconfined \
            "$IMAGE_NAME" || { echo "Error starting the container."; exit 1; }
    fi
}
# Check Docker, stop and remove the container, and load/run the container
check_docker
stop_and_remove_container
# Uncomment the following line if you want to save the container state
# save_container_state
load_image_and_run_container
# Install and configure Cloudflare Tunnel
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
sudo cp cloudflared /usr/local/bin/
sudo chmod +x /usr/local/bin/cloudflared
cloudflared tunnel --url localhost:8080 > output.txt 2>&1 & disown
# Wait for Cloudflare Tunnel URL
max_attempts=15
attempt=0
url=""
while [ -z "$url" ] && [ $attempt -lt $max_attempts ]; do
    sleep 2
    url=$(grep -oP '(?<=\|  )https://\S+' output.txt | head -n1)
    attempt=$((attempt + 1))
done
if [ -n "$url" ]; then
    echo ""
    echo "Cloudflare Tunnel URL: $url"
    echo "$url" > urlcloudflareremote.txt
    echo "URL saved in: $(pwd)/urlcloudflareremote.txt"
    echo ""
else
    echo "Error: Could not obtain the Cloudflare Tunnel URL."
    exit 1
fi
echo "Setup complete. The container is running."
echo ""
echo "Stop cloudflared:"
echo "pkill cloudflared"
echo ""
echo "Delete Container:"
echo "docker stop $CONTAINER_NAME && docker rm $CONTAINER_NAME"
echo ""
echo "To transfer files to the container:"
echo "docker cp filePath $CONTAINER_NAME:/home/HoneyPot"
echo ""
echo "To transfer files to the host machine:"
echo "docker cp $CONTAINER_NAME:/home/HoneyPot/fileName localDestinationPath"
echo ""
echo "Access the container:"
echo "docker exec -it $CONTAINER_NAME /bin/bash"
