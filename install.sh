#!/usr/bin/env bash
# ============================================================================
#  Arch Linux Post-Install Bootstrap Script
#  Run after a fresh Arch install to get up and running quickly.
#  Usage: curl -fsSL <your-raw-github-url> | bash
#     or: chmod +x install.sh && ./install.sh
# ============================================================================

set -euo pipefail

# --- Colors -----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR ]${NC}  $*" >&2; }

# --- Pre-flight checks ------------------------------------------------------
if [[ $EUID -eq 0 ]]; then
    err "Don't run this as root. Run as your normal user (sudo will be used when needed)."
    exit 1
fi

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Arch Linux Post-Install Bootstrap Script   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
echo ""

# --- System Update ----------------------------------------------------------
info "Updating system..."
sudo pacman -Syu --noconfirm
ok "System updated."

# --- Essential Packages -----------------------------------------------------
info "Installing essential packages..."
sudo pacman -S --noconfirm --needed \
    base-devel \
    git \
    curl \
    wget \
    unzip \
    zip \
    p7zip \
    htop \
    btop \
    fastfetch \
    man-db \
    man-pages \
    openssh \
    networkmanager \
    bluez \
    bluez-utils \
    pipewire \
    pipewire-alsa \
    pipewire-pulse \
    pipewire-jack \
    wireplumber \
    liblc3 \
    xdg-user-dirs \
    xdg-utils \
    reflector \
    fzf \
    ripgrep \
    fd \
    bat \
    eza \
    zoxide \
    tldr \
    tree \
    jq \
    less
ok "Essential packages installed."

# --- Enable Core Services ---------------------------------------------------
info "Enabling core services..."
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
sudo systemctl enable --now sshd 2>/dev/null || true
ok "Core services enabled."

# --- Create XDG User Directories -------------------------------------------
info "Creating user directories..."
xdg-user-dirs-update
ok "User directories created."

# --- Optimise Mirrors with Reflector ----------------------------------------
info "Optimising pacman mirrors (this may take a moment)..."
sudo reflector --country Australia --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist 2>/dev/null || warn "Reflector failed — mirrors unchanged."
ok "Mirrors optimised."

# --- Enable Parallel Downloads in pacman ------------------------------------
info "Enabling parallel downloads in pacman..."
sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
ok "Parallel downloads enabled."

# --- Enable multilib repo ---------------------------------------------------
info "Enabling multilib repository..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
    sudo pacman -Sy --noconfirm
fi
ok "Multilib enabled."

# --- Install yay (AUR helper) -----------------------------------------------
if ! command -v yay &>/dev/null; then
    info "Installing yay (AUR helper)..."
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    (cd /tmp/yay-bin && makepkg -si --noconfirm)
    rm -rf /tmp/yay-bin
    ok "yay installed."
else
    ok "yay already installed."
fi

# --- Development Tools ------------------------------------------------------
info "Installing development tools..."
sudo pacman -S --noconfirm --needed \
    vim \
    neovim \
    tmux \
    python \
    python-pip \
    nodejs \
    npm \
    rustup \
    docker \
    docker-compose \
    lazygit
ok "Development tools installed."

# --- Rust Toolchain ---------------------------------------------------------
info "Setting up Rust toolchain..."
rustup default stable 2>/dev/null || true
ok "Rust toolchain ready."

# --- Docker -----------------------------------------------------------------
info "Setting up Docker..."
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
ok "Docker enabled (re-login for group change to take effect)."

# --- Fonts ------------------------------------------------------------------
info "Installing fonts..."
sudo pacman -S --noconfirm --needed \
    ttf-jetbrains-mono-nerd \
    ttf-firacode-nerd \
    noto-fonts \
    noto-fonts-cjk \
    noto-fonts-emoji \
    ttf-liberation
ok "Fonts installed."

# --- Firewall ---------------------------------------------------------------
info "Setting up firewall (ufw)..."
sudo pacman -S --noconfirm --needed ufw
sudo systemctl enable --now ufw 2>/dev/null || true
sudo ufw default deny incoming 2>/dev/null || true
sudo ufw default allow outgoing 2>/dev/null || true
sudo ufw enable 2>/dev/null || true
ok "Firewall configured."

# --- Shell Setup (zsh + oh-my-zsh) ------------------------------------------
info "Installing zsh..."
sudo pacman -S --noconfirm --needed zsh
if [[ "$SHELL" != *"zsh"* ]]; then
    sudo chsh -s "$(which zsh)" "$USER"
    ok "Default shell changed to zsh (takes effect on next login)."
fi

if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
    ok "Oh My Zsh installed."
fi

# --- Useful zsh plugins (via yay) -------------------------------------------
info "Installing zsh plugins..."
yay -S --noconfirm --needed \
    zsh-autosuggestions \
    zsh-syntax-highlighting 2>/dev/null || true

# Configure zsh plugins
if [[ -f "$HOME/.zshrc" ]] && ! grep -q "zsh-autosuggestions" "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'EOF'

# Plugins
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF
fi

# Alias neofetch to fastfetch (neofetch is archived and removed from repos)
if [[ -f "$HOME/.zshrc" ]] && ! grep -q "alias neofetch" "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" << 'EOF'

# neofetch was removed from Arch repos — use fastfetch instead
alias neofetch='fastfetch'
EOF
fi
ok "Zsh plugins installed."

# --- Git Config Reminder ----------------------------------------------------
warn "Don't forget to configure git:"
echo "       git config --global user.name \"Your Name\""
echo "       git config --global user.email \"you@example.com\""

# ============================================================================
#  OPTIONAL SECTIONS — Uncomment what you want
# ============================================================================

# --- Desktop Environment (uncomment ONE) ------------------------------------
# info "Installing GNOME..."
# sudo pacman -S --noconfirm gnome gnome-tweaks gdm
# sudo systemctl enable gdm

# info "Installing KDE Plasma..."
# sudo pacman -S --noconfirm plasma-meta kde-applications-meta sddm
# sudo systemctl enable sddm

# info "Installing Hyprland (Wayland tiling WM)..."
# sudo pacman -S --noconfirm hyprland kitty waybar wofi swaybg swaylock grim slurp
# yay -S --noconfirm hyprpaper

# --- GUI Applications (uncomment to enable) ---------------------------------
# info "Installing GUI apps..."
# sudo pacman -S --noconfirm --needed \
#     firefox \
#     thunar \
#     vlc \
#     obs-studio \
#     gimp \
#     libreoffice-fresh \
#     discord
# yay -S --noconfirm --needed \
#     visual-studio-code-bin \
#     spotify \
#     google-chrome

# --- Gaming -----------------------------------------------------------------
info "Installing gaming packages..."
sudo pacman -S --noconfirm --needed \
    steam \
    lutris \
    wine-staging \
    gamemode \
    lib32-mesa \
    vulkan-icd-loader \
    lib32-vulkan-icd-loader \
    vulkan-tools \
    lib32-pipewire

yay -S --noconfirm --needed \
    protonup-qt \
    mangohud \
    lib32-mangohud

# Add user to gamemode group
sudo usermod -aG gamemode "$USER"
ok "Gaming packages installed."

# --- NVIDIA Drivers (RTX 3090 Ti) -------------------------------------------
info "Installing NVIDIA drivers for RTX 3090 Ti..."
sudo pacman -S --noconfirm \
    nvidia \
    nvidia-utils \
    nvidia-settings \
    lib32-nvidia-utils \
    opencl-nvidia \
    lib32-opencl-nvidia

# Enable nvidia-drm modeset (needed for Wayland compositors)
if [[ -f /etc/default/grub ]]; then
    info "Configuring GRUB for NVIDIA..."
    if ! grep -q "nvidia-drm.modeset=1" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/&nvidia-drm.modeset=1 /' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        ok "GRUB configured for NVIDIA."
    fi
fi

# Add nvidia modules to mkinitcpio
if [[ -f /etc/mkinitcpio.conf ]]; then
    info "Adding NVIDIA modules to initramfs..."
    if ! grep -q "nvidia" /etc/mkinitcpio.conf; then
        sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
        sudo mkinitcpio -P
        ok "Initramfs updated with NVIDIA modules."
    fi
fi

# Enable NVIDIA power management services
sudo systemctl enable nvidia-suspend.service 2>/dev/null || true
sudo systemctl enable nvidia-hibernate.service 2>/dev/null || true
sudo systemctl enable nvidia-resume.service 2>/dev/null || true

ok "NVIDIA drivers installed and configured."

# ============================================================================

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Bootstrap complete! 🎉               ║${NC}"
echo -e "${GREEN}║                                              ║${NC}"
echo -e "${GREEN}║  IMPORTANT - Next Steps:                     ║${NC}"
echo -e "${GREEN}║  • REBOOT to load NVIDIA drivers             ║${NC}"
echo -e "${GREEN}║  • Log out/in for group changes (docker,     ║${NC}"
echo -e "${GREEN}║    gamemode)                                 ║${NC}"
echo -e "${GREEN}║  • Set up your git config                    ║${NC}"
echo -e "${GREEN}║  • Run 'nvidia-smi' to verify GPU           ║${NC}"
echo -e "${GREEN}║  • Uncomment a DE section if needed          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""