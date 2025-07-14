FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    python3 \
    python3-pip \
    systemd \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd
RUN ssh-keygen -A

RUN useradd -m -s /bin/bash ansible
RUN echo 'ansible:ansible' | chpasswd
RUN usermod -aG sudo ansible

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN echo 'ansible ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

RUN apt-get update && apt-get install -y \
    iproute2 \
    iptables \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

RUN echo '#!/bin/bash\n\
# Create log file if it doesn'\''t exist\n\
touch /var/log/auth.log\n\
# Start SSH service\n\
service ssh start\n\
# Keep container running - sleep instead of tail to avoid issues\n\
while true; do\n\
  sleep 60\n\
  # Check if SSH is still running, restart if needed\n\
  if ! service ssh status > /dev/null 2>&1; then\n\
    echo "SSH service not running, restarting..."\n\
    service ssh start\n\
  fi\n\
done' > /start.sh
RUN chmod +x /start.sh

EXPOSE 22

CMD ["/start.sh"] 