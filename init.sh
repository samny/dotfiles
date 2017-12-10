#!/bin/bash

sudo add-apt-repository ppa:neovim-ppa/stable
sudo apt update
sudo apt upgrade
sudo apt install -y neovim mosh zsh tmux python-dev python-pip python3-dev python3-pip silversearcher-ag

curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

rm -rf ~/.vim ~/.vimrc ~/.zshrc ~/.tmux ~/.tmux.conf

mkdir -p ~/.config ~/.config/nvim
ln -s ~/dotfiles/zshrc ~/.zshrc
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
ln -s ~/dotfiles/vimrc ~/.config/nvim/init.vim

echo "export SHELL=`which zsh`" >> ~/.profile
echo "[ -z \"$ZSH_VERSION\" ] && exec \"$SHELL\" -l" >> ~/.profile
