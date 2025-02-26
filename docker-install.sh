#!/bin/sh

set -e

# Function to run commands with sudo if not root
run_with_sudo() {
  if [ "$(id -u)" -ne 0 ]; then
    sudo "$@"
  else
    "$@"
  fi
}

# Variable to keep track of packages installed by the script
installed_packages=""

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

package_installed() {
  if command_exists apk; then
    apk info --installed "$1" >/dev/null 2>&1
  elif command_exists dpkg-query; then
    dpkg-query -l "$1" >/dev/null 2>&1
  else
    echo "Unsupported package manager."
    exit 1
  fi
}

# Function to install a package using apk (Alpine Linux)
install_package_apk() {
  if ! package_installed "$1"; then
    run_with_sudo apk add --no-cache "$1"
    if [ "$2" != "true" ]; then
      echo "Adding $1 to installed packages..."
      installed_packages="${installed_packages} $1"
    fi
  fi
}

# Function to install a package using apt (Debian/Ubuntu)
install_package_apt() {
  if ! package_installed "$1"; then
    run_with_sudo apt-get install -y -qq "$1"
    if [ "$2" != "true" ]; then
      echo "Adding $1 to installed packages..."
      installed_packages="${installed_packages} $1"
    fi
  fi
}

# Function to install a package using the appropriate package manager
install_package() {
  if command_exists apk; then
    install_package_apk "$1" "$2"
  elif command_exists apt-get; then
    install_package_apt "$1" "$2"
  else
    echo "Unsupported package manager."
    exit 1
  fi
}

install_gcloud() {
  echo "Installing Google Cloud SDK..."

  install_package curl
  install_package bash
  install_package python3 true

  curl -sSL https://sdk.cloud.google.com | bash

  /root/google-cloud-sdk/bin/gcloud components install beta gke-gcloud-auth-plugin --quiet

  echo "export PATH=\$PATH:/root/google-cloud-sdk/bin" >> ~/.bashrc

  echo "Google Cloud SDK installed successfully.\n"
}

# Update apt package index
if command_exists apt-get; then
  echo "Updating package index..."
  run_with_sudo apt-get update -qq
fi

# Parse arguments
install_gcloud=false

for arg in "$@"; do
  case "$arg" in
    --gcloud)
      install_gcloud=true
      ;;
    *)
      ;;
  esac
done

# Install Google Cloud SDK if --gcloud argument is present
if $install_gcloud; then
  install_gcloud
fi

# Uninstall temporary packages
for pkg in $installed_packages; do
  echo "Removing $pkg..."
  if command_exists apk; then
    run_with_sudo apk del "$pkg"
  elif command_exists apt-get; then
    run_with_sudo apt-get purge -y -qq "$pkg"
    run_with_sudo apt-get autoremove -y -qq
  fi
done

echo "Script executed successfully."
