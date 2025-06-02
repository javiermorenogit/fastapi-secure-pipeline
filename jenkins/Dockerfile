# jenkins/Dockerfile

FROM jenkins/jenkins:lts-jdk17

USER root

# Actualizamos apt y agregamos docker.io, git y curl
RUN apt-get update -qq \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
         docker.io \
         git \
         curl \
    && rm -rf /var/lib/apt/lists/* \
    && usermod -aG docker jenkins

USER jenkins
